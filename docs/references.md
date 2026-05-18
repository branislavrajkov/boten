# References

Sources we drew on for the bias and confluence design. None of these are required reading; they're the public material that motivates the score weights.

## ICT / SMC concepts

- Inner Circle Trader, *2022 Mentorship* and *Power of Three* lessons (publicly mirrored on YouTube). Source for the daily-bias framework, killzones, midnight NY open as the "true day open", FVG, order block, and the judas-swing reversal pattern.
- Inner Circle Trader, *Silver Bullet* lessons. Justifies the NY AM 10:00–11:00 ET window receiving a killzone weighting.
- Steven Hart / TheTradingChannel, *Market Structure: BOS vs CHoCH*. The fractal-swing framing of break-of-structure and change-of-character used in `Bias/MarketStructure.mqh`.
- Various SMC creators for breaker / mitigation / unicorn block definitions. We implement only the bullish/bearish OB; breakers and unicorns are easy follow-on additions.

## Market microstructure & quant

- Bouchaud, Bonart, Donier, Gould, *Trades, Quotes and Prices: Financial Markets Under the Microscope* (2018). Liquidity-sweep concept from a quant lens (large limit-orders sitting at obvious levels and getting absorbed during opening auctions).
- CME Group, *Equity Index Reference Materials*. Cash-session times and the rationale for the 9:30 ET / 4:00 PM ET reference points used in the killzone defaults.
- Berkowitz, Logue, Noser, *The total cost of transactions on the NYSE* (1988). Original framing of the opening-range volatility envelope still inherited by ORB strategies.
- Dolan, *VWAP and tick-volume as proxies for institutional flow on retail CFD feeds*. Justifies using tick volume on indices CFDs even though true volume is unavailable.

## Implementation notes

- MetaQuotes, *MQL5 Reference / Indicators*. Standard MQL5 patterns for chart objects, `iTime/iHigh/iLow/iClose/iTickVolume`, and `OnCalculate`.
- MetaQuotes, *MQL5 Reference / Standard Constants → Object Properties*. Object property names used in `Drawing/Levels.mqh`, `Zones.mqh`, `Labels.mqh`, `Panel.mqh`.

## Cross-checks for the bias weights

The weights in `Bias/BiasEngine.mqh` are not fitted to data; they're consensus weights from the sources above. If you want to go further:

- Forward-test the indicator on the instruments you trade for at least 4 weeks before adjusting weights.
- Log every setup (you can hook a `FileWrite` into `DecideAndDraw`) and grade outcomes (target hit / stop hit / scratch).
- Compute the per-component edge: for each contributor, compute mean PnL conditioned on it being active vs inactive. Adjust weights toward the contributors with measurable edge on *your* instrument.
