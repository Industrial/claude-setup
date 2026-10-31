---
name: lighter-market-loop
description: Run one autonomous trading cycle on a Lighter.xyz perpetuals market, given only the tab URL. Use when asked to run a market loop, an MR-1 cycle, a Lighter cycle, or to manage a Lighter perp position on a specific market URL. Resolves the URL to a chrome-devtools page by identity (never a cached page number), runs the staleness detector, reads RSI/DMI/ATR/VolOsc, applies rev-5 entries and rev-7 trailing-stop management, enforces account-level kill switches across concurrent sessions, and appends a log row. One cycle per invocation.
category: trading
---

# Lighter market loop

One cycle, one market, one invocation. Argument is the **tab URL**, e.g.
`https://app.lighter.xyz/trade/ETH`. Everything else is derived.

This skill programs a whole session: it resolves its own page, refuses to act on
unverifiable state, and does nothing at all on most cycles. **Doing nothing is the
expected outcome.** Fire only when a rule fires.

One cycle per invocation means **something has to invoke it repeatedly.** Nothing in
this repo does. **Start a loop — see §10 — and do it on the first cycle of a session,
before the market moves past the state you just read.**

## 0. Bootstrap from the URL — never from a page number

`MARKET` = last path segment of the URL (`/trade/ETH` → `ETH`).
`LOGFILE` = `<repo>/.tmp/lighter-experiment/<MARKET>.md` — **except LIT, whose log is
the historical `MR-1.md`.** Check for an existing log before creating one; never start
a second log for a market that already has one.
`LEDGER`  = `<repo>/.tmp/lighter-experiment/ACCOUNT.json` (shared, see §8).

1. `list_pages`.
2. Find the row whose URL **equals the argument exactly**. That row's number is
   `PAGE` for this cycle only.
3. No match → `new_page(url, background: true)`, then `list_pages` again to read
   `PAGE`. **A tab opened this cycle is a series discontinuity: NO ENTRY this
   cycle** (§6), read-only.
4. Two or more matches → **stop and report.** Duplicate tabs on one market mean two
   sessions may both be acting.

**Re-resolve every cycle. Never carry `PAGE` between cycles, never hardcode it.**

Why this matters, verified in chrome-devtools-mcp v1.12.0:

- Page IDs come from a module-level `nextPageId++` counter, matched by identity in
  `getPageById`. They are **stable and never reused or renumbered** — closing a tab
  cannot slide you onto another market. Sparse lists (3, 4, 6, 7) are normal.
- But the counter is **per MCP server process**. Each Claude session spawns its own,
  so *your* page 7 is not *their* page 7. IDs are never a shared name — URLs are.
- `pageIdRouting` defaults to **true**. **Pass `pageId` on every single call.**
- **Never call `select_page`.** The selected-page pointer silently relocates when a
  page closes (`"the previously selected page was closed. Page 3 is now selected"`),
  and any call omitting `pageId` follows it onto the wrong tab. `select_page` also
  does `bringToFront` and steals the user's view.
- Background tabs are safe: `emulateFocusedPage(true)` is latched per page for
  "multi-agent workflows", so a hidden tab is **not** throttled and its chart stays
  live.
- Do **not** use `isolatedContext` — separate storage partition, so no wallet session.

## 1. Identity gate — hard stop

From one fresh `take_snapshot(pageId: PAGE)`:

| Check | Required | On failure |
|---|---|---|
| RootWebArea url | ends in `/trade/<MARKET>` | **stop and report** |
| Account selector | reads `Andromeda` | **stop and report** |
| Canvas label | `Chart for …-<MARKET>, 5 minutes` | log it and report |

The URL check is the one that catches cross-market misaddressing. Do not skip it
because the other two passed.

## 2. Staleness detector — runs before anything else

All three tests, every cycle:

- **(a)** `|legend C − header MARK PRICE| > 1 ATR` ⇒ stale.
- **(b)** full legend tuple (OHLC + volume + ATR + VolOsc + all five DMI + RSI)
  identical to last cycle **while the mark changed** ⇒ stale.
- **(c)** C clearly not tracking the live bar ⇒ parked crosshair ⇒ SKIP.

On any stale read: **log the cycle as SKIPPED and do nothing else.**

### Known false positives — these are NOT staleness

