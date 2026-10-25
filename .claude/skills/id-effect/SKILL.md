---
name: id_effect
description: >-
  Router for id_effect Rust skills — Effect<A, E = Never, R = HNil> on a fiber runtime,
  effect!/~ do-notation, typed capability HLists (caps!, need, provide, Layer), streams,
  STM, schema, schedules, deterministic testing. Baseline: id_effect 0.12 (0.13 "Breadth"
  pending). Use when editing id_effect crates, the book, or any consumer. Loads
  sub-skills for depth.
---

# id_effect (Rust) — Router

Quick reference for **id_effect 0.12**. Start with the design methodology, then read the
specialized skill for your task.

> **Start here:** [designing-with-id-effect](../designing-with-id-effect/SKILL.md) — the
> authoritative design method (edge/core shape, capability & Layer design, error doctrine,
> testing grammar, host-framework seams, anti-patterns, 0.13 delta). The sub-skills below
> predate it in places; where they disagree, the design skill and the crate's own book win.

## Pick a skill

| Task | Skill |
|------|-------|
| How to DESIGN with id_effect (start here) | [designing-with-id-effect](../designing-with-id-effect/SKILL.md) |
| Learn Effect / `effect!` / `~` | [id_effect-fundamentals](id_effect-fundamentals/SKILL.md) |
| DI, capabilities, `caps!`, Layers | [id_effect-capabilities](id_effect-capabilities/SKILL.md) |
| Exit, Cause, recovery | [id_effect-errors](id_effect-errors/SKILL.md) |
| Fibers, scopes, Schedule | [id_effect-concurrency](id_effect-concurrency/SKILL.md) |
| Compute Fabric, admission, bulk parallelism | [id_effect-compute-fabric](id_effect-compute-fabric/SKILL.md) |
| STM, `TRef`, transactional collections | [id_effect-stm](id_effect-stm/SKILL.md) |
| Stream, Sink, backpressure | [id_effect-streams](id_effect-streams/SKILL.md) |
| Schema / Unknown parsing | [id_effect-schema](id_effect-schema/SKILL.md) |
| Optics (Lens, Prism) | [id_effect-optics](id_effect-optics/SKILL.md) |
| Parser combinators / Codec | [id_effect-parse](id_effect-parse/SKILL.md) |
| Resilience / batching / breakers | [id_effect-resilience](id_effect-resilience/SKILL.md) |
| `run_test`, TestExecutor, fakes | [id_effect-testing](id_effect-testing/SKILL.md) |
| Tokio, Axum, CLI | [id_effect-integration](id_effect-integration/SKILL.md) |
| FSM, saga, Statem | [id_effect-fsm](id_effect-fsm/SKILL.md) |
| Event sourcing, projections | [id_effect-events](id_effect-events/SKILL.md) |
| Algebra / Foldable (`id_effect_fp`) | [id_effect-algebra](id_effect-algebra/SKILL.md) |
| Platform crates map | [id_effect-platform](id_effect-platform/SKILL.md) |
| Migration from async fn / older versions | [id_effect-migration](id_effect-migration/SKILL.md) |
| PR review | [id_effect-review](id_effect-review/SKILL.md) |

## Effect core (0.12 cheat sheet)

- **`Effect<A, E = Never, R = HNil>`** — lazy, Send, one-shot description on a fiber runtime.
- **Run edges only:** `eff.block_on()` (`R = HNil`; refuses inside async),
  `Runtime::global().run(eff).await`, `run_main(eff, env, cfg)` in `main`,
  `run_test(eff)` in tests. Never run in library code.
- **`effect!({ .. })`** — do-notation: `~Cap` reads a capability, `~expr` binds a
  sub-effect (errors widen via `From`), `~(a, b)` joins in parallel, `?` on `Result`s.
  One `effect!` per function, full return type written out. `effect_local!` for `!Send`.
- **Constructors:** `succeed`, `fail`, `die`, `sync`, `suspend`, `from_async`, `sleep`.
- **Outcome:** `Exit<A, E>` with `Cause::{Fail, Die, Interrupt, Both, Then}` —
  defects are bugs, never domain failures.

## Capability DI (0.12)

| Do | Pattern |
|----|---------|
| Declare needs | `Effect<_, _, caps!(K1, K2)>` — `R` is an HList, type = identity |
| Read | `~Cap` in `effect!`; `need::<T>()` outside; `try_need::<T>()` on `DynEnv` |
| Provide a value | `.provide(v)` / `.provide_env(hlist![..])` — at the edge |
| Provide via construction | `Layer<Out, E, In>`: `Layer::succeed` / `Layer::effect(|| ..)` / `Layer::acquire_release`; compose with `merge` / `provide_to` / `provide_merge`; one `provide_layer` at the edge |
| Same-type roles | Newtype each role (`MainDb(Pool)`, `CacheDb(Pool)`) |
| Swappable impls | Trait + `struct Svc(pub Arc<dyn Trait>)`; methods return `Effect<A, E>` with `R = HNil` |
| Test doubles | `.provide(fake_value)` — no mock machinery |

Memoisation is by layer VALUE: bind a layer once and clone it; two calls of a
layer-returning fn build twice.

## Removed (do not use — 0.6-era DI, gone since 0.7)

- `run_with`, `run_blocking`, `provide!`, `providers!`, `require!`, `mock_capability!`
- `Env` / `ProviderSpec` runtime DI, `CancellationToken`, `TestClock`, old `run_test`
- `#[::id_effect::capability(T)]` key types — a capability is now just a type in `R`

(The current `#[derive(ProviderSpecDerive)]` exists but only for argument-free default
constructions; dependent capabilities hand-write a value-taking `layer(spec)`.)

## Verify

```bash
cargo test --workspace
cargo clippy --workspace -- -D warnings
cargo test -p id_effect --test ui_compile_fail
cd crates/id_effect/book && mdbook build
cargo dylint --all        # id_effect_lints idiom enforcement
```

## Docs

- Book: `crates/id_effect/book/` (ships in the published crate)
- Idiom guide: `book/src/appendix-e-idiom-guide.md`
- Migration: `book/src/appendix-b-migration.md`, `docs/MIGRATION-0.7.md`, `docs/MIGRATION-0.13.md` (pending)
- Design method: [designing-with-id-effect](../designing-with-id-effect/SKILL.md)
