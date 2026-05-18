//+------------------------------------------------------------------+
//|                                                PrevDayLevels.mqh |
//|        Prior day H/L/Mid and prior week H/L from D1/W1 bars     |
//+------------------------------------------------------------------+
#ifndef __BOTEN_PREVDAYLEVELS_MQH__
#define __BOTEN_PREVDAYLEVELS_MQH__

#include <Boten/Drawing/Levels.mqh>
#include <Boten/Drawing/Labels.mqh>
#include <Boten/Utils/Logger.mqh>

struct PrevDayLevels
{
   double   pdh;          // previous day high
   double   pdl;          // previous day low
   double   pdm;          // previous day midpoint
   double   pdc;          // previous day close
   double   pwh;          // previous week high
   double   pwl;          // previous week low
   datetime day_start;    // broker time of "today" anchor
   bool     valid;
};

void PrevDayLevels_Init(PrevDayLevels &v)
{
   v.pdh = 0.0; v.pdl = 0.0; v.pdm = 0.0; v.pdc = 0.0;
   v.pwh = 0.0; v.pwl = 0.0;
   v.day_start = 0;
   v.valid = false;
}

bool PrevDayLevels_Update(PrevDayLevels &v, const string symbol)
{
   // Bar 1 on D1 is the most recent fully-closed daily bar (yesterday).
   // Bar 1 on W1 is the most recent fully-closed weekly bar (last week).
   double d_high  = iHigh(symbol,  PERIOD_D1, 1);
   double d_low   = iLow(symbol,   PERIOD_D1, 1);
   double d_close = iClose(symbol, PERIOD_D1, 1);
   double w_high  = iHigh(symbol,  PERIOD_W1, 1);
   double w_low   = iLow(symbol,   PERIOD_W1, 1);

   if(d_high <= 0.0 || w_high <= 0.0)
   {
      BotenLogWarn("PrevDayLevels: not enough D1/W1 history yet.");
      v.valid = false;
      return false;
   }

   v.pdh = d_high;
   v.pdl = d_low;
   v.pdc = d_close;
   v.pdm = 0.5 * (d_high + d_low);
   v.pwh = w_high;
   v.pwl = w_low;
   v.day_start = iTime(symbol, PERIOD_D1, 0);
   v.valid = true;

   BotenLogDebug(StringFormat(
      "PrevDayLevels updated: PDH=%.2f PDL=%.2f PDM=%.2f PDC=%.2f PWH=%.2f PWL=%.2f",
      v.pdh, v.pdl, v.pdm, v.pdc, v.pwh, v.pwl));
   return true;
}

void PrevDayLevels_Draw(const PrevDayLevels &v,
                          const string prefix,
                          const color c_pdh, const color c_pdl, const color c_pdm,
                          const color c_pwh, const color c_pwl,
                          const bool  show_day, const bool show_week)
{
   if(!v.valid) return;

   string base = prefix + "PD_";

   datetime t1 = v.day_start;
   datetime t2 = t1 + 7 * 24 * 3600;

   if(show_day)
   {
      BotenLevels_Segment(base + "PDH", t1, t2, v.pdh, c_pdh, 1, STYLE_SOLID);
      BotenLevels_Segment(base + "PDL", t1, t2, v.pdl, c_pdl, 1, STYLE_SOLID);
      BotenLevels_Segment(base + "PDM", t1, t2, v.pdm, c_pdm, 1, STYLE_DOT);
      BotenLabels_Text   (base + "PDH_TXT", t2, v.pdh, " PDH", c_pdh);
      BotenLabels_Text   (base + "PDL_TXT", t2, v.pdl, " PDL", c_pdl);
      BotenLabels_Text   (base + "PDM_TXT", t2, v.pdm, " PDM", c_pdm);
   }

   if(show_week)
   {
      BotenLevels_Segment(base + "PWH", t1, t2, v.pwh, c_pwh, 1, STYLE_DASH);
      BotenLevels_Segment(base + "PWL", t1, t2, v.pwl, c_pwl, 1, STYLE_DASH);
      BotenLabels_Text   (base + "PWH_TXT", t2, v.pwh, " PWH", c_pwh);
      BotenLabels_Text   (base + "PWL_TXT", t2, v.pwl, " PWL", c_pwl);
   }
}

#endif // __BOTEN_PREVDAYLEVELS_MQH__
