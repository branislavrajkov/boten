//+------------------------------------------------------------------+
//|  GoldFib.mq5 — Gold (XAUUSD) Scalping EA with Fibonacci sizing  |
//|                                                                  |
//|  Position sizing follows the Fibonacci sequence.                 |
//|    Loss  → advance one step  (1,1,2,3,5,8,13,21,34,55…)         |
//|    Win   → retreat two steps (each win covers two prior bets)    |
//|  A full cycle completes when the level returns to 0.             |
//|                                                                  |
//|  Signal: EMA crossover confirmed by RSI + trend EMA filter.      |
//|  Guards: session window, spread cap, daily loss limit.           |
//+------------------------------------------------------------------+
#property copyright  "Boten / GoldFib"
#property version    "1.00"
#property strict

#include <XAU/FibManager.mqh>
#include <XAU/Signal.mqh>
#include <XAU/TradeManager.mqh>

//===================================================================//
//                          Inputs                                    //
//===================================================================//

//--- Fibonacci sizing
input double InpBaseLot      = 0.01;  // Base lot (multiplier = 1)
input int    InpMaxFibLevel  = 6;     // Max Fibonacci level cap (0-10). Level 6 = x13 base lot

//--- Signal (applied on InpTimeframe)
input ENUM_TIMEFRAMES InpTimeframe     = PERIOD_M5;  // Signal timeframe
input int             InpFastEMA       = 8;           // Fast EMA period
input int             InpSlowEMA       = 21;          // Slow EMA period
input int             InpTrendEMA      = 50;          // Trend EMA period (direction filter)
input int             InpRSIPeriod     = 14;          // RSI period
input int             InpRSIOverbought = 70;          // RSI: skip buy above this
input int             InpRSIOversold   = 30;          // RSI: skip sell below this

//--- Risk per trade (in symbol points)
input int  InpStopLoss      = 150;  // Stop loss in points (150 pts = ~$1.50 on 0.01 lot XAUUSD)
input int  InpTakeProfit    = 200;  // Take profit in points
input int  InpBreakevenPts  = 100;  // Move SL to breakeven after this many points profit (0 = off)
input int  InpTrailPts      = 150;  // Trailing stop distance in points (0 = off)
input int  InpTrailStepPts  = 20;   // Minimum trail move to avoid over-modifying

//--- Filters
input int    InpMaxSpread         = 40;   // Skip entry if spread exceeds this (in points)
input int    InpSessionStartHour  = 7;    // Session start hour (GMT)
input int    InpSessionEndHour    = 20;   // Session end hour (GMT)
input bool   InpFridayClose       = true; // Close all positions before weekend (Friday 20:00 GMT)
input double InpMaxDailyLoss      = 50.0; // Max daily loss in account currency (0 = disabled)

//--- EA identity
input ulong InpMagic    = 20240001;  // Magic number
input int   InpSlippage = 10;        // Max slippage in points

//===================================================================//
//                       Module state                                 //
//===================================================================//

FibManager    g_fib;
SignalState   g_sig;
TradeManager  g_tm;

datetime g_lastBar      = 0;   // last processed bar time
double   g_dailyLoss    = 0.0; // accumulated loss today
datetime g_today        = 0;   // anchor for daily loss reset
ulong    g_lastTicket   = 0;   // ticket of the most recently closed trade

//===================================================================//
//                          OnInit                                    //
//===================================================================//
int OnInit()
{
   if(_Symbol != "XAUUSD" && StringFind(_Symbol, "XAU") < 0 &&
      StringFind(_Symbol, "GOLD") < 0)
   {
      Print("[GoldFib] WARNING: EA is designed for XAUUSD. Attached symbol is ", _Symbol);
   }

   FibManager_Init(g_fib, InpBaseLot, InpMaxFibLevel);
   TradeManager_Init(g_tm, InpMagic, InpSlippage);

   if(!Signal_Init(g_sig, InpTimeframe,
                   InpFastEMA, InpSlowEMA, InpTrendEMA,
                   InpRSIPeriod, InpRSIOverbought, InpRSIOversold))
      return INIT_FAILED;

   g_lastBar   = 0;
   g_dailyLoss = 0.0;
   g_today     = iTime(_Symbol, PERIOD_D1, 0);

   PrintFormat("[GoldFib] Initialised. BaseLot=%.2f MaxFibLevel=%d (x%d) SL=%d TP=%d",
               InpBaseLot, InpMaxFibLevel, FIB_SEQ[InpMaxFibLevel], InpStopLoss, InpTakeProfit);
   return INIT_SUCCEEDED;
}

//===================================================================//
//                          OnDeinit                                  //
//===================================================================//
void OnDeinit(const int reason)
{
   Signal_Release(g_sig);
   PrintFormat("[GoldFib] Deinit. Reason=%d FibLevel=%d CycleNet=%.2f",
               reason, g_fib.level, g_fib.cycleNet);
}

