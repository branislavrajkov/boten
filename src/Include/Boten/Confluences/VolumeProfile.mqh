//+------------------------------------------------------------------+
//|                                                VolumeProfile.mqh |
//|     Prior-day POC/VAH/VAL from M5 tick volume + spike detection  |
//+------------------------------------------------------------------+
#ifndef __BOTEN_VOLPROFILE_MQH__
#define __BOTEN_VOLPROFILE_MQH__

#include <Boten/Drawing/Levels.mqh>
#include <Boten/Drawing/Labels.mqh>
#include <Boten/Utils/Logger.mqh>

#define BOTEN_VP_BINS 50

struct VolumeProfile
{
   double   poc;
   double   vah;
   double   val;
   double   day_high;
   double   day_low;
   datetime day_start;        // start of the day we profiled
   datetime day_end;
   bool     valid;
};

void VolumeProfile_Init(VolumeProfile &v)
{
   v.poc = 0.0; v.vah = 0.0; v.val = 0.0;
   v.day_high = 0.0; v.day_low = 0.0;
   v.day_start = 0; v.day_end = 0;
   v.valid = false;
}

// Build a histogram from M5 bars of the previous D1 bar. POC = highest-volume
// bin; VAH/VAL = boundaries of the top 70% of volume around the POC.
void VolumeProfile_Update(VolumeProfile &v, const string symbol)
{
   datetime ystart = iTime(symbol, PERIOD_D1, 1);
   datetime today  = iTime(symbol, PERIOD_D1, 0);
   if(ystart == 0 || today == 0)
   {
      v.valid = false;
      return;
   }
   double y_high = iHigh(symbol, PERIOD_D1, 1);
   double y_low  = iLow (symbol, PERIOD_D1, 1);
   if(y_high <= y_low) { v.valid = false; return; }

   v.day_start = ystart;
   v.day_end   = today;
   v.day_high  = y_high;
   v.day_low   = y_low;

   double bin_size = (y_high - y_low) / BOTEN_VP_BINS;
   double bins[BOTEN_VP_BINS];
   for(int i = 0; i < BOTEN_VP_BINS; ++i) bins[i] = 0.0;

   for(int i = 0; i < 600; ++i)
   {
      datetime bt = iTime(symbol, PERIOD_M5, i);
      if(bt == 0) break;
      if(bt < ystart) break;
      if(bt >= today) continue;
      double tp = (iHigh(symbol, PERIOD_M5, i) +
                    iLow (symbol, PERIOD_M5, i) +
                    iClose(symbol, PERIOD_M5, i)) / 3.0;
      long   tv = iTickVolume(symbol, PERIOD_M5, i);
      int idx = (int)MathFloor((tp - y_low) / bin_size);
      if(idx < 0) idx = 0;
      if(idx >= BOTEN_VP_BINS) idx = BOTEN_VP_BINS - 1;
      bins[idx] += (double)tv;
   }

   int    poc_i = 0;
   double poc_v = bins[0];
   double total = 0.0;
   for(int i = 0; i < BOTEN_VP_BINS; ++i)
   {
      total += bins[i];
      if(bins[i] > poc_v) { poc_v = bins[i]; poc_i = i; }
   }
   if(total <= 0.0) { v.valid = false; return; }

   double target = total * 0.70;
   double accum  = bins[poc_i];
   int lo = poc_i, hi = poc_i;
   while(accum < target && (lo > 0 || hi < BOTEN_VP_BINS - 1))
   {
      double up_v = (hi < BOTEN_VP_BINS - 1) ? bins[hi + 1] : -1.0;
      double dn_v = (lo > 0)                 ? bins[lo - 1] : -1.0;
      if(up_v >= dn_v && hi < BOTEN_VP_BINS - 1)
      {
         hi++;
         accum += up_v;
      }
      else if(lo > 0)
      {
         lo--;
         accum += dn_v;
      }
      else break;
   }
   v.poc = y_low + (poc_i + 0.5) * bin_size;
   v.vah = y_low + (hi    + 1.0) * bin_size;
   v.val = y_low + (lo)            * bin_size;
   v.valid = true;
   BotenLogDebug(StringFormat(
      "VP updated: POC=%.2f VAH=%.2f VAL=%.2f", v.poc, v.vah, v.val));
}

void VolumeProfile_Draw(const VolumeProfile &v,
                          const string prefix,
                          const color c_poc, const color c_va)
{
   if(!v.valid) return;
   string base = prefix + "VP_";
   datetime t1 = v.day_end;
   datetime t2 = t1 + 24 * 3600;
   BotenLevels_Segment(base + "POC", t1, t2, v.poc, c_poc, 2, STYLE_SOLID);
   BotenLevels_Segment(base + "VAH", t1, t2, v.vah, c_va,  1, STYLE_DOT);
   BotenLevels_Segment(base + "VAL", t1, t2, v.val, c_va,  1, STYLE_DOT);
   BotenLabels_Text   (base + "POC_T", t2, v.poc, " POC", c_poc);
   BotenLabels_Text   (base + "VAH_T", t2, v.vah, " VAH", c_va);
   BotenLabels_Text   (base + "VAL_T", t2, v.val, " VAL", c_va);
}

// True if the most recently closed bar's tick volume is >= 1.5x the
// trailing 20-bar average.
bool VolumeProfile_VolumeSpikeOnLastBar(const string symbol,
                                           const ENUM_TIMEFRAMES tf)
{
   long last = iTickVolume(symbol, tf, 1);
   if(last <= 0) return false;
   double sum = 0.0;
   int n = 20;
   for(int i = 2; i <= 1 + n; ++i)
   {
      long t = iTickVolume(symbol, tf, i);
      if(t <= 0) return false;
      sum += (double)t;
   }
   double avg = sum / n;
   if(avg <= 0.0) return false;
   return ((double)last >= 1.5 * avg);
}

#endif // __BOTEN_VOLPROFILE_MQH__
