//+------------------------------------------------------------------+
//|                                                 PowerOfThree.mqh |
//|     Daily/weekly open vs current price (ICT P03 framing)        |
//+------------------------------------------------------------------+
#ifndef __BOTEN_PO3_MQH__
#define __BOTEN_PO3_MQH__

#include <Boten/Utils/Logger.mqh>

struct PowerOfThree
{
   double   daily_open;
   double   weekly_open;
   double   current_price;
   bool     above_daily_open;
   bool     above_weekly_open;
   bool     valid;
};

void PowerOfThree_Init(PowerOfThree &p)
{
   p.daily_open = 0.0;
   p.weekly_open = 0.0;
   p.current_price = 0.0;
   p.above_daily_open = false;
   p.above_weekly_open = false;
   p.valid = false;
}

void PowerOfThree_Update(PowerOfThree &p,
                          const string symbol_unused,
                          const datetime broker_now)
{
   p.daily_open  = iOpen(_Symbol, PERIOD_D1, 0);
   p.weekly_open = iOpen(_Symbol, PERIOD_W1, 0);
   p.current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(p.daily_open <= 0.0 || p.weekly_open <= 0.0)
   {
      p.valid = false;
      return;
   }
   p.above_daily_open  = (p.current_price > p.daily_open);
   p.above_weekly_open = (p.current_price > p.weekly_open);
   p.valid = true;
}

// Bias contributions: +1 above daily open, -1 below; same for weekly.
int PowerOfThree_DailyBiasContribution(const PowerOfThree &p)
{
   if(!p.valid) return 0;
   return p.above_daily_open ? +1 : -1;
}

int PowerOfThree_WeeklyBiasContribution(const PowerOfThree &p)
{
   if(!p.valid) return 0;
   return p.above_weekly_open ? +1 : -1;
}

#endif // __BOTEN_PO3_MQH__
