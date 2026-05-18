//+------------------------------------------------------------------+
//|                                                       Labels.mqh |
//|         Anchored chart labels (text + arrow) helpers              |
//+------------------------------------------------------------------+
#ifndef __BOTEN_LABELS_MQH__
#define __BOTEN_LABELS_MQH__

void BotenLabels_Text(const string name,
                       const datetime t,
                       const double   price,
                       const string   text,
                       const color    clr,
                       const int      font_size = 9,
                       const string   font      = "Consolas")
{
   long chart = 0;
   if(ObjectFind(chart, name) < 0)
      ObjectCreate(chart, name, OBJ_TEXT, 0, t, price);
   ObjectSetInteger(chart, name, OBJPROP_TIME,  0, t);
   ObjectSetDouble (chart, name, OBJPROP_PRICE, 0, price);
   ObjectSetString (chart, name, OBJPROP_TEXT,  text);
   ObjectSetInteger(chart, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetString (chart, name, OBJPROP_FONT,  font);
   ObjectSetInteger(chart, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(chart, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chart, name, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(chart, name, OBJPROP_BACK,       false);
}

void BotenLabels_Arrow(const string name,
                       const datetime t,
                       const double   price,
                       const int      arrow_code,
                       const color    clr,
                       const int      width = 2)
{
   long chart = 0;
   if(ObjectFind(chart, name) < 0)
      ObjectCreate(chart, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(chart, name, OBJPROP_TIME,  0, t);
   ObjectSetDouble (chart, name, OBJPROP_PRICE, 0, price);
   ObjectSetInteger(chart, name, OBJPROP_ARROWCODE, arrow_code);
   ObjectSetInteger(chart, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(chart, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chart, name, OBJPROP_HIDDEN,     true);
}

#endif // __BOTEN_LABELS_MQH__
