//+------------------------------------------------------------------+
//|                                                        Zones.mqh |
//|                  Rectangle helpers for FVG/OB/entry zones        |
//+------------------------------------------------------------------+
#ifndef __BOTEN_ZONES_MQH__
#define __BOTEN_ZONES_MQH__

void BotenZones_Rect(const string name,
                      const datetime t1, const double p1,
                      const datetime t2, const double p2,
                      const color  clr,
                      const bool   fill  = true,
                      const int    width = 1,
                      const ENUM_LINE_STYLE style = STYLE_SOLID)
{
   long chart = 0;
   if(ObjectFind(chart, name) < 0)
      ObjectCreate(chart, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(chart, name, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (chart, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(chart, name, OBJPROP_TIME,  1, t2);
   ObjectSetDouble (chart, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(chart, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(chart, name, OBJPROP_STYLE, style);
   ObjectSetInteger(chart, name, OBJPROP_FILL,  fill);
   ObjectSetInteger(chart, name, OBJPROP_BACK,  fill);
   ObjectSetInteger(chart, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chart, name, OBJPROP_HIDDEN,     true);
}

#endif // __BOTEN_ZONES_MQH__
