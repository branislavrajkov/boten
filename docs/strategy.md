# Strategy: bias score and confluence score

This document explains the math and the *why* behind every weight. The weights live as constants and inputs, so you can tune them as you collect statistics.

## Layer 1 — Daily bias score

Computed once at NY midnight and refreshed on each new H4 close. The score is signed; sign indicates direction, magnitude indicates conviction. We expose it in the corner HUD.

| Component                        | Range          | Where computed                              |
| -------------------------------- | -------------- | ------------------------------------------- |
| H4 market structure              | -2 .. +2       | `Bias/MarketStructure.mqh`                  |
| Previous-day close vs PDM        | -1 .. +1       | `Bias/BiasEngine.mqh`                       |
| Asia first-side-swept (Power3)   | -1 .. +1       | `Bias/AsiaRange.mqh` + `BiasEngine.mqh`     |
| Daily-open vs price              | -1 .. +1       | `Bias/PowerOfThree.mqh`                     |
| Weekly-open vs price             | -1 .. +1       | `Bias/PowerOfThree.mqh`                     |
| **Sum**                          | -6 .. +6       |                                             |

**Rationales**

- **H4 structure (BOS = ±2, CHoCH = ±1)**: A confirmed break-of-structure on H4 is the cleanest macro-direction filter for indices. CHoCH is a counter-trend warning, not a confirmation, so it gets half the weight.
- **PDC vs PDM**: If yesterday closed in the upper half of the day, dealers are statistically more likely to defend that side; index reversion to the prior-day mid is a common opening play, but extension above the close is the prevailing direction.
- **Asia Power-of-3**: Classic ICT / Wyckoff framing. If the Asia *high* is taken first during London, the high tends to be the day's *false* move, leaving the day-low side (=bearish bias) as the true move. Mirror for low.
- **Daily-open vs price**: Modern smart-money traders watch the daily open as the first "is-the-day-bullish-or-bearish" reference. Above = today is currently up vs that anchor.
- **Weekly-open vs price**: Same logic, one timeframe up. Carries equal weight to daily because indices respect the weekly open strongly.

**Threshold**: if `|score| < InpMinBiasConviction` (default 2), we treat the day as range-bound and skip entries.

## Layer 2 — Entry confluence score

Computed every new LTF (default M15) bar after a bias is established. The score is unsigned; only confluences whose direction agrees with the day's bias contribute.

| Confluence                                         | Weight |
| -------------------------------------------------- | ------ |
| Aligned LTF FVG (unmitigated, reachable)           | +2     |
| Aligned LTF order block (unmitigated, reachable)   | +2     |
| Recent liquidity sweep aligned (PDH/PDL/Asia HL)   | +2     |
| Inside a killzone                                  | +1     |
| Reaction at PDH/PDL/PDM/midnight NY open           | +1     |
| ORB extreme broken in bias direction               | +1     |
| VWAP relationship aligned with bias                | +1     |
| Tick-volume spike on the trigger candle            | +1     |

The maximum theoretical score is around 11. The default trigger threshold `InpMinEntryScore=5` was chosen so a setup typically requires a sweep + FVG/OB + a session/level confluence, which approximates the textbook ICT "judas swing" pattern on NAS100/SPX500.

**Why this combination favours indices**

- PDH/PDL liquidity sweeps + NY AM killzone + 5–15m FVG is the canonical NAS100/ES "false move into liquidity → reverse" pattern.
- Midnight NY open is the daily reference price for ICT-style indices traders; reactions there before NY cash open are common.
- Tick volume + VWAP substitute for real-volume profile that index CFDs lack.
- H4 BOS/CHoCH is the simplest robust trend filter that survives news days.

## Trigger and entry construction

When `score ≥ InpMinEntryScore` and bias direction matches:

- **Entry zone** = the most recent unmitigated FVG (preferred) or order block aligned with bias.
- **Stop** = beyond the zone's outer edge plus a 5-point buffer.
- **First target** = opposing daily liquidity (PDH for longs, PDL for shorts). If the level has already been swept, we project a 1:2 R:R as fallback.
- **Setup id** = `{symbol}_{zone_time}_{direction}_{score}`. The same id deduplicates alerts inside the cooldown window.

## Tuning suggestions

After 4–8 weeks of paper-trading the alerts, tune in this order:

1. `InpMinEntryScore`: raise it if too noisy, lower it if you see textbook setups missed.
2. `InpMinBiasConviction`: raise to 3 to skip mixed-bias days.
3. The H4 fractal width (`BOTEN_MS_FRACTAL_LEFT/RIGHT` constants in `Bias/MarketStructure.mqh`): widen to reduce false BOS in choppy markets.
4. `InpSweepLookbackBars`: how recent a sweep must be to still count. Default 6 LTF bars (~1.5h on M15).
5. The bias-component weights in `Bias/BiasEngine.mqh`: only after you've accumulated enough samples to know which contributors actually predict the day.

## Future statistical tuning

Out of scope for this indicator-only deliverable, but a natural follow-on:

- Export a journal CSV from MT5 (price, bias score, confluence score, setup outcome) using `FileWrite` calls inside `DecideAndDraw`.
- Pair with a Python research notebook (pandas) to back out the per-component edge and re-fit the weights.
- A/B presets per instrument once the sample size is sufficient.
