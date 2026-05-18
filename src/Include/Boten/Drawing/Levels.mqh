//+------------------------------------------------------------------+
//|                                                       Levels.mqh |
//|              Horizontal lines and trendline-segment helpers      |
//+------------------------------------------------------------------+
#ifndef __BOTEN_LEVELS_MQH__
#define __BOTEN_LEVELS_MQH__

void BotenLevels_HLine(const string name,
                        const double price,
                        const color  clr,
                        const int    width   = 1,
                        const ENUM_LINE_STYLE style = STYLE_SOLID,
                        const string label   = "")
{
   long chart = 0;
   if(ObjectFind(chart, name) < 0)
      ObjectCreate(chart, name, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble (chart, name, OBJPROP_PRICE, price);
   ObjectSetInteger(chart, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(chart, name, OBJPROP_STYLE, style);
   ObjectSetInteger(chart, name, OBJPROP_BACK,  false);
   ObjectSetInteger(chart, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chart, name, OBJPROP_HIDDEN,     true);
   if(label != "")
      ObjectSetString(chart, name, OBJPROP_TEXT, label);
}

// A horizontal segment between two times, useful for "today's PDH".
void BotenLevels_Segment(const string name,
                          const datetime t1, const datetime t2,
                          const double price,
                          const color  clr,
                          const int    width   = 1,
                          const ENUM_LINE_STYLE style = STYLE_SOLID)
{
   long chart = 0;
   if(ObjectFind(chart, name) < 0)
      ObjectCreate(chart, name, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(chart, name, OBJPROP_TIME, 0, t1);
   ObjectSetDouble (chart, name, OBJPROP_PRICE, 0, price);
   ObjectSetInteger(chart, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble (chart, name, OBJPROP_PRICE, 1, price);
   ObjectSetInteger(chart, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(chart, name, OBJPROP_STYLE, style);
   ObjectSetInteger(chart, name, OBJPROP_RAY_LEFT,  false);
   ObjectSetInteger(chart, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(chart, name, OBJPROP_BACK,       false);
   ObjectSetInteger(chart, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chart, name, OBJPROP_HIDDEN,     true);
}

// Delete every chart object whose name starts with prefix.
void BotenLevels_DeleteByPrefix(const string prefix)
{
   long chart = 0;
   int total = ObjectsTotal(chart);
   for(int i = total - 1; i >= 0; --i)
   {
      string name = ObjectName(chart, i);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(chart, name);
   }
}

#endif // __BOTEN_LEVELS_MQH__
