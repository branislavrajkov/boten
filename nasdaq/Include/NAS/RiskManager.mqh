//+------------------------------------------------------------------+
//|  RiskManager.mqh — Linear risk scaling per consecutive loss     |
//|                                                                  |
//|  Risk starts at basePct, adds stepPct each loss, resets on win. |
//|  Persisted across EA reloads via MT5 GlobalVariables.           |
//+------------------------------------------------------------------+
#ifndef NAS_RISK_MANAGER_MQH
#define NAS_RISK_MANAGER_MQH

struct RiskManager
{
   double basePct;     // risk % after a win (reset target)
   double stepPct;     // added per consecutive loss
   double maxPct;      // hard cap
   double currentPct;  // active risk % for the next trade
   int    lossStreak;  // consecutive losses since last win
};

void RiskManager_Init(RiskManager &rm, double base, double step, double cap)
{
   rm.basePct    = base;
   rm.stepPct    = step;
   rm.maxPct     = cap;
   rm.currentPct = base;
   rm.lossStreak = 0;
}

void RiskManager_OnWin(RiskManager &rm)
{
   rm.lossStreak = 0;
   rm.currentPct = rm.basePct;
}

void RiskManager_OnLoss(RiskManager &rm)
{
   rm.lossStreak++;
   rm.currentPct = MathMin(rm.basePct + rm.lossStreak * rm.stepPct, rm.maxPct);
}

//--- slDist: stop-loss distance in price units (same units as the chart price).
//    e.g. 25.0 on NAS100 quoted at 19000.0 means a $25 stop distance per point-unit.
double RiskManager_Lots(const RiskManager &rm, double slDist)
{
   if(slDist <= 0.0) return 0.0;

   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * rm.currentPct / 100.0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0 || tickValue <= 0.0) return 0.0;

   double slTicks  = slDist / tickSize;
   double slPerLot = slTicks * tickValue;
   if(slPerLot <= 0.0) return 0.0;

   double lots    = riskMoney / slPerLot;
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots / stepLot) * stepLot;
   return MathMax(minLot, MathMin(maxLot, lots));
}

#endif // NAS_RISK_MANAGER_MQH
