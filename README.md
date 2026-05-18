# Boten — MT5 Indices Bias and Confluence Indicator

A single MQL5 dashboard indicator for indices (NAS100, US30, SPX500, GER40) that:

1. Computes a **daily bias score** from HTF context (PDH/PDL, Asia range, H4 structure, weekly profile).
2. Overlays an **entry-confluence engine** (FVG, order blocks, liquidity sweeps, ORB, killzones, VWAP, volume) on the chart.
3. Highlights the **next high-probability entry zone** with a suggested stop, first target, and alerts.

No auto-execution. You trade manually.

## Repository layout

```
boten/
  README.md
  src/
    Boten.mq5                            # indicator entry point
    Include/
      Boten/
        Config.mqh
        Bias/
          BiasEngine.mqh
          PrevDayLevels.mqh
          AsiaRange.mqh
          MarketStructure.mqh
          PowerOfThree.mqh
        Confluences/
          FVG.mqh
          OrderBlock.mqh
          LiquiditySweep.mqh
          ORB.mqh
          Killzones.mqh
          VWAP.mqh
          VolumeProfile.mqh
          MidnightOpen.mqh
        Drawing/
          Panel.mqh
          Levels.mqh
          Zones.mqh
          Labels.mqh
        Utils/
          Sessions.mqh
          Symbols.mqh
          Logger.mqh
          Alerts.mqh
  docs/
    strategy.md                          # bias/confluence weights and rationale
    config.md                            # every input explained
    references.md                        # ICT/SMC and quant references
```

## Install

1. Open MetaTrader 5.
2. Click **File → Open Data Folder**. This opens the `MQL5` folder.
3. Copy `src/Boten.mq5` into `MQL5/Indicators/`.
4. Copy the entire `src/Include/Boten/` directory into `MQL5/Include/` so the layout becomes `MQL5/Include/Boten/Config.mqh`, `MQL5/Include/Boten/Bias/...`, etc.
5. Open MetaEditor (F4 in MT5), open `Indicators/Boten.mq5`, press **F7** to compile. There should be 0 errors.
6. Back in MT5, refresh the **Navigator** (Ctrl+N) and drag **Boten** onto an indices chart (e.g. NAS100 M15).

## First-attach checklist

- **Time & DST**: most MT5 brokers run server time at GMT+2 winter / GMT+3 summer (EET/EEST). If yours does, leave defaults. Otherwise set `InpAutoDST=false` and tune `InpBrokerOffsetWinter` to your fixed offset.
- **Instrument preset**: leave on `Auto`. The indicator detects NAS100/US30/SPX500/GER40 from common symbol names (USTEC, US100, WS30, US500, DE40, etc.). Set explicitly if your broker uses an unusual symbol.
- **Killzones**: defaults are GMT-anchored to the canonical ICT windows. They are **not** DST-shifted on the assumption that liquidity-window timing follows the underlying market structure (NYSE open at 9:30 ET = 13:30 GMT in DST, 14:30 GMT in standard time). Adjust if you prefer fixed clock-time killzones.
- **Confluence threshold**: `InpMinEntryScore=5` is conservative. Drop to 3 to see more setups while you're learning the tool's tendencies, raise to 6+ for high-conviction-only.
- **Alerts**: turn `InpAlertPush=true` and configure your MT5 push (Tools → Options → Notifications) if you want phone alerts.

## What you'll see on the chart

- **Horizontal lines** for PDH/PDL/PDM (solid/dotted) and PWH/PWL (dashed).
- **Asia range box** (gold) with sweep-direction marker once the range is taken.
- **Killzone bands** as faint vertical shading for London / NY AM / NY PM.
- **ORB box** for the configured London and NY opening ranges.
- **FVG rectangles** (green=bullish, red=bearish), shrinking/disappearing as price mitigates them.
- **Order block rectangles** (dotted outline).
- **Sweep arrows** at PDH/PDL/Asia high/low taken-and-rejected wicks.
- **VWAP** with 1σ/2σ bands.
- **POC / VAH / VAL** of the prior day.
- **Midnight NY open** dash-dot line.
- **Entry zone** (gold rectangle) with stop and target dashed lines, and a score badge — only when the setup score crosses the threshold.
- **Corner HUD** with symbol, bias direction, score breakdown, current confluence, last setup time.

## Tuning

The score weights are documented in [`docs/strategy.md`](docs/strategy.md). Every input is documented in [`docs/config.md`](docs/config.md). For an academic / SMC reading list see [`docs/references.md`](docs/references.md).

## Limitations and non-goals

- Indicator-only. No auto-execution; we do not place, modify, or close orders.
- Index CFDs do not provide real volume, so the volume profile is built from M5 tick volume. The shape is informative but the absolute magnitudes are broker-dependent.
- DST inference assumes EU schedule (most MT5 brokers). If your broker runs US DST or no DST, set `InpAutoDST=false`.
- The H4 BOS/CHoCH detector uses fractal swings. It is robust on indices, but extremely choppy news days can produce noisy structure events.
# boten
