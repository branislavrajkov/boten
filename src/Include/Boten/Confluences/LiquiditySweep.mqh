//+------------------------------------------------------------------+
//|                                               LiquiditySweep.mqh |
//|     Wick-through-and-close-back across PDH/PDL/Asia HL          |
//+------------------------------------------------------------------+
#ifndef __BOTEN_LIQSWEEP_MQH__
#define __BOTEN_LIQSWEEP_MQH__

#include <Boten/Drawing/Labels.mqh>
#include <Boten/Bias/PrevDayLevels.mqh>
#include <Boten/Bias/AsiaRange.mqh>
#include <Boten/Utils/Logger.mqh>

#define BOTEN_SWEEP_MAX 32

// A sweep event. direction is the *expected reaction* direction:
// sweeping a high (taking out buy-stops) = bearish reaction = direction -1.
// sweeping a low  (taking out sell-stops) = bullish reaction = direction +1.
struct SweepEvent
{
   datetime time;
   double   wick_price;
   double   level_price;
   int      direction;       // +1 (after low sweep) or -1 (after high sweep)
   string   level_tag;       // "PDH" / "PDL" / "AH" / "AL"
   bool     valid;
};

struct SweepState
{
   SweepEvent events[BOTEN_SWEEP_MAX];
   int        count;
   datetime   last_processed_bar;
};

void Sweep_Init(SweepState &s)
{
   s.count = 0;
   s.last_processed_bar = 0;
   for(int i = 0; i < BOTEN_SWEEP_MAX; ++i) s.events[i].valid = false;
}

void Sweep_OnNewDay(SweepState &s)
{
   // We keep yesterday's events for short-term lookback windows but cap them
   // so a fresh day does not rebuild against stale levels. Easiest is reset.
   s.count = 0;
   s.last_processed_bar = 0;
   for(int i = 0; i < BOTEN_SWEEP_MAX; ++i) s.events[i].valid = false;
}

int Sweep_Add(SweepState &s,
                      const datetime t,
                      const double wick,
                      const double level,
                      const int dir,
                      const string tag)
{
   for(int i = 0; i < s.count; ++i)
      if(s.events[i].valid && s.events[i].time == t && s.events[i].level_tag == tag)
         return i;
   int slot = -1;
   if(s.count < BOTEN_SWEEP_MAX) { slot = s.count; s.count++; }
   else
   {
      datetime oldest = TimeCurrent();
      for(int i = 0; i < BOTEN_SWEEP_MAX; ++i)
         if(s.events[i].time < oldest) { oldest = s.events[i].time; slot = i; }
   }
   if(slot < 0) return -1;
   s.events[slot].time        = t;
   s.events[slot].wick_price  = wick;
   s.events[slot].level_price = level;
   s.events[slot].direction   = dir;
   s.events[slot].level_tag   = tag;
   s.events[slot].valid       = true;
   return slot;
}

// Detect: bar `i` (closed) wicked above `level` and closed back below.
bool Sweep_HighTaken(const string symbol, const ENUM_TIMEFRAMES tf,
                             const int i, const double level)
{
   if(level <= 0.0) return false;
   double h = iHigh (symbol, tf, i);
   double c = iClose(symbol, tf, i);
   return (h > level && c < level);
}

bool Sweep_LowTaken(const string symbol, const ENUM_TIMEFRAMES tf,
                            const int i, const double level)
{
   if(level <= 0.0) return false;
   double l = iLow  (symbol, tf, i);
   double c = iClose(symbol, tf, i);
   return (l < level && c > level);
}

void Sweep_Update(SweepState &s,
                    const string symbol,
                    const ENUM_TIMEFRAMES tf,
                    const PrevDayLevels &pdl,
                    const AsiaRange &asia,
                    const int lookback_bars)
{
   // Re-scan the most recent N bars; events are dedup'd by (time, tag).
   for(int i = 1; i <= lookback_bars; ++i)
   {
      datetime t = iTime(symbol, tf, i);
      if(t == 0) break;

      if(Sweep_HighTaken(symbol, tf, i, pdl.pdh))
         Sweep_Add(s, t, iHigh(symbol, tf, i), pdl.pdh, -1, "PDH");
      if(Sweep_LowTaken (symbol, tf, i, pdl.pdl))
         Sweep_Add(s, t, iLow (symbol, tf, i), pdl.pdl, +1, "PDL");
      if(asia.finalised)
      {
         if(Sweep_HighTaken(symbol, tf, i, asia.high))
            Sweep_Add(s, t, iHigh(symbol, tf, i), asia.high, -1, "AH");
         if(Sweep_LowTaken (symbol, tf, i, asia.low))
            Sweep_Add(s, t, iLow (symbol, tf, i), asia.low, +1, "AL");
      }
   }
}

void Sweep_Draw(const SweepState &s, const string prefix)
{
   string base = prefix + "SWP_";
   for(int i = 0; i < s.count; ++i)
   {
      if(!s.events[i].valid) continue;
      string nm = base + IntegerToString(i);
      // Up arrow below price for low sweeps (bullish), down arrow above for highs.
      int code = (s.events[i].direction > 0) ? 233 : 234;
      color clr = (s.events[i].direction > 0) ? clrLime : clrRed;
      BotenLabels_Arrow(nm, s.events[i].time, s.events[i].wick_price,
                         code, clr, 2);
      BotenLabels_Text(nm + "_T", s.events[i].time, s.events[i].wick_price,
                        " " + s.events[i].level_tag, clr);
   }
}

bool Sweep_RecentInDirection(const SweepState &s,
                                const int dir,
                                const int max_bars_old)
{
   datetime now = TimeCurrent();
   for(int i = 0; i < s.count; ++i)
   {
      if(!s.events[i].valid) continue;
      if(s.events[i].direction != dir) continue;
      // Loose age filter: 1 hour per "bar" is generous; the OnCalculate
      // loop only refreshes on new bars anyway.
      if(now - s.events[i].time <= max_bars_old * 3600)
         return true;
   }
   return false;
}

#endif // __BOTEN_LIQSWEEP_MQH__
