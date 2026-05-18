//+------------------------------------------------------------------+
//|                                                        Panel.mqh |
//|        Top-left HUD with bias score, conviction, last setup     |
//+------------------------------------------------------------------+
#ifndef __BOTEN_PANEL_MQH__
#define __BOTEN_PANEL_MQH__

#include <Boten/Bias/BiasEngine.mqh>

struct PanelState
{
   bool initialised;
};

void Panel_Init(PanelState &p)
{
   p.initialised = true;
}

// Internal helper: create or update an OBJ_LABEL at corner-anchored offset.
void Panel_Label(const string name,
                         const int x, const int y,
                         const string text,
                         const color clr,
                         const int font_size = 9,
                         const string font   = "Consolas")
{
   long chart = 0;
   if(ObjectFind(chart, name) < 0)
      ObjectCreate(chart, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(chart, name, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(chart, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(chart, name, OBJPROP_YDISTANCE, y);
   ObjectSetString (chart, name, OBJPROP_TEXT,      text);
   ObjectSetInteger(chart, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(chart, name, OBJPROP_FONTSIZE,  font_size);
   ObjectSetString (chart, name, OBJPROP_FONT,      font);
   ObjectSetInteger(chart, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chart, name, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(chart, name, OBJPROP_BACK,       false);
}

// Background rectangle for the panel area.
void Panel_Background(const string name,
                              const int x, const int y,
                              const int w, const int h,
                              const color bg)
{
   long chart = 0;
   if(ObjectFind(chart, name) < 0)
      ObjectCreate(chart, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(chart, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(chart, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(chart, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(chart, name, OBJPROP_XSIZE,      w);
   ObjectSetInteger(chart, name, OBJPROP_YSIZE,      h);
   ObjectSetInteger(chart, name, OBJPROP_BGCOLOR,    bg);
   ObjectSetInteger(chart, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(chart, name, OBJPROP_COLOR,      clrDimGray);
   ObjectSetInteger(chart, name, OBJPROP_BACK,       false);
   ObjectSetInteger(chart, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chart, name, OBJPROP_HIDDEN,     true);
}

void Panel_Draw(const PanelState &p,
                 const string prefix,
                 const BiasResult &bias,
                 const int   last_score,
                 const int   last_direction,
                 const string last_setup_id,
                 const datetime last_setup_time,
                 const color bg,
                 const color fg)
{
   string base = prefix + "PANEL_";
   const int x  = 10;
   const int y0 = 18;
   const int line_h = 14;
   const int width  = 280;
   const int rows   = 7;

   Panel_Background(base + "BG", x - 4, y0 - 4, width, rows * line_h + 8, bg);

   string dir_str = (bias.score > 0) ? "LONG"
                  : (bias.score < 0) ? "SHORT"
                                      : "NEUTRAL";
   string sym = _Symbol;

   Panel_Label(base + "L0", x, y0 + 0 * line_h,
               StringFormat("BOTEN  %s  bias %s (%+d)", sym, dir_str, bias.score), fg, 10);
   Panel_Label(base + "L1", x, y0 + 1 * line_h,
               StringFormat("Bias parts: %s", bias.breakdown), fg);
   Panel_Label(base + "L2", x, y0 + 2 * line_h,
               StringFormat("Conviction: %d", MathAbs(bias.score)), fg);

   string entry_dir = (last_direction > 0) ? "LONG"
                    : (last_direction < 0) ? "SHORT"
                                            : "-";
   Panel_Label(base + "L3", x, y0 + 3 * line_h,
               StringFormat("Confluence: %d  side: %s", last_score, entry_dir), fg);

   string last_str = (last_setup_id == "")
                       ? "(none yet)"
                       : last_setup_id;
   Panel_Label(base + "L4", x, y0 + 4 * line_h,
               StringFormat("Last setup: %s", last_str), fg);

   string when = (last_setup_time == 0)
                   ? "-"
                   : TimeToString(last_setup_time, TIME_DATE | TIME_MINUTES);
   Panel_Label(base + "L5", x, y0 + 5 * line_h,
               StringFormat("Setup time:  %s", when), fg);

   Panel_Label(base + "L6", x, y0 + 6 * line_h,
               "Tip: edit InpMinEntryScore to tune sensitivity", fg);
}

#endif // __BOTEN_PANEL_MQH__
