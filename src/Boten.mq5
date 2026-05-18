//+------------------------------------------------------------------+
//|                                                         Boten.mq5 |
//|        Indices Bias and Confluence Indicator (MT5, MQL5)         |
//+------------------------------------------------------------------+
//| Computes a daily bias score from HTF context (PDH/PDL, Asia,     |
//| H4 structure, weekly profile) and overlays an entry-confluence   |
//| engine (FVG, OB, sweeps, ORB, killzones, VWAP, volume) to        |
//| highlight the next high-probability entry zone with alerts.      |
//|                                                                  |
//| Install:                                                         |
//|   - Boten.mq5      -> MQL5/Indicators/Boten.mq5                  |
//|   - Include/Boten/ -> MQL5/Include/Boten/                        |
//| Then compile in MetaEditor and attach to a chart.                |
//+------------------------------------------------------------------+
#property copyright "Boten"
#property link      ""
#property version   "0.1"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Boten/Utils/Logger.mqh>
#include <Boten/Utils/Symbols.mqh>
#include <Boten/Utils/Sessions.mqh>
#include <Boten/Utils/Alerts.mqh>
#include <Boten/Config.mqh>

#include <Boten/Drawing/Levels.mqh>
#include <Boten/Drawing/Zones.mqh>
#include <Boten/Drawing/Labels.mqh>
#include <Boten/Drawing/Panel.mqh>

#include <Boten/Bias/PrevDayLevels.mqh>
#include <Boten/Bias/AsiaRange.mqh>
#include <Boten/Bias/MarketStructure.mqh>
#include <Boten/Bias/PowerOfThree.mqh>
#include <Boten/Bias/BiasEngine.mqh>

#include <Boten/Confluences/Killzones.mqh>
#include <Boten/Confluences/ORB.mqh>
#include <Boten/Confluences/FVG.mqh>
#include <Boten/Confluences/OrderBlock.mqh>
#include <Boten/Confluences/LiquiditySweep.mqh>
#include <Boten/Confluences/VWAP.mqh>
#include <Boten/Confluences/VolumeProfile.mqh>
#include <Boten/Confluences/MidnightOpen.mqh>

//===================================================================//
//                     Module state (single instances)                //
//===================================================================//
PrevDayLevels   g_pdl;
AsiaRange       g_asia;
MarketStructure g_struct;
PowerOfThree    g_pof3;
BiasResult      g_bias;

ORBState        g_orb_london;
ORBState        g_orb_ny;
FVGState        g_fvg;
OrderBlockState g_ob;
SweepState      g_sweep;
VWAPState       g_vwap;
VolumeProfile   g_vp;
MidnightOpen    g_mn_open;
PanelState      g_panel;

// Latest setup snapshot (for dedup of alerts and panel display).
string  g_last_setup_id   = "";
int     g_last_score      = 0;
int     g_last_direction  = 0;
double  g_last_entry_low  = 0.0;
double  g_last_entry_high = 0.0;
double  g_last_stop       = 0.0;
double  g_last_target     = 0.0;
datetime g_last_setup_time = 0;

// Cached bar tracking so we only do work on new bars / new HTF bars.
datetime g_last_ltf_bar = 0;
datetime g_last_htf_bar = 0;
datetime g_last_day     = 0;

#define BOTEN_OBJ_PREFIX "BOT_"

//===================================================================//
//                              OnInit                                //
//===================================================================//
int OnInit()
{
   BotenLogSetLevel(InpLogLevel);
   BotenSessions_Configure(InpAutoDST, InpBrokerOffsetWinter, InpBrokerOffsetSummer);
   BotenAlerts_Configure(InpAlertPopup, InpAlertPush, InpAlertEmail, InpAlertCooldownSeconds);
   BotenAlerts_Reset();

   BotenConfig_Resolve();

   PrevDayLevels_Init(g_pdl);
   AsiaRange_Init(g_asia);
   MarketStructure_Init(g_struct);
   PowerOfThree_Init(g_pof3);
   BiasEngine_Init(g_bias);

   ORB_Init(g_orb_london, "LON");
   ORB_Init(g_orb_ny,     "NY");
   FVG_Init(g_fvg);
   OrderBlock_Init(g_ob);
   Sweep_Init(g_sweep);
   VWAP_Init(g_vwap);
   VolumeProfile_Init(g_vp);
   MidnightOpen_Init(g_mn_open);
   Panel_Init(g_panel);

   BotenLogInfo("Boten initialised. Attached to " + _Symbol);
   return INIT_SUCCEEDED;
}

