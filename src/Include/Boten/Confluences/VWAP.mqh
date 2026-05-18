//+------------------------------------------------------------------+
//|                                                         VWAP.mqh |
//|     Session VWAP (anchored to NY midnight) with sigma bands     |
//+------------------------------------------------------------------+
#ifndef __BOTEN_VWAP_MQH__
#define __BOTEN_VWAP_MQH__

#include <Boten/Drawing/Levels.mqh>
#include <Boten/Drawing/Labels.mqh>
#include <Boten/Utils/Sessions.mqh>
#include <Boten/Utils/Logger.mqh>

struct VWAPState
{
   double   vwap;
   double   sigma;        // standard deviation of typical price weighted by volume
   double   band_up_1;
   double   band_dn_1;
   double   band_up_2;
   double   band_dn_2;
   datetime anchor;       // session-day anchor (NY midnight in broker time)
   bool     valid;
};

void VWAP_Init(VWAPState &v)
{
   v.vwap = 0.0; v.sigma = 0.0;
   v.band_up_1 = 0.0; v.band_dn_1 = 0.0;
   v.band_up_2 = 0.0; v.band_dn_2 = 0.0;
   v.anchor = 0;
   v.valid = false;
}

void VWAP_Update(VWAPState &v, const string symbol, const datetime broker_now)
{
   datetime anchor = BotenSessions_NYMidnightOfBroker(broker_now);
   v.anchor = anchor;

   // Use M1 bars from anchor to now. Limit scan to ~24h to stay cheap.
   double sumPV  = 0.0;
   double sumV   = 0.0;
   double sumPPV = 0.0;
   int counted = 0;
   for(int i = 0; i < 1500; ++i)   // up to 25h on M1
   {
      datetime bt = iTime(symbol, PERIOD_M1, i);
      if(bt == 0) break;
      if(bt < anchor) break;
      double h = iHigh (symbol, PERIOD_M1, i);
      double l = iLow  (symbol, PERIOD_M1, i);
      double c = iClose(symbol, PERIOD_M1, i);
      long   tv = iTickVolume(symbol, PERIOD_M1, i);
      double tp = (h + l + c) / 3.0;
      double w  = (double)tv;
      if(w <= 0.0) w = 1.0;
      sumPV  += tp * w;
      sumV   += w;
      sumPPV += tp * tp * w;
      counted++;
   }
   if(sumV <= 0.0 || counted < 5)
   {
      v.valid = false;
      return;
   }
   v.vwap  = sumPV / sumV;
   double mean_sq = sumPPV / sumV;
   double var = MathMax(0.0, mean_sq - v.vwap * v.vwap);
   v.sigma = MathSqrt(var);
   v.band_up_1 = v.vwap + v.sigma;
   v.band_dn_1 = v.vwap - v.sigma;
   v.band_up_2 = v.vwap + 2.0 * v.sigma;
   v.band_dn_2 = v.vwap - 2.0 * v.sigma;
   v.valid = true;
}

void VWAP_Draw(const VWAPState &v, const string prefix, const color clr)
{
   if(!v.valid) return;
   string base = prefix + "VWAP_";
   datetime t1 = v.anchor;
   datetime t2 = TimeCurrent() + 4 * 3600;
   BotenLevels_Segment(base + "MID", t1, t2, v.vwap, clr, 2, STYLE_SOLID);
   BotenLevels_Segment(base + "U1",  t1, t2, v.band_up_1, clr, 1, STYLE_DOT);
   BotenLevels_Segment(base + "D1",  t1, t2, v.band_dn_1, clr, 1, STYLE_DOT);
   BotenLevels_Segment(base + "U2",  t1, t2, v.band_up_2, clr, 1, STYLE_DASH);
   BotenLevels_Segment(base + "D2",  t1, t2, v.band_dn_2, clr, 1, STYLE_DASH);
   BotenLabels_Text   (base + "TXT", t2, v.vwap, " VWAP", clr);
}

bool VWAP_AlignedWithDirection(const VWAPState &v,
                                  const int dir,
                                  const double price)
{
   if(!v.valid) return false;
   if(dir > 0) return price > v.vwap;
   if(dir < 0) return price < v.vwap;
   return false;
}

#endif // __BOTEN_VWAP_MQH__
