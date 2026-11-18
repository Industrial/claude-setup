---
name: idclear-cursor-nix-features
paths:
  - "nix/devenv-modules/**"
  - "**/devenv.nix"
  - "**/devenv.yaml"
description: >-
  Editing the shared devenv feature modules under `nix/devenv-modules/features/` for
  this monorepo — feature-flag pattern, mkDefault vs mkForce precedence,
  how per-hook / per-script options propagate into the auto-generated
  `pre-commit-config.json` (and other devenv artifacts), and how to find
  downstream option schemas in the cached nix store. Use when adding or
  patching a `nix/devenv-modules/features/*.nix` module, debugging why a devenv
  consumer sees unexpected behaviour after a `git-hooks` / `git-hooks-prek`
  change, or wiring a new consumer repo against this facade.
disable-model-invocation: true
---

# idclear `nix/devenv-modules` feature modules

## When to use

- Editing a file under `nix/devenv-modules/features/*.nix` (e.g. to change a
  pre-commit hook's `verbose` flag, default script body, or env vars).
- Adding a new `nix/devenv-modules/features/<name>.nix` and the matching
  `<name>.assay.nix` claim suite.
- Wiring a new consumer repo that imports `nix/devenv-modules` and wondering
  which `local.features.*.enable = true` lines to flip.
- Debugging why a `devenv up` regeneration produces a `pre-commit-config.json`
  (or other auto-generated artifact) with unexpected values — usually the
  field is silently being set to the default somewhere upstream.

## Layout

These modules used to come from the shared `.cursor` submodule (option
namespace `cursor.features.*`). They are now vendored into each repo under
`nix/devenv-modules/`, with the namespace `local.features.*`. A repo's copy
is its own: changes do not propagate to other repos.

```
nix/devenv-modules/
  default.nix / default.assay.nix     # module entry, imported from the root devenv.nix
  devenv.nix / devenv.yaml            # consumer-facing entrypoint
  lib/
    assay.nix                          # pinned Industrial/assay claim DSL
    feature-eval.nix                   # evalModules + freeform (no per-feature stub inventory)
  features/
    <name>.nix                         # one devenv module per feature
    <name>.assay.nix                   # co-located assay claim suite
```

Each feature defaults to **off**. Consumer enables per-feature with:

```nix
local.features.<name>.enable = true;
# optional override
local.features.<name>.<option> = "value";
```

The facade is consumed from `devenv.nix` via:

```nix
{ imports = [ ./nix/devenv-modules ]; }
```

## Editing a feature module — pattern

`nix/devenv-modules/features/git-hooks-prek.nix` is the canonical worked example
(see `references/git-hooks-prek-verbose-fix.md` for the exact diff from
this session). General shape:

```nix
{ lib, config, pkgs, ... }:
let
  cfg = config.local.features.<feature-name>;
in {
  options.local.features.<feature-name> = {
    enable   = lib.mkEnableOption "...";
    # typed options specific to the feature
    optionX  = lib.mkOption { type = lib.types.str; default = "..."; };
  };

  config = lib.mkIf cfg.enable {
    # env vars, packages, scripts, enterShell, git-hooks.hooks.<name>
  };
}
```

### Precedence — `mkDefault` vs `mkForce` vs the `soft` override trick

The shared modules commonly use:

- `mkDefault` (1000): default the consumer can override.
- `soft = lib.mkOverride 1500` in `git-hooks-moon.nix`: weaker than
  `mkDefault`, so user `.env` / dotenv wins on conflict. Reuse this when
  the option must lose to user-supplied env vars.
- `lib.mkForce` in the consumer's `devenv.nix`: project-level override
  that beats both. Use sparingly — it defeats the feature module.

If a feature option appears stuck at its default, check that no
`lib.mkForce` is set downstream. If a feature option is overridden by a
devenv dotenv-loaded variable, that's the `soft` precedence doing its
job — `git-hooks-moon.nix` line 7 (in this checkout) is the canonical
example.

### Co-located assay suite

Every `features/<name>.nix` has a co-located `features/<name>.assay.nix`
that exercises the module's claims. Use `assay run <path>` to execute.
Keep the suite in lockstep with module changes — the README at
`nix/devenv-modules/README.md` is explicit about this.

## How auto-generated configs flow downstream

Several features write artifacts that devenv regenerates on `devenv up`:

| Feature module     | Writes / regenerates                                     |
|--------------------|----------------------------------------------------------|
| `git-hooks.nix`    | `.pre-commit-config.<yaml\|json>` (cachix submodule)     |
| `git-hooks-prek.nix` | Calls `prek install -f -c <cfg>` (re-uses pre-commit config) |
| `git-hooks-moon.nix`  | Adds `pre-commit` / `pre-push` shell scripts (devenv scripts) |

The symlink at `/data/Code/idclear/monorepo/.pre-commit-config.yaml`
points into `/nix/store/...-pre-commit-config.json` — that's the
generated artifact. Editing a feature module + `devenv up` re-renders
the JSON and replaces the symlink target.

## Finding downstream option schemas

When you need to add or override an option on something the facade
delegates to (most commonly `git-hooks.<hook-name>` from cachix
`git-hooks.nix`), the schema is **not** in this repo — it's in the
cached nix store. Find it:

```bash
# Locate the git-hooks submodule source in the nix store
find /nix/store -maxdepth 4 -path "*git-hooks*" -name "hook.nix" \
  2>/dev/null | head -1
```

Then read `hook.nix` — the `mkOption { ... }` blocks define every
per-hook key (`verbose`, `always_run`, `pass_filenames`, `args`, …).
The serialization list near the bottom (look for
`inherit (config) … verbose …`) tells you exactly which keys end up in
the generated JSON.

### Worked example — `verbose` for prek output

prek (and Python pre-commit) capture hook stdout/stderr by default and
only print on failure. The `verbose = true` hook option forces
output on success too. To turn it on across the hooks this repo wires:

1. Open `nix/devenv-modules/features/git-hooks-prek.nix`.
2. Add `verbose = true;` to each `hooks.<name> = { … }` block
   (typically `pre-commit` and `pre-push`; the `commit-msg` hook has no
   user-facing output to show so it's left at the default).
3. Run `devenv up` (or just exit and re-enter the shell). The
   `.pre-commit-config.json` symlink target flips; prek picks up the
   new config on the next commit/push.

See `references/git-hooks-prek-verbose-fix.md` for the exact diff,
the regenerated JSON snippet, and the `hook.nix` line numbers I
discovered while doing this.

## Pitfalls

### Don't edit the generated JSON directly

The `.pre-commit-config.json` symlink target is a nix store path.
devenv rewrites it on every `devenv up`. Any direct edit is silently
overwritten. Make the change in the feature module instead.

### `disable-model-invocation: true` on this skill

This is a project-specific operational skill, not a heuristic match.
Agents should not load it from description-matching; load only when the
user explicitly references `nix/devenv-modules` features or `git-hooks-prek`
configuration.

### LeanCTX is locked to the repo root

`mcp_lean_ctx_ctx_read` / `ctx_tree` reject absolute paths outside the
repo. To inspect the cached nix-store sources for downstream schemas,
use `terminal` (e.g. `find /nix/store ...`) or `read_file` from a
shell — not lean-ctx.

### `nix/store` lookups are slow; narrow first

`find /nix/store` walks the whole store. Prefer one of:

```bash
find /nix/store -maxdepth 4 -name "hook.nix" 2>/dev/null
ls /nix/store/ | grep -i <keyword>
```

to bound the walk. A full `find /` will hit the 5-minute timeout.

### Consumer-repo duplicate `nix/` facade = duplicate-option error at `devenv up`

A consumer repo (this monorepo included, at one point) sometimes grows
a parallel tree under `nix/` (outside `nix/devenv-modules/`) shadowing the modules:

- `nix/default.nix` — `{imports = [./devenv-modules ./devenv.nix];}`
- `nix/devenv.yaml` — `imports: [./devenv-modules]`
- `nix/devenv.nix` — barrel that re-imports `./features/program-*.nix`
- `nix/features/<name>.nix` + `<name>.assay.nix` — byte-identical copies
  of `nix/devenv-modules/features/<name>.nix`
- `nix/features/hermes-agent/templates/{config.yaml,.env.example,SOUL.md}`
- `nix/lib/{assay.nix,feature-eval.nix}` — passthrough re-exports

This produces **duplicate-option errors** at `devenv up`:

```
error: The option `local.features.program-hermes.enable' in
`/…/nix/features/program-hermes.nix' is already declared in
`/…/nix/devenv-modules/features/program-hermes.nix'.
```

Fix order (don't shortcut — each step depends on the last):

1. **Diff the duplicates first** (`diff -rq nix/features/X nix/devenv-modules/features/X`
   per `X`). Most copies are byte-identical and safe to delete. Any
   with **local customisations** (e.g. extra MCP entries in
   `hermes-agent/templates/config.yaml`) need those changes ported
   into `nix/devenv-modules/features/…` or reproduced in the parent
   `devenv.nix` — don't delete-and-lose a one-off tweak.
2. **Drop the parent's `nix/devenv.nix` barrel** — it's a re-import
   list for files the facade already provides. After this, the
   facade's `nix/default.nix` becomes a one-line passthrough
   (`{imports = [./devenv-modules];}`); that passthrough can then also
   go.
3. **Delete the duplicated feature files** with `git rm` (after the
   diff in step 1 confirms they're identical). The orphaned
   `package.nix` derivations under `nix/features/<name>/` go with them.
4. **Re-point every template path** that referenced `nix/features/…`
   to `nix/devenv-modules/features/…`:
   - `devenv.nix` `enterShell` block (the `.env`, `config.yaml`,
     `SOUL.md` seed copies).
   - `AGENTS.md` and any other doc that pointed readers at the old
     path.
5. **Drop `local.features.<dead-feature>.enable = true;`** lines
   for features that lived in the parallel `nix/features/` but no
   longer exist in `nix/devenv-modules/features/` (e.g. when the shared stack
   removed `program-serena` upstream, the parent's local
   `program-serena.nix` should also go — and so should its `enable`
   line in `devenv.nix`).
6. **Replace `nix/moon.yml` with a `nix-test` task in the parent
   `moon.yml`** that runs `assay run nix/devenv-modules`. Co-located assay
   suites are still valuable as a regression-test surface; the parent
   doesn't need a separate sub-project (`library` moon layer) to host
   them. One task in the root `moon.yml` is enough.
7. **Wire `nix-test` into the pre-push gate**
   (`local.features.git-hooks-moon.prePushTargets`) so CI exercises
   the canonical feature stack on every push.

End state: the parent has **zero** `.nix` files outside `nix/devenv-modules/` except `devenv.nix`;
`nix/devenv-modules` is the only facade; a single `nix-test` task in the
parent `moon.yml` exercises it.

See `references/parent-nix-facade-cleanup.md` for the exact `comm` /
`diff -rq` discovery commands, the file-by-file deletion sequence,
and the 10-file diff this produced in this checkout.

## See also

- `nix/devenv-modules/README.md` — module authoring rules + Enable API
- `nix/devenv-modules/features/git-hooks-moon.nix` — the `soft` precedence pattern
- `nix/devenv-modules/features/git-hooks-prek.nix` — the verbose-output pattern
- `references/git-hooks-prek-verbose-fix.md` — session-specific transcript
- `.claude/skills/nix-and-flakes/` — Nix language reference