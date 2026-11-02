---
id: fleet-rust-tooling
name: fleet-rust-tooling
description: >-
  Decide which dotfiles/NixOS components deserve a Rust rewrite vs staying a
  shell script; conventions for building, packaging (buildRustPackage), wiring
  into features/cli + profiles, and assay/id_effect testing of Rust tools in
  the .dotfiles fleet.
tags: []
related_skills: [nixos-managing, nixos-fleet-management]
---

# Fleet Rust Tooling

Class-level guide for "should this be Rust?" and "how do we ship Rust tools here".

## Script-or-Rust triage

Propose a Rust implementation only when MOST of these hold:

- Long-running process: daemon, HTTP server, timer loop, concurrency fan-out.
- Real parsing: XML/JSON/structured formats or REST clients — regex/sed on
  live config/state files is fragile (real case: arr-wiring seeds *arr
  `config.xml` via grep/sed).
- Retry/backoff, wait-for-ready logic, typed error handling.
- Deserves unit tests via the assay / id_effect workflow.

Keep as plain scripts (user directive, 2026-08, reaffirmed 2026-11-02):

- `bin/` plumbing (`fleet`, `vm/`, `generations/`, `update/`, `ci/` wrappers)
- fish functions/shell wrappers, hyprland/gnome launchers, writeShellApplication glue
- `scripts/*-mcp-wrapper.sh`, `installer/install-nixos.sh`

Never pitch a "Rust shell" project for what a ≤50-line script already does well.

**Scope ruling (2026-11-02): the Rust programme covers `rust/tools/*` ONLY.**
`bin/` is 37 files / 1,375 LOC, of which 27 are ≤21-line wrappers — converting
them buys nothing and costs a crate + nix package + lockfile + assay suite each.
The bin/-level entries in the candidate backlog below are parked, not queued.

## Inventory & layout patterns (copy these)

The workspace manifest is **`rust/Cargo.toml`**. (A stale `rust/workspace.toml`
listing long-gone members was deleted 2026-11-02 — cargo never read it; earlier
revisions of this skill pointed at it, which is why new crates kept missing the
real `members` list.)

| Tool | Layout | Packaging note |
|------|--------|----------------|
| oomkiller, nix-hash | `rust/tools/<name>` | members of the `rust/Cargo.toml` cargo workspace |
| nixos-update-notifier | `rust/tools/nixos-update-notifier` | STANDALONE crate: own Cargo.lock plus an empty `[workspace]` table so buildRustPackage vendors correctly |
| assay, nixq, usbtree, leaves | external repo | consumed as flake `inputs`, packaged upstream |

All three in-tree crates are edition 2024; devenv ships rustc 1.97-nightly.

## Wiring a new tool into the fleet

1. Create `rust/tools/<name>/`; join the workspace (add to `members` in
   `rust/Cargo.toml`) OR make it standalone with its own lockfile +
   `[workspace]` header.
2. Feature module `features/cli/<name>/default.nix`: `buildRustPackage`
   (or `callPackage` of a flake input), binary into `environment.systemPackages`.
3. Import from `profiles/base.nix` only if ALL hosts want it; else wire per-host.
4. Colocated `<stem>.assay.nix` suite; gate = `devenv shell -- assay run .`.
5. User-level systemd units (timers/notifications hitting the session D-Bus)
   live in the feature module — see `features/cli/nixos-update-notifier/default.nix`
   for the Nice/IOSchedulingClass pattern for heavy periodic jobs.

## id_effect version policy

**Current: 0.13.0** (released; core + `axum`, `cli`, `config`, `macro`, `optics`,
`platform`, `proc_macro`, `resilience`). Needs edition 2024 / rustc ≥ 1.94 —
`designing-with-id-effect` still documents 0.12 and calls 0.13 unreleased; that
note is stale, but its §15 break list is the upgrade checklist.

Pin id_effect ONCE, in `[workspace.dependencies]` of `rust/Cargo.toml`, and have
members write `id_effect = { workspace = true }`. Types from two id_effect
versions do not unify, so a split pin is a compile error waiting to happen.

**Known duplicate — the `Industrial/assay` family pins id_effect 0.4.0.**
`nixdrv`, `nixfetch`, `nixq`, `nixstore` (and `assay` itself) all pin `0.4.0`
exactly, so any in-tree crate depending on them resolves BOTH 0.4.0 and 0.13.0.
That is tolerable only while no id_effect type crosses the boundary — true today
because nix-hash's id_effect use is two link-check tests. Before any tool
genuinely builds on `Effect` while also using the assay crates, migrate
`/data/Code/rust/assay` to 0.13 first. Verify with:
`cargo tree -p <crate> -i id_effect@0.4.0`.

## Pitfalls

- New crate not added to `rust/Cargo.toml` members → cargo resolver errors.
  A member listed there that does NOT exist on disk is the same failure in
  reverse (real case: a phantom `tools/skjold` member broke every
  workspace-wide command until 2026-11-02).
- Standalone crate without the empty `[workspace]` table → attaches to a
  parent workspace and breaks buildRustPackage hashing.
- A declared id_effect dep that the source never uses still forces a version
  bump on every upgrade — `id_effect_macro`/`id_effect_proc_macro` sat unused in
  nix-hash for months. Grep before you pin.
- `pkgs.writers.writePython3` enforces pycodestyle at BUILD time — nontrivial
  embedded logic is safer as Rust (see nixos-managing pitfalls).
- `rust/tools/nix-hash/default.nix` is a `writeShellApplication` that calls
  `cargo build` at runtime, NOT `buildRustPackage` — so lockfile changes need no
  vendor-hash update there. Do not "fix" this by assuming a `cargoHash`.
- Releases follow devops/release-engineering; bump consumers in the same change.
- `/tmp` is a 2 GB tmpfs and devenv writes its activation script there. When it
  fills, `devenv shell` dies with `No space left on device`. Work around with
  `TMPDIR=<repo>/.tmp/devenv-tmp devenv shell -- …` rather than deleting another
  session's in-flight files.

## Candidate backlog (fleet audit 2026-08)

Ranked Rust-replacement candidates with file paths and rationale:
see `references/replacement-candidates.md`.

1. arr-wiring reconciler (replace sed-on-XML + writePython3)
2. Alert bridge (Alertmanager webhook receiver + active port probes → textfile collector)
3. vulnix replacement (OSV-backed closure scanner)
4. rustic, if/when backup coverage gets added (none exists today)
