//+------------------------------------------------------------------+
//|                                                          ORB.mqh |
//|       Configurable Opening Range Breakout (London / NY)         |
//+------------------------------------------------------------------+
#ifndef __BOTEN_ORB_MQH__
#define __BOTEN_ORB_MQH__

#include <Boten/Drawing/Zones.mqh>
#include <Boten/Drawing/Labels.mqh>
#include <Boten/Utils/Sessions.mqh>
#include <Boten/Utils/Logger.mqh>

// One ORB (London or NY). The "broken" flag flips on the first close
// past the high (->+1) or low (->-1) after the range is locked.
struct ORBState
{
   string   tag;
   double   high;
   double   low;
   datetime t_start;
   datetime t_end;
   bool     finalised;
   int      broken;          // 0 / +1 / -1
   datetime broken_time;
};

void ORB_Init(ORBState &o, const string tag)
{
   o.tag = tag;
   o.high = 0.0; o.low = 0.0;
   o.t_start = 0; o.t_end = 0;
   o.finalised = false;
   o.broken = 0;
   o.broken_time = 0;
}

// session_start_h/m is the SESSION start in GMT; we run the ORB for
// `minutes` after that. Resets when a new day starts.
void ORB_Update(ORBState &o,
                  const string symbol,
                  const datetime broker_now,
                  const int session_start_h,
                  const int session_start_m,
                  const int minutes)
{
   datetime ts = BotenSessions_TodayGMT(broker_now,
                                          session_start_h,
                                          session_start_m);
   datetime te = ts + minutes * 60;

   // Detect day rollover by comparing current ts to stored t_start.
   if(o.t_start != ts)
   {
      o.t_start = ts;
      o.t_end   = te;
      o.high = 0.0; o.low = 0.0;
      o.finalised = false;
      o.broken = 0;
      o.broken_time = 0;
   }

   if(broker_now < ts) return;

   if(broker_now < te && !o.finalised)
   {
      // Build the range from M1 bars within [ts, te).
      double hh = -DBL_MAX;
      double ll =  DBL_MAX;
      for(int i = 0; i < 240; ++i)  // up to 4h on M1
      {
         datetime bt = iTime(symbol, PERIOD_M1, i);
         if(bt == 0) break;
         if(bt < ts) break;
         if(bt >= te) continue;
         double bh = iHigh(symbol, PERIOD_M1, i);
         double bl = iLow (symbol, PERIOD_M1, i);
         if(bh > hh) hh = bh;
         if(bl < ll) ll = bl;
      }
      if(hh > 0.0 && ll < DBL_MAX)
      {
         o.high = hh;
         o.low  = ll;
      }
   }
   else if(broker_now >= te && !o.finalised)
   {
      // Final lock pass over M1 bars.
      double hh = -DBL_MAX;
      double ll =  DBL_MAX;
      for(int i = 0; i < 240; ++i)
      {
         datetime bt = iTime(symbol, PERIOD_M1, i);
         if(bt == 0) break;
         if(bt < ts) break;
         if(bt >= te) continue;
         double bh = iHigh(symbol, PERIOD_M1, i);
         double bl = iLow (symbol, PERIOD_M1, i);
         if(bh > hh) hh = bh;
         if(bl < ll) ll = bl;
      }
      if(hh > 0.0 && ll < DBL_MAX)
      {
         o.high = hh;
         o.low  = ll;
         o.finalised = true;
         BotenLogDebug(StringFormat("ORB %s locked: H=%.2f L=%.2f",
                                    o.tag, o.high, o.low));
      }
   }

   if(o.finalised && o.broken == 0)
   {
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(bid > o.high)
      {
         o.broken = +1;
         o.broken_time = broker_now;
         BotenLogDebug(StringFormat("ORB %s broken upward.", o.tag));
      }
      else if(bid < o.low)
      {
         o.broken = -1;
         o.broken_time = broker_now;
         BotenLogDebug(StringFormat("ORB %s broken downward.", o.tag));
      }
   }
}

void ORB_Draw(const ORBState &o,
                const string prefix,
                const color clr)
{
   if(o.t_start == 0 || o.high <= 0.0) return;

   string base = prefix + "ORB_" + o.tag + "_";
   datetime t2 = o.t_end + 6 * 3600;
   BotenZones_Rect(base + "BOX", o.t_start, o.high, t2, o.low, clr, true);
   BotenLabels_Text(base + "TXT", t2, o.high, " ORB " + o.tag, clr);
}

bool ORB_BrokenInDirection(const ORBState &o, const int dir)
{
   if(!o.finalised) return false;
   return (o.broken == dir);
}

#endif // __BOTEN_ORB_MQH__
