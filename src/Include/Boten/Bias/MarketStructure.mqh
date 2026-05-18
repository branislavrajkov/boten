//+------------------------------------------------------------------+
//|                                              MarketStructure.mqh |
//|     HTF BOS / CHoCH detection from fractal swing points         |
//+------------------------------------------------------------------+
#ifndef __BOTEN_STRUCT_MQH__
#define __BOTEN_STRUCT_MQH__

#include <Boten/Utils/Logger.mqh>

enum ENUM_BOTEN_STRUCT
{
   BOTEN_STRUCT_NONE         = 0,
   BOTEN_STRUCT_BULL_BOS     = 1,
   BOTEN_STRUCT_BEAR_BOS     = 2,
   BOTEN_STRUCT_BULL_CHOCH   = 3,
   BOTEN_STRUCT_BEAR_CHOCH   = 4
};

struct MarketStructure
{
   ENUM_BOTEN_STRUCT  state;
   double             last_swing_high;
   double             last_swing_low;
   datetime           last_event_time;
   bool               valid;
};

void MarketStructure_Init(MarketStructure &m)
{
   m.state = BOTEN_STRUCT_NONE;
   m.last_swing_high = 0.0;
   m.last_swing_low  = 0.0;
   m.last_event_time = 0;
   m.valid = false;
}

#define BOTEN_MS_FRACTAL_LEFT  3
#define BOTEN_MS_FRACTAL_RIGHT 3
#define BOTEN_MS_LOOKBACK      150

bool MS_IsSwingHigh(const string symbol, const ENUM_TIMEFRAMES tf,
                            const int s)
{
   double centre = iHigh(symbol, tf, s);
   for(int k = 1; k <= BOTEN_MS_FRACTAL_LEFT; ++k)
      if(iHigh(symbol, tf, s + k) >= centre) return false;
   for(int k = 1; k <= BOTEN_MS_FRACTAL_RIGHT; ++k)
      if(iHigh(symbol, tf, s - k) >= centre) return false;
   return true;
}

bool MS_IsSwingLow(const string symbol, const ENUM_TIMEFRAMES tf,
                           const int s)
{
   double centre = iLow(symbol, tf, s);
   for(int k = 1; k <= BOTEN_MS_FRACTAL_LEFT; ++k)
      if(iLow(symbol, tf, s + k) <= centre) return false;
   for(int k = 1; k <= BOTEN_MS_FRACTAL_RIGHT; ++k)
      if(iLow(symbol, tf, s - k) <= centre) return false;
   return true;
}

void MarketStructure_Update(MarketStructure &m,
                              const string symbol,
                              const ENUM_TIMEFRAMES tf)
{
   // Walk forward through closed bars, updating "last" swing high/low and
   // emitting BOS/CHoCH events whenever a close pierces a recent swing.
   ENUM_BOTEN_STRUCT current_state = BOTEN_STRUCT_NONE;
   double swh = 0.0, swl = 0.0;
   datetime last_event_t = 0;
   ENUM_BOTEN_STRUCT prev_dir = BOTEN_STRUCT_NONE; // last directional event

   // Iterate from oldest to newest among closed bars.
   for(int s = BOTEN_MS_LOOKBACK; s >= 1; --s)
   {
      if(s + BOTEN_MS_FRACTAL_LEFT >= Bars(symbol, tf)) continue;

      if(MS_IsSwingHigh(symbol, tf, s)) swh = iHigh(symbol, tf, s);
      if(MS_IsSwingLow (symbol, tf, s)) swl = iLow (symbol, tf, s);

      double cls = iClose(symbol, tf, s - 1 < 0 ? 0 : s);
      datetime t = iTime(symbol, tf, s);

      if(swh > 0.0 && cls > swh)
      {
         current_state = (prev_dir == BOTEN_STRUCT_BEAR_BOS ||
                          prev_dir == BOTEN_STRUCT_BEAR_CHOCH)
                           ? BOTEN_STRUCT_BULL_CHOCH
                           : BOTEN_STRUCT_BULL_BOS;
         prev_dir = current_state;
         last_event_t = t;
         swh = 0.0;            // consume so we don't re-fire on the same swing
      }
      if(swl > 0.0 && cls < swl)
      {
         current_state = (prev_dir == BOTEN_STRUCT_BULL_BOS ||
                          prev_dir == BOTEN_STRUCT_BULL_CHOCH)
                           ? BOTEN_STRUCT_BEAR_CHOCH
                           : BOTEN_STRUCT_BEAR_BOS;
         prev_dir = current_state;
         last_event_t = t;
         swl = 0.0;
      }
   }

   m.state = current_state;
   m.last_swing_high = swh;
   m.last_swing_low  = swl;
   m.last_event_time = last_event_t;
   m.valid = (current_state != BOTEN_STRUCT_NONE);

   BotenLogDebug(StringFormat("MarketStructure: state=%d", (int)m.state));
}

// Signed contribution for the bias score: +2 bull BOS, -2 bear BOS, -1 bull CHoCH, +1 bear CHoCH.
// Rationale: BOS confirms trend direction; CHoCH is a counter-trend warning -
// it weakens the bias rather than flipping it on its own.
int MarketStructure_BiasContribution(const MarketStructure &m)
{
   if(!m.valid) return 0;
   switch(m.state)
   {
      case BOTEN_STRUCT_BULL_BOS:   return +2;
      case BOTEN_STRUCT_BEAR_BOS:   return -2;
      case BOTEN_STRUCT_BULL_CHOCH: return +1;
      case BOTEN_STRUCT_BEAR_CHOCH: return -1;
      default:                       return 0;
   }
}

string MarketStructure_StateName(const MarketStructure &m)
{
   switch(m.state)
   {
      case BOTEN_STRUCT_BULL_BOS:   return "BullBOS";
      case BOTEN_STRUCT_BEAR_BOS:   return "BearBOS";
      case BOTEN_STRUCT_BULL_CHOCH: return "BullCHoCH";
      case BOTEN_STRUCT_BEAR_CHOCH: return "BearCHoCH";
      default:                       return "None";
   }
}

#endif // __BOTEN_STRUCT_MQH__
