//+------------------------------------------------------------------+
//|                                                    AsiaRange.mqh |
//|        Asia session high/low and "which side swept first"       |
//+------------------------------------------------------------------+
#ifndef __BOTEN_ASIARANGE_MQH__
#define __BOTEN_ASIARANGE_MQH__

#include <Boten/Drawing/Zones.mqh>
#include <Boten/Drawing/Labels.mqh>
#include <Boten/Utils/Sessions.mqh>
#include <Boten/Utils/Logger.mqh>

// Sweep side enum: 0 = none, +1 = high taken first (likely day-low side bias),
// -1 = low taken first (likely day-high side bias).
struct AsiaRange
{
   double   high;
   double   low;
   double   mid;
   datetime t_start;          // broker time of asia start
   datetime t_end;            // broker time of asia end
   bool     finalised;        // true once we are past asia end today
   int      swept_side;       // 0 / +1 / -1 - first side taken during/after London open
   bool     drawn_finalised;
};

void AsiaRange_Init(AsiaRange &a)
{
   a.high = 0.0; a.low = 0.0; a.mid = 0.0;
   a.t_start = 0; a.t_end = 0;
   a.finalised = false;
   a.swept_side = 0;
   a.drawn_finalised = false;
}

// Called at NY midnight: reset asia state for the new day.
void AsiaRange_OnNewDay(AsiaRange &a, const datetime broker_now)
{
   a.high = 0.0; a.low = 0.0; a.mid = 0.0;
   a.t_start = 0; a.t_end = 0;
   a.finalised = false;
   a.swept_side = 0;
   a.drawn_finalised = false;
}

// Update asia high/low while we are inside the asia window; lock when window ends.
// asia_start_h/m and asia_end_h/m are GMT.
void AsiaRange_Update(AsiaRange &a,
                      const string symbol,
                      const datetime broker_now,
                      const int asia_start_h, const int asia_start_m,
                      const int asia_end_h,   const int asia_end_m)
{
   // Set start/end timestamps once per day.
   if(a.t_start == 0)
   {
      a.t_start = BotenSessions_TodayGMT(broker_now,
                                          asia_start_h, asia_start_m);
      a.t_end   = BotenSessions_TodayGMT(broker_now,
                                          asia_end_h,   asia_end_m);
   }

   bool inside_asia = (broker_now >= a.t_start && broker_now < a.t_end);

   if(inside_asia)
   {
      // Recompute via tick: this is cheap (single tick) but we also
      // do a definitive recompute when window closes.
      double h = SymbolInfoDouble(symbol, SYMBOL_BID);
      double l = h;
      if(a.high == 0.0 || h > a.high) a.high = h;
      if(a.low  == 0.0 || l < a.low ) a.low  = l;
      a.mid = 0.5 * (a.high + a.low);
   }
   else if(broker_now >= a.t_end && !a.finalised)
   {
      // Recompute the asia high/low from M5 bars to avoid the tick noise.
      // We scan M5 bars whose open time falls within [t_start, t_end).
      double hh = -DBL_MAX;
      double ll =  DBL_MAX;
      for(int i = 0; i < 600; ++i)   // up to ~50h on M5, plenty
      {
         datetime bt = iTime(symbol, PERIOD_M5, i);
         if(bt == 0) break;
         if(bt < a.t_start) break;
         if(bt >= a.t_end)  continue;
         double bh = iHigh(symbol, PERIOD_M5, i);
         double bl = iLow (symbol, PERIOD_M5, i);
         if(bh > hh) hh = bh;
         if(bl < ll) ll = bl;
      }
      if(hh > 0.0 && ll < DBL_MAX)
      {
         a.high = hh;
         a.low  = ll;
         a.mid  = 0.5 * (hh + ll);
      }
      a.finalised = true;
      BotenLogDebug(StringFormat(
         "AsiaRange finalised: H=%.2f L=%.2f mid=%.2f",
         a.high, a.low, a.mid));
   }

   // After asia ends, watch for the first sweep of the high or low.
   if(a.finalised && a.swept_side == 0 && a.high > 0.0 && a.low > 0.0)
   {
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(bid > a.high)
      {
         a.swept_side = +1;
         BotenLogDebug("AsiaRange high swept first (bearish bias for day).");
      }
      else if(bid < a.low)
      {
         a.swept_side = -1;
         BotenLogDebug("AsiaRange low swept first (bullish bias for day).");
      }
   }
}

void AsiaRange_Draw(const AsiaRange &a,
                     const string prefix,
                     const color clr)
{
   if(a.t_start == 0 || a.t_end == 0) return;
   if(a.high <= 0.0 || a.low <= 0.0)  return;

   string base = prefix + "ASIA_";
   datetime t1 = a.t_start;
   datetime t2 = a.finalised ? a.t_end + 6 * 3600 : a.t_end;

   BotenZones_Rect(base + "BOX", t1, a.high, t2, a.low, clr, true);
   BotenLabels_Text(base + "TXT", t2, a.high,
      a.finalised ? " ASIA" : " ASIA (live)", clr);
}

#endif // __BOTEN_ASIARANGE_MQH__
