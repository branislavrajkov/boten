//+------------------------------------------------------------------+
//|                                                 MidnightOpen.mqh |
//|     NY 00:00 reference price (ICT "true day open" for indices)  |
//+------------------------------------------------------------------+
#ifndef __BOTEN_MIDNIGHT_MQH__
#define __BOTEN_MIDNIGHT_MQH__

#include <Boten/Drawing/Levels.mqh>
#include <Boten/Drawing/Labels.mqh>
#include <Boten/Utils/Sessions.mqh>
#include <Boten/Utils/Logger.mqh>

struct MidnightOpen
{
   double   price;
   datetime t_open;       // broker time of NY 00:00 today
   bool     valid;
};

void MidnightOpen_Init(MidnightOpen &m)
{
   m.price = 0.0;
   m.t_open = 0;
   m.valid = false;
}

void MidnightOpen_Update(MidnightOpen &m,
                          const string symbol,
                          const datetime broker_now)
{
   datetime t = BotenSessions_NYMidnightOfBroker(broker_now);
   m.t_open = t;
   // Find the M1 bar whose open-time is exactly t (or the closest <= t).
   // CopyRates is overkill; iBarShift on M1 is enough.
   int shift = iBarShift(symbol, PERIOD_M1, t, false);
   if(shift < 0)
   {
      m.valid = false;
      return;
   }
   m.price = iOpen(symbol, PERIOD_M1, shift);
   m.valid = (m.price > 0.0);
   if(m.valid)
      BotenLogDebug(StringFormat("Midnight NY open: %.2f at %s",
                                   m.price,
                                   TimeToString(m.t_open, TIME_DATE | TIME_MINUTES)));
}

void MidnightOpen_Draw(const MidnightOpen &m,
                         const string prefix,
                         const color clr)
{
   if(!m.valid) return;
   string base = prefix + "MN_";
   datetime t2 = m.t_open + 24 * 3600;
   BotenLevels_Segment(base + "LINE", m.t_open, t2, m.price, clr, 1, STYLE_DASHDOTDOT);
   BotenLabels_Text   (base + "TXT",  t2, m.price, " 00:00 NY", clr);
}

#endif // __BOTEN_MIDNIGHT_MQH__
