//+------------------------------------------------------------------+
//|                                                      Symbols.mqh |
//|              Broker-name tolerant symbol detection and tick info |
//+------------------------------------------------------------------+
#ifndef __BOTEN_SYMBOLS_MQH__
#define __BOTEN_SYMBOLS_MQH__

enum ENUM_BOTEN_INSTRUMENT
{
   BOTEN_INSTRUMENT_AUTO    = 0,
   BOTEN_INSTRUMENT_NAS100  = 1,
   BOTEN_INSTRUMENT_US30    = 2,
   BOTEN_INSTRUMENT_SPX500  = 3,
   BOTEN_INSTRUMENT_GER40   = 4,
   BOTEN_INSTRUMENT_CUSTOM  = 5
};

// Detect instrument family from broker symbol name. Brokers vary on
// suffix and prefix - we look for the index hint anywhere in the string.
ENUM_BOTEN_INSTRUMENT BotenSymbol_DetectFromName(const string sym)
{
   string s = sym;
   StringToUpper(s);

   if(StringFind(s, "NAS")    >= 0 ||
      StringFind(s, "USTEC")  >= 0 ||
      StringFind(s, "NDX")    >= 0 ||
      StringFind(s, "US100")  >= 0 ||
      StringFind(s, "TECH100")>= 0)
      return BOTEN_INSTRUMENT_NAS100;

   if(StringFind(s, "DOW")   >= 0 ||
      StringFind(s, "DJI")   >= 0 ||
      StringFind(s, "US30")  >= 0 ||
      StringFind(s, "WS30")  >= 0 ||
      StringFind(s, "DJ30")  >= 0)
      return BOTEN_INSTRUMENT_US30;

   if(StringFind(s, "SPX")   >= 0 ||
      StringFind(s, "SP500") >= 0 ||
      StringFind(s, "US500") >= 0 ||
      StringFind(s, "S&P")   >= 0)
      return BOTEN_INSTRUMENT_SPX500;

   if(StringFind(s, "DAX")    >= 0 ||
      StringFind(s, "GER40")  >= 0 ||
      StringFind(s, "DE40")   >= 0 ||
      StringFind(s, "GER30")  >= 0 ||
      StringFind(s, "DE30")   >= 0)
      return BOTEN_INSTRUMENT_GER40;

   return BOTEN_INSTRUMENT_CUSTOM;
}

string BotenSymbol_FamilyName(ENUM_BOTEN_INSTRUMENT fam)
{
   switch(fam)
   {
      case BOTEN_INSTRUMENT_NAS100: return "NAS100";
      case BOTEN_INSTRUMENT_US30:   return "US30";
      case BOTEN_INSTRUMENT_SPX500: return "SPX500";
      case BOTEN_INSTRUMENT_GER40:  return "GER40";
      case BOTEN_INSTRUMENT_CUSTOM: return "CUSTOM";
      default:                      return "AUTO";
   }
}

// Convert a "points" distance to a price distance. Index symbols usually
// have point == 1.0 (e.g. NAS100 quoted at 18000.0 with 1 digit), but
// we use SymbolInfoDouble() to stay broker-tolerant.
double BotenSymbol_PointsToPrice(const string sym, const double points)
{
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(pt <= 0.0) pt = _Point;
   return points * pt;
}

// Symbol decimal digits (used for formatting).
int BotenSymbol_Digits(const string sym)
{
   long d = 0;
   if(!SymbolInfoInteger(sym, SYMBOL_DIGITS, d))
      d = (long)_Digits;
   return (int)d;
}

#endif // __BOTEN_SYMBOLS_MQH__
