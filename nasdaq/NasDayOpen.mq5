//+------------------------------------------------------------------+
//|  NasDayOpen.mq5 — NAS100 Day-Open Mean-Reversion EA            |
//|                                                                  |
//|  Strategy summary:                                              |
//|   1. Mark the daily open price (D1 bar open).                  |
//|   2. Wait for price to extend >= InpExtension away from open.  |
//|   3. Once extended, wait for price to return toward open.       |
//|   4. Enter counter-trend at InpEntryOffset from open:          |
//|        Up-extension  → SELL at open + EntryOffset              |
//|        Down-extension → BUY  at open - EntryOffset             |
//|   5. TP = daily open.  SL = InpStopLoss from entry.            |
//|   6. All levels are in PRICE UNITS (same scale as chart price). |
//|      e.g. 90.0 means $90 on NAS100 quoted around 19000.        |
//|   7. Risk scales: +InpRiskStep% per loss, resets on win.       |
//|   8. One trade per day, during first InpWindowHours hours.     |
//|                                                                  |
//|  Spread note (NAS100 typical spread 1-3 price units):           |
//|   - SL loss is exact: SL is set InpStopLoss above/below entry. |
//|   - TP profit ≈ InpEntryOffset − spread (e.g. 38 − 2 = 36).   |
//|   - Set InpMaxSpreadPrice ≤ 3.0 to skip wide-spread entries.   |
//|   - Raising InpEntryOffset by 1-2 fully compensates for spread.|
//+------------------------------------------------------------------+
#property copyright  "Boten / NasDayOpen"
#property version    "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <NAS/RiskManager.mqh>

//===================================================================//
//                           Inputs                                  //
//===================================================================//

//--- Strategy levels — ALL in price units (same as chart price)
input double InpExtension       = 90.0;  // Distance from daily open that arms the trade
input double InpEntryOffset     = 38.0;  // Entry level: open ± this value on return
input double InpStopLoss        = 25.0;  // SL distance from entry price

//--- Trading window
// Window starts the moment the D1 bar opens (daily reopen = midnight Belgrade time
// on most NAS100 brokers). No timezone configuration needed.
input int    InpWindowHours     = 3;     // How many hours after D1 open to allow entries

//--- Risk scaling
input double InpBaseRisk        = 1.0;   // Starting risk per trade (%)
input double InpRiskStep        = 1.0;   // Risk added per consecutive loss (%)
input double InpMaxRisk         = 10.0;  // Risk cap (%)

//--- Filters
input double InpMaxSpreadPrice  = 3.0;   // Max allowed spread in price units (0 = off)

//--- EA identity
input ulong  InpMagic           = 20250001;
input int    InpSlippage        = 20;    // Slippage in MT5 points

//===================================================================//
//                       State machine                               //
//===================================================================//

enum EState
{
   STATE_SEEK,      // waiting for extension
   STATE_ARMED,     // extended — waiting for return to entry level
   STATE_IN_TRADE,  // position open
   STATE_DONE       // done for today
};

EState        g_state       = STATE_SEEK;
int           g_direction   = 0;     // +1 = armed for short, -1 = armed for long
double        g_dailyOpen   = 0.0;
datetime      g_today       = 0;
datetime      g_windowClose = 0;

RiskManager   g_risk;
CTrade        g_trade;
CPositionInfo g_pos;

//===================================================================//
//                         Helpers                                   //
//===================================================================//

bool IsInWindow()   { return (TimeCurrent() < g_windowClose); }

bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(g_pos.SelectByIndex(i) && g_pos.Symbol() == _Symbol && g_pos.Magic() == InpMagic)
         return true;
   return false;
}

bool SpreadOk()
{
   if(InpMaxSpreadPrice <= 0.0) return true;
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)
                   * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return spread <= InpMaxSpreadPrice;
}

double Norm(double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

void ResetDay()
{
   g_dailyOpen = iOpen(_Symbol, PERIOD_D1, 0);
   g_state     = STATE_SEEK;
   g_direction = 0;

   // Anchor window to the D1 bar open time — that is the daily reopen,
   // no timezone math needed regardless of broker server clock.
   datetime wStart = iTime(_Symbol, PERIOD_D1, 0);
   g_windowClose   = wStart + InpWindowHours * 3600;

   PrintFormat("[NasDayOpen] New day. Open=%.2f  Window: %s → %s  Risk=%.1f%% (streak=%d)",
               g_dailyOpen,
               TimeToString(wStart,         TIME_MINUTES),
               TimeToString(g_windowClose,  TIME_MINUTES),
               g_risk.currentPct, g_risk.lossStreak);
}

//===================================================================//
//                           OnInit                                  //
//===================================================================//
int OnInit()
{
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(InpSlippage);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);

   RiskManager_Init(g_risk, InpBaseRisk, InpRiskStep, InpMaxRisk);

   // Restore risk state that survived an EA reload or platform restart
   double savedStreak = GlobalVariableGet("NAS_DOB_Streak");
   double savedRisk   = GlobalVariableGet("NAS_DOB_Risk");
   if(savedRisk >= InpBaseRisk)
   {
      g_risk.lossStreak = (int)savedStreak;
      g_risk.currentPct = MathMin(savedRisk, InpMaxRisk);
   }

   g_today = iTime(_Symbol, PERIOD_D1, 0);
   ResetDay();

   PrintFormat("[NasDayOpen] Init. Extension=%.1f Entry=%.1f SL=%.1f  MaxSpread=%.1f",
               InpExtension, InpEntryOffset, InpStopLoss, InpMaxSpreadPrice);
   return INIT_SUCCEEDED;
}

