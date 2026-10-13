---
name: andromeda-backtest-tuning
description: Safely run and tune andromeda backtest/hyperopt for the AFML/FreqAI strategies (walk-forward fold sizing, cheap vs expensive AFML knobs, hyperopt --only usage, and the out-of-sample discipline that keeps a tuning session from producing an overfit result). Load before touching afml.* config values, running `andromeda hyperopt`, or debugging a "no walk-forward fold survived" / "the primary called only N trades" refusal.
category: development
---

# Andromeda backtest + hyperopt tuning

Everything here was learned the hard way running real backtests/hyperopt against
real HL/HYPE and Lighter/LIT catalog data (2026-09-19/20). Read before any
`andromeda backtest` or `andromeda hyperopt` invocation that touches a config
also used by a live/paper session, and before changing any `afml.*` value.

## Safety: `backtest` can spawn a rogue live session if you're not on the fix

`andromeda backtest` reuses whatever config you point it at — often the *same*
file a live/paper session for that venue uses (that's what makes it reusable
for `paper` in the first place: real venue, real feed, `dry_run: true`).
`session_kind()`/`frequi_runmode()` derive the post-backtest UI runmode purely
from the config's own venue/feed content, with no idea a backtest command is
what asked. Confirmed live: an early `andromeda backtest` run against the
Lighter paper config opened a **second live WS session** against the same
market the real paper session was already capturing, while that session kept
running.

Fixed in `bind_api(force_webserver=...)` (`command_line_interface_service.py`)
— `_cmd_backtest` always passes `force_webserver=True` now, forcing the
backtest-results webserver view regardless of what the config implies. If you
ever see `bind_api`/`_cmd_run_with_ui` being refactored, **verify this call
site still passes `force_webserver=True`** — a regression here is a live
capture safety issue, not a UI inconvenience. Test:
`app_main_test.py::test_main_backtest_never_attaches_a_live_session_even_when_the_config_would`.

Always run backtests on a `--port` different from any live session's port, and
`ps aux | grep andromeda` before *and* after to confirm nothing unexpected is
still bound to a socket.

## `--start`/`--end` do not bound the FreqAI materialize step

Confirmed empirically: `andromeda backtest --start X --end Y` does not reduce
`bars=N` in the `walkforward materialize` log line to the requested window —
you cannot "shrink the window" this way to dodge a fragile early fold. What
actually bounds the feature-engineered row count in practice is a mix of catalog
extent and internal FE windowing; treat `--start`/`--end` as best-effort request
hints, not a hard input-window contract, until someone traces the exact
resolution path.

## Walk-forward fold sizing: `n_folds` vs available history

`PredictionConfig.n_folds` (default 8) splits label-eligible (CUSUM-sampled)
events into `n_folds + 1` contiguous blocks; fold *k* trains on everything
before its test block. The **earliest fold always has the least training
data**, by construction — no `--start`/`--end` trick changes that; only more
total history, or fewer folds, gives it more.

Two distinct failure modes, easy to conflate:

1. `"no walk-forward fold survived purging: N events, K folds, min_train=M"`
   — no fold's post-purge training set reaches `min_train`. Fix: fewer folds
   (more history per fold) or more total history.
2. `"the primary called only 0 trades on N training rows; the meta model needs
   at least M"` — a fold *did* survive (N ≥ M already), but the primary's raw
   score is degenerate (effectively constant) across that fold, so
   `sides_from()` (`np.sign(score - median(score))`) returns all zeros. **This
   is not a sample-size problem** — confirmed by testing N=10, N=55, N=88, all
   still zero. Lowering `min_train_events`/`min_meta_rows` further does not
   fix it; it just makes the fold that hits this error smaller.

Diagnostic order when a backtest refuses:
- Try `n_folds` reduced (2, then 1 with `n_test_groups` also set to 1 —
  `PredictionConfig.__post_init__` requires `n_test_groups <= n_folds`).