A `Cross` button in the chart toolbar is the cursor-mode label. Normal.

A **DMI block identical while OHLC/volume/RSI moved** is a pin. Identify which:

| Pin | Signature | Mechanism |
|---|---|---|
| Proportional (denominator-only) decay | both DI legs scale by **one common ratio** | DM contributions fixed, TR growing ⇒ DX pinned by construction |
| Inside bar as of this read | `H < prevH` **and** `L > prevL` | `+DM = −DM = 0` ⇒ DX pin guaranteed |
| Range-frozen bar | H and L both static | TR static ⇒ all five DMI plots **and ATR** freeze exactly while C/volume/VolOsc/RSI move |
| Frozen ADX/ADXR | same bar **and** DX unchanged | correct behaviour, not a fault |

Always verify with the identity:

```
DX = |+DI − −DI| / (+DI + −DI) × 100
```

Agreement to the last displayed place (±0.0002, from 4-dp DI inputs) confirms a live
read. A miss of ~0.01+ is an open discrepancy — **report it, do not invent a
mechanism.** For the inside-bar case, `common_ratio ÷ (13/14)` gives the TR growth
factor; cross-check it against the ATR change.

Say **"inside as of this read"**, never "an inside bar" — a mid-bar sample is not the
bar's close.

## 3. Read order

RSI(14) first. Then DMI in **plot order: +DI, −DI, DX, ADX, ADXR**. Then ATR(14),
Volume Osc(5,10), volume, mark, index, funding.

`NEXT FUNDING` is an **MM:SS countdown**, not a clock. A wrap (`01:58` → `58:57`)
means the funding hour rolled.

### Cross-bar arithmetic — the rule that prevents invented moves

`ADX = (ADX_prev_closed × 13 + DX_current) / 14`

A mid-bar legend read is **not** the bar's close. Comparing two mid-bar samples
manufactures moves that never happened. To compare across a bar boundary, back-solve
the close:

```
ADX_prev_closed = (ADX_current × 14 − DX_current) / 13
DX_prev_closed  = ADX_prev_closed × 14 − ADX_prev_prev_closed × 13
```

Then state the change against the **back-solved close**. Expect your own mid-bar
samples to be overstated; correct them in the log when they are.

A clean case (sample == close) happening twice does not make it persistent. Re-derive
every cycle.

## 4. ATR basis — never trade off the live print

The live ATR(14) includes the **forming** bar's true range, so it is deflated just
after a bar opens and inflated mid-breakout. Both directions are traps.

Maintain a **mature basis** and back-solve it each cycle:

```
TR_live  = max(H − L, |H − prevC|, |prevC − L|)      # prevC ≈ the forming bar's open
ATR_prev = (14 × ATR_live − TR_live) / 13
```

Most reliable when `TR_live` is small (newborn or quiet bar); near-exact at zero volume.

**Step rule:** move the basis only when the back-solve differs by **≥ 2 ticks** *and*
the bar that just closed was representative (range ≳ 0.7 ATR). **1 tick is rounding
noise — hold.** A *completed* quiet bar is still a real bar.

Use **one basis for both halves** of any threshold test. All sizing and all trail
arithmetic use the basis, never the live print.

## 5. If a position is open — rev 7, the main work

No take-profit, ever. Positions exit only on the trailing stop.

1. **Verify the stop exists**: Open Orders count and its trigger/limit values. Report
   PnL in **$ and in R**.
2. Track the **lowest low since entry** (short) / highest high (long).
3. Compute the trail from the **basis**:
   - short: `trigger = lowest_low + 2 × ATR`, `limit = trigger × 1.01`
   - long:  `trigger = highest_high − 2 × ATR`, `limit = trigger × 0.99`
4. **Ratchet in the favourable direction only — never back**, even if ATR expands or
   price retraces. The computed trail is *not* monotonic because the basis can widen;
   the **stop** must be, and never-back is what enforces that.
5. **Only modify when the improvement is ≥ 0.25 ATR.** Otherwise leave the order
   alone and say so. Churn on a working order is a bigger risk than a fraction of an
   ATR of unprotected profit.
6. **Modify in place, never cancel-then-replace** — the position is never unprotected.

