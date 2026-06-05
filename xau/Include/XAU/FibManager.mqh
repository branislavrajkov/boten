//+------------------------------------------------------------------+
//|  FibManager.mqh — Fibonacci position-sizing state machine        |
//|                                                                  |
//|  Sequence: 1,1,2,3,5,8,13,21,34,55,89                           |
//|  Loss  → advance one step (bet more next time)                   |
//|  Win   → retreat two steps (partially unwind losses)             |
//|  Each F(n) win recovers the two preceding bets: F(n-1)+F(n-2)    |
//+------------------------------------------------------------------+
#ifndef XAU_FIB_MANAGER_MQH
#define XAU_FIB_MANAGER_MQH

//--- Fibonacci table (index 0..10)
static const int FIB_SEQ[11] = { 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89 };
#define FIB_MAX_IDX 10

struct FibManager
{
   int    level;        // current position in FIB_SEQ
   int    maxLevel;     // hard cap — never go above this
   double baseLot;      // lot size for multiplier = 1

   int    cycleLosses;  // losses this cycle (for dashboard)
   int    cycleWins;    // wins this cycle
   double cycleNet;     // running P&L of the cycle in account currency
};

//--- Initialise with defaults
void FibManager_Init(FibManager &fm, double baseLot, int maxLevel)
{
   fm.level      = 0;
   fm.maxLevel   = MathMin(maxLevel, FIB_MAX_IDX);
   fm.baseLot    = baseLot;
   fm.cycleLosses = 0;
   fm.cycleWins   = 0;
   fm.cycleNet    = 0.0;
}

//--- Current lot size to trade
double FibManager_CurrentLot(const FibManager &fm)
{
   double raw = fm.baseLot * FIB_SEQ[fm.level];
   //--- normalise to broker lot step
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   raw = MathFloor(raw / step) * step;
   return MathMax(minv, MathMin(maxv, raw));
}

//--- Current Fibonacci multiplier (for display)
int FibManager_CurrentMultiplier(const FibManager &fm)
{
   return FIB_SEQ[fm.level];
}

//--- Call after a winning trade closes
void FibManager_OnWin(FibManager &fm, double profit)
{
   fm.cycleWins++;
   fm.cycleNet += profit;
   fm.level = MathMax(0, fm.level - 2);
}

//--- Call after a losing trade closes
void FibManager_OnLoss(FibManager &fm, double loss)
{
   fm.cycleLosses++;
   fm.cycleNet += loss;  // loss is negative
   int next = fm.level + 1;
   if(next > fm.maxLevel)
   {
      //--- cap reached: hold at max but do NOT keep escalating
      fm.level = fm.maxLevel;
      Print("[FibManager] WARNING: Fibonacci cap reached at level ", fm.maxLevel,
            " (x", FIB_SEQ[fm.maxLevel], "). Staying here until a win.");
   }
   else
      fm.level = next;
}

//--- True once a full profitable cycle has completed (back to level 0 after win)
bool FibManager_CycleComplete(const FibManager &fm)
{
   return (fm.level == 0 && fm.cycleWins > 0);
}

//--- Reset cycle counters (call after logging a completed cycle)
void FibManager_ResetCycle(FibManager &fm)
{
   fm.cycleLosses = 0;
   fm.cycleWins   = 0;
   fm.cycleNet    = 0.0;
}

#endif // XAU_FIB_MANAGER_MQH
