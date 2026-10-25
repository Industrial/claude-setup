---
name: designing-with-id-effect
description: >-
  The design methodology for building software on id_effect 0.12+ — Effect<A, E, R>
  edge/core structure, capability and Layer design, error doctrine, concurrency and
  resource rules, the testing grammar, host-framework seams (e.g. NautilusTrader),
  anti-patterns, and the 0.13 "Breadth" delta. Use when designing, structuring, or
  reviewing any code that uses id_effect, deciding what becomes an Effect, modelling
  capabilities or errors, or embedding id_effect in a framework that owns its own
  event loop.
---

# Designing with id_effect — The Method

Authoritative design doctrine for id_effect **0.12** (0.13 "Breadth" unreleased; §15).
Full guide with diagrams: https://claude.ai/code/artifact/62da738d-b744-428f-b901-4f68fdaabda1
Sources: the mdbook shipped inside the `id_effect` crate (parts I–VII + idiom guide),
the nautilus-trader seam, and the `release/0.13.0` branch of Industrial/id_effect.

**The method in one sentence:** describe the whole program as a lazy value, name every
dependency in its type, provide everything once at the edge, run exactly there — so the
pure core stays plain Rust and tests own time, randomness and failure.

## 1. Mental model (everything follows from these)

`Effect<A, E = Never, R = HNil>` is a **description** (recipe, not cake).

- **Lazy** — nothing runs before a run edge; the API difference from `async fn` is what you return.
- **One-shot** — running consumes it; anything that re-runs (`Effect::retry`, `Effect::repeat`,
  `Layer::effect`, supervision) takes a **factory** `Fn() -> Effect`.
- **Typed requirements** — `R` is an HList (`caps!(Db, Logger)` = `HCons<Db, HCons<Logger, HNil>>`);
  a missing capability is a compile error naming it. No container, no registration, no reflection.
- **Send, on fibers** — executor owns the clock (every sleep/timeout/retry delay/pool TTL).
  `LocalEffect` is the `!Send` sibling, same combinators.

Outcome: `Exit<A, E>` = `Success(A) | Failure(Cause<E>)`.
`Cause`: `Fail(E)` (planned, handleable) · `Die(Defect)` (bug: panic or `die(..)` — never retried,
never caught by `catch`, never compensated) · `Interrupt(FiberId)` (finalizers run, fiber stops)
· `Both`/`Then` composites. **Defects are for bugs, not domain failures.**

Run edges (the only places side effects begin): `eff.block_on()` (`R = HNil` only; refuses
inside async with a `BlockOnInAsync` defect), `Runtime::global().run(eff).await`,
`run_main(eff, env, cfg)` in a CLI `main`, `run_test(eff)` / `fork_root(test_executor)` in
tests, or a host (Axum route, RPC procedure, job worker — one fiber per request; disconnect
interrupts it).

## 2. The shape of a program

**Describe in the core, provide and run at the edge.** Library code never constructs
dependencies and never runs effects; `main` is a thin shell (parse argv → wire layers →
one `provide_layer` → run).

Code becomes an `Effect` only when it (a) does I/O, (b) reads a capability, or (c) is the
program edge. Everything else stays a plain function: parsing, validation, decisions,
error classification. Canonical phrasing: "only the read does I/O, so only the read is an
effect" — that split keeps the parse tests free of wiring.

Decision ladder — stop at the first yes:
1. Pure transformation? → plain function (most code).
2. One small linear async call nobody substitutes? → plain `async fn`; lift with `from_async` when needed.
3. I/O, dependency, policy (retry/timeout/span), or test substitution? → `Effect<A, E, R>`.
4. `!Send` value held across an await? → `LocalEffect`; lift Send arms via `.into_local()`.
5. Many values over time? → `Stream<A, E, R>`.
6. Long-lived stateful entity / must survive crashes? → `Process` under supervision; durable → `id_effect_workflow`.

**R is compiler-enforced documentation**: adding a capability inside a body forces it into
the signature, so dependency changes are visible in diffs.

