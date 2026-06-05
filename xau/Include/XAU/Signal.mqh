//+------------------------------------------------------------------+
//|  Signal.mqh — Entry signal for XAUUSD scalper                   |
//|                                                                  |
//|  Logic (all on the configured timeframe):                        |
//|    Fast EMA crosses above Slow EMA  → BUY signal                |
//|    Fast EMA crosses below Slow EMA  → SELL signal               |
//|    RSI must be in the valid range (not deep OB/OS against trade) |
//|    Trend filter: price must be on the correct side of Trend EMA  |
//+------------------------------------------------------------------+
#ifndef XAU_SIGNAL_MQH
#define XAU_SIGNAL_MQH

#define SIGNAL_NONE  0
#define SIGNAL_BUY   1
#define SIGNAL_SELL -1

struct SignalState
{
   int    fastPeriod;
   int    slowPeriod;
   int    trendPeriod;
   int    rsiPeriod;
   int    rsiOverbought;
   int    rsiOversold;
   ENUM_TIMEFRAMES tf;

   int    handle_fast;
   int    handle_slow;
   int    handle_trend;
   int    handle_rsi;
};

bool Signal_Init(SignalState &s,
                 ENUM_TIMEFRAMES tf,
                 int fastPeriod,
                 int slowPeriod,
                 int trendPeriod,
                 int rsiPeriod,
                 int rsiOverbought,
                 int rsiOversold)
{
   s.tf           = tf;
   s.fastPeriod   = fastPeriod;
   s.slowPeriod   = slowPeriod;
   s.trendPeriod  = trendPeriod;
   s.rsiPeriod    = rsiPeriod;
   s.rsiOverbought = rsiOverbought;
   s.rsiOversold   = rsiOversold;

   s.handle_fast  = iMA(_Symbol, tf, fastPeriod,  0, MODE_EMA, PRICE_CLOSE);
   s.handle_slow  = iMA(_Symbol, tf, slowPeriod,  0, MODE_EMA, PRICE_CLOSE);
   s.handle_trend = iMA(_Symbol, tf, trendPeriod, 0, MODE_EMA, PRICE_CLOSE);
   s.handle_rsi   = iRSI(_Symbol, tf, rsiPeriod,  PRICE_CLOSE);

   if(s.handle_fast == INVALID_HANDLE || s.handle_slow  == INVALID_HANDLE ||
      s.handle_trend == INVALID_HANDLE || s.handle_rsi  == INVALID_HANDLE)
   {
      Print("[Signal] Failed to create indicator handles.");
      return false;
   }
   return true;
}

void Signal_Release(SignalState &s)
{
   if(s.handle_fast  != INVALID_HANDLE) IndicatorRelease(s.handle_fast);
   if(s.handle_slow  != INVALID_HANDLE) IndicatorRelease(s.handle_slow);
   if(s.handle_trend != INVALID_HANDLE) IndicatorRelease(s.handle_trend);
   if(s.handle_rsi   != INVALID_HANDLE) IndicatorRelease(s.handle_rsi);
}

//--- Returns SIGNAL_BUY, SIGNAL_SELL, or SIGNAL_NONE
//--- Only called on confirmed new bar (bar[1] = last closed bar)
int Signal_Get(const SignalState &s)
{
   double fast[2], slow[2], trend[2], rsi[2];

   if(CopyBuffer(s.handle_fast,  0, 0, 2, fast)  < 2) return SIGNAL_NONE;
   if(CopyBuffer(s.handle_slow,  0, 0, 2, slow)  < 2) return SIGNAL_NONE;
   if(CopyBuffer(s.handle_trend, 0, 0, 2, trend) < 2) return SIGNAL_NONE;
   if(CopyBuffer(s.handle_rsi,   0, 0, 2, rsi)   < 2) return SIGNAL_NONE;

   //--- [0] = current forming bar, [1] = last closed bar
   //--- Use [1] (closed) for cross detection to avoid repainting
   bool crossedUp   = (fast[1] > slow[1]) && (fast[0] <= slow[0]);  // just crossed up on closed bar
   bool crossedDown = (fast[1] < slow[1]) && (fast[0] >= slow[0]);  // just crossed down

   // Actually, for a cross on the LAST CLOSED bar we check:
   // previous bar [1] vs bar [0] (which is now closed, and [1] is older)
   // CopyBuffer index 0 = most recent (still forming if called on tick).
   // Since we call on new bar, [0] is the just-opened bar, [1] is the just-closed bar.
   // Cross: [1] crossed relative to [2]... let me use 3 bars to be safe.
   double fast3[3], slow3[3], trend3[3], rsi3[3];
   if(CopyBuffer(s.handle_fast,  0, 0, 3, fast3)  < 3) return SIGNAL_NONE;
   if(CopyBuffer(s.handle_slow,  0, 0, 3, slow3)  < 3) return SIGNAL_NONE;
   if(CopyBuffer(s.handle_trend, 0, 0, 3, trend3) < 3) return SIGNAL_NONE;
   if(CopyBuffer(s.handle_rsi,   0, 0, 3, rsi3)   < 3) return SIGNAL_NONE;

   //--- bar[1] = last fully closed bar (where the cross happened)
   //--- bar[2] = bar before that
   bool buySignal  = (fast3[1] > slow3[1]) && (fast3[2] <= slow3[2]);
   bool sellSignal = (fast3[1] < slow3[1]) && (fast3[2] >= slow3[2]);

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(buySignal)
   {
      //--- RSI not overbought (avoid buying at the top)
      if(rsi3[1] >= s.rsiOverbought) return SIGNAL_NONE;
      //--- Price above trend EMA (macro uptrend filter)
      if(price < trend3[1]) return SIGNAL_NONE;
      return SIGNAL_BUY;
   }

   if(sellSignal)
   {
      //--- RSI not oversold (avoid selling at the bottom)
      if(rsi3[1] <= s.rsiOversold) return SIGNAL_NONE;
      //--- Price below trend EMA (macro downtrend filter)
      if(price > trend3[1]) return SIGNAL_NONE;
      return SIGNAL_SELL;
   }

   return SIGNAL_NONE;
}

#endif // XAU_SIGNAL_MQH
