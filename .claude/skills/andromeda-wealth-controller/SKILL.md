---
name: andromeda-wealth-controller
description: Post-promote wealth-trajectory stake control for Andromeda — wallet-aware available equity on the entry ladder, trajectory stake budget under DD/ruin caps, paper only, and never a second decide_on_bar. Load before changing stake_amount, custom_stake_amount, resolve_stake_amount, or wealth_trajectory config.
category: development
---

# Andromeda wealth controller

Capital control **after** a candidate survives falsifier + promote. Not a hyperopt
loss term in spine v0. Not a second decision core.

## Trajectory stake (v0)

- Config block `wealth_trajectory`: target curve, max drawdown, ruin floor.
- Controller outputs a **stake budget** and/or halt flag.
- Strategy consumes via `custom_stake_amount` / hooks `resolve_stake_amount`.
- Equity above trajectory → reduce stake. DD breach → `_entries_halted`.

## Wallet-aware available

- Compute free equity: starting + closed_pnl − open_stakes.
- Thread that value as `available` into `decision_core` / entry ladder.
- Today's bug pattern: `available=stake.amount` (flat) — two concurrent entries
  can overshoot the wallet. Fix is one shared available source on both parity hosts.

## No second `decide_on_bar`

Wealth adjusts **how much** to risk, not **whether** to enter on signal semantics.
Entry/exit still come from the single `decide_on_bar` path (ADR-0037). Do not add
a parallel decision callback, host-only stake rule, or NT-only gate.

## Paper only

- Live Lighter capital automation is out of scope (start path unimplemented).
- Human gate forever for live. Wealth controller runs on paper / dry_run sessions.
- Dream overnight must refuse if a live session shares the dream port
  (`live_session_risk`).

## Anchors

| Concern | Where |
|---------|--------|
| Stake resolve | `adapters/.../hooks.resolve_stake_amount` |
| Halt | `execution_service._entries_halted` |
| Parity | `host_decision_parity_test` / sequence parity — both hosts same `available` |
| Domain | `python/andromeda/domain/wealth_trajectory.py` (`WealthTrajectoryController`) |
