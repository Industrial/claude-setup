---
name: andromeda-autoresearch
description: Closed-loop Andromeda research overnight — lock an immutable eval harness, hypothesize→mutate→measure→remember via subprocess `andromeda hyperopt`, append Hypothesis/Trial/Verdict/FailureAtom memory, and never edit Level-1 strategy source. Load before running dream/autoresearch, planning `--only` groups, or extending the trial ledger.
category: development
---

# Andromeda autoresearch

Closed research loop that converges evidence under a **locked** eval harness.
Overnight agents mutate config / `--only` surfaces only — never Level-1 strategy
source. Spec: `.maestro/specs/andromeda-autoresearch-spine.md`.

## Spine (BOOT → REPORT)

```
BOOT → LOCK_HARNESS → LOAD_MEMORY → LOOP(hypothesize→mutate→measure) → FALSIFY → PROMOTE|QUARANTINE → WEALTH_BUDGET → REPORT
```

| Step | Rule |
|------|------|
| LOCK_HARNESS | Pin strategy, config digest, venue, catalog, pairs, A/B windows, costs, folds, loss, seed. Change any pin ⇒ new `harness_id`. |
| LOOP | Subprocess `andromeda hyperopt` (CLI boundary). Capture stdout JSON (`"top"`). Append Trial rows. |
| FALSIFY | Fail-closed — see `andromeda-falsifier`. |
| PROMOTE | New config file only; never silent overwrite of paper. |
| WEALTH | Post-promote stake budget — see `andromeda-wealth-controller`. |

## Immutable harness

Per night the harness is frozen. Domain type: `andromeda.domain.autoresearch_harness.Harness`.

- `harness_id` = sha256 of canonical JSON of all pins (sorted keys).
- Discovery window **A** and holdout **B** must not overlap (half-open `[start, end)`).
- Editing loss, costs, or folds mid-loop is forbidden — that is a new harness, not a trial.

## Mutation tiers (overnight surface)

| Tier | Surface | Overnight? |
|------|---------|------------|
| **G** | Gate knobs (`min_conf`, `exit_conf_frac`, `min_edge_ticks`, …) | Yes — cheap, preferred |
| **L** | Label knobs (`barrier_mult`, `vol_window`, …) | Yes — expensive; budget fewer epochs |
| **U** | Universe / search surface (`--only` groups, exemplar config JSON, pairlist[0] discipline) | Yes |
| **S** | Level-1 strategy source (`.py` under `strategies/`) | **No** — human-gated EXECUTE only |

Overnight agents **must not** edit Tier S. Strategy purity AST + NT reload contract
forbid importing `andromeda`/`sieve` from strategy modules except Parameter ACL.

## Hyperopt mechanics

- Prefer `andromeda hyperopt` over hand-rolled grids.
- Always pass explicit `--only name …` (2–4 knobs). Joint 18-D search needs a charter.
- Default loss is `composite` on window A. Wealth trajectory is **not** hyperopt loss v0.
- Hyperopt scores `pairlist[0]` only. Promote requires a separate multi-pair HistoricalRunner confirm (P3).
- Parse final JSON for `"top"`, not `"history"`. Trials print nothing until the end — size timeouts honestly.

## FailureAtom schema

Append-only memory (`andromeda.research.autoresearch_ledger`):

| Field | Role |
|-------|------|
| `fingerprint` | Stable id for dedupe / planner quarantine |
| `error_family` | e.g. `holdout_collapse`, `coverage_incomplete`, `infra`, `live_session_risk` |
| `context_json` | Structured extras |
| `rule` | Which gate / planner rule fired |
| `harness_id` | Ties atom to the locked ruler |
| `ts` | ISO timestamp |

Never `UPDATE` past FailureAtom / Hypothesis / Trial / Verdict rows. Query by
`error_family` or `fingerprint` when planning the next `--only` group.

## Non-negotiables

1. Do not move the ruler inside a trial.
2. Do not promote on composite-on-A alone — holdout B + falsifier required.
3. Do not edit Level-1 strategy overnight (Tier S).
4. Halt the dream loop on `live_session_risk` (see dream section in `andromeda-backtest-tuning`).
