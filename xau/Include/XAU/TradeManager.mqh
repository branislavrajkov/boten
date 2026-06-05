//+------------------------------------------------------------------+
//|  TradeManager.mqh — Order open / trail / close helpers          |
//+------------------------------------------------------------------+
#ifndef XAU_TRADE_MANAGER_MQH
#define XAU_TRADE_MANAGER_MQH

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

struct TradeManager
{
   CTrade        trade;
   CPositionInfo pos;
   ulong         magic;
   int           slippage;   // in points
};

void TradeManager_Init(TradeManager &tm, ulong magic, int slippage)
{
   tm.magic    = magic;
   tm.slippage = slippage;
   tm.trade.SetExpertMagicNumber(magic);
   tm.trade.SetDeviationInPoints(slippage);
   tm.trade.SetTypeFilling(ORDER_FILLING_FOK);
}

//--- Returns true if we currently hold a position for this EA
bool TradeManager_HasPosition(TradeManager &tm)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(tm.pos.SelectByIndex(i) &&
         tm.pos.Symbol() == _Symbol &&
         tm.pos.Magic()  == tm.magic)
         return true;
   }
   return false;
}

//--- Ticket of current open position, 0 if none
ulong TradeManager_PositionTicket(TradeManager &tm)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(tm.pos.SelectByIndex(i) &&
         tm.pos.Symbol() == _Symbol &&
         tm.pos.Magic()  == tm.magic)
         return tm.pos.Ticket();
   }
   return 0;
}

//--- Open a BUY position
bool TradeManager_Buy(TradeManager &tm, double lots, int slPts, int tpPts)
{
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double sl    = (slPts > 0) ? ask - slPts * point : 0;
   double tp    = (tpPts > 0) ? ask + tpPts * point : 0;
   return tm.trade.Buy(lots, _Symbol, ask, sl, tp, "GoldFib");
}

//--- Open a SELL position
bool TradeManager_Sell(TradeManager &tm, double lots, int slPts, int tpPts)
{
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double sl    = (slPts > 0) ? bid + slPts * point : 0;
   double tp    = (tpPts > 0) ? bid - tpPts * point : 0;
   return tm.trade.Sell(lots, _Symbol, bid, sl, tp, "GoldFib");
}

//--- Close the current EA position
bool TradeManager_CloseAll(TradeManager &tm)
{
   bool ok = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(tm.pos.SelectByIndex(i) &&
         tm.pos.Symbol() == _Symbol &&
         tm.pos.Magic()  == tm.magic)
      {
         if(!tm.trade.PositionClose(tm.pos.Ticket()))
            ok = false;
      }
   }
   return ok;
}

//--- Move SL to breakeven once unrealised profit >= bePts points
void TradeManager_Breakeven(TradeManager &tm, int bePts)
{
   if(bePts <= 0) return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double beThreshold = bePts * point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!tm.pos.SelectByIndex(i)) continue;
      if(tm.pos.Symbol() != _Symbol || tm.pos.Magic() != tm.magic) continue;

      double open = tm.pos.PriceOpen();
      double sl   = tm.pos.StopLoss();
      double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(tm.pos.PositionType() == POSITION_TYPE_BUY)
      {
         if((bid - open) >= beThreshold && sl < open)
            tm.trade.PositionModify(tm.pos.Ticket(), open, tm.pos.TakeProfit());
      }
      else
      {
         if((open - ask) >= beThreshold && (sl > open || sl == 0))
            tm.trade.PositionModify(tm.pos.Ticket(), open, tm.pos.TakeProfit());
      }
   }
}

//--- Trail stop by trailPts once in profit
void TradeManager_Trail(TradeManager &tm, int trailPts, int trailStepPts)
{
   if(trailPts <= 0) return;
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double trail    = trailPts     * point;
   double step     = trailStepPts * point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!tm.pos.SelectByIndex(i)) continue;
      if(tm.pos.Symbol() != _Symbol || tm.pos.Magic() != tm.magic) continue;

      double sl  = tm.pos.StopLoss();
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(tm.pos.PositionType() == POSITION_TYPE_BUY)
      {
         double newSl = bid - trail;
         if(newSl > sl + step)
            tm.trade.PositionModify(tm.pos.Ticket(), newSl, tm.pos.TakeProfit());
      }
      else
      {
         double newSl = ask + trail;
         if(sl == 0 || newSl < sl - step)
            tm.trade.PositionModify(tm.pos.Ticket(), newSl, tm.pos.TakeProfit());
      }
   }
}

#endif // XAU_TRADE_MANAGER_MQH
