//+------------------------------------------------------------------+
//|                                                    Killzones.mqh |
//|       Translucent background bands for London/NY AM/NY PM       |
//+------------------------------------------------------------------+
#ifndef __BOTEN_KILLZONES_MQH__
#define __BOTEN_KILLZONES_MQH__

#include <Boten/Drawing/Zones.mqh>
#include <Boten/Drawing/Labels.mqh>
#include <Boten/Utils/Sessions.mqh>

// Single helper that draws one shaded killzone for "today".
void Killzones_DrawOne(const string name,
                                const datetime broker_now,
                                const int sh, const int sm,
                                const int eh, const int em,
                                const color clr,
                                const string tag)
{
   datetime t1 = BotenSessions_TodayGMT(broker_now, sh, sm);
   datetime t2 = BotenSessions_TodayGMT(broker_now, eh, em);
   if(t2 <= t1) return;

   // Draw rectangle that spans the full chart vertically by using a very
   // wide price range. We use the current broker bid +/- a percentage as
   // a fallback; the exact extents are visually clipped by the chart anyway.
   double mid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double span = MathMax(mid * 0.05, 100.0);
   BotenZones_Rect(name, t1, mid + span, t2, mid - span, clr, true);
   BotenLabels_Text(name + "_TXT", t1, mid + span * 0.9, " " + tag, clr);
}

void Killzones_Draw(const string prefix,
                     const datetime broker_now,
                     const bool en_lon, const int lh1, const int lm1,
                                         const int lh2, const int lm2,
                                         const color c_lon,
                     const bool en_am,  const int ah1, const int am1,
                                         const int ah2, const int am2,
                                         const color c_am,
                     const bool en_pm,  const int ph1, const int pm1,
                                         const int ph2, const int pm2,
                                         const color c_pm)
{
   string base = prefix + "KZ_";
   if(en_lon)
      Killzones_DrawOne(base + "LON", broker_now, lh1, lm1, lh2, lm2, c_lon, "LDN KZ");
   if(en_am)
      Killzones_DrawOne(base + "AM",  broker_now, ah1, am1, ah2, am2, c_am,  "NY AM");
   if(en_pm)
      Killzones_DrawOne(base + "PM",  broker_now, ph1, pm1, ph2, pm2, c_pm,  "NY PM");
}

#endif // __BOTEN_KILLZONES_MQH__