`effect!` rules (idiom guide): one `effect!` per function, full return type written out
(macro takes `E`/`R` from it); `~Cap` reads a capability, `~expr` binds a sub-effect
(errors widen via `From`), `~(a, b)` joins in parallel; `?` works on `Result`s; branch
inside the block; never nest the macro; single step → use the combinator, no macro;
combinators go before the bind (`~fetch(x).timeout(d)`); borrowed sub-effects are built
before the macro (the body is `'static`).

## 3. Capabilities

A capability is any `Send + Sync + 'static` type; the type is its identity. Pick the
LEAST machinery that is honest:

| Shape | When |
|---|---|
| Plain value (`VenueSpec`) | Pure, owned, trivially constructible — tests provide a real one. "A trait would buy indirection and nothing else." |
| Role newtype (`MainDb(Pool)` / `CacheDb(Pool)`) | Two capabilities would share a Rust type — swap becomes a type error |
| Trait + newtype (`Users(pub Arc<dyn UserRepo>)`) | Implementations genuinely differ (live vs in-memory). Trait methods return `Effect<A, E>` with `R = HNil`; shape the port to the caller ("one method, because one is all a configuration needs") |
| Generic over `R` (`where R: Selector<Cap, I>` + `need::<Cap>()`) | Library code that must not fix the caller's env |
| `DynEnv` + `try_need` | Capability set genuinely dynamic (plugins, per-request) — fails typed, never panics |

Canonical capability module (nautilus pattern): pure value object + its "id_effect face":

```rust
pub type VenueEnv = HCons<VenueSpec, HNil>;
pub fn layer<E: Send + 'static>(spec: VenueSpec) -> Layer<VenueEnv, E> {
  Layer::succeed(HCons::new(spec, HNil))
}
pub fn venue() -> Effect<Venue, Never, VenueEnv> {       // reading cannot fail — Never
  need::<VenueSpec>().map(|spec| spec.venue())
}
```

Read with `~Cap` / `need::<T>()`; no `get_mut` — mutable state uses `Ref`/`SynchronizedRef`/STM.
Provide with `.provide(v)` / `.provide_env(hlist![..])` / `.provide_layer(layer)` — once,
at the edge, never deep in the call graph. Anti-patterns: god traits (one `AppService`),
tuple environments, two same-type capabilities, `#[derive(ProviderSpec)]` for dependent
capabilities (its `layer()` cannot take arguments — hand-write a value-taking `layer(spec)`).

## 4. Layers

"Effects declare needs; layers declare construction." `Layer<Out, E, In>` is a lazy,
compiler-checked construction graph — no runtime planner.

- Constructors: `Layer::succeed(hlist![..])` (ready values), `Layer::effect(|| eff)`
  (effectful, factory per build), `Layer::acquire_release(acq, rel)` (release on scope
  close, every exit kind), `Layer::scoped(|scope| ..)`.
- Composition: `a.merge(b)` (side by side), `base.provide_to(upper)` (base private),
  `upper.provide_merge(base)` (keep both), `layer.launch()` (alive until interrupted),
  `build_scoped(&scope)`.
- **Memoisation is by layer VALUE (Arc pointer), not type**: two calls of a layer-returning
  fn build twice. Bind once, clone everywhere; `.fresh()` opts out. Two layers producing
  the same capability type panic at wiring (deliberately, at startup) — newtype one side.
  `Layer::from_effect` dies on a second build — prefer `Layer::effect`.
- Decision: values/tests → `.provide`; effectful/dependent/resource construction → layer
  graph + one `provide_layer` at the edge; daemon → `launch()`; dynamic set → `DynEnv`.

## 5. Errors

- One error enum per boundary (`Debug, PartialEq, Eq, Hash`; actionable `Display`).
- **Variants split by caller response, not source** — four HTTP failure modes are one
  variant when the caller's options are identical ("retry later, or stop"); a failure
  handled differently gets its own variant (skip-this-market vs abort-the-run).
- `impl From<Inner> for Outer` per lower error so `~` widens silently; `Never` for the
  infallible ("the honest answer"); `err!(A | B)` only for one-off pairs — a named enum
  once a third case appears (`Or<A, Or<B, C>>` reads badly in signatures and matches).
