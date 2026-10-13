---
name: andromeda-dream
description: >-
  Endless Andromeda overnight operator for Claude Code only — wake→night→morning
  handoff→continue in a Claude Code session (new session or same session). Runs
  `andromeda dream` (Tier G/L/U only; never Tier S); classical search stays
  subprocess `andromeda hyperopt`; Claude Code is the OUTER operator. Load before
  dream, overnight, morning handoff, or endless nights. No Cursor. No Hermes.
category: development
---

# Andromeda dream operator

Compose the autoresearch spine into **endless Claude Code nights**: wake → night →
morning handoff → continue. Spec: `.maestro/specs/andromeda-dream-operator.md`.
Spine detail: `andromeda-autoresearch`. Promote gates: `andromeda-falsifier`.
Port / live-session safety: `andromeda-backtest-tuning` (Dream / overnight mode).

**Maestro does not schedule dream nights.** Endless cadence is this skill plus
**Claude Code sessions** reading the morning markdown handoff.

**Forbidden operator surfaces:** Cursor (any product), Hermes (cron or agent).
Claude Code is the only AI allowed.

## Operator loop

```
WAKE → NIGHT (`andromeda dream …`) → MORNING (JSON + MD handoff) → CONTINUE (Claude Code session)
```

| Phase | What you do |
|-------|-------------|
| **Wake** | Read latest `catalog/index/dream-*.md` handoff (or start fresh). Confirm no live/paper session owns the API port. Load this skill + `andromeda-autoresearch`. |
| **Night** | Run `andromeda dream` with locked A/B windows. Classical search is always subprocess `andromeda hyperopt` — Claude Code is the **outer** operator only (plan continue-from-here, never inside the search loop). |
| **Morning** | Read the markdown handoff: `harness_id`, ledger path, next `--only`, quarantines, promote path or refuse reasons. JSON twin lives beside it. |
| **Continue** | Stay in Claude Code or open a **new Claude Code session** with the wake prompt below. Do **not** ask Maestro to tick nights. Do **not** use Cursor or Hermes. |

## Mutation tiers (overnight)

| Tier | Surface | Overnight? |
|------|---------|------------|
| **G** | Gate knobs | Yes — preferred |
| **L** | Label knobs | Yes — budget fewer epochs |
| **U** | Universe / `--only` / exemplars | Yes |
| **S** | Level-1 strategy `.py` | **Never** — human-gated EXECUTE only |

Refuse any overnight ask that edits Tier S. Strategy purity + NT reload contracts
forbid importing `andromeda`/`sieve` from strategy modules except Parameter ACL.

## CLI

```bash
andromeda dream --config <path> --search-start <ISO> --search-end <ISO> --holdout-start <ISO> --holdout-end <ISO> [--max-epochs N]
```

| Flag | Role |
|------|------|
| `--config` | Operator config (strategy, venue, pairlist, costs, afml.*). |
| `--search-start/end` | Discovery window **A** (half-open). |
| `--holdout-start/end` | Holdout window **B** — must not overlap A. |
| `--max-epochs N` | Cap LOOP epochs (default may be 1). |

Windows and digests lock into a `Harness`; ledger SQLite under `catalog/index/`.
One epoch: plan → hyperopt A → reproduce_a → holdout B metrics → falsify →
promote|quarantine → REPORT. Promote writes **new** files under
`python/andromeda/configs/generated/` — never silent overwrite of paper.

## BOOT safety

1. Real `port_in_use(api_port)` probe before the night starts.
2. Conflicting port **or** `live_session_risk` → **BOOT halt**, append
   `FailureAtom` with `error_family=live_session_risk`, still write morning
   summary, **stop** — do not continue hypothesizing.
3. Bind dream/backtest/hyperopt to a port no paper/live session uses.
   See `andromeda-backtest-tuning` Dream / overnight mode for `force_webserver`
   and `ps aux` checks.

## Morning handoff

After REPORT, read:

```
catalog/index/dream-*.md
```

(JSON twin: `catalog/index/dream-*.json` — same stem as the locked `harness_id`
prefix.) The markdown is the continue-from-here surface for the next Claude Code
turn or session:

- `harness_id` and ledger path (`catalog/index/autoresearch.sqlite`)
- next `--only` group (respect quarantines from FailureAtoms)
- promote path under `configs/generated/` **or** refuse reasons
- halted / `live_session_risk` if BOOT stopped early

Do not invent a second memory store — query the ledger and the handoff.

Required handoff fields before continuing: `harness_id`, ledger path,
`epochs_run`, `phase`, `halted`/`halt_reason`, `quarantines`, promote path **or**
refuse reasons, **Continue from here** block, `short_window_disclaimer`.

## Endless recipe (Claude Code only)

Full copy-paste recipe: `python/andromeda/docs/hyperopt/dream_endless_operator.md`.

**Maestro does not schedule dream nights.** Cadence is this skill + Claude Code
only — **never Cursor, never Hermes**.

### Wake prompt (paste as first message or next turn)

```text
Read the latest catalog/index/dream-*.md continue-from-here. Load skill andromeda-dream. If BOOT halt, empty plan, catalog floor, or live_session_risk → stop. Otherwise run andromeda dream with A/B windows and config from the handoff. After REPORT, leave the new morning MD as the next continue-from-here. Maestro must not schedule dream nights. Do not use Cursor or Hermes.
```

### How to run endlessly

1. **Same Claude Code session** — after REPORT, paste the wake prompt again (or follow the handoff **Continue from here** block) for the next night.
2. **New Claude Code session** — open a fresh session in the repo, paste the wake prompt, run one night, stop on stop conditions.

There is no external cron. You (or Claude Code following this skill) start each night.

### Stop conditions (end the loop)

| Condition | Action |
|-----------|--------|
| **BOOT halt** / **`live_session_risk`** | Stop; fix port/session before any new night |
| **Empty plan** | All knobs quarantined / planner empty → stop; human reopens search space |
| **Catalog floor** | History too thin for trustworthy A/B → stop; extend catalog first |

## Cross-links

| Skill | Use when |
|-------|----------|
| `andromeda-autoresearch` | Harness lock, FailureAtom memory, Tier table, hyperopt JSON `"top"` |
| `andromeda-falsifier` | Fail-closed promote checklist (coverage, calendar, holdout B, A-only) |
| `andromeda-backtest-tuning` | Port / rogue-session landmines, walk-forward fold sizing, `--only` craft |

## Non-negotiables

1. Claude Code is the **only** AI OUTER operator; classical search = subprocess `andromeda hyperopt`.
2. Overnight mutations Tier **G/L/U** only — never Tier **S**.
3. Halt on `live_session_risk` / conflicting API port.
4. Endless loop = this skill + Claude Code sessions/turns — **no Maestro schedule, no Cursor, no Hermes**.
5. Package home stays `python/andromeda`.
