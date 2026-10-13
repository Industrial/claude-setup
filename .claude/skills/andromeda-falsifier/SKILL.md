---
name: andromeda-falsifier
description: Fail-closed promote gates for Andromeda autoresearch — catalog coverage, calendar floors, holdout window B bands, A-only refusal, and minimum trade counts. Load before promoting hyperopt winners to paper configs or wiring FalsifierService / PromotionGateService.
category: development
---

# Andromeda falsifier

Every promote decision is **fail-closed**. Missing evidence is a refuse, not a
soft warning. Short-catalog Sharpe is advisory only.

## Checklist (all must pass)

| Gate | Refuse when | FailureAtom family (typical) |
|------|-------------|------------------------------|
| Coverage | Catalog `coverage_incomplete` / missing micro·l2·funding for the window | `coverage_incomplete` |
| Calendar | Search or holdout window below minimum calendar / bar floor | `calendar_floor` |
| Holdout B | No B run, or B metrics not same-ballpark as A | `holdout_collapse` / `holdout_missing` |
| A-only | Candidate scored or selected using window B, or promote attempted from A alone | `a_only_promote` |
| Min trades | Trade count below floor on A reproduce or B confirm | `min_trades` |
| `--only` | Trial searched outside declared `--only` set | `only_violation` |
| Purity | Strategy purity / lookahead CI already red | `purity` |

## A / B partition

- Window **A** = discovery / search. Hyperopt and shortlisting live here.
- Window **B** = confirmation. Scoring non-shortlisted candidates on B is refused.
- Mechanical partition: A ∩ B empty (harness uses half-open ends). Adjacent OK:
  `search_end == holdout_start` is fine; overlap raises at harness lock.

## Promote path

1. Reproduce best Trial as plain `andromeda backtest` on A (params match within tolerance).
2. Run unchanged config on B.
3. Falsifier checklist green.
4. AFML candidates: aspirational `PromotionGateService` / DSR path when wired;
   scalper path uses holdout bands only — do not claim DSR without a ledger row.
5. Writer emits a **new** config (never silent overwrite of live paper).

## Refusals write memory

Each refuse appends a `FailureAtom` with `fingerprint`, `error_family`, `rule`,
and `harness_id`. The `--only` planner reads these to quarantine islands — do not
delete or rewrite past atoms.