//===================================================================//
//                          OnTick                                    //
//===================================================================//
void OnTick()
{
   //--- 1. Daily loss reset
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != g_today)
   {
      g_today     = today;
      g_dailyLoss = 0.0;
   }

   //--- 2. Friday close — shut everything before weekend gap
   if(InpFridayClose)
   {
      MqlDateTime dt;
      TimeToStruct(TimeGMT(), dt);
      if(dt.day_of_week == 5 && dt.hour >= 20)
      {
         if(TradeManager_HasPosition(g_tm))
         {
            Print("[GoldFib] Friday close: closing position before weekend.");
            TradeManager_CloseAll(g_tm);
         }
         return;
      }
   }

   //--- 3. Daily loss guard
   if(InpMaxDailyLoss > 0.0 && g_dailyLoss <= -InpMaxDailyLoss)
   {
      if(TradeManager_HasPosition(g_tm))
      {
         Print("[GoldFib] Daily loss limit hit. Closing position.");
         TradeManager_CloseAll(g_tm);
      }
      return;
   }

   //--- 4. Manage open position (trail / breakeven) — runs on every tick
   if(TradeManager_HasPosition(g_tm))
   {
      TradeManager_Breakeven(g_tm, InpBreakevenPts);
      TradeManager_Trail(g_tm, InpTrailPts, InpTrailStepPts);
      return;  // one position at a time; no new entry while open
   }

   //--- 5. New bar gate — only evaluate signal on confirmed bar close
   datetime barTime = iTime(_Symbol, InpTimeframe, 0);
   if(barTime == g_lastBar) return;
   g_lastBar = barTime;

   //--- 6. Session filter (GMT)
   MqlDateTime dtGMT;
   TimeToStruct(TimeGMT(), dtGMT);
   if(dtGMT.hour < InpSessionStartHour || dtGMT.hour >= InpSessionEndHour) return;

   //--- 7. Spread filter
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpread)
   {
      PrintFormat("[GoldFib] Spread %.0f > limit %d, skipping.", spread, InpMaxSpread);
      return;
   }

   //--- 8. Signal
   int signal = Signal_Get(g_sig);
   if(signal == SIGNAL_NONE) return;

   //--- 9. Execute trade with current Fibonacci lot
   double lots = FibManager_CurrentLot(g_fib);
   bool   ok   = false;

   if(signal == SIGNAL_BUY)
      ok = TradeManager_Buy(g_tm, lots, InpStopLoss, InpTakeProfit);
   else
      ok = TradeManager_Sell(g_tm, lots, InpStopLoss, InpTakeProfit);

   if(ok)
   {
      PrintFormat("[GoldFib] %s  lot=%.2f  FibLevel=%d (x%d)",
                  (signal == SIGNAL_BUY ? "BUY" : "SELL"),
                  lots, g_fib.level, FibManager_CurrentMultiplier(g_fib));
   }
   else
   {
      PrintFormat("[GoldFib] Order failed. Error=%d", GetLastError());
   }
}

//===================================================================//
//               OnTradeTransaction — detect closed trades            //
//===================================================================//
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   //--- Only care about position close events on our symbol
   if(trans.type   != TRADE_TRANSACTION_DEAL_ADD) return;
   if(trans.symbol != _Symbol)                    return;

   //--- Fetch the deal
   ulong dealTicket = trans.deal;
   if(!HistoryDealSelect(dealTicket)) return;

   ulong magic = (ulong)HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
   if(magic != InpMagic) return;

   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) return;

   double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                 + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                 + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

   if(profit >= 0.0)
   {
      FibManager_OnWin(g_fib, profit);
      PrintFormat("[GoldFib] WIN  profit=%.2f  → FibLevel now %d (x%d)  CycleNet=%.2f",
                  profit, g_fib.level, FibManager_CurrentMultiplier(g_fib), g_fib.cycleNet);
   }
   else
   {
      g_dailyLoss += profit;  // profit is negative on a loss
      FibManager_OnLoss(g_fib, profit);
      PrintFormat("[GoldFib] LOSS profit=%.2f  → FibLevel now %d (x%d)  CycleNet=%.2f  DailyLoss=%.2f",
                  profit, g_fib.level, FibManager_CurrentMultiplier(g_fib), g_fib.cycleNet, g_dailyLoss);
   }

   //--- Check if a cycle completed (back to level 0 after wins)
   if(FibManager_CycleComplete(g_fib))
   {
      PrintFormat("[GoldFib] === CYCLE COMPLETE === Net=%.2f Wins=%d Losses=%d. Resetting.",
                  g_fib.cycleNet, g_fib.cycleWins, g_fib.cycleLosses);
      FibManager_ResetCycle(g_fib);
   }
}