- Recovery, narrowest tool first: `.map_err` (rewrite) → `.catch` (recover/route — may
  re-`fail` transient errors and log-and-`succeed` permanent ones: "caught and logged,
  not swallowed, and not fatal") → `.exit()` only to observe defects/interrupts, never
  to swallow them.
- Accumulation: map items to `item.exit()`, run `all(..)`, split afterwards — decide
  explicitly whether a defect aborts the batch.

## 6. Concurrency & resources

- Structured: a forked child is interrupted AND awaited when its parent exits;
  `fork_daemon` is the explicit opt-out; dropping a `FiberHandle` does NOT interrupt.
- Say what you mean: `~(a, b)` / `zip_par`; `all` / `for_each_par` with
  `Concurrency::{Sequential, Bounded(n), Unbounded, Inherit}`; `race` (first success),
  `race_first` (first completion), `timeout(d)`. Losers are interrupted and awaited.
- Interruption lands at suspension points — no cancellation tokens. A pure loop inside
  one `sync(..)` closure is uninterruptible: chunk it or `yield_fiber()`.
- Resources — every path releases: one use → `acquire_use_release`; several/mid-body →
  `Effect::scoped` + `add_finalizer` (LIFO, every exit kind); non-resource cleanup →
  `.ensuring`; app lifetime → `Layer::acquire_release`; reusable connections → `Pool`
  (checkout registers its own give-back finalizer). Finalizers are
  `Effect<(), Never, HNil>` — handle their errors inside them.
- Supervision ladder (pick the lowest layer covering the failure domain): core
  `supervised`/`Supervisor` (restarts defects too; interrupts never) →
  `id_effect_process` OTP trees → `DistributedSupervisor`.

## 7. Time, retries, schedules

Time belongs to the executor — no clock capability, so time-based code is deterministic
in tests by construction.

```rust
Effect::retry(
    || fetch(x).timeout_fail(ms(800), || E::Timeout),   // per-attempt timeout inside
    Schedule::exponential(ms(100))
        .intersect(Schedule::recurs(4))                  // ALWAYS bound the schedule
        .jittered(),
).timeout(secs(10))                                      // overall timeout outside
```

Factories, never hand-written retry loops. Retry steps on typed failure only (defects and
interrupts never). Retry transient faults; **circuit-break downed dependencies**
("retrying a dependency that is down makes the outage worse") — `retry_with_breaker` or a
resilience `Pipeline` (one pipeline value per dependency; clones share breaker state).
Cron via `Schedule::cron`/`CronRegistry`; cluster-wide once-per-tick needs `CronLeader`
over a CP lease.

## 8. Data at boundaries — parse, don't validate

All external data enters as `Unknown`; a `Schema` (bidirectional codec) turns it into a
trusted type in one step; nothing beyond the parse boundary sees `Unknown`. Refinements
both enforce and export (JSON Schema/OpenAPI come from the same values that decode — the
contract cannot drift). `Brand`/`RefinedBrand` make validation stick in the type system;
`Secret<T>`/`Redacted<T>` print `<redacted>`, `.expose()` only at point of use. Fail-fast
`decode` for control flow; `decode_unknown_all → ParseErrors` to report every issue with
paths. Never raw serde_json at a boundary; never deserialize-then-validate.

## 9. Streams & shared state

- "How many values?" One → Effect; zero-or-more over time → `Stream` (pull-based, chunked,
  lazy, interruptible).
- Backpressure exists only at the push/pull edge: `BoundedBlock` (lose nothing) /
  `DropOldest` (freshest wins) / `DropNewest` / `Fail` (overflow is a bug) — choose per source.
- **Bad records are values, not stream failures** (a stream ends at its first error):
  parse to `Option`/`Result` items and filter.
- `map_effect_par(n, f)` bounds in-flight work, preserves output order. Windows are
  element-timestamped (deterministic). Prove memory bounds: infinite source + `take(n)` —
  a stage that drains its input hangs instead of passing.
- State: one value → `Ref`/`SynchronizedRef`; multiple related values / composed
  invariants → STM (`TRef`, `TQueue`, `TMap` + `commit`; retrying transactions park the
  fiber; `or_else` fires on retry). **STM transactions must not span I/O** (bodies rerun).
  Bounding concurrent effects → core `Semaphore::with_permit`, not `TSemaphore`.

## 10. Testing

The test decides how effects run. No mocking frameworks, no registries, no test-only
constructors. Grammar: **build → provide fakes → run_test → assert on the Exit.**

```rust
use id_effect::testing::{run_test, assert_exit_success, expect_exit_failure};
assert_exit_success(&run_test(venue().provide(spec())), &Venue::from("BINANCE"));
let e = expect_exit_failure(run_test(load(p).provide_layer(test_layer(fs))));
assert!(matches!(e, ConfigError::Unreadable { .. }));
```

- `run_test` forks on a fresh `TestExecutor`, jumps the clock timer-to-timer, panics on
  deadlock. Exit assertions are `#[track_caller]` and see inside composite causes.
  **Assert on the Exit, not on logs.** Golden files: `assert_golden_exit` + `ID_EFFECT_BLESS=1`.
- Fakes are values behind the same trait; make them faithful (assert the fake's error
  text equals the real one's).
- Own every axis of nondeterminism: time (`advance`, exact-duration assertions —
  exponential(10ms)×recurs(3) is exactly 70ms), randomness (`TestRandom::seeded`),
  interleavings (`TestExecutor::seeded` + `explore_interleavings`; pin failing seeds),
  faults (`FaultPlan::seeded` injected INSIDE the retry factory; replay by seed),
  properties (`prop_check`, `from_schema` generators, `run_state_machine`),
  real dependencies (`id_effect_test` containers as scoped layers, `isolated_db()` /
  `TemplateDb`, `TestClient`, contract tests against the generated OpenAPI).
- **Isolate the untestable**: every network-touching call in its own tiny coverage-exempt
  file behind a closure parameter; all decisions behind the closure, tested against fakes.
  Final tier: subprocess tests on the real binary sweeping the exit taxonomy
  (0 success / 1 typed failure / 2 usage / 101 defect / 130 interrupted) and asserting no
  invocation exits with a defect.

## 11. Platform & ecosystem

Recurring shape: every boundary = capability trait + `*Service` newtype + `*Env` alias +
layer, with a live impl and a first-class fake. Crates: core `id_effect`; edge
`id_effect_cli` (run_main, exit taxonomy); `_tokio`; `_platform` (hardened HTTP/fs/process
ports, SSRF guard); `_config` (profiles, `Secret`, Vault); `_sql`/`_redis`/`_storage`;
`_axum`/`_rpc` (typed routes & procedures — an access decision or it doesn't compile;
generated OpenAPI; contract checking); `_jobs`/`_messaging`/`_mail`/`_workflow`/`_events`;
`_process`/`_node` (mesh); `_resilience`, `_logger`, `_opentelemetry`, `_fsm`, `_optics`,
`_fp`, `_test`, `_tool` (the `id-effect` CLI: new/doctor --graph/dev/migrate/rpc);
`id_effect_kit` (front door + posture check + layer graph).

Doctrine: closed by default — every `dangerous_*` opt-out is posture-recorded and must be
accepted in config or prod refuses to start. At-least-once everywhere ⇒ idempotent
handlers (`UniqueKey`, `Inbox`, `Idempotency-Key`, `ActivityContext::idempotency_key`);
side effects commit with the caller's transaction (`enqueue_in`, `Outbox::stage`,
`deliver_later_in`). One id_effect version per build (types don't unify).
**Adopt piecewise — dependency-graph discipline trumps framework completeness** (e.g.
prefer leaf crates over the kit when features don't pay; a 100-line hand-rolled FS
capability beats an unconditional reqwest+TLS dependency for a program with no HTTP).

## 12. Process mesh

Request-scoped computation → Effect; many-values pipeline → Stream; named, addressable,
restartable thing with state → `Process` (OTP: bounded mailboxes that refuse when full,
OneForOne/OneForAll/RestForOne, `Statem` for protocol machines, `Saga` for compensation —
typed failures only); business process surviving deploys → `id_effect_workflow`
(everything nondeterministic through the journaled `WorkflowContext`; replay must be
deterministic). Distributed: process groups are AP (CRDT); **two owners must never
coexist → `ClusterSingleton` with a CP lease**. Mutual TLS by default, no default trust.

## 13. Embedding in a host framework (the seam)

When a framework owns its own event loop (NautilusTrader): draw ONE seam, in writing, in
the workspace manifest, and let every crate obey it. "The host owns the event loop and
the hot path stays plain; everything composed around it — config, wiring, catalog,
session lifecycle, CLI — is an Effect."

- The host's run crosses the seam as **one opaque `sync` step**; everything thread-bound
  lives inside the closure so nothing `!Send` appears in an effect's type.
- `Effect` by default; `LocalEffect` the moment a `!Send` value is held across an await
  ("the grain of the library, not a workaround"); compose via `.into_local()`.
- Never block on async inside an effect ("Cannot start a runtime from within a runtime");
  await async clients via `from_async(move || async move { .. })`.
- Escape hatches return pure values — the capability hands out the spec; the caller
  builds `!Send` config on the engine's thread.
- When a battery's runtime model conflicts (e.g. `run_main`'s `park_on` vs a session
  needing a reactor): **keep the contract, not the function** — the 0/1/101/130 exit
  mapping and Ctrl-C-interrupts-with-finalizers, on your own runtime. Pin it with
  subprocess tests on the real binary.

## 14. Anti-patterns (most have a Dylint lint — wire `id_effect_lints` into CI)

Reusing a run effect · hand-written retry loops · `block_on` in async · `.await` outside
`from_async` · `tokio::spawn`/`thread::spawn`/`thread::sleep`/wall clocks ·
`unwrap`/`panic!`/`println!` in effect code · discarded `.fork()` handles · swallowing
defects/interrupts via `.exit()` · constructing dependencies in library code · `.provide`
deep in the call graph · god traits · tuple envs · same-type capabilities · `DynEnv` for
static sets · layer fns called twice expecting sharing · duplicate capability producers ·
monolithic error enums · stacked `Or` · unbounded schedules · retrying a downed dependency ·
long CPU loops in one `sync` step · blanket `.uninterruptible()` · failing a stream on a
bad record · drain-then-stream · `run_collect` on unbounded input · I/O in STM · raw
serde_json at boundaries · deserialize-then-validate · secrets in logs/globals/durable
queues · editing an applied migration · mock frameworks · asserting on logs · wall-clock
waits in tests · unpinned flaky seeds.

## 15. 0.13 "Breadth" (unreleased — verify against the tag before relying on it)

On `release/0.13.0` (draft PR #121). New: `id_effect_ai` published (chat, Schema-typed
tools, bounded agent loop, embeddings, MCP server/client), `id_effect_admin` (deny-by-
default entity admin), `id_effect_i18n`, axum `ui` (maud+htmx), SQL relations/keyset
pagination/`EntityHooks`+outbox/tenancy. Core: `Effect::any_env` / `LocalEffect::any_env`
replace the `from_ctx` workaround — sweep on upgrade. Enumerated breaks:
`MeshRpcError::PeerSilent` arm, `HostConfig.webtransport`, `CheckArgs.allow_retired`,
`posture::PROBES: [&str; 19]`, the whole `id_effect_ai` reshape. Behaviour changes: WS
control-frame caps, real 0-RTT behind the existing opt-out, same-tick RPC client batching,
mesh heartbeats (upgrade servers before clients). Core+cli-only consumers: near-zero-touch.

## 16. Review checklist

1. Describe in the core, provide once, run at the edge.
2. Pure core stays plain — only the I/O is an effect.
3. Signature = documentation: honest `E` (`Never` when infallible), exact `R`.
4. Capabilities are values first; traits only with something to substitute; newtype roles.
5. One error enum per boundary, variants by caller response, `From` widening; defects = bugs.
6. Every acquisition names its release; finalizers on every exit kind.
7. Factories for re-runs; bound every schedule; timeouts inside and outside; breakers for outages.
8. Parse, don't validate: `Unknown` → Schema → brands; contracts generated, never written.
9. Tests provide fakes, own time, assert on `Exit`; isolate the untestable.
10. Closed by default; every `dangerous_*` posture-recorded and accepted in writing.
11. At the seam: one written rule, host run = one `sync` step, `LocalEffect` for `!Send`
    across await, `from_async` never nested runtimes, keep the exit taxonomy.
12. Adopt the platform piecewise; one id_effect version per build.
