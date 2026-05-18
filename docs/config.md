# Configuration reference

Every input on the Boten indicator, grouped as it appears in the MT5 dialog.

## General

| Input                  | Default | Meaning |
| ---------------------- | ------- | ------- |
| `InpInstrumentPreset`  | Auto    | Instrument family. `Auto` detects from the symbol name (NAS, USTEC, NDX, US100 → NAS100; DOW, DJI, US30, WS30 → US30; SPX, US500, S&P → SPX500; DAX, GER40, DE40 → GER40). Setting `Custom` keeps generic defaults. |
| `InpLogLevel`          | 3       | 0=off, 1=err only, 2=+warn, 3=+info, 4=+debug. Logs land in MT5 *Experts* journal. |

## Time & DST

| Input                    | Default | Meaning |
| ------------------------ | ------- | ------- |
| `InpAutoDST`             | true    | Auto-switch broker-GMT offset between summer/winter values using EU DST schedule (most MT5 brokers run on EET/EEST). Set false for a fixed offset. |
| `InpBrokerOffsetWinter`  | 2       | Hours your broker time is ahead of GMT in winter (or fixed offset if `InpAutoDST=false`). |
| `InpBrokerOffsetSummer`  | 3       | Hours your broker time is ahead of GMT in summer. |

If you don't know your broker's timezone, in MT5 go to **Tools → Options → Server**, or just attach the indicator and check whether the PDH/PDL lines align with the daily bars. If they're shifted, your offset inputs are wrong.

## Asia session

| Input                    | Default | Meaning |
| ------------------------ | ------- | ------- |
| `InpAsiaStartHourGMT`    | 0       | Asia session start hour (GMT). 00:00 GMT = Tokyo open ~ 09:00 JST. |
| `InpAsiaStartMinGMT`     | 0       | Asia session start minute. |
| `InpAsiaEndHourGMT`      | 6       | Asia session end hour (GMT). 06:00 GMT = London pre-market. |
| `InpAsiaEndMinGMT`       | 0       | Asia session end minute. |

## Killzones (GMT, no DST shift)

GMT-anchored windows where the confluence engine adds +1 if the trigger fires while we're inside.

| Input                    | Default          | Meaning |
| ------------------------ | ---------------- | ------- |
| `InpKZLondonEnabled`     | true             | Enable London open window. |
| `InpKZLondonStartH/M`    | 07:00 GMT        | London open start. |
| `InpKZLondonEndH/M`      | 10:00 GMT        | London open end. |
| `InpKZNYAMEnabled`       | true             | Enable NY morning window. |
| `InpKZNYAMStartH/M`      | 12:30 GMT        | ≈ 08:30 ET, NY pre-market spike window. |
| `InpKZNYAMEndH/M`        | 15:00 GMT        | ≈ 11:00 ET, end of NY morning. |
| `InpKZNYPMEnabled`       | true             | Enable NY afternoon window. |
| `InpKZNYPMStartH/M`      | 17:00 GMT        | ≈ 13:00 ET. |
| `InpKZNYPMEndH/M`        | 20:00 GMT        | ≈ 16:00 ET (close). |

These are *fixed* in GMT on purpose — index liquidity windows track the underlying exchange clock, but the indicator does not auto-shift for DST. If you trade only US cash hours and want exact 9:30 ET behaviour year-round, change these manually twice a year, or contribute a DST-shifted variant.

## Opening Range Breakout

| Input                  | Default | Meaning |
| ---------------------- | ------- | ------- |
| `InpLondonORBMinutes`  | 15      | Length of the London ORB starting at the London KZ start. |
| `InpNYORBMinutes`      | 15      | Length of the NY AM ORB starting at the NY AM KZ start. |

## Bias & confluence engine

| Input                        | Default | Meaning |
| ---------------------------- | ------- | ------- |
| `InpMinBiasConviction`       | 2       | If `|bias score|` is below this, the day is treated as range-bound and no entries are generated. |
| `InpMinEntryScore`           | 5       | Confluence-score threshold to fire an entry zone and alert. |
| `InpLevelProximityPoints`    | 0       | Distance (in symbol points) within which price is considered "at" PDH/PDL/PDM/midnight. 0 = use per-symbol preset (NAS100=15, US30=25, SPX500=4, GER40=12). |
| `InpSweepLookbackBars`       | 6       | How many recently-closed LTF bars to scan for liquidity sweeps. Larger = more lenient. |
| `InpLTFTimeframe`            | M15     | Timeframe for FVG/OB/sweep detection and the entry trigger. |
| `InpHTFTimeframe`            | H4      | Timeframe for market-structure detection feeding the bias score. |

## Display toggles

Each layer has a toggle under "Display toggles" so you can declutter without changing logic. Default is `true` for all.

`InpShowPDLevels`, `InpShowPWLevels`, `InpShowAsiaRange`, `InpShowKillzones`, `InpShowORB`, `InpShowFVG`, `InpShowOB`, `InpShowSweepArrows`, `InpShowVWAP`, `InpShowVolumeProfile`, `InpShowMidnightOpen`, `InpShowEntryZone`, `InpShowPanel`.

## Colours

Pick whatever fits your chart theme. The defaults are tuned for a dark chart background.

| Group   | Inputs |
| ------- | ------ |
| Levels  | `InpColorPDH`, `InpColorPDL`, `InpColorPDM`, `InpColorPWH`, `InpColorPWL`, `InpColorMidnight` |
| Asia    | `InpColorAsia` |
| Killzones | `InpColorKZLondon`, `InpColorKZNYAM`, `InpColorKZNYPM` |
| ORB     | `InpColorORB` |
| FVG/OB  | `InpColorFVGBull`, `InpColorFVGBear`, `InpColorOBBull`, `InpColorOBBear` |
| Volume  | `InpColorVWAP`, `InpColorVPPOC`, `InpColorVPVA` |
| Decision| `InpColorEntryZone`, `InpColorPanelBg`, `InpColorPanelFg` |

## Alerts

| Input                       | Default | Meaning |
| --------------------------- | ------- | ------- |
| `InpAlertPopup`             | true    | Popup `Alert()` window when a setup fires. |
| `InpAlertPush`              | false   | Push notification to your linked MT5 mobile app. Configure under Tools → Options → Notifications. |
| `InpAlertEmail`             | false   | Email via MT5's built-in mailer. Configure SMTP under Tools → Options → Email. |
| `InpAlertCooldownSeconds`   | 60      | Minimum seconds between alerts with the same setup id. Prevents repeat fires while a setup is still valid. |