//===================================================================//
//                            OnDeinit                                //
//===================================================================//
void OnDeinit(const int reason)
{
   // Clean up every chart object we may have created.
   BotenLevels_DeleteByPrefix(BOTEN_OBJ_PREFIX);
   ChartRedraw(0);
   BotenLogInfo(StringFormat("Boten deinit (reason=%d).", reason));
}

//===================================================================//
//                            OnCalculate                             //
//===================================================================//
int OnCalculate(const int        rates_total,
                const int        prev_calculated,
                const datetime  &time[],
                const double    &open[],
                const double    &high[],
                const double    &low[],
                const double    &close[],
                const long      &tick_volume[],
                const long      &volume[],
                const int       &spread[])
{
   if(rates_total < 50) return rates_total;

   datetime now = TimeCurrent();

   // Daily refresh (NY-midnight aligned).
   datetime today_anchor = BotenSessions_NYMidnightOfBroker(now);
   bool new_day = (today_anchor != g_last_day);
   if(new_day)
   {
      g_last_day = today_anchor;
      PrevDayLevels_Update(g_pdl, _Symbol);
      AsiaRange_OnNewDay(g_asia, now);
      VolumeProfile_Update(g_vp, _Symbol);
      MidnightOpen_Update(g_mn_open, _Symbol, now);
      Sweep_OnNewDay(g_sweep);

      if(InpShowPDLevels || InpShowPWLevels)
         PrevDayLevels_Draw(g_pdl, BOTEN_OBJ_PREFIX,
                            InpColorPDH, InpColorPDL, InpColorPDM,
                            InpColorPWH, InpColorPWL,
                            InpShowPDLevels, InpShowPWLevels);
      if(InpShowVolumeProfile)
         VolumeProfile_Draw(g_vp, BOTEN_OBJ_PREFIX, InpColorVPPOC, InpColorVPVA);
      if(InpShowMidnightOpen)
         MidnightOpen_Draw(g_mn_open, BOTEN_OBJ_PREFIX, InpColorMidnight);
   }

   // Asia range tracking and sweep markers run on every tick, but they
   // short-circuit cheaply when outside the relevant time window.
   AsiaRange_Update(g_asia, _Symbol, now,
                     InpAsiaStartHourGMT, InpAsiaStartMinGMT,
                     InpAsiaEndHourGMT,   InpAsiaEndMinGMT);
   if(InpShowAsiaRange)
      AsiaRange_Draw(g_asia, BOTEN_OBJ_PREFIX, InpColorAsia);

   if(InpShowKillzones)
      Killzones_Draw(BOTEN_OBJ_PREFIX, now,
                      InpKZLondonEnabled, InpKZLondonStartH, InpKZLondonStartM,
                                          InpKZLondonEndH,   InpKZLondonEndM,
                                          InpColorKZLondon,
                      InpKZNYAMEnabled,  InpKZNYAMStartH,   InpKZNYAMStartM,
                                          InpKZNYAMEndH,    InpKZNYAMEndM,
                                          InpColorKZNYAM,
                      InpKZNYPMEnabled,  InpKZNYPMStartH,   InpKZNYPMStartM,
                                          InpKZNYPMEndH,    InpKZNYPMEndM,
                                          InpColorKZNYPM);

   ORB_Update(g_orb_london, _Symbol, now,
               InpKZLondonStartH, InpKZLondonStartM,
               InpLondonORBMinutes);
   ORB_Update(g_orb_ny, _Symbol, now,
               InpKZNYAMStartH, InpKZNYAMStartM,
               InpNYORBMinutes);
   if(InpShowORB)
   {
      ORB_Draw(g_orb_london, BOTEN_OBJ_PREFIX, InpColorORB);
      ORB_Draw(g_orb_ny,     BOTEN_OBJ_PREFIX, InpColorORB);
   }

   // VWAP updates on every tick (cumulative); volume-profile/midnight done above.
   VWAP_Update(g_vwap, _Symbol, now);
   if(InpShowVWAP)
      VWAP_Draw(g_vwap, BOTEN_OBJ_PREFIX, InpColorVWAP);

   // New-bar work on the LTF (FVG/OB/sweep + decision layer).
   datetime ltf_bar = iTime(_Symbol, InpLTFTimeframe, 0);
   bool new_ltf = (ltf_bar != g_last_ltf_bar);
   if(new_ltf)
   {
      g_last_ltf_bar = ltf_bar;

      FVG_Update(g_fvg, _Symbol, InpLTFTimeframe);
      if(InpShowFVG)
         FVG_Draw(g_fvg, BOTEN_OBJ_PREFIX, InpColorFVGBull, InpColorFVGBear);

      OrderBlock_Update(g_ob, _Symbol, InpLTFTimeframe);
      if(InpShowOB)
         OrderBlock_Draw(g_ob, BOTEN_OBJ_PREFIX, InpColorOBBull, InpColorOBBear);

      Sweep_Update(g_sweep, _Symbol, InpLTFTimeframe,
                    g_pdl, g_asia, InpSweepLookbackBars);
      if(InpShowSweepArrows)
         Sweep_Draw(g_sweep, BOTEN_OBJ_PREFIX);
   }

   // New-bar work on the HTF (market structure + bias score).
   datetime htf_bar = iTime(_Symbol, InpHTFTimeframe, 0);
   bool new_htf = (htf_bar != g_last_htf_bar);
   if(new_htf || new_day)
   {
      g_last_htf_bar = htf_bar;
      MarketStructure_Update(g_struct, _Symbol, InpHTFTimeframe);
      PowerOfThree_Update(g_pof3, _Symbol, now);
      BiasEngine_Update(g_bias, g_pdl, g_asia, g_struct, g_pof3);
   }

   // Decision layer: compute confluence score every new LTF bar.
   if(new_ltf)
   {
      DecideAndDraw(now);
   }

   // Refresh corner panel.
   if(InpShowPanel)
      Panel_Draw(g_panel, BOTEN_OBJ_PREFIX,
                 g_bias, g_last_score, g_last_direction,
                 g_last_setup_id, g_last_setup_time,
                 InpColorPanelBg, InpColorPanelFg);

   ChartRedraw(0);
   return rates_total;
}

