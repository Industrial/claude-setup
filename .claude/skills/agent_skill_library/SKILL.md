---
name: agent_skill_library
description: >-
  Index of the 183 skills held off the session roster — the full tree lives in
  .claude/skills/ as real directories and every one is invocable as /<name> or
  readable by path. Groups: agent_ arch_ data_ ddd_ git_ id_ infra_ lang_
  maestro_ nix_ quant_ research_ test_ think_ web_. Invoke when a task needs
  expertise outside the default roster, or to check whether a skill for
  something exists before concluding none does.
---

# Skill library

One tree, `.claude/skills/`, 236 skills. Names are `<group>_<subgroup>_<leaf>`:
underscores are the hierarchy, hyphens are word breaks inside a segment. Claude
Code discovers skills at exactly one directory level, so the underscore is the
only tree there is — nesting a skill deeper makes it invisible.

53 of them carry a description in the session roster and can auto-invoke. The
183 below are set to `user-invocable-only`: installed and current, but costing
nothing until needed. They are not second-class — the roster is chosen by what
this stack triggers, not by quality.

To use one, invoke it as `/<name>` or read its `SKILL.md` and follow it exactly
as if it had loaded itself. If you reach for the same skill repeatedly, add its
name to `.claude/skills.manifest` and run
`bash plugins/id-workflow/hooks/sync-skills.sh` to promote it.

## `a11y-playwright-testing_`

| Skill | What it covers |
|---|---|
| `a11y-playwright-testing` | Accessibility testing for web applications using Playwright (@playwright/test) with TypeScript and axe-core. Use when asked to write, run, or debug automated accessibility checks, keyboard navigati... |

## `abstraction-laddering_`

| Skill | What it covers |
|---|---|
| `abstraction-laddering` | Reframe problems by climbing up (why) for broader context or down (how) for concrete subproblems. Use when the stated problem is too narrow, too vague, or solving the wrong thing. |

## `abstraction-layer-pattern_`

| Skill | What it covers |
|---|---|
| `abstraction-layer-pattern` | Pattern for implementing abstraction layers with multiple implementations in Python codebases, following dependency inversion principles. |

## `accessibility-auditing_`

| Skill | What it covers |
|---|---|
| `accessibility-auditing` | Use Cursor's browser aria snapshots to audit a page for accessibility issues — missing labels, broken tab order, contrast, and ARIA misuse. |

## `activate_`

| Skill | What it covers |
|---|---|
| `activate` | Session initialization routine for Hermes Agent. Verify and activate core MCP servers and tools. Use at the start of a session to ensure all necessary services are running and healthy. |

## `adding-docker_`

| Skill | What it covers |
|---|---|
| `adding-docker` | Dockerize an application with a production-ready Dockerfile, docker-compose setup, and .dockerignore. |

## `agent_`

| Skill | What it covers |
|---|---|
| `agent` | Agent role selection for Hermes Agent. Choose the appropriate agent role based on task type and ID mode. Maps to Cursor's agent rules: researcher, architect, implementer, reviewer. |
| `agent_skill_library` | Index of the 183 skills held off the session roster — the full tree lives in .claude/skills/ as real directories and every one is invocable as /<name> or readable by path. Groups: agent_ arch_ data... |

## `ai-agents-ui-skills_`

| Skill | What it covers |
|---|---|
| `ai-agents-ui-skills` | Comprehensive guide for building AI agents using ToolLoopAgent, workflow patterns, and AI SDK UI components (useChat, generative UIs, tool calling) |

## `ai-sdk-6-skills_`

| Skill | What it covers |
|---|---|
| `ai-sdk-6-skills` | AI SDK 6 Beta overview, agents, tool approval, Groq (Llama), and Vercel AI Gateway. Key breaking changes from v5 and new patterns. |

## `andromeda-backtest-tuning_`

