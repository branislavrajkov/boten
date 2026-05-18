//+------------------------------------------------------------------+
//|                                                   OrderBlock.mqh |
//|     Last opposing candle before LTF BOS = bullish/bearish OB    |
//+------------------------------------------------------------------+
#ifndef __BOTEN_ORDERBLOCK_MQH__
#define __BOTEN_ORDERBLOCK_MQH__

#include <Boten/Drawing/Zones.mqh>
#include <Boten/Utils/Logger.mqh>

#define BOTEN_OB_MAX 32
#define BOTEN_OB_LOOKBACK 200
#define BOTEN_OB_FRACTAL_LEFT  3
#define BOTEN_OB_FRACTAL_RIGHT 3

struct OBZone
{
   int      direction;        // +1 bullish OB, -1 bearish OB
   double   lower;
   double   upper;
   datetime formed_time;
   datetime end_time;
   bool     mitigated;
   bool     valid;
};

struct OrderBlockState
{
   OBZone zones[BOTEN_OB_MAX];
   int    count;
};

void OrderBlock_Init(OrderBlockState &s)
{
   s.count = 0;
   for(int i = 0; i < BOTEN_OB_MAX; ++i) s.zones[i].valid = false;
}

// Find a fractal swing high/low at shift s on tf: high[s] is greatest among
// shifts [s-right ... s+left] (and analogously low for bearish).
bool OB_IsSwingHigh(const string symbol, const ENUM_TIMEFRAMES tf,
                            const int s)
{
   double centre = iHigh(symbol, tf, s);
   for(int k = 1; k <= BOTEN_OB_FRACTAL_LEFT; ++k)
      if(iHigh(symbol, tf, s + k) >= centre) return false;
   for(int k = 1; k <= BOTEN_OB_FRACTAL_RIGHT; ++k)
      if(iHigh(symbol, tf, s - k) >= centre) return false;
   return true;
}

bool OB_IsSwingLow(const string symbol, const ENUM_TIMEFRAMES tf,
                           const int s)
{
   double centre = iLow(symbol, tf, s);
   for(int k = 1; k <= BOTEN_OB_FRACTAL_LEFT; ++k)
      if(iLow(symbol, tf, s + k) <= centre) return false;
   for(int k = 1; k <= BOTEN_OB_FRACTAL_RIGHT; ++k)
      if(iLow(symbol, tf, s - k) <= centre) return false;
   return true;
}

int OB_AddZone(OrderBlockState &s,
                       const int direction,
                       const double lower, const double upper,
                       const datetime t, const datetime t_now)
{
   for(int i = 0; i < s.count; ++i)
   {
      if(s.zones[i].valid &&
         s.zones[i].direction   == direction &&
         s.zones[i].formed_time == t)
         return i;
   }
   int slot = -1;
   if(s.count < BOTEN_OB_MAX) { slot = s.count; s.count++; }
   else
   {
      datetime oldest = TimeCurrent();
      for(int i = 0; i < BOTEN_OB_MAX; ++i)
      {
         if(s.zones[i].formed_time < oldest)
         { oldest = s.zones[i].formed_time; slot = i; }
      }
   }
   if(slot < 0) return -1;
   s.zones[slot].direction   = direction;
   s.zones[slot].lower       = lower;
   s.zones[slot].upper       = upper;
   s.zones[slot].formed_time = t;
   s.zones[slot].end_time    = t_now;
   s.zones[slot].mitigated   = false;
   s.zones[slot].valid       = true;
   return slot;
}