//===================================================================//
//                  Decision: bias + confluence -> entry              //
//===================================================================//
void DecideAndDraw(const datetime now)
{
   // No bias conviction -> nothing to do.
   if(MathAbs(g_bias.score) < InpMinBiasConviction)
   {
      g_last_direction = 0;
      g_last_score     = 0;
      g_last_setup_id  = "";
      return;
   }

   int dir = (g_bias.score > 0) ? +1 : -1;
   int score = 0;
   string contributors = "";

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double prox  = g_boten_cfg.level_proximity_price;

   // Killzone presence.
   bool in_kz =
      (InpKZLondonEnabled && BotenSessions_IsInWindowGMT(now,
            InpKZLondonStartH, InpKZLondonStartM,
            InpKZLondonEndH,   InpKZLondonEndM)) ||
      (InpKZNYAMEnabled  && BotenSessions_IsInWindowGMT(now,
            InpKZNYAMStartH,  InpKZNYAMStartM,
            InpKZNYAMEndH,    InpKZNYAMEndM)) ||
      (InpKZNYPMEnabled  && BotenSessions_IsInWindowGMT(now,
            InpKZNYPMStartH,  InpKZNYPMStartM,
            InpKZNYPMEndH,    InpKZNYPMEndM));
   if(in_kz) { score += 1; contributors += "KZ "; }

   // Aligned LTF FVG.
   FVGZone fvg_z;
   if(FVG_LatestAligned(g_fvg, dir, price, fvg_z))
   {
      score += 2;
      contributors += "FVG ";
   }

   // Aligned LTF order block.
   OBZone ob_z;
   bool have_ob = OrderBlock_LatestAligned(g_ob, dir, price, ob_z);
   if(have_ob) { score += 2; contributors += "OB "; }

   // Recent liquidity sweep.
   if(Sweep_RecentInDirection(g_sweep, dir, InpSweepLookbackBars))
   { score += 2; contributors += "Sweep "; }

   // Reaction at PDH/PDL/PDM/midnight.
   double dPDH = MathAbs(price - g_pdl.pdh);
   double dPDL = MathAbs(price - g_pdl.pdl);
   double dPDM = MathAbs(price - g_pdl.pdm);
   double dMN  = MathAbs(price - g_mn_open.price);
   if(dPDH < prox || dPDL < prox || dPDM < prox || dMN < prox)
   { score += 1; contributors += "Level "; }

   // ORB break in bias direction.
   if(ORB_BrokenInDirection(g_orb_london, dir) ||
      ORB_BrokenInDirection(g_orb_ny,     dir))
   { score += 1; contributors += "ORB "; }

   // VWAP alignment.
   if(VWAP_AlignedWithDirection(g_vwap, dir, price))
   { score += 1; contributors += "VWAP "; }

   // Tick-volume spike on the just-closed LTF bar.
   if(VolumeProfile_VolumeSpikeOnLastBar(_Symbol, InpLTFTimeframe))
   { score += 1; contributors += "Vol "; }

   g_last_score     = score;
   g_last_direction = dir;

   if(score < InpMinEntryScore)
   {
      g_last_setup_id = "";
      return;
   }

   // Pick the entry zone: prefer FVG, fall back to OB.
   double zone_low  = 0.0;
   double zone_high = 0.0;
   datetime zone_t1 = 0;
   bool have_zone = false;
   if(FVG_LatestAligned(g_fvg, dir, price, fvg_z))
   {
      zone_low  = MathMin(fvg_z.lower, fvg_z.upper);
      zone_high = MathMax(fvg_z.lower, fvg_z.upper);
      zone_t1   = fvg_z.formed_time;
      have_zone = true;
   }
   else if(have_ob)
   {
      zone_low  = MathMin(ob_z.lower, ob_z.upper);
      zone_high = MathMax(ob_z.lower, ob_z.upper);
      zone_t1   = ob_z.formed_time;
      have_zone = true;
   }
   if(!have_zone) return;

   // Stop and first target.
   double buffer = 5.0 * g_boten_cfg.point;
   double stop, target;
   if(dir > 0)
   {
      stop   = zone_low - buffer;
      target = (g_pdl.pdh > price) ? g_pdl.pdh : price + 2.0 * (price - stop);
   }
   else
   {
      stop   = zone_high + buffer;
      target = (g_pdl.pdl < price) ? g_pdl.pdl : price - 2.0 * (stop - price);
   }

   string id = StringFormat("%s_%I64d_%d_%d", _Symbol, (long)zone_t1, dir, score);

   g_last_setup_id   = id;
   g_last_setup_time = now;
   g_last_entry_low  = zone_low;
   g_last_entry_high = zone_high;
   g_last_stop       = stop;
   g_last_target     = target;

   if(InpShowEntryZone)
      DrawEntryZone(id, zone_low, zone_high, stop, target, zone_t1, now);

   string title = StringFormat("Boten %s %s setup (score %d)",
                                _Symbol,
                                (dir > 0 ? "LONG" : "SHORT"),
                                score);
   string body  = StringFormat("Entry %.*f-%.*f  Stop %.*f  Target %.*f  [%s]",
                                g_boten_cfg.digits, zone_low,
                                g_boten_cfg.digits, zone_high,
                                g_boten_cfg.digits, stop,
                                g_boten_cfg.digits, target,
                                contributors);
   BotenAlerts_Fire(id, title, body);
}

void DrawEntryZone(const string id,
                    const double zone_low, const double zone_high,
                    const double stop,     const double target,
                    const datetime t1,     const datetime now)
{
   string base = BOTEN_OBJ_PREFIX + "ENTRY_";
   datetime t2 = now + PeriodSeconds(InpLTFTimeframe) * 30;
   BotenZones_Rect(base + "ZONE", t1, zone_low, t2, zone_high,
                    InpColorEntryZone, true);
   BotenLevels_Segment(base + "STOP",   t1, t2, stop,
                        InpColorEntryZone, 1, STYLE_DASH);
   BotenLevels_Segment(base + "TARGET", t1, t2, target,
                        InpColorEntryZone, 1, STYLE_DASHDOTDOT);
   BotenLabels_Text(base + "TAG", t2, zone_high, " ENTRY " + IntegerToString(g_last_score),
                    InpColorEntryZone);
}