- If it still refuses even at `n_folds=1` (the most generous possible split),
  the instrument genuinely does not have enough absolute history yet — proven
  by testing this exact case on both a young instrument (Lighter/LIT, session
  hours old) and confirming a mature one (HL/HYPE, 653 days) succeeds at
  `n_folds=2` on a 2-week window and at native `n_folds=8` on a 60-day window.
  There is no config trick around "not enough real history" — wait for more.

## Validating a *different*, mature instrument proves the mechanism, not the strategy

When the instrument you actually care about doesn't have enough history yet,
you can still validate that the **walk-forward + meta-labeling pipeline
itself** works by running the same strategy family against a mature instrument
that shares the same `andromeda_prediction`/`afml` machinery (e.g. HL/HYPE has
653 days of history and full `md_micro` coverage — verify this per-window with
`CatalogService.load_micro`/`load_l2`/`load_funding`/`load_oi`, don't assume).
A completed backtest with real trades and real (even mediocre) Sharpe/PnL
numbers is proof the code path works end to end. It says **nothing** about
whether the young instrument's own thresholds are any good — those still need
their own validation once there's enough of their own data.

## `AFML_LABEL_KNOBS` vs `AFML_GATE_KNOBS` — know which one you're changing

`domain/afml_overrides.py` draws the line explicitly:

- **Label knobs** (`barrier_mult`, `vol_window`, `max_holding_bars`,
  `cost_bps_round_trip`) reshape the triple-barrier labels the model trains
  on. They're part of the `PredictionStore` cache key — changing one forces a
  full walk-forward re-fit. Expensive per trial/run.
- **Gate knobs** (`min_conf`, `min_edge_ticks`, `exit_conf_frac`,
  `exit_persist_bars`, `meta_conf`, `halt_drawdown`, `halt_window_minutes`)
  only gate trading decisions on an *already-computed* prediction. They are
  explicitly excluded from the cache key. Cheap to sweep — no re-fit.

Sweep gate knobs broadly and often; treat label-knob sweeps as expensive and
budget fewer trials for them.

## Use `andromeda hyperopt`, not a hand-rolled grid, for gate knobs

The strategy classes already declare every `afml` knob as a real freqtrade
`DecimalParameter`/`IntParameter`/`CategoricalParameter` with a sane range.
Manually grid-searching one value at a time is strictly worse: it misses
interaction effects and non-monotonic regions. Confirmed live: a manual sweep
of `min_conf` alone found 0.55 was much better than the 0.63 default (Sharpe
-0.26 → 2.02 on one window) — but a proper joint hyperopt over
`min_conf`+`exit_conf_frac`+`min_edge_ticks` found an *entirely different,
better* region (`min_conf=0.83`, high not low) that the one-dimensional manual
sweep never would have found, because it never tried anything above the
default.

Mechanics that matter:
- `optimizable_parameters()` (`freqtrade/hyperopt/engine.py`) requires
  `optimize=True` **on the strategy class** first — `--only NAME` can only
  narrow an already-enabled set, it cannot activate a disabled one. To search
  a gate knob that currently has `optimize=False`, flip it in the strategy
  source (safe: it's a post-prediction gate, doesn't force a re-fit).
- Some params (e.g. `prediction_target`) are `optimize=True` by design but
  meant for an **isolated** `--only prediction_target` run — leaving them in
  a joint search with `meta_labeling` fixed True can produce an invalid
  combination (`PredictionConfigException`: e.g. `p_profit` is already
  meta-labelling). Always pass explicit `--only name --only name ...` for a
  controlled joint search rather than omitting `--only` and hoping.
- `--loss composite` (the default) rewards expectancy, bounded PnL, and
  **equity-curve smoothness (`eq_slope · eq_r2`)**, and penalizes drawdown —
  it is not raw-PnL-maximizing. A trial with lower total PnL but a much
  higher `eq_r2` can and did win over one with more raw profit. Prefer it
  over `onlyprofit` unless you have a specific reason not to.
- Hyperopt trials print nothing until the end — no incremental progress. Give
  the process a generous `timeout` (a 60-epoch run over a 60-day/1m window
  took ~600s+ and was killed with zero output by an under-sized timeout on
  first attempt). Budget epochs down before budgeting timeout up if unsure.
- The CLI's final JSON key is `"top"` (a capped list of best trials), not
  `"history"` — parse for that key name.

## The one non-negotiable step: validate on a different window

A parameter combination chosen by *any* method — manual, hyperopt, whatever —
that only proves itself on the same window it was searched over is not
evidence of an edge. It is evidence you found a combination that fit that
window's noise. Confirmed pattern that generalized: hyperopt's winning gate
config (Sharpe 1.68, PF 1.49 on the search window) scored Sharpe 1.83, PF 1.39
on a **separate, non-overlapping 60-day window it never saw**. That's what
makes a result trustworthy. If a candidate's performance collapses or inverts
on a second window, it was overfit — discard it, don't rationalize it.

Minimum bar before reporting any tuning result as real:
1. Search/tune on window A.
2. Re-run the exact winning config as a plain `andromeda backtest` on window A
   to confirm the CLI reproduces hyperopt's own internal numbers (sanity
   check that nothing was double-counted or miscounted).
