# Claude Code harness

What this layer does, and why each piece exists. Cursor and Hermes read the same conventions
from `AGENTS.md` and `.cursor/`; this layer adds the enforcement Claude Code can do and the
other two cannot.

This directory is the payload of the `features/ai/claude-code` dotfiles feature. Once
`bin/link-files-nixos` has run, `~/.claude` is a symlink to it and this is the system-wide
harness — the same relationship `features/ai/hermes-agent` has with `~/.hermes`.

## Where things live

The enforcement layer is packaged as a plugin so a second repository can install it instead of
copying it:

```
harness/
  .claude-plugin/marketplace.json  makes this directory a marketplace
  plugins/id-workflow/             the plugin — one copy of every script
    .claude-plugin/plugin.json
    hooks/hooks.json               the only hook wiring
    hooks/*.sh                     guards, mode state, formatter, verification gate
    agents/id-*.md                 the five tool-scoped subagents
    statusline.sh
settings.json                      permissions, statusline, plugin declaration, skillOverrides
mcp.json                           the four nix-backed MCP servers
commands/                          /id and friends — real files, 16 of them
skills/                            every skill, one tree, 230 of them
skills.manifest                    which of them carry a description in the roster
```

One level up, in the feature itself:

```
bin/link-files-nixos   makes ~/.claude point here
bin/vendor-skills      rebuilds the skill trees from their sources
bin/check-payload      the invariant suite — run it before the switch
collisions.tsv         which copy wins when two sources share a skill name
renames.tsv            source directories whose basename is a bad skill name
```

`check-payload` is referenced here and by `skills.manifest` but does not exist in this payload;
nothing currently enforces the roster budget automatically.