| Skill | What it covers |
|---|---|
| `andromeda-backtest-tuning` | Safely run and tune andromeda backtest/hyperopt for the AFML/FreqAI strategies (walk-forward fold sizing, cheap vs expensive AFML knobs, hyperopt --only usage, and the out-of-sample discipline that... |

## `api-gleam_`

| Skill | What it covers |
|---|---|
| `api-gleam` | REST/JSON API design patterns for Gleam + Wisp + Mist. Use this skill when designing routes, error responses, pagination, request dispatch, or middleware composition. |

## `architecture-doc-authoring_`

| Skill | What it covers |
|---|---|
| `architecture-doc-authoring` | Authoring normative architecture documentation (SERVICE.md-style ports & adapters / DI guides) and distilling project-specific docs into portable, project-agnostic guides. Use when documenting how ... |

## `architecture-patterns_`

| Skill | What it covers |
|---|---|
| `architecture-patterns` | Master proven backend architecture patterns including Clean Architecture, Hexagonal Architecture, and Domain-Driven Design to build maintainable, testable, and scalable systems. |

## `authjs-skills_`

| Skill | What it covers |
|---|---|
| `authjs-skills` | Auth.js v5 setup for Next.js authentication including Google OAuth, credentials provider, environment configuration, and core API integration |

## `balancing-feedback-loop_`

| Skill | What it covers |
|---|---|
| `balancing-feedback-loop` | Identify and analyze balancing (stabilizing) feedback loops that counteract deviation from a goal or setpoint. Use for control systems, regulation, resistance to change, and equilibrium dynamics. |

## `brand-guidelines_`

| Skill | What it covers |
|---|---|
| `brand-guidelines` | Applies Anthropic's official brand colors and typography to any sort of artifact that may benefit from having Anthropic's look-and-feel. Use it when brand colors or style guidelines, visual formatt... |

## `busirocket-nextjs_`

| Skill | What it covers |
|---|---|
| `busirocket-nextjs` | Applies Next.js App Router route handler patterns. Use when creating or refactoring route.ts files, implementing API endpoints, validating request inputs, and returning standardized JSON responses ... |

## `busirocket-react_`

| Skill | What it covers |
|---|---|
| `busirocket-react` | Applies React component and hook structure rules plus Zustand state management. Use when writing or refactoring React components, extracting hooks, deciding client vs server components, implementin... |

## `canvas-design_`

| Skill | What it covers |
|---|---|
| `canvas-design` | Create beautiful visual art in .png and .pdf documents using design philosophy. You should use this skill when the user asks to create a poster, piece of art, design, or other static piece. Create ... |

## `clerk-nextjs-skills_`

| Skill | What it covers |
|---|---|
| `clerk-nextjs-skills` | Clerk authentication for Next.js 16 (App Router only) with proxy.ts setup, migration from middleware.ts, environment configuration, and MCP server integration. |

## `comparing-branches-visually_`

| Skill | What it covers |
|---|---|
| `comparing-branches-visually` | Check out two branches in separate worktrees, start both dev servers on different ports, screenshot the same pages, and produce a visual diff. |

## `concept-map_`

| Skill | What it covers |
|---|---|
| `concept-map` | Build hierarchical knowledge graphs with labeled linking phrases connecting concepts around a focus question. Use for domain learning, explaining systems, and surfacing knowledge gaps before design... |

## `confidence-speed-quality_`

| Skill | What it covers |
|---|---|
| `confidence-speed-quality` | Calibrate whether to optimize for delivery speed or output quality based on confidence in problem importance and solution correctness. Use when choosing between quick iteration, thorough design, or... |

## `connection-circles_`

| Skill | What it covers |
|---|---|
| `connection-circles` | Map causal links between system variables with polarity (+/-) and trace closed loops to find reinforcing and balancing feedback. Use as a stepping stone to causal loop diagrams and leverage-point a... |

## `containers-orchestration_`

| Skill | What it covers |
|---|---|
| `containers-orchestration` | Docker and container orchestration best practices for production-ready containers. Covers multi-stage builds, security scanning, distroless images, Docker Compose patterns, health checks, and CI/CD... |

## `context-dissolution_`

| Skill | What it covers |
|---|---|
| `context-dissolution` | Dissolve a bounded context (contexts/<bc>/) in the andromeda package into services/, domain/, and adapters/driven/ per ARCHITECTURE.md. Use when consolidating a context behind application services,... |

## `cqrs-implementation_`

| Skill | What it covers |
|---|---|
| `cqrs-implementation` | Implement Command Query Responsibility Segregation for scalable architectures. Use when separating read and write models, optimizing query performance, or building event-sourced systems. |

## `cynefin-framework_`

| Skill | What it covers |
|---|---|
| `cynefin-framework` | Classify situations into Clear, Complicated, Complex, Chaotic, or Disorder domains and apply the matching sense-making response (best practice, expert analysis, safe-to-fail probes, stabilize-then-... |

## `dark-mode-testing_`

| Skill | What it covers |
|---|---|
| `dark-mode-testing` | Toggle between light and dark mode in Cursor's browser, screenshot both states, and flag missing token mappings or contrast issues. |

## `ddd-context-dissolution_`

| Skill | What it covers |
|---|---|
| `ddd-context-dissolution` | Dissolve an andromeda bounded context (contexts/<bc>/) into services/, domain/ models, value_objects and driven adapters per ARCHITECTURE.md. Use when removing a context, moving its types to domain... |

## `ddd-context-mapping_`

| Skill | What it covers |
|---|---|
| `ddd-context-mapping` | Map relationships between bounded contexts and define integration contracts using DDD context mapping patterns. |

## `ddd-strategic-design_`

| Skill | What it covers |
|---|---|
| `ddd-strategic-design` | Design DDD strategic artifacts including subdomains, bounded contexts, and ubiquitous language for complex business domains. |

## `ddd-tactical-patterns_`

| Skill | What it covers |
|---|---|
| `ddd-tactical-patterns` | Apply DDD tactical patterns in code using entities, value objects, aggregates, repositories, and domain events with explicit invariants. |

## `debate_`

| Skill | What it covers |
|---|---|
| `debate` | Engage in a read-only debate on a topic without making any file changes. Use when you want to discuss ideas, explore alternatives, or reason through problems without committing to implementation. A... |

## `decision-matrix_`

| Skill | What it covers |
|---|---|
| `decision-matrix` | Score options against weighted criteria to produce a ranked, auditable recommendation. Use when 3+ options compete on multiple dimensions and gut feel is insufficient. |

## `definitively-agent-config_`

| Skill | What it covers |
|---|---|
| `definitively-agent-config` | Agent profiles and LLM node fragments for the `.definitively/` workflow framework. Covers adding new agent backends (e.g. hermes, cursor) and wiring them into definitively programs as LLM nodes. |

## `dev-caches-cleanup_`

| Skill | What it covers |
|---|---|
| `dev-caches-cleanup` | Reclaim disk from developer tool caches and build artifacts on Linux: Rust target/, npm, cargo, sccache, uv, bun, pnpm, Nix, LM Studio models, Trash, and devenv/.venv trees. Use after disk audit id... |

## `disk-audit_`

| Skill | What it covers |
|---|---|
| `disk-audit` | Audit Linux disk usage to find large directories, caches, and reclaimable space. Use when the user asks to analyze disk space, find what's using storage, or plan cleanup on / or a home directory. C... |

## `disk-cleanup-plan_`

| Skill | What it covers |
|---|---|
| `disk-cleanup-plan` | Produce a prioritized, risk-rated disk cleanup plan from audit findings. Use after linux-disk-audit to recommend what to remove, estimated savings, commands to run, and what requires user confirmat... |

## `docker-agents-generator_`

| Skill | What it covers |
|---|---|
| `docker-agents-generator` | Use when containerizing an application from scratch or generating Dockerfile and Compose configurations for a new project. Prevents insecure defaults by enforcing non-root users, multi-stage builds... |

## `docker-agents-review_`

| Skill | What it covers |
|---|---|
| `docker-agents-review` | Use when reviewing a Dockerfile or Compose file before merging, deploying, or auditing container security posture. Prevents shipping containers that run as root, lack health checks, expose secrets ... |

## `docker-cleanup_`

| Skill | What it covers |
|---|---|
| `docker-cleanup` | Safely reclaim disk space from Docker images, build cache, containers, and volumes. Use when docker system df shows high usage, build cache is large, or Docker root is under ~/.local/share/docker (... |

## `docker-core-architecture_`

| Skill | What it covers |
|---|---|
| `docker-core-architecture` | Use when designing Docker container architecture or explaining how Docker Engine components interact. Prevents misconceptions about container isolation, image layering, and the relationship between... |

## `docker-core-networking_`

| Skill | What it covers |
|---|---|
| `docker-core-networking` | Use when configuring Docker networks, debugging container connectivity, or setting up service discovery between containers. Prevents using the default bridge network in production, which lacks DNS ... |

## `docker-core-security_`

| Skill | What it covers |
|---|---|
| `docker-core-security` | Use when hardening containers, scanning images for vulnerabilities, or implementing least-privilege Docker deployments. Prevents running containers as root, exposing secrets in image layers, and sk... |

## `docker-errors-build_`

| Skill | What it covers |
|---|---|
| `docker-errors-build` | Use when debugging Docker build failures or unexpected cache behavior. Prevents wasted hours from misunderstanding COPY context paths, cache invalidation rules, and BuildKit mount syntax. Covers bu... |

## `docker-errors-compose_`

| Skill | What it covers |
|---|---|
| `docker-errors-compose` | Use when docker compose up fails, services refuse to start, or dependency health checks time out. Prevents cascading failures from unvalidated Compose files, incorrect depends_on conditions, and un... |

## `docker-errors-networking_`

| Skill | What it covers |
|---|---|
| `docker-errors-networking` | Use when containers cannot reach each other, DNS resolution fails between services, or published ports are not accessible from the host. Prevents connectivity failures from using the default bridge... |

## `docker-errors-runtime_`

| Skill | What it covers |
|---|---|
| `docker-errors-runtime` | Use when a running container crashes, exits unexpectedly, or behaves incorrectly at runtime. Prevents misdiagnosis of OOM kills, permission denied errors, and silent container exits by following th... |

## `docker-helper_`

| Skill | What it covers |
|---|---|
| `docker-helper` | Build, debug, and optimize Docker configurations. Use when a user asks to create a Dockerfile, fix Docker build errors, optimize image size, write docker-compose files, debug container issues, set ... |

## `docker-impl-build-optimization_`

| Skill | What it covers |
|---|---|
| `docker-impl-build-optimization` | Use when optimizing Docker build times or fixing unexpected cache invalidation. Prevents full rebuilds from incorrect instruction ordering and bloated images from missing .dockerignore entries. Cov... |

## `docker-impl-cicd_`

| Skill | What it covers |
|---|---|
| `docker-impl-cicd` | Use when setting up Docker CI/CD pipelines, pushing images to registries, or configuring multi-platform builds with GitHub Actions. Prevents broken workflows from incorrect docker/build-push-action... |

## `docker-impl-compose-workflows_`

| Skill | What it covers |
|---|---|
| `docker-impl-compose-workflows` | Use when setting up multi-environment Compose workflows or merging override files. Prevents environment variable shadowing from incorrect precedence and broken extends from circular dependencies. C... |

## `docker-impl-go-templates_`

| Skill | What it covers |
|---|---|
| `docker-impl-go-templates` | Use when formatting Docker CLI output with --format flags or extracting specific fields from docker inspect. Prevents broken template syntax from missing braces, incorrect field paths, and unquoted... |

## `docker-impl-production_`

| Skill | What it covers |
|---|---|
| `docker-impl-production` | Use when hardening Dockerfiles for production deployment or choosing base images. Prevents containers running as root, missing HEALTHCHECK definitions, and zombie processes from shell-form ENTRYPOI... |

## `docker-impl-storage_`

| Skill | What it covers |
|---|---|
| `docker-impl-storage` | Use when persisting container data, mounting host directories, or configuring database storage volumes. Prevents data loss from anonymous volumes on container removal and silent mount failures with... |

## `docker-syntax-buildkit_`

| Skill | What it covers |
|---|---|
| `docker-syntax-buildkit` | Use when optimizing Dockerfile builds with cache mounts, mounting secrets during build, or writing multi-line RUN with heredoc syntax. Prevents baking credentials into image layers, cache-busting o... |

## `docker-syntax-cli-containers_`

| Skill | What it covers |
|---|---|
| `docker-syntax-cli-containers` | Use when running, inspecting, or managing Docker containers from the CLI. Prevents silent data loss from missing -v on rm, zombie containers from skipped stop commands, and incorrect docker run fla... |

## `docker-syntax-cli-images_`

| Skill | What it covers |
|---|---|
| `docker-syntax-cli-images` | Use when building, tagging, pushing, or cleaning up Docker images. Prevents dangling image accumulation from missing prune commands and broken deployments from incorrect tag or push sequences. Cove... |

## `docker-syntax-compose-resources_`

| Skill | What it covers |
|---|---|
| `docker-syntax-compose-resources` | Use when defining top-level networks, volumes, configs, or secrets in compose.yaml. Prevents misconfigured network drivers, orphaned volumes, and secrets mounted with wrong permissions. Covers netw... |

## `docker-syntax-compose-services_`

| Skill | What it covers |
|---|---|
| `docker-syntax-compose-services` | Use when writing compose.yaml service definitions, configuring service dependencies, or setting up health checks and resource limits. Prevents depends_on without condition: service_healthy, which s... |

## `docker-syntax-dockerfile_`

| Skill | What it covers |
|---|---|
| `docker-syntax-dockerfile` | Use when writing or reviewing Dockerfiles, choosing between CMD and ENTRYPOINT, or selecting COPY vs ADD. Prevents shell-form CMD that blocks signal propagation, ADD for local files where COPY suff... |

## `docker-syntax-multistage_`

| Skill | What it covers |
|---|---|
| `docker-syntax-multistage` | Use when optimizing Docker image size, separating build-time and runtime dependencies, or creating minimal production images. Prevents shipping compilers, build tools, and source code in production... |

## `eisenhower-matrix_`

| Skill | What it covers |
|---|---|
| `eisenhower-matrix` | Prioritize tasks by importance and urgency into four quadrants with explicit scoring, handling strategies, and sequencing rules. Use for work triage, scheduling, and deciding what to do now vs late... |

## `elixir-concurrency_`

| Skill | What it covers |
|---|---|
| `elixir-concurrency` | Implements concurrent and parallel data processing in Elixir using Task, Flow, GenStage, and Broadway with correct back-pressure. Use when building pipelines, batch processing, rate-limited workers... |

## `elixir-core_`

| Skill | What it covers |
|---|---|
| `elixir-core` | Applies idiomatic Elixir — pattern matching, pipelines, Enum/Stream, protocols, structs, and @spec. Use when editing .ex/.exs files, writing pure functions, refactoring imperative code, or when the... |

## `elixir-liveview_`

| Skill | What it covers |
|---|---|
| `elixir-liveview` | Builds Phoenix LiveView interfaces with correct lifecycle, components, streams, and PubSub patterns. Use when editing .ex files in live/ directories, HEEx templates, LiveComponents, or when the use... |

## `elixir-otp-design_`

| Skill | What it covers |
|---|---|
| `elixir-otp-design` | Designs Elixir OTP systems using layered boundaries, supervision, and fault tolerance. Use when implementing GenServer, Agent, Supervisor, Application, designing process trees, or when the user men... |

## `elixir-phoenix_`

| Skill | What it covers |
|---|---|
| `elixir-phoenix` | Builds Phoenix web applications using contexts, plugs, routers, Ecto, and channels. Use when editing Phoenix controllers, contexts, schemas, plugs, router, or Ecto queries outside of LiveView-speci... |

## `elixir-review_`

| Skill | What it covers |
|---|---|
| `elixir-review` | Reviews Elixir and Phoenix code for idiomaticity, layer violations, OTP misuse, and test gaps. Use when reviewing pull requests, examining .ex changes, or when the user asks for an Elixir code review. |

## `elixir-testing_`

| Skill | What it covers |
|---|---|
| `elixir-testing` | Writes ExUnit tests for Elixir and Phoenix using context tests, LiveView tests, and property-based testing patterns. Use when editing test/ files, adding test coverage, or when the user asks how to... |

## `event-sourcing_`

| Skill | What it covers |
|---|---|
| `event-sourcing` | Event sourcing patterns for functional TypeScript — persist state as an append-only log of past events and rebuild it by folding them. Use when implementing a Decider write model, an event store, p... |

## `event-store-design_`

| Skill | What it covers |
|---|---|
| `event-store-design` | Design and implement event stores for event-sourced systems. Use when building event sourcing infrastructure, choosing event store technologies, or implementing event persistence patterns. |

## `first-principles_`

| Skill | What it covers |
|---|---|
| `first-principles` | Decompose problems to foundational truths, challenge assumptions with Socratic questioning and Five Whys, then rebuild solutions from verified constraints. Use when analogies fail, inherited design... |

## `fixing-accessibility_`

| Skill | What it covers |
|---|---|
| `fixing-accessibility` | Audit and fix HTML accessibility issues including ARIA labels, keyboard navigation, focus management, color contrast, and form errors. Use when adding interactive controls, forms, dialogs, or revie... |

## `fixing-motion-performance_`

| Skill | What it covers |
|---|---|
| `fixing-motion-performance` | Audit and fix animation performance issues including layout thrashing, compositor properties, scroll-linked motion, and blur effects. Use when animations stutter, transitions jank, or reviewing CSS... |

## `frontend-engineering_`

| Skill | What it covers |
|---|---|
| `frontend-engineering` | Framework-agnostic frontend architecture playbook. Workflows for picking rendering (SSG / SSR / SPA / ISR), setting bundle budgets, choosing state management (local / server / global), Core Web Vit... |

## `gleam_`

| Skill | What it covers |
|---|---|
| `gleam` | Core Gleam language skill. Use when writing pure Gleam functions, parsing or validating input (Parse, Don't Validate), decoding JSON, designing a library, or defining shared domain types — not back... |

## `gleam-backend_`

| Skill | What it covers |
|---|---|
| `gleam-backend` | Gleam backend development skill for the Erlang target. Covers Wisp, Mist, OTP actors, Supervision trees, Squirrel/Parrot SQL codegen integration, JWT auth, and HTTP runners. Use when building serve... |

## `gleam-idiomatic_`

| Skill | What it covers |
|---|---|
| `gleam-idiomatic` | Guides writing and reviewing idiomatic Gleam code. Use when editing or creating Gleam modules (.gleam), implementing Gleam APIs, or when the user asks for Gleam style, Wisp (backend), Lustre (front... |

## `hard-choice_`

| Skill | What it covers |
|---|---|
| `hard-choice` | Classify decisions by impact and comparability to choose the right decision process — quick call, values-based choice, analysis, or deep deliberation. Use before investing analysis effort or when o... |

## `hermes-configuration-management_`

| Skill | What it covers |
|---|---|
| `hermes-configuration-management` | Manages backing up, replacing, synchronizing, and restoring Hermes Agent configurations across different installations or environments. |

## `hermes-environment-replication_`

| Skill | What it covers |
|---|---|
| `hermes-environment-replication` | Replicate a Hermes development environment to another project. |

## `hermes-lmstudio-connection_`

| Skill | What it covers |
|---|---|
| `hermes-lmstudio-connection` | Guidance for configuring Hermes Agent to use LM Studio's built‑in OpenAI‑compatible API. Includes workflow, configuration commands, verification steps, and reference links. |

## `hermes-plugin-authoring_`

| Skill | What it covers |
|---|---|
| `hermes-plugin-authoring` | How to write, wire, and Nix-package a Hermes Agent plugin in the /home/tom/.dotfiles repo. Covers plugin structure, the register(ctx) API, tool/hook registration, the hermes_agent.plugins entry poi... |

## `hermes-plugin-development_`

| Skill | What it covers |
|---|---|
| `hermes-plugin-development` | How to write, structure, and wire a Hermes Agent plugin in this dotfiles repo. Covers the full-plugin-with-tools pattern, Nix packaging, entry-point discovery, upstream skill delivery via fetchFrom... |

## `hermes-provider-and-free-model-discovery_`

| Skill | What it covers |
|---|---|
| `hermes-provider-and-free-model-discovery` | Techniques for enumerating which AI model providers Hermes can connect to, and which offer free-to-use model tiers. Covers source-level provider discovery, API-based free model enumeration, and loc... |

## `iceberg-model_`

| Skill | What it covers |
|---|---|
| `iceberg-model` | Analyze problems across four levels — Events, Patterns, Structures, Mental Models — to move from reactive fixes to systemic interventions. Use for recurring bugs, organizational dysfunction, and sy... |

## `id_`

| Skill | What it covers |
|---|---|
| `id` | Industrial Delivery orchestrator - start in ORIENT mode and auto-route by lane. Load and obey the ID workflow protocol. Declare every response with [ID:<MODE>] and lane:<tiny/normal/heavy>. Prefer ... |

## `id-effect_`

| Skill | What it covers |
|---|---|
| `id-effect` | Router for id_effect Rust skills — Effect<A,E,R>, effect! macro, capability DI 3.0 (Env, ProviderSpec, caps!, require!, run_with). Use when editing id_effect crates, examples, book, or workspace in... |

## `id-effect-algebra_`

| Skill | What it covers |
|---|---|
| `id-effect-algebra` | Teaches id_effect algebra stratum: Foldable, Alternative, Traversable, Bifoldable, Invariant. Use when extending type classes or using traverse/alt/fold. |

## `id-effect-capabilities_`

| Skill | What it covers |
|---|---|
| `id-effect-capabilities` | Expert in id_effect 3.0 capability DI: #[capability], caps!, Env, Needs, ProviderSpec, provide!, run_with, provider graphs, and service trait design. Use when wiring dependencies, declaring service... |

## `id-effect-compute-fabric_`

| Skill | What it covers |
|---|---|
| `id-effect-compute-fabric` | Teaches id_effect Compute Fabric: ResourcePolicy, supervisor admission, run/run_with installation, implicit parallelism (ADR 0007/0008), AdaptiveContext, and EDG auto-parallel effect! binds. Use wh... |

## `id-effect-concurrency_`

| Skill | What it covers |
|---|---|
| `id-effect-concurrency` | Teaches id_effect concurrency: fibers, fork/join, fiber_all/fiber_race/fiber_any, cancellation, FiberRef, supervision, scopes/finalizers, acquire_release, and Schedule retry/repeat. Use when spawni... |

## `id-effect-errors_`

| Skill | What it covers |
|---|---|
| `id-effect-errors` | Teaches id_effect error handling: Exit, Cause, typed failures vs defects, recovery combinators, error accumulation, and CLI exit mapping. Use when handling failures, designing error types, retry/ca... |

## `id-effect-events_`

| Skill | What it covers |
|---|---|
| `id-effect-events` | Write and review id_effect_events and id_effect_graph — EventStore, EsEntityEventStore, ProjectionRunner, MemoryEventStore, FileJournal, CQRS dispatch, Dag and topological_sort. Use when editing ev... |

## `id-effect-fsm_`

| Skill | What it covers |
|---|---|
| `id-effect-fsm` | Write and review id_effect_fsm — StateMachine, TransitionTable, Interpreter with run_blocking, to_mermaid, HasTag matcher bridge, Saga compensation, SessionSend/SessionRecv, workflow bridge. Use wh... |

## `id-effect-fundamentals_`

| Skill | What it covers |
|---|---|
| `id-effect-fundamentals` | Teaches id_effect foundations: Effect as a lazy description, Effect<A,E,R>, effect! do-notation, the ~ bind operator, map/flat_map/pipe, IntoBind for Result, and when not to use the macro. Use when... |

## `id-effect-integration_`

| Skill | What it covers |
|---|---|
| `id-effect-integration` | Teaches id_effect workspace integration: id_effect_tokio run_async, id_effect_platform I/O, id_effect_platform::http::reqwest HTTP, id_effect_axum hosting, id_effect_config, id_effect_logger, id_ef... |

## `id-effect-migration_`

| Skill | What it covers |
|---|---|
| `id-effect-migration` | Captures the id_effect v2→v3 API migration pattern for the solana-yield-optimizer project. Centralizes knowledge of breaking changes so future sessions can resolve remaining compilation errors effi... |

## `id-effect-optics_`

| Skill | What it covers |
|---|---|
| `id-effect-optics` | Teaches id_effect_optics: Lens, Prism, Optional, Traversal, transducers, schema field paths on Unknown, JSON patch (add/replace/remove/move/copy/test), TrieZipper navigation/rebuild. Use when focus... |

## `id-effect-parse_`

| Skill | What it covers |
|---|---|
| `id-effect-parse` | Parser combinators, Pretty documents, invertible Codec, Diff, and Stream parse bridges in id_effect_parse. Use when parsing text/byte protocols, pretty-printing debug output, or round-tripping wire... |

## `id-effect-platform_`

| Skill | What it covers |
|---|---|
| `id-effect-platform` | Platform capabilities — HttpClient, FileSystem, ProcessRuntime in id_effect_platform. Use when editing crates/id_effect_platform, platform Maestro missions, or migrating from id_effect_platform::ht... |

## `id-effect-resilience_`

| Skill | What it covers |
|---|---|
| `id-effect-resilience` | Runtime resilience for id_effect: RequestResolver batching, SubscriptionRef, Redacted schema values, match_effect!, and id_effect_resilience (circuit breaker, rate limiter, bulkhead, hedged). Use w... |

## `id-effect-review_`

| Skill | What it covers |
|---|---|
| `id-effect-review` | Reviews id_effect Rust code for idiomaticity, capability DI violations, removed API usage, effect! misuse, and test gaps. Use when reviewing pull requests, examining id_effect changes, or when the ... |

## `id-effect-schema_`

| Skill | What it covers |
|---|---|
| `id-effect-schema` | Teaches id_effect schema: Unknown at boundaries, struct_/array/optional/union combinators, validation refinements, and ParseError handling. Use when parsing JSON/API payloads, defining DTOs, or val... |

## `id-effect-stm_`

| Skill | What it covers |
|---|---|
| `id-effect-stm` | Teaches id_effect STM: Stm, TRef, commit/atomically, stm!, TQueue/TMap/TSemaphore, stm::fail/retry. Use for composable in-memory shared state without mutex deadlocks. Transactions must be short and... |

## `id-effect-streams_`

| Skill | What it covers |
|---|---|
| `id-effect-streams` | Teaches id_effect streams: Stream vs Effect, chunks, sinks, backpressure, map_par_n async concurrency, and Rayon Parallelism policy. Use when processing iterables, pipelines, bulk transforms, or ch... |

## `id-effect-testing_`

| Skill | What it covers |
|---|---|
| `id-effect-testing` | Expert in testing id_effect code: run_test harness, Exit assertions, TestClock, mock_capability!, build_env/provide! test providers, and property testing. Never mock id_effect internals with module... |

## `id-execute_`

| Skill | What it covers |
|---|---|
| `id-execute` | ID EXECUTE mode: Implement contract-scoped code only. Use when building  according to approved Maestro plan. |

## `id-lanes_`

| Skill | What it covers |
|---|---|
| `id-lanes` | ID lane routing rules: determines how to route tasks based on size and clarity. Use with maestro intake to set appropriate lane (tiny/normal/heavy). |

## `id-orient_`

| Skill | What it covers |
|---|---|
| `id-orient` | ID ORIENT mode: Sharpen the ask, pick skills and agent, set lane. Use when starting a new task or when needing to clarify requirements. |

## `id-plan_`

| Skill | What it covers |
|---|---|
| `id-plan` | ID PLAN mode: Create Maestro/spec/plan artifacts only. Use when ready to  specify what to build after research is complete. |

## `id-research_`

| Skill | What it covers |
|---|---|
| `id-research` | ID RESEARCH mode: Gather sufficient context to plan (or debate-only loop). Use when exploring a problem space before committing to a plan. |

## `id-review_`

| Skill | What it covers |
|---|---|
| `id-review` | ID REVIEW mode: Record evidence notes only. Use when verifying completed work. |

## `id-ship_`

| Skill | What it covers |
|---|---|
| `id-ship` | ID SHIP mode: Git/GitHub operations only. Use when releasing completed work. |

## `idclear-docker-compose-modes_`

| Skill | What it covers |
|---|---|
| `idclear-docker-compose-modes` | idclear monorepo Docker Compose dev vs production modes for test-nextjs, ng-client, and risk-calculator. Covers local dev servers (HMR), comment-toggle prod-local image for test-nextjs, and COMPOSE... |

## `idclear-logto-monorepo_`

| Skill | What it covers |
|---|---|
| `idclear-logto-monorepo` | idclear monorepo Logto integration — libs/logto Management API client, @idclear/authentication policy, test-nextjs @logto/next proxy and Effect LogtoService, logto-init bootstrap, and e2e Logto flo... |

## `idclear-vps-testing-deploy_`

| Skill | What it covers |
|---|---|
| `idclear-vps-testing-deploy` | Deploy idclear to the testing VPS (SSH targ@212.227.30.157, testing.idclear.com) via docker compose prod overlay. Use when user asks to deploy, redeploy, push to VPS, verify testing.idclear.com, SS... |

## `impact-effort_`

| Skill | What it covers |
|---|---|
| `impact-effort` | Plot initiatives on impact vs effort to find quick wins, major projects, fill-ins, and items to avoid. Use for backlog prioritization, roadmap sequencing, and resource allocation when ROI matters m... |

## `inversion_`

| Skill | What it covers |
|---|---|
| `inversion` | Solve problems backward — enumerate failure modes, run pre-mortems, and define anti-goals to build robust forward plans. Use for risk mitigation, architecture stress tests, and avoiding predictable... |

## `issue-trees_`

| Skill | What it covers |
|---|---|
| `issue-trees` | Decompose problems MECE into hierarchical issue trees (diagnostic why-trees) or solution trees (how-trees) for systematic analysis. Use for complex scoping, root cause structuring, and consulting-s... |

## `json-render-react_`

| Skill | What it covers |
|---|---|
| `json-render-react` | React renderer for json-render that turns JSON specs into React components. Use when working with @json-render/react, building React UIs from JSON, creating component catalogs, or rendering AI-gene... |

## `ladder-of-inference_`

| Skill | What it covers |
|---|---|
| `ladder-of-inference` | Trace reasoning from observable data through selection, interpretation, assumptions, and conclusions to surface hidden leaps and bias. Use to debug flawed conclusions, de-escalate disagreements, an... |

## `literature-search-arxiv_`

| Skill | What it covers |
|---|---|
| `literature-search-arxiv` | Search for scientific papers, preprints, and publications on arXiv. Extract metadata, abstracts, and download full-text PDFs or HTML versions of papers. Use when the user asks to find research pape... |

## `literature-search-openalex_`

| Skill | What it covers |
|---|---|
| `literature-search-openalex` | Query the OpenAlex scholarly database for research papers, authors, institutions, topics, sources, publishers, funders, geo-locations, and keywords. Use when searching academic papers, resolving DO... |

## `logto-open-source-auth-infrastructure_`

| Skill | What it covers |
|---|---|
| `logto-open-source-auth-infrastructure` | Logto is a modern, open-source authentication and authorization infrastructure built on OIDC and OAuth 2.1. It provides multi-tenancy, enterprise SSO, RBAC, and SDKs for 30+ frameworks, making it t... |

## `lustre_`

| Skill | What it covers |
|---|---|
| `lustre` | Gleam frontend development skill targeting JavaScript. Covers Lustre 5.x, MVU Architecture, Advanced Forms (save-lifecycle state machines/FieldState), UI Patterns, SPA Routing (modem), and HTTP req... |

## `lustre-guide_`

| Skill | What it covers |
|---|---|
| `lustre-guide` | Lustre framework patterns for Gleam UIs. Covers MVU architecture (init/update/view), application constructors (lustre.simple, lustre.application, lustre.component), message naming using Subject Ver... |

## `maestro-command-migration_`

| Skill | What it covers |
|---|---|
| `maestro-command-migration` | Migrate editor-specific slash command workflows (e.g., .cursor/commands) to Maestro missions and tasks. Use when replacing ad-hoc command files with Maestro's hierarchical planning, tracking, and v... |

## `maestro-design_`

| Skill | What it covers |
|---|---|
| `maestro-design` | Interview-driven product-spec authoring for maestro. Runs the grill protocol from ADR-0016 — walks the decision tree one branch at a time, challenges user language against CONTEXT.md and committed ... |

## `maestro-handoff_`

| Skill | What it covers |
|---|---|
| `maestro-handoff` | Read handoff envelopes left by previous agents at the start of a session or when picking up a task in a maestro-initialized project. Use whenever you suspect a prior session left context behind — t... |

## `maestro-mcp-patterns_`

| Skill | What it covers |
|---|---|
| `maestro-mcp-patterns` | Practical patterns and pitfalls for using Maestro via MCP tools (not the CLI). Covers the mission creation path that actually works, contract gotchas, and directory prerequisites. Load alongside ma... |

## `maestro-mission_`

| Skill | What it covers |
|---|---|
| `maestro-mission` | Turn an approved heavy-mode product-spec into an executable mission with child tasks. Use after `maestro-design` has produced a `mode: heavy` spec, or when a single task has grown big enough that i... |

## `maestro-setup_`

| Skill | What it covers |
|---|---|
| `maestro-setup` | Set up a repository as a long-running agent harness. Use when a project needs Maestro-owned context docs, evidence-first onboarding, root AGENTS.md guidance, language style guides, host-runtime ses... |

## `maestro-task_`

| Skill | What it covers |
|---|---|
| `maestro-task` | Use at the start of any multi-step work in a maestro-initialized project, and throughout task execution. Claim one task at a time, iterate through the verify → block / ship loop. `claim` and `block... |

## `maestro-verify_`

| Skill | What it covers |
|---|---|
| `maestro-verify` | The canonical verification protocol for any task in a maestro project. Documents witness levels, Trust Verifier scope, ProofMap, plan-check, verdict semantics, cost-budget monitoring, AI Reviewer p... |

## `mcp-server-skills_`

| Skill | What it covers |
|---|---|
| `mcp-server-skills` | Pattern for building MCP servers in Next.js with mcp-handler, shared Zod schemas, and reusable server actions. |

## `mikro-orm-idclear_`

| Skill | What it covers |
|---|---|
| `mikro-orm-idclear` | Applies MikroORM v7 inside the IdClear monorepo: @idclear/db Effect tags and layers, request-scoped EntityManager forking, emFind/emFlush helpers, entityProps recipes, soft-delete and audit subscri... |

## `next-upgrade_`

| Skill | What it covers |
|---|---|
| `next-upgrade` | Upgrade Next.js to the latest version following official migration guides and codemods |

## `nextjs-react-typescript_`

| Skill | What it covers |
|---|---|
| `nextjs-react-typescript` | Expert in TypeScript, Node.js, Next.js App Router, React, Shadcn UI, Radix UI and Tailwind |

## `nixos-codebase-analysis_`

| Skill | What it covers |
|---|---|
| `nixos-codebase-analysis` | Analyze a NixOS dotfiles repository and produce structured improvement analyses. Research the codebase structure, compare against best practices, and produce organized lists of improvements across ... |

## `nixos-improvements_`

| Skill | What it covers |
|---|---|
| `nixos-improvements` | Class-level skill for documenting and tracking NixOS configuration improvements, optimizations, and best practices. This skill captures patterns, preferences, and proven configurations for NixOS se... |

## `ooda-loop_`

| Skill | What it covers |
|---|---|
| `ooda-loop` | Iterate Observe-Orient-Decide-Act cycles to adapt under uncertainty faster than the environment changes. Use in fast-moving incidents, competitive delivery, and probe-heavy Complex domains. |

## `optimized-nextjs-typescript_`

| Skill | What it covers |
|---|---|
| `optimized-nextjs-typescript` | Optimized Next.js TypeScript best practices with modern UI/UX, focusing on performance, security, and clean architecture |

## `pg-gleam_`

| Skill | What it covers |
|---|---|
| `pg-gleam` | Postgres performance optimization and best practices for a Gleam + Squirrel/Parrot + POG + Cigogne stack. Use this skill when writing, reviewing, or optimizing Postgres queries, schema designs, or ... |

## `playwright-ci_`

| Skill | What it covers |
|---|---|
| `playwright-ci` | Production-ready CI/CD configurations for Playwright — GitHub Actions, GitLab CI, CircleCI, Azure DevOps, Jenkins, Docker, parallel sharding, reporting, code coverage, and global setup/teardown. |

## `playwright-core_`

| Skill | What it covers |
|---|---|
| `playwright-core` | Battle-tested Playwright patterns for writing and debugging reliable E2E, API, component, visual, accessibility, and security tests. Use when you need locator strategy, assertions, fixtures, networ... |

## `playwright-migration_`

| Skill | What it covers |
|---|---|
| `playwright-migration` | Step-by-step migration guides for moving to Playwright from Cypress or Selenium/WebDriver — command mappings, architecture changes, and incremental adoption strategies. |

## `playwright-pom_`

| Skill | What it covers |
|---|---|
| `playwright-pom` | Page Object Model patterns for Playwright — when to use POM, how to structure page objects, and when fixtures or helpers are a better fit. |

## `pre-push_`

| Skill | What it covers |
|---|---|
| `pre-push` | Use Maestro-centric development for pre-push checks. As you run bun run ci:pre-push,  for each problem found create simple small Maestro tasks (or specs). Include problems,  type errors etc found i... |

## `prism-3way_`

| Skill | What it covers |
|---|---|
| `prism-3way` | Three orthogonal analytical operations (WHERE/WHEN/WHY) + cross-operation synthesis. Each operation attacks the problem from a fundamentally different angle. The disagreements between the three ARE... |

## `prism-discover_`

| Skill | What it covers |
|---|---|
| `prism-discover` | Discover all possible analysis domains for an artifact. Finds obvious and non-obvious angles — architecture, security, but also marketing positioning, user psychology, regulatory implications, teac... |

## `prism-full_`

| Skill | What it covers |
|---|---|
| `prism-full` | Full Prism: multi-pass structural analysis with mandatory adversarial self-correction. Designs custom analytical passes, executes them with chaining, then attacks its own findings before synthesizi... |

## `prism-reflect_`

| Skill | What it covers |
|---|---|
| `prism-reflect` | Constraint transparency: analyzes an artifact structurally, then analyzes what its own analysis concealed. Produces a conservation law AND a constraint report showing what was maximized, what was s... |

## `prism-scan_`

| Skill | What it covers |
|---|---|
| `prism-scan` | Structural analysis through dynamically generated cognitive lenses. Generates the optimal analytical lens for the specific code/artifact, then executes it. Finds conservation laws, structural invar... |

## `productive-thinking-model_`

| Skill | What it covers |
|---|---|
| `productive-thinking-model` | Six-step structured problem solving from situational understanding through success definition, catalytic questions, ideation, solution forging, and resource alignment. Use for open-ended problems n... |

## `quality_`

| Skill | What it covers |
|---|---|
| `quality` | Raise the ask to its sharpest correct form, then answer that. Maximize usefulness per word.  Cut filler, hedges, and restatement. Prefer dense structure over prose. Do not sacrifice correctness for... |

## `react-view-transitions_`

| Skill | What it covers |
|---|---|
| `react-view-transitions` | Guide for implementing smooth, native-feeling animations using React's View Transition API (`<ViewTransition>` component, `addTransitionType`, and CSS view transition pseudo-elements). Use this ski... |

## `reinforcing-feedback-loop_`

| Skill | What it covers |
|---|---|
| `reinforcing-feedback-loop` | Identify and analyze reinforcing (amplifying) feedback loops where change compounds in the same direction — virtuous growth or vicious decline. Use when you see exponential trends, runaway effects,... |

## `release-engineering_`

| Skill | What it covers |
|---|---|
| `release-engineering` | Audit and execute software releases: enumerate unpushed/uncommitted/unreleased/ unpublished work, pick version bumps, run quality gates, tag-triggered CI releases, and registry publishing (crates.i... |

## `responsive-testing_`

| Skill | What it covers |
|---|---|
| `responsive-testing` | Open the app in Cursor's browser at multiple viewport sizes, screenshot each, and report any layout breakage. |

## `saga-orchestration_`

| Skill | What it covers |
|---|---|
| `saga-orchestration` | Patterns for managing distributed transactions and long-running business processes. |

## `scienceskillscommon_`

| Skill | What it covers |
|---|---|
| `scienceskillscommon` | Shared Python package for Science Skills, currently containing http_client -- a unified HTTP client with rate limiting, retries, and exponential backoff. Not a standalone agent skill. Do not invoke... |

## `second-order-thinking_`

| Skill | What it covers |
|---|---|
| `second-order-thinking` | Extend consequence analysis beyond immediate effects by repeatedly asking and then what to surface cascading outcomes, incentives, and long-term risks. Use for strategy, policy, and architectural d... |

## `shadcn-skills_`

| Skill | What it covers |
|---|---|
| `shadcn-skills` | Installation, components, blocks, forms, theming, and MCP guidance for shadcn/ui in modern Next.js projects using pnpm |

## `six-thinking-hats_`

| Skill | What it covers |
|---|---|
| `six-thinking-hats` | Deliberately switch between six thinking modes (facts, emotions, risks, benefits, creativity, process) to produce balanced analysis without mixing modes. Use for high-stakes decisions, design revie... |

## `skill-library-structure_`

| Skill | What it covers |
|---|---|
| `skill-library-structure` | Class‑level convention for organizing Hermes skills within the project. Every skill that belongs to the shared library must follow this pattern: - reside under `features/ai/hermes-agent/.hermes/ski... |

## `skills_`

| Skill | What it covers |
|---|---|
| `skills` | Scan available skills. Select every skill that materially improves this task; skip the rest.  Before acting: list reviewed vs using (paths only). Load and follow each selected skill.  Prefer fewer,... |

## `supabase-nextjs_`

| Skill | What it covers |
|---|---|
| `supabase-nextjs` | Use when doing ANY task involving Supabase. Triggers: Supabase products (Database, Auth, Edge Functions, Realtime, Storage, Vectors, Cron, Queues); client libraries and SSR integrations (supabase-j... |

## `temporal-cloud_`

| Skill | What it covers |
|---|---|
| `temporal-cloud` | Fix Temporal Cloud connection, auth, and config problems. Use when users hit login failures, can't connect to Cloud, get x509/TLS errors, have namespace or endpoint mismatches, paste broken SDK con... |

## `temporal-developer_`

| Skill | What it covers |
|---|---|
| `temporal-developer` | Develop, debug, and manage Temporal applications across Python, TypeScript, Go, Java, .NET, Ruby, and Rust. Use when the user is building workflows, activities, or workers with a Temporal SDK, debu... |

## `temporal-workflow-design-critic_`

| Skill | What it covers |
|---|---|
| `temporal-workflow-design-critic` | Critique, audit, or score a Temporal workflow design for correctness, production readiness, and best-practice compliance. Use when asked to review a Temporal architecture, evaluate whether a design... |

## `theme-factory_`

| Skill | What it covers |
|---|---|
| `theme-factory` | Toolkit for styling artifacts with a theme. These artifacts can be slides, docs, reportings, HTML landing pages, etc. There are 10 pre-set themes with colors/fonts that you can apply to any artifac... |

## `using-ui-stack_`

| Skill | What it covers |
|---|---|
| `using-ui-stack` | Enforce a configuration-driven design system when generating UI. Ensures consistent spacing, colors, typography, dark mode, interactions, and accessibility across all AI-generated components. |

## `visual-qa-testing_`

| Skill | What it covers |
|---|---|
| `visual-qa-testing` | Visually QA a web application by launching it in Cursor's built-in browser, taking screenshots, checking console errors, and auditing network requests. Use after making UI changes to verify they lo... |

## `web-artifacts-builder_`

| Skill | What it covers |
|---|---|
| `web-artifacts-builder` | Suite of tools for creating elaborate, multi-component claude.ai HTML artifacts using modern frontend web technologies (React, Tailwind CSS, shadcn/ui). Use for complex artifacts requiring state ma... |

## `web-design-guidelines_`

| Skill | What it covers |
|---|---|
| `web-design-guidelines` | Review UI code for Web Interface Guidelines compliance. Use when asked to "review my UI", "check accessibility", "audit design", "review UX", or "check my site against best practices". |

## `web-research-techniques_`

| Skill | What it covers |
|---|---|
| `web-research-techniques` | How to research topics on the internet using Hermes Agent's available tools. Covers the right tool for each research pattern, with recipes for GitHub API searches, web scraping, and synthesizing re... |

## `webapp-playwright-testing_`

| Skill | What it covers |
|---|---|
| `webapp-playwright-testing` | Browser automation toolkit using Playwright MCP for testing web applications. Use when asked to navigate pages, click elements, fill forms, take screenshots, verify UI components, check console log... |

## `workflow-skill-creator_`

| Skill | What it covers |
|---|---|
| `workflow-skill-creator` | Distills a completed user workflow or interaction into a reusable agent skill. Use when the user asks to turn their workflow, interaction, or multi-step process into a skill, or when they say "make... |

## `zwicky-box_`

| Skill | What it covers |
|---|---|
| `zwicky-box` | Generate solution space by listing independent problem dimensions and their values, then combining systematically (morphological analysis). Use for creative ideation, architecture variants, and exp... |

---

Generated by `plugins/id-workflow/hooks/sync-skills.sh` from `.claude/skills.manifest`.
Do not edit by hand — edit the manifest and re-run.