To modify: Open Orders → `Modify Order` → set Trigger Price and Price.
**`fill` silently reverts these fields.** Use click → `Ctrl+A` → `type_text`, then
**snapshot and verify both values** before clicking `Modify Order`.

**Do not close the position manually. `Reverse Position` is banned** — it sits
adjacent to `Close Position` and one click doubles exposure the wrong way.

Distinguish the three reasons for not ratcheting and name which applies: **threshold**,
**never-back**, or **the trail moved away from price**.

## 6. If flat — rev 5 entries

Counter-trend by design. Do **not** apply any with-trend ban, DI-direction, ADX or
VolOsc condition.

- **ARM STATE** lives in `LOGFILE`'s rev-5 section. ARMED once RSI(14) has printed
  **above 70**; otherwise NOT ARMED.
- NOT ARMED and RSI > 70 ⇒ **set ARMED, record the cycle, take no trade.**
- ARMED and RSI < 70 ⇒ **the short triggers.**
- **Arming is a state observation, not a trade** — record it even with a position
  open. Entries stay gated on being flat.
- **Series continuity:** no entry on the first cycle after any reload, navigation,
  timeframe change, or a tab opened this cycle. A *new tab* is a separate target and
  does **not** break an existing page's continuity.

### Submitting the short

```
size   = floor(0.01 × equity / (2 × ATR_basis))
SL trigger = entry + 2 × ATR_basis
SL limit   = trigger × 1.01          # NO TAKE-PROFIT
```

Report **both** the trigger-based risk (`size × 2 × ATR`) and the worst-case
**limit-based** risk (`size × (limit − entry)`). The trigger figure is a floor, not an
expectation — realised stop-outs land between the two.

**Re-read RSI immediately before submitting. If it is back at or above 70, ABORT and
stay armed.**

On a market order the stop can only be set from **Est. Price**; the fill can differ by
many ticks, so state the resulting ATR multiple honestly after the fill.

### Click protocol — uids remap between snapshots

1. Fresh snapshot immediately before **every** click. Never reuse a cached uid.
2. Verify the target element's own label matches intent before clicking.
3. **Re-verify the Amount field and all bracket fields.** Leftover ticket state
   persists between cycles — never assume a field is empty. The venue **auto-populates
   SL Limit from the trigger** the moment the trigger is entered, so typing into it
   prepends a digit. **Always `Ctrl+A` then type on the SL fields.**
4. Before submitting: confirm direction, Order Size, Est. Liq. Price and the bracket
   prices read as intended.
5. **Never submit immediately after typing** — snapshot and verify in between.
6. After submitting: re-snapshot and verify the fill. Log it.
7. **After any position closes, clear the Amount field in the same cycle.** A leftover
   amount leaves the submit button live and one stray click opens an unintended
   position.

## 7. Market calibration — re-derive per market, never carry over

Per-market and independent: tick size, leverage (LIT 5x vs ETH 50x), margin mode,
order-ticket state. Shared across tabs: wallet, sub-account, equity, **and TradingView
layout** — so a timeframe change in one tab may propagate. Never change the timeframe.

Some markets render an extra **binary-options widget** ("Up or Down", a `1-Tap` switch,
live `Up 30¢ / Down 72¢` buttons). Those are one-click real money. **Never click
anything in it**; treat its presence as noise in the snapshot.

New tabs load the newest app bundle while an old tab keeps its own version. Reloading
to match **breaks series continuity** — don't, unless the user asks.

## 8. Kill switches — account-level, not per-market

**Read `LEDGER` before sizing anything.** Equity is a single shared pool: every market
tab on this sub-account reports the *same* balance. Two sessions each sizing at "1% of
equity" are sizing off the **same** money, so concurrent positions make the true
account risk the **sum**, and per-market counters are blind to each other.

```json
{ "equity_floor": 39.00, "realized_pnl": 0.0, "loss_streak": 0,
  "round_trips": 0, "max_concurrent_positions": 1,
  "open": { "LIT": false, "ETH": false } }
```

Create `LEDGER` if missing. Before any entry:

- `equity < equity_floor` ⇒ **halt.**
- `loss_streak ≥ 3` ⇒ **halt.**
- `round_trips ≥ 8` ⇒ **halt.**
- any other market's `open` is true and that would exceed
  `max_concurrent_positions` ⇒ **no entry**, report why.
