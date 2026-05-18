//+------------------------------------------------------------------+
//|                                                   BiasEngine.mqh |
//|     Aggregates HTF inputs into one signed daily-bias score      |
//+------------------------------------------------------------------+
#ifndef __BOTEN_BIASENGINE_MQH__
#define __BOTEN_BIASENGINE_MQH__

#include <Boten/Bias/PrevDayLevels.mqh>
#include <Boten/Bias/AsiaRange.mqh>
#include <Boten/Bias/MarketStructure.mqh>
#include <Boten/Bias/PowerOfThree.mqh>
#include <Boten/Utils/Logger.mqh>

struct BiasResult
{
   int    score;             // signed; sign = direction, magnitude = conviction
   string breakdown;         // human-readable reason string for the panel
   datetime last_update;
};

void BiasEngine_Init(BiasResult &b)
{
   b.score = 0;
   b.breakdown = "";
   b.last_update = 0;
}

void BiasEngine_Update(BiasResult &b,
                         const PrevDayLevels   &pdl,
                         const AsiaRange       &asia,
                         const MarketStructure &ms,
                         const PowerOfThree    &p3)
{
   int total = 0;
   string parts = "";

   int ms_part = MarketStructure_BiasContribution(ms);
   if(ms_part != 0)
   {
      total += ms_part;
      parts += StringFormat("MS%+d ", ms_part);
   }

   // Previous day close vs PDM.
   if(pdl.valid)
   {
      int part = (pdl.pdc > pdl.pdm) ? +1 : -1;
      total += part;
      parts += StringFormat("PDC%+d ", part);
   }

   // Asia sweep direction (Power of 3): if high swept first, expect day-low side to set.
   if(asia.finalised && asia.swept_side != 0)
   {
      // Asia high taken first (+1 swept_side) -> bearish day bias contribution = -1.
      int part = -asia.swept_side;
      total += part;
      parts += StringFormat("AS%+d ", part);
   }

   if(p3.valid)
   {
      int dpart = PowerOfThree_DailyBiasContribution(p3);
      int wpart = PowerOfThree_WeeklyBiasContribution(p3);
      total += dpart;
      total += wpart;
      parts += StringFormat("D0%+d W0%+d ", dpart, wpart);
   }

   b.score = total;
   b.breakdown = parts;
   b.last_update = TimeCurrent();
   BotenLogInfo(StringFormat("Bias updated: %+d (%s)", total, parts));
}

#endif // __BOTEN_BIASENGINE_MQH__
