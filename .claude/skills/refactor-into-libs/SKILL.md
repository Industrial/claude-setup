---
name: refactor-into-libs
description: >
  Move code from an app (or another package) into an existing or new
  `libs/*` bun workspace package in this monorepo — deciding whether to
  extend an existing lib or scaffold a new one, wiring `package.json`,
  `moon.yml`, `bunfig.toml`, `tsconfig.json`, root `tsconfig.json`
  references, and consumer dependencies correctly, then verifying with
  typecheck/lint/test. Use when asked to "extract this into a lib",
  "move this to libs/", "make this a shared package", or when code in
  `apps/*` is duplicated or needed by more than one app. Do not use for
  moving code between folders within the same package (plain refactor,
  no workspace wiring needed).
---

# Refactor into libs/

Checklist-driven workflow for relocating code out of `apps/*` (or another
`libs/*` package) into a `libs/*` bun workspace package, with the exact
wiring this monorepo needs to keep `moon run :build`, `bun run typecheck`,
and per-package coverage green afterward. Grounded in `AGENTS.md` and the
shape of existing packages (`libs/schemas`, `libs/ui`, `libs/db`) — read
those sections before deviating from what's written here.

## When to use

- Code in `apps/test-nextjs` (or another app) is needed by a second app, or
  is already duplicated across two places.
- The user says "extract this into a lib", "make this shared", "move this
  to libs/", or points at a folder and asks it to become a package.

## When NOT to use

- Moving code between folders **inside** the same package — that's a plain
  file move, no workspace/moon/tsconfig wiring involved.
- Introducing a brand-new third-party dependency wrapper with no existing
  call site to move — that's a new lib from scratch, not a refactor; most
  of the scaffolding steps below still apply, but skip the "find the code"
  and "update call sites" steps.

## Step 0 — Extend an existing lib, or create a new one?

Proliferation is the failure mode this step guards against — this repo
already has 25+ `libs/*` packages (`authentication`, `base`, `blob-storage`,
`common`, `crud`, `db`, `effect*` (7 packages), `logto`, `misttrack`,
`models`, `rule-engine`, `schemas`, `subject-model`, `theme`,
`typescript-configuration`, `ui`, …). Before scaffolding a new one:

1. `ctx_search` / `roam_search_symbol` for the domain concept across
   `libs/*` — does an existing package already own this concern (schema
   types → `@idclear/schemas`, Effect infra → the `effect-*` family,
   MikroORM entities → `@idclear/models`, generic non-Effect helpers →
   `@idclear/common` or `@idclear/base`)?
2. Extend the existing lib when the code is a natural addition to its
   existing domain and doesn't need a different dependency graph (e.g. a
   pure-TS lib gaining a React-only helper is a smell — that belongs in a
   lib that already depends on React, or a new one).
3. Create a new lib when the code is a distinct domain/bounded concern, or
   pulling it into an existing lib would force that lib to gain a new
   runtime dependency (React, Temporal, a provider SDK) that its other
   consumers don't want pulled in transitively.

If extending: skip to **Step 2**. If creating: continue to **Step 1**.

## Step 1 — Scaffold a new libs/* package

Copy the shape of the smallest lib that matches your dependency profile —
`libs/schemas` for a pure-TS/Effect lib with no framework dependency,
`libs/ui` for a lib with React + CSS. There is no `moon generate` template
in this repo; copy-and-adapt is the established method.

```
libs/<name>/
├── package.json
├── moon.yml
├── bunfig.toml
├── tsconfig.json
├── test.setup.ts        # only if the lib needs test-wide setup (see libs/schemas)
└── src/
    └── index.ts          # the only public entry point — everything re-exports through here
```

**`package.json`** — minimum shape (see `libs/schemas/package.json` for a
real example):

```jsonc
{
  "name": "@idclear/<name>",
  "version": "0.1.0",
  "type": "module",
  "main": "src/index.ts",
  "module": "src/index.ts",
  "exports": {
    ".": { "types": "./src/index.ts", "default": "./src/index.ts" }
  },
  // REQUIRED — see AGENTS.md "Tree-shaking: every lib declares sideEffects".
  // `false` for a pure library; `["**/*.css"]` only if a module imports CSS
  // for its side effect (libs/ui's exception). Never omit this field.
  "sideEffects": false,
  "dependencies": {
    // "@idclear/<other-lib>": "workspace:*" for any internal lib this one calls
  },
  "devDependencies": {
    "@idclear/base": "workspace:*",
    "@typescript/native-preview": "^7.0.0-dev.20260128.1"
  },
  "scripts": {
    "packages:install": "bun install",
    "packages:update": "bunx npm-check-updates -u",
    "test": "bun test src",
    "test:coverage": "bun test src --coverage --pass-with-no-tests"
  }
}
```

Before writing `"sideEffects": false`, verify the lib really is pure: no
bare `import 'x'` in `src/`, no top-level mutation of globals/registries.
`@idclear/db`, `@idclear/models`, and `@pkg/blob-storage` are the deliberate
exceptions (MikroORM entity metadata registration) — do not copy their
omission unless your lib has the same constraint.

**`tsconfig.json`** — extends the shared base, composite for TS project
references:

