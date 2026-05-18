//+------------------------------------------------------------------+
//|                                                          FVG.mqh |
//|        3-candle Fair Value Gap detection with mitigation        |
//+------------------------------------------------------------------+
#ifndef __BOTEN_FVG_MQH__
#define __BOTEN_FVG_MQH__

#include <Boten/Drawing/Zones.mqh>
#include <Boten/Utils/Logger.mqh>

#define BOTEN_FVG_MAX 64
#define BOTEN_FVG_SCAN_BARS 200

struct FVGZone
{
   int      direction;        // +1 bullish, -1 bearish
   double   lower;
   double   upper;
   datetime formed_time;      // open-time of bar 1 (the 3rd of the trio)
   datetime end_time;         // dynamic right edge for drawing
   bool     mitigated;
   bool     valid;
};

struct FVGState
{
   FVGZone zones[BOTEN_FVG_MAX];
   int     count;
   datetime last_scan_bar;
};

void FVG_Init(FVGState &f)
{
   f.count = 0;
   f.last_scan_bar = 0;
   for(int i = 0; i < BOTEN_FVG_MAX; ++i) f.zones[i].valid = false;
}

// Detect bullish FVG: low[1] > high[3] (gap between candle 3 and 1, candle 2 imbalances).
// Detect bearish FVG: high[1] < low[3].
// We index using "shift" semantics: shift 0 = current forming bar, shift 1 = last closed.
// We scan up to BOTEN_FVG_SCAN_BARS back so first-attach populates a useful history;
// subsequent calls dedup via formed_time, so the work is O(scan) but cheap.
void FVG_Update(FVGState &f, const string symbol, const ENUM_TIMEFRAMES tf)
{
   datetime cur = iTime(symbol, tf, 0);
   if(cur == 0) return;

   int total_bars = Bars(symbol, tf);
   int scan_max = MathMin(BOTEN_FVG_SCAN_BARS, total_bars - 4);
   for(int s = 1; s <= scan_max; ++s)
   {
      double h1 = iHigh(symbol, tf, s);
      double l1 = iLow (symbol, tf, s);
      double h3 = iHigh(symbol, tf, s + 2);
      double l3 = iLow (symbol, tf, s + 2);
      datetime t1 = iTime(symbol, tf, s);
      if(t1 == 0 || h3 <= 0.0 || l3 <= 0.0) continue;

      int direction = 0;
      double lower = 0.0;
      double upper = 0.0;
      if(l1 > h3)
      {
         direction = +1;
         lower = h3;
         upper = l1;
      }
      else if(h1 < l3)
      {
         direction = -1;
         lower = h1;
         upper = l3;
      }
      if(direction == 0) continue;

      // Skip if we already have this exact zone.
      bool dup = false;
      for(int i = 0; i < f.count; ++i)
      {
         if(!f.zones[i].valid) continue;
         if(f.zones[i].formed_time == t1 &&
            f.zones[i].direction == direction)
         { dup = true; break; }
      }
      if(dup) continue;

      // Slot in (replace oldest if full).
      int slot = -1;
      if(f.count < BOTEN_FVG_MAX) { slot = f.count; f.count++; }
      else
      {
         datetime oldest_t = TimeCurrent();
         for(int i = 0; i < BOTEN_FVG_MAX; ++i)
         {
            if(f.zones[i].formed_time < oldest_t)
            { oldest_t = f.zones[i].formed_time; slot = i; }
         }
      }
      if(slot < 0) continue;

      f.zones[slot].direction   = direction;
      f.zones[slot].lower       = lower;
      f.zones[slot].upper       = upper;
      f.zones[slot].formed_time = t1;
      f.zones[slot].end_time    = t1;
      f.zones[slot].mitigated   = false;
      f.zones[slot].valid       = true;

      BotenLogDebug(StringFormat(
         "FVG new: dir=%+d [%.2f, %.2f] @ %s",
         direction, lower, upper,
         TimeToString(t1, TIME_DATE | TIME_MINUTES)));
   }

   // Update mitigation/end_time across all stored zones.
   datetime t_now = iTime(symbol, tf, 0);
   for(int i = 0; i < f.count; ++i)
   {
      if(!f.zones[i].valid) continue;
      // Walk forward bars from formed_time + 1 and check for fill.
      // For efficiency we only check the most recent closed bar.
      double bar_h = iHigh(symbol, tf, 1);
      double bar_l = iLow (symbol, tf, 1);

      f.zones[i].end_time = t_now;

      // Bullish FVG mitigated if a later bar dips into it from above.
      if(f.zones[i].direction > 0 && bar_l <= f.zones[i].upper)
      {
         if(bar_l <= f.zones[i].lower)
            f.zones[i].mitigated = true;
         else
            f.zones[i].upper = bar_l;   // shrink to remaining gap
      }
      else if(f.zones[i].direction < 0 && bar_h >= f.zones[i].lower)
      {
         if(bar_h >= f.zones[i].upper)
            f.zones[i].mitigated = true;
         else
            f.zones[i].lower = bar_h;
      }
   }
}

void FVG_Draw(const FVGState &f,
                const string prefix,
                const color c_bull, const color c_bear)
{
   string base = prefix + "FVG_";
   for(int i = 0; i < f.count; ++i)
   {
      if(!f.zones[i].valid) continue;
      string nm = base + IntegerToString(i);
      if(f.zones[i].mitigated)
      {
         ObjectDelete(0, nm);
         continue;
      }
      color clr = (f.zones[i].direction > 0) ? c_bull : c_bear;
      BotenZones_Rect(nm,
                       f.zones[i].formed_time, f.zones[i].upper,
                       f.zones[i].end_time,    f.zones[i].lower,
                       clr, true);
   }
}

// Find the most recent unmitigated FVG aligned with `dir` whose price is
// reachable from the current price (above for shorts, below for longs).
bool FVG_LatestAligned(const FVGState &f,
                          const int dir,
                          const double price,
                          FVGZone &out)
{
   datetime best_t = 0;
   int best = -1;
   for(int i = 0; i < f.count; ++i)
   {
      if(!f.zones[i].valid || f.zones[i].mitigated) continue;
      if(f.zones[i].direction != dir) continue;
      // For longs: want a bullish FVG below current price (a return-to-fill spot).
      if(dir > 0 && f.zones[i].upper > price) continue;
      // For shorts: bearish FVG above price.
      if(dir < 0 && f.zones[i].lower < price) continue;
      if(f.zones[i].formed_time > best_t)
      { best_t = f.zones[i].formed_time; best = i; }
   }
   if(best < 0) return false;
   out = f.zones[best];
   return true;
}

#endif // __BOTEN_FVG_MQH__