void OrderBlock_Update(OrderBlockState &s,
                         const string symbol,
                         const ENUM_TIMEFRAMES tf)
{
   datetime t_now = iTime(symbol, tf, 0);
   int total_bars = Bars(symbol, tf);
   int max_idx = MathMin(BOTEN_OB_LOOKBACK, total_bars - 35);
   if(max_idx < 5) return;

   // Walk back through bars looking for the most recent BOS event.
   // For a bullish BOS: a bar closes above a previously confirmed swing high.
   // The OB is the last bearish (close < open) bar before the impulse.
   for(int s_idx = 1; s_idx < max_idx; ++s_idx)
   {
      double cls = iClose(symbol, tf, s_idx);
      // Look for any swing high in shifts [s_idx+1 .. s_idx+30] that this close exceeds.
      for(int sw = s_idx + BOTEN_OB_FRACTAL_RIGHT + 1; sw < s_idx + 30; ++sw)
      {
         if(!OB_IsSwingHigh(symbol, tf, sw)) continue;
         double swh = iHigh(symbol, tf, sw);
         if(cls > swh)
         {
            // Find last bearish candle in (s_idx ... sw).
            for(int j = s_idx + 1; j <= sw; ++j)
            {
               double op = iOpen (symbol, tf, j);
               double cl = iClose(symbol, tf, j);
               if(cl < op)
               {
                  double lo = iLow (symbol, tf, j);
                  double hi = iHigh(symbol, tf, j);
                  datetime tt = iTime(symbol, tf, j);
                  OB_AddZone(s, +1, lo, hi, tt, t_now);
                  break;
               }
            }
            break;
         }
      }
      // Mirror for bearish BOS.
      for(int sw2 = s_idx + BOTEN_OB_FRACTAL_RIGHT + 1; sw2 < s_idx + 30; ++sw2)
      {
         if(!OB_IsSwingLow(symbol, tf, sw2)) continue;
         double swl = iLow(symbol, tf, sw2);
         if(cls < swl)
         {
            for(int j = s_idx + 1; j <= sw2; ++j)
            {
               double op = iOpen (symbol, tf, j);
               double cl = iClose(symbol, tf, j);
               if(cl > op)
               {
                  double lo = iLow (symbol, tf, j);
                  double hi = iHigh(symbol, tf, j);
                  datetime tt = iTime(symbol, tf, j);
                  OB_AddZone(s, -1, lo, hi, tt, t_now);
                  break;
               }
            }
            break;
         }
      }
   }

   // Mitigation pass.
   double last_h = iHigh(symbol, tf, 1);
   double last_l = iLow (symbol, tf, 1);
   double last_c = iClose(symbol, tf, 1);
   for(int i = 0; i < s.count; ++i)
   {
      if(!s.zones[i].valid || s.zones[i].mitigated) continue;
      s.zones[i].end_time = t_now;
      if(s.zones[i].direction > 0)
      {
         // Mitigated when price closes below the OB low.
         if(last_c < s.zones[i].lower) s.zones[i].mitigated = true;
      }
      else
      {
         if(last_c > s.zones[i].upper) s.zones[i].mitigated = true;
      }
   }
}

void OrderBlock_Draw(const OrderBlockState &s,
                      const string prefix,
                      const color c_bull, const color c_bear)
{
   string base = prefix + "OB_";
   for(int i = 0; i < s.count; ++i)
   {
      if(!s.zones[i].valid) continue;
      string nm = base + IntegerToString(i);
      if(s.zones[i].mitigated) { ObjectDelete(0, nm); continue; }
      color clr = (s.zones[i].direction > 0) ? c_bull : c_bear;
      BotenZones_Rect(nm,
                       s.zones[i].formed_time, s.zones[i].upper,
                       s.zones[i].end_time,    s.zones[i].lower,
                       clr, false, 1, STYLE_DOT);
   }
}

bool OrderBlock_LatestAligned(const OrderBlockState &s,
                                 const int dir,
                                 const double price,
                                 OBZone &out)
{
   datetime best = 0;
   int idx = -1;
   for(int i = 0; i < s.count; ++i)
   {
      if(!s.zones[i].valid || s.zones[i].mitigated) continue;
      if(s.zones[i].direction != dir) continue;
      if(dir > 0 && s.zones[i].upper > price) continue;
      if(dir < 0 && s.zones[i].lower < price) continue;
      if(s.zones[i].formed_time > best)
      { best = s.zones[i].formed_time; idx = i; }
   }
   if(idx < 0) return false;
   out = s.zones[idx];
   return true;
}

#endif // __BOTEN_ORDERBLOCK_MQH__