```json
{
  "composite": true,
  "extends": "../typescript-configuration/src/lib/tsconfig.base.json",
  "files": ["./src/index.ts"],
  "include": ["./src/**/*.ts"]
}
```

**`bunfig.toml`** — the coverage gate. Copy verbatim from any sibling lib;
the plural keys and explicit zeroes are load-bearing (`TESTING.md` §6):

```toml
[test]
preload = ["../base/src/testing/test-preload.ts"]
coverageReporter = ["text", "lcov"]
coverageDir = "coverage"
coveragePathIgnorePatterns = ["../**", "../../**", "e2e/**"]
coverageSkipTestFiles = true
coverageThreshold = { lines = 0.95, functions = 0, statements = 0 }
```

**`moon.yml`** — copy from `libs/schemas/moon.yml`; `test` and `coverage`
tasks both depend on `monorepo:format`, `monorepo:oxlint`,
`monorepo:typecheck`, `monorepo:biome`. `libs/*` is already a glob project
pattern in `.moon/workspace.yml` — a new lib directory with a `moon.yml` is
auto-discovered, no registration needed there.

**Root `tsconfig.json` — NOT auto-discovered, must edit by hand.** Add
`{ "path": "libs/<name>" }` to the root `references` array (alphabetical,
matching the existing entries). Skipping this step is the most common way
this workflow silently breaks `bun run typecheck` (`tsgo -b --noEmit`) for
everyone else, because the new package's project reference is simply
absent from the build graph — no error until someone runs a full build.

## Step 2 — Move the code

1. `git mv` the source files into `libs/<name>/src/` (or the existing
   lib's `src/`), preserving history.
2. Fix internal imports: relative imports within the moved code stay
   relative; imports of things that stayed behind in the app become
   `@idclear/<name>` package imports.
3. Keep Effect imports deep (`import * as Effect from 'effect/Effect'`,
   never the bare `effect` barrel) — this is enforced by biome
   `style/noRestrictedImports` and runs in `bun run typecheck`.
4. Re-export the moved public API through `src/index.ts` — that barrel is
   the lib's only public surface; nothing outside `src/index.ts` should be
   imported directly by consumers (this is what makes the `sideEffects`
   field meaningful — see AGENTS.md).
5. Move the corresponding `*.test.ts` files alongside their source files
   (not into a separate `__tests__` tree) and confirm they still import
   test helpers from `@idclear/base/testing`, not `bun:test` directly
   (`TESTING.md`).

## Step 3 — Wire consumers

For every app or lib that used the old location:

1. Add `"@idclear/<name>": "workspace:*"` to its `package.json`
   `dependencies` (bun workspaces resolve this via symlink on install — no
   path aliases needed, there's no `tsconfig` `paths` map in this repo).
2. Update import specifiers from the old relative/local path to
   `@idclear/<name>`.
3. If the moved code is used inside `apps/test-nextjs`'s client bundle and
   is not on that route's first paint, consider whether it should go
   through a `next/dynamic` wrapper per the "Code splitting" section of
   AGENTS.md — moving code into a lib does not exempt it from that
   convention.
4. Run `bun install` at the repo root so the new/changed workspace
   dependency gets symlinked.

## Step 4 — Verify

Run the full gate, not just the pieces — `monorepo:lint` already fans out
to format, oxlint, typecheck, and biome:

```bash
bun run typecheck                    # catches a missing root tsconfig reference
bun run oxlint
cd libs/<name> && bun run test:coverage   # per-file 95% line gate
moon run :build                      # confirms the project graph resolved
bun run ci:pre-push                  # full gate, affected vs remote
```

A missing root `tsconfig.json` reference (Step 1) surfaces here as
`tsgo -b` either silently skipping the new package or failing to resolve
`@idclear/<name>` imports from consumers — if typecheck fails only on the
new import and the package itself compiles standalone, check that first.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Bundler pulls in the whole new lib for one import | Missing/wrong `sideEffects` field | Add `"sideEffects": false` (or the CSS array form) to the new lib's `package.json` |
| `tsgo -b --noEmit` doesn't see the new package, or consumer imports fail to resolve | New lib missing from root `tsconfig.json` `references` | Add `{ "path": "libs/<name>" }` |
| `moon run :coverage` fails only on the new lib | `bunfig.toml` copied incompletely (missing plural keys / explicit zeroes) | Copy `bunfig.toml` from a sibling lib verbatim, don't hand-write it |
| Consumer can't resolve `@idclear/<name>` | Forgot `"@idclear/<name>": "workspace:*"` in the consumer's `package.json`, or didn't re-run `bun install` | Add the dependency, `bun install` |
| `effect` barrel import lint error after the move | Moved code imported `{ Effect } from 'effect'` | Switch to `import * as Effect from 'effect/Effect'` |

## See also

- `AGENTS.md` — "Tree-shaking: every lib declares `sideEffects`" and
  "Effect imports are always deep" (the two rules this skill exists to
  enforce during a move)
- `TESTING.md` §6 — the coverage gate's exact `bunfig.toml` contract
- `.claude/skills/improve-test-coverage/SKILL.md` — once the lib exists,
  use this to close any coverage gaps the move introduced