//===================================================================//
//                           OnDeinit                                //
//===================================================================//
void OnDeinit(const int reason)
{
   GlobalVariableSet("NAS_DOB_Streak", g_risk.lossStreak);
   GlobalVariableSet("NAS_DOB_Risk",   g_risk.currentPct);
}

//===================================================================//
//                           OnTick                                  //
//===================================================================//
void OnTick()
{
   //--- Daily reset
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != g_today)
   {
      g_today = today;
      ResetDay();
   }

   //--- Manage open trade — TP/SL handle the close; just detect if it's gone
   if(g_state == STATE_IN_TRADE)
   {
      if(!HasPosition()) g_state = STATE_DONE;  // safety fallback; OnTradeTransaction is primary
      return;
   }

   if(g_state == STATE_DONE) return;

   //--- Window expired
   if(!IsInWindow())
   {
      Print("[NasDayOpen] Window closed — done for today.");
      g_state = STATE_DONE;
      return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   //--- Look for extension
   if(g_state == STATE_SEEK)
   {
      if(bid >= g_dailyOpen + InpExtension)
      {
         g_direction = 1;
         g_state     = STATE_ARMED;
         PrintFormat("[NasDayOpen] ARMED SHORT — BID %.2f extended +%.1f from open %.2f",
                     bid, InpExtension, g_dailyOpen);
      }
      else if(bid <= g_dailyOpen - InpExtension)
      {
         g_direction = -1;
         g_state     = STATE_ARMED;
         PrintFormat("[NasDayOpen] ARMED LONG  — BID %.2f extended -%.1f from open %.2f",
                     bid, InpExtension, g_dailyOpen);
      }
      return;
   }

   //--- Wait for return and trigger entry
   if(g_state == STATE_ARMED)
   {
      // Safety: if price has blown through the entry level and is now beyond daily open,
      // the entry was either taken or missed — either way we're done.
      if(g_direction ==  1 && bid <= g_dailyOpen)
      {
         Print("[NasDayOpen] SHORT setup: price fell through open without triggering. Done.");
         g_state = STATE_DONE;
         return;
      }
      if(g_direction == -1 && bid >= g_dailyOpen)
      {
         Print("[NasDayOpen] LONG setup: price rose through open without triggering. Done.");
         g_state = STATE_DONE;
         return;
      }

      bool trigger = (g_direction ==  1 && bid <= g_dailyOpen + InpEntryOffset) ||
                     (g_direction == -1 && bid >= g_dailyOpen - InpEntryOffset);
      if(!trigger) return;

      if(!SpreadOk())
      {
         double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)
                         * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         PrintFormat("[NasDayOpen] Spread %.2f > limit %.2f, skipping.", spread, InpMaxSpreadPrice);
         return;
      }

      double lots = RiskManager_Lots(g_risk, InpStopLoss);
      if(lots <= 0.0)
      {
         Print("[NasDayOpen] Lot calculation failed — aborting.");
         g_state = STATE_DONE;
         return;
      }

      bool ok = false;
      if(g_direction == 1)  // SHORT: entered at bid, SL above, TP at daily open
      {
         double sl = Norm(bid + InpStopLoss);
         double tp = Norm(g_dailyOpen);
         ok = g_trade.Sell(lots, _Symbol, bid, sl, tp, "NasDayOpen");
         PrintFormat("[NasDayOpen] SELL lots=%.2f  bid=%.2f  SL=%.2f  TP=%.2f  Risk=%.1f%%",
                     lots, bid, sl, tp, g_risk.currentPct);
      }
      else                   // LONG: entered at ask, SL below, TP at daily open
      {
         double sl = Norm(ask - InpStopLoss);
         double tp = Norm(g_dailyOpen);
         ok = g_trade.Buy(lots, _Symbol, ask, sl, tp, "NasDayOpen");
         PrintFormat("[NasDayOpen] BUY  lots=%.2f  ask=%.2f  SL=%.2f  TP=%.2f  Risk=%.1f%%",
                     lots, ask, sl, tp, g_risk.currentPct);
      }

      if(ok)
         g_state = STATE_IN_TRADE;
      else
      {
         PrintFormat("[NasDayOpen] Order failed. Error=%d  Retry next tick.", GetLastError());
         // leave state ARMED so it retries on the next tick
      }
   }
}

//===================================================================//
//           OnTradeTransaction — classify win/loss on close         //
//===================================================================//
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type   != TRADE_TRANSACTION_DEAL_ADD) return;
   if(trans.symbol != _Symbol)                    return;
   if(!HistoryDealSelect(trans.deal))             return;
   if((ulong)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic) return;

   ENUM_DEAL_ENTRY de = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(de != DEAL_ENTRY_OUT && de != DEAL_ENTRY_INOUT) return;

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   if(profit >= 0.0)
   {
      RiskManager_OnWin(g_risk);
      PrintFormat("[NasDayOpen] WIN  profit=%.2f → Risk reset to %.1f%%",
                  profit, g_risk.currentPct);
   }
   else
   {
      RiskManager_OnLoss(g_risk);
      PrintFormat("[NasDayOpen] LOSS profit=%.2f → Risk now %.1f%% (streak=%d)",
                  profit, g_risk.currentPct, g_risk.lossStreak);
   }

   GlobalVariableSet("NAS_DOB_Streak", g_risk.lossStreak);
   GlobalVariableSet("NAS_DOB_Risk",   g_risk.currentPct);

   g_state = STATE_DONE;
}