- any unverifiable state — unexpected modal, a position this log did not open, a fill
  not matching intent, selector not reading `Andromeda` ⇒ **halt.**

Update `LEDGER` in the same cycle as any fill or close. **Never read kill-switch
counts from the invoking prompt** — prompts go stale. The ledger and the venue are the
only authorities.

## 9. Log

Append one row to `LOGFILE`'s table, **newest first**, by anchoring an `Edit` on the
previous row (the file is large; prefer an anchored edit over rewriting). Log RSI
alongside the DMI/VolOsc observation columns. Record staleness verdict, the basis and
its back-solve, the pin type when one occurred, and the reason for any non-action.

Keep the spoken report to **one or two lines** unless something fired, the stop was
ratcheted, a limit tripped, or the staleness check rejected the cycle.

When arithmetic overturns one of your earlier readings, **say so plainly in the log and
move on.** Correct the record; don't re-litigate it.

## 10. Cadence — start a loop, do not hand-drive it

**There is no scheduler for this skill.** Verified on 2026-10-31: no user crontab, no
`CronCreate` jobs, and no systemd timer that runs it. (`lighter-cost-surface.timer`
*sounds* like one and is not — it sweeps the fee/cost surface from another repo and
never touches the browser, the log or the ledger.) Cycles r1–r367 were all hand-driven,
which is why the r-labels in `MR-1.md` had **drifted ~2 minutes ahead of venue clock
time** by r348. Drifting labels are the signature of manual pacing.

**On the first cycle of a session, after the log row is written, start the loop:**

```
/loop 3m /lighter-market-loop <the same URL>
```

Three minutes matches the nominal cadence the log was built on. Say that the loop is
starting, and name the interval — the user must be able to see the cadence they are now
on without inferring it.

### Check for an existing loop before starting one

**Two loops on one market is the §0 step-4 failure with extra steps.** A second driver
means two sessions acting on one position, and the per-experiment kill-switch counters
in §8 are blind to each other. Before starting: if a loop on this market is already
running in this session, **say so and start nothing.** If one may be running in a
*different* session, that is unverifiable from here — **report it and let the user
decide**, exactly as §0 step 4 handles duplicate tabs.

### Stop the loop when a rule stops the cycle

A kill switch is not advice to the current cycle only. **Any §8 halt — equity floor,
loss streak, round-trip cap, or unverifiable state — ends the loop, not just the
cycle.** Stop it and report; do not let it keep waking up into a halted experiment.

### Why not a cron job or a cloud agent

| Driver | Verdict |
|---|---|
| `/loop` in this session | **Correct.** Same session, same MCP server, reaches the user's Chromium and its live wallet session |
| Scheduled cloud agent (`/schedule`) | **Cannot work.** Runs in a cloud container with no access to the local browser, the wallet, or `.tmp/` |
| systemd timer firing headless `claude -p` | **Works mechanically, rejected on risk.** A fresh MCP process per run is survivable — §0 resolves by URL, so renumbered pages are harmless — but nobody is present to interrupt a cycle that is about to submit an order |

The browser is the reason: `--no-javascript-evaluation` is deliberate because that
browser holds live wallets, and it runs on the user's machine. Any driver that cannot
reach it cannot run this skill.

### Unattended entries are the real exposure

A loop will keep running while the user is away, and **rev 5 can fire an entry with
nobody watching.** That is the intended design — the venue holds the stop, not this
session — but it means the §8 kill switches are the only brake once the loop is
running. **Say this plainly when starting a loop**, and state the current counters
(equity against the floor, loss streak, round trips) so the decision is informed rather
than implied.

## Anchors

| Concern | Where |
|---|---|
| Rule text, trade records, log | `.tmp/lighter-experiment/<MARKET>.md` |
| Account-level kill switches | `.tmp/lighter-experiment/ACCOUNT.json` |
| Page resolution | `list_pages` → match URL → `pageId` on every call |
| Page ID semantics | `McpContext.js` `nextPageId++`; per-process, stable, never reused |
| Background tabs | `McpPage.js` `emulateFocusedPage(true)` |
| Why no JS eval | `--no-javascript-evaluation` is deliberate: the browser holds live wallets |
| Cadence | §10 — `/loop 3m /lighter-market-loop <url>`; nothing else schedules this |