`settings.json` carries no hooks at all; `extraKnownMarketplaces` and `enabledPlugins` declare
the plugin instead. Claude Code does **not** auto-install a declared plugin
([#23737](https://github.com/anthropics/claude-code/issues/23737), closed as a duplicate of a
not-planned bug), so the plugin has to be installed once by hand. Until it is, there are no
rails at all — that is the cost of the single-mechanism wiring.

The seven `/id*` commands deliberately stay in `commands/` rather than moving into the plugin:
plugin commands are namespaced, so `/id-execute` would become `/id-workflow:id-execute`.
Commands are prose prompts with no enforcement value, so there is nothing to gain by moving them
and a worse keystroke to lose.

## Design premise

Cursor enforces workflow with prose the agent agrees to follow. Claude Code has three mechanisms
prose does not: **PreToolUse hooks** (deny the tool call), **subagents with tool allowlists**
(remove the capability), and a **statusline** (make state visible). So the ID workflow port is not a
transliteration of the Cursor pack — it converts that pack's soft rails into hard ones and reads the
pack itself, unforked, from `.cursor/commands/id-workflow/`.

## Hooks

| Hook | Event | What it does | Escape hatch |
|---|---|---|---|
| `block-native-tools.sh` | PreToolUse | Routes Read/Grep/Edit/Write/WebSearch/WebFetch to lean-ctx, roam-code, searxng, context7 | `CLAUDE_ALLOW_NATIVE_TOOLS=1` |
| `guard-bash.sh` | PreToolUse (Bash) | Blocks git branch deletion (never bypassable), routes shell to `ctx_shell`, requires `devenv shell --` when the routing hatch is open | routing only |
| `guard-write-paths.sh` | PreToolUse (writes) | Confines every write to the working tree; redirects scratch to `.tmp/` | `CLAUDE_ALLOW_OUTSIDE_WRITES=1` |
| `guard-id-mode.sh` | PreToolUse (writes) | Enforces the ID write ban for the current mode | `CLAUDE_ALLOW_ID_WRITES=1` |
| `id-mode-from-prompt.sh` | UserPromptSubmit | Sets ID mode when you type `/id…`, parses `lane:` and `tsk-` | — |
| `session-scratch-dir.sh` | SessionStart | Creates `.tmp/` and overrides the harness `/tmp` scratchpad instruction | — |
| `session-id-context.sh` | SessionStart | Re-injects mode/lane/task after resume or compaction | — |
| `format-after-edit.sh` | PostToolUse | Formats what was just edited | — |
| `stop-verify-gate.sh` | Stop | Refuses to end a turn on code that does not lint or typecheck | `CLAUDE_SKIP_STOP_GATE=1` |
| `test-hooks.sh` | — | The suite for all of the above: `bash plugins/id-workflow/hooks/test-hooks.sh` | — |

Every hook above except one is restrictive — it denies a write, blocks a tool, confines a path.
`stop-verify-gate.sh` is the exception and the only one that closes a loop: it makes the session
verify its own work instead of asking it to. It runs `bun run oxlint` then `bun run typecheck`
(~8s cold, ~0.1s when the changed files have not moved since the last green run), skips recon
modes entirely, and hands control back after three blocks on an unchanged tree rather than
spinning. It is deliberately not wired to `definitively run pre-commit`: those programs contain
`llm:` nodes that would spawn a nested Claude to grade this one. Tests are an opt-in tier —
`CLAUDE_STOP_GATE=lint,types,tests` — because a gate slow enough to annoy gets switched off.
Set `CLAUDE_STOP_GATE_DEBUG=1` to trace cache hits.

Hooks are snapshotted at session start. After editing one, restart Claude Code (`/hooks` shows what
is currently loaded).

One thing that did not survive the move to a system-wide install cleanly: `stop-verify-gate.sh`
runs `bun run oxlint` and `bun run typecheck`, which exist in the idclear monorepo and nowhere
else. In a Rust or Nix repository it finds no such scripts. It degrades quietly rather than
blocking, but the gate is doing nothing there — making it stack-aware is outstanding work.

## ID workflow

State lives in `.tmp/id/state.json` — mode, lane, claimed task — and is the single source of truth
for the guard, the statusline, and session re-injection. No state file means ID is disengaged and
nothing is restricted; a session that never types `/id` behaves like an unhooked one.

```
/id            enter ORIENT and auto-route
/id-orient   /id-research   /id-plan   /id-execute   /id-review   /id-ship
bash plugins/id-workflow/hooks/id-state.sh show | set <MODE> [--lane L] [--task T] | clear
```

What each mode may write — enforced, not requested:

| Mode | Writable |
|---|---|
| ORIENT, RESEARCH | `.tmp/**` |
| PLAN | `.tmp/**`, `.maestro/**`, `.cursor/plans/**` |
| REVIEW | `.tmp/**`, `.maestro/**` |
| EXECUTE, SHIP | anything in the working tree |

Known limit: the ban covers file-write **tools**. `ctx_shell` command strings are not inspected, so
a `sed -i` would slip through. That was a deliberate scope decision, not an oversight — guarding
arbitrary shell reliably is harder than the hole is wide.

## Subagents

| Agent | Model | Writes | Use in |
|---|---|---|---|
| `id-researcher` | inherit | none | ORIENT, RESEARCH — fan out per subsystem or hypothesis |
| `id-architect` | inherit | planning artifacts | PLAN — run several on competing framings |
| `id-implementer` | inherit | code | EXECUTE — one self-contained leaf each |
| `id-reviewer` | inherit | evidence | REVIEW, SHIP — adjudicates, cannot patch |
| `id-review-lens` | haiku | none | REVIEW — four in parallel: ac, correctness, scope, tests |

The read-only ones are read-only in their tool list, so the mode's write ban holds even if a prompt
tries to talk them out of it. `ctx_shell` is present for git recon; lean-ctx itself refuses shell
file-writes into the repo.

## Commands

`commands/` holds all 16 entrypoints as real files — the seven `/id*` ones plus the escape
hatches (`/quality`, `/skills`, `/agent`, `/debate`, `/plan-hierarchically`, `/pre-push`,
`/activate`, `/mcp-debug`, `/new-skill`). They used to be symlinks into
`.cursor/commands/`; see **Vendoring** below for why they are not any more.

## Skills

Every skill is here as real content — 230 of them in **one tree**, `skills/`, vendored from four
sources. None are symlinks and none need `.cursor/` or `.hermes/` to be present.

Nothing moves. There is no `skill-library/` directory and no sync script. Both existed to
reconcile `.cursor/skills` and `.hermes/skills` into a roster; those source trees are gone, so
the machinery that merged them went too.

What is still rationed is the **roster**: Claude Code loads every listed skill's name and
description at session start, and that listing is finite.

**The budget is characters, not entries.** The roster is a concatenation of every name and
description, and it is *truncated*, not trimmed entry-by-entry: it stops mid-word and everything
after the cut arrives as a bare slug. Measured at 81 entries / 26,629 chars, the cut landed
around position 73 — `scrutinize` (505 ch) and `system-design` (700 ch) arrived bare while `tdd`
at position 78 survived on a 75-char description. The ceiling sits near 21,000 chars. An earlier
note here claimed a 90-*entry* ceiling enforced by `check-payload`; both were wrong — that script
has never existed in this payload, and 90 short descriptions fit where 81 long ones did not.

Membership is a **flag, not a location**:

- **On the roster** — named in `skills.manifest`. Description loaded at session start,
  auto-invocable. 48 entries.
- **Off the roster** — `"user-invocable-only"` in `settings.json` under `skillOverrides`. Still
  installed, still `/name`-invocable, still readable by path; it simply does not spend roster
  budget. 181 entries. The `skill-library` skill explains how to search the tree.
- **Deleted** — 33 skills that taught general software craft the model already performs natively:
  commit conventions, rebase and merge resolution, ADR format, clean/hexagonal architecture, DDD
  theory, generic React and Playwright guidance, design taste. See `skills.manifest` for the bar.

**Identity is the directory name, not the frontmatter `name:`.** 28 skills disagree between the
two — `dev-caches-cleanup` declares `linux-dev-caches-cleanup`, the `id-effect-*` family declares
`id_effect-*`. Key both `skills.manifest` and `skillOverrides` on the directory name, or the
override silently fails to match and the skill quietly keeps its roster slot.

Promote by adding the directory name to `skills.manifest` and deleting its `skillOverrides`
entry; demote by the reverse. Both files, every time — that pairing is the only invariant, and
nothing on disk changes either way.

`skills/skill-library/SKILL.md` deliberately carries **no generated list**. An embedded index
goes stale the moment a skill is added or renamed, and there is no longer a script to rebuild it;
it teaches reading the tree instead, which is always correct.

## Vendoring, and the fork it creates

The skills came from `~/.dotfiles/.cursor/skills` (191), the hermes tree (79), `~/.maestro/skills`
(6) and the pre-dotfiles `~/.claude` (2) — 278 `SKILL.md` files, 262 unique names after dedupe.

They are copied, not linked, because this payload is the primary AI setup and has to work in any
repository, including ones with no `.cursor/` checkout. The consequence is worth stating plainly:

**`.cursor/skills` is a git submodule pointing at `github.com/Industrial/cursor-setup`, and
copying 191 skills out of it forks them.** Upstream changes no longer arrive on their own. The
refresh path is `bin/vendor-skills`, which re-runs the whole vendoring; it is the reason the
vendoring is a script rather than a one-off `cp -r`. What should happen to `.cursor/skills` in
the long run — become downstream of this payload, or be retired — is still open.

Two smaller consequences:

- The six `maestro-*` skills are **generated** by the maestro CLI into `~/.maestro/skills/`.
  Vendoring captured them at a point in time; they will go stale when maestro updates. Re-run
  `bin/vendor-skills` after upgrading it.
- Some vendored skill bodies reference `.cursor/...` paths internally. Those references were not
  rewritten — 229 skill bodies is a separate job — so a skill may occasionally point at a path
  that does not exist in the current project. The `.cursor/skills/...` paths some bodies cite are
  already dead: skills live at `.cursor/.claude/skills/`, and `.cursor/skills/` does not exist.
- **Nested `SKILL.md` files sit inside other skills**, and that is deliberate. `id-effect` is a
  collection whose body links its parts by relative path (`id_effect-fundamentals/SKILL.md`), so
  the parts have to travel with the parent. Those same parts are also vendored as top-level
  skills — `id-effect-fundamentals` — so they are findable by name. The content exists twice.
  Claude Code only scans one level deep, so the nested copies never reach the roster, and
  `bin/vendor-skills` rewrites both from the one source on every run. Editing the payload by hand
  is what would make them diverge — edit the source and re-vendor instead.

Name conflicts are resolved by two files rather than by copy order. `collisions.tsv` records
which copy wins when two sources ship different skills under one name, with the reasoning.
`renames.tsv` fixes source directories whose basename would be a useless roster entry — a
mikro-orm skill living in `entities/`, a playwright one in `pom/`. Names stay plain: no
`cursor-` or `hermes-` prefixes, ever.

```
bin/vendor-skills             apply
bin/vendor-skills --dry-run   report, write nothing
bin/vendor-skills --check     fail if the payload is missing a source skill
bin/check-payload             every invariant above, asserted
```

## Statusline

`statusline.sh` renders `[ID:MODE] lane:… · task · branch · ±dirty`, colour-coded by how much the
mode permits (green recon, yellow planning, cyan write-enabled). With ID disengaged it falls back to
model and branch. It reads one JSON file and two git plumbing calls — never call `maestro` from it,
that costs ~200 ms per render.

## Settings

`settings.json` is committed and shared. `settings.local.json` is per-machine and gitignored; keep
session-specific permission grants there, not in the shared file.