3. Run the same config, unchanged, on window B (different calendar period,
   ideally not adjacent to A).
4. Only report the result as "found something" if B's numbers are in the same
   ballpark as A's — not just "still positive," but comparable magnitude.

## Sharpe from a short window is mostly noise

`Sharpe Ratio (252 days)` annualizes whatever the tested window measured. A
5-day window annualizes with a ~√(252/5.4) ≈ 6.8× multiplier — a single bad or
lucky stretch dominates the number. A `-5.98` Sharpe from a forced 2-fold,
5.4-day compromise (needed just to get *any* result at all) turned into
`-0.26` — essentially noise, Profit Factor 0.95 — once tested with the
strategy's real `n_folds=8` config over a proper 60-day window. Don't trust an
annualized Sharpe from anything under a few weeks of trades.

## Known untuned placeholders (don't mistake these for bugs)

`min_train_events = 50` / `min_meta_rows = 50` on both `FreqaiAfmlHlHype1mStrategy`
and `FreqaiAfmlLighterLit1mStrategy` carry their own comment: *"Placeholder,
not a tuned value... The real number is a backtest sweep's job, once there is
backtest data to sweep against."* Nobody had ever run that sweep before this
session. A "horrible" first backtest result is as likely to be an untuned
threshold or an unfair test setup (see above) as a real strategy problem —
check both before concluding the strategy itself is bad.

## Expectation-setting

No backtest result — however well cross-validated — is a promise about live
performance, and none of this justifies "trade real capital fast." Report
results plainly, including when a result doesn't hold up on a second window,
and don't let a good-looking Sharpe number imply more confidence than a
two-window HL/HYPE proxy test earns for a different, much younger instrument
(Lighter/LIT) that hasn't been validated at all yet on its own data.

## Dream / overnight mode

Overnight autoresearch (`andromeda dream` / locked-harness loop) reuses the same
backtest/hyperopt surfaces — so the live-session landmines above apply harder.

1. **Ports** — Bind dream/backtest/hyperopt to a `--port` that no paper or live
   session is using. Never share a frequi/API port with a running capture session.
2. **`force_webserver`** — `_cmd_backtest` must keep passing
   `bind_api(force_webserver=True)`. A regression attaches a rogue live WS to the
   same market the paper session is capturing.
3. **`ps aux` checks** — Before BOOT and after REPORT (and after any infra
   FailureAtom), run `ps aux | grep andromeda` and confirm nothing unexpected is
   bound to a socket.
4. **Halt on `live_session_risk`** — If BOOT or a trial detects a conflicting live
   session, append a FailureAtom with family `live_session_risk` and **stop the
   loop**. Do not continue hypothesizing while a live capture is at risk.

See also: `andromeda-autoresearch`, `andromeda-falsifier`.
