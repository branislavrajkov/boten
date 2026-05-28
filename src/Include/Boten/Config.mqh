//+------------------------------------------------------------------+
//|                                                       Config.mqh |
//|              All Boten inputs and resolved per-symbol presets    |
//+------------------------------------------------------------------+
#ifndef __BOTEN_CONFIG_MQH__
#define __BOTEN_CONFIG_MQH__

#include <Boten/Utils/Symbols.mqh>
#include <Boten/Utils/Logger.mqh>

//===================================================================//
//                              INPUTS                                //
//===================================================================//
input group "=== General ==="
input ENUM_BOTEN_INSTRUMENT InpInstrumentPreset = BOTEN_INSTRUMENT_AUTO;
input int                   InpLogLevel         = 3;       // 0=off,1=err,2=warn,3=info,4=debug

input group "=== Time & DST ==="
input bool InpAutoDST              = true;
input int  InpBrokerOffsetWinter   = 2;                    // hours from GMT (winter / standard)
input int  InpBrokerOffsetSummer   = 3;                    // hours from GMT (summer / DST)

input group "=== Asia session ==="
input int  InpAsiaStartHourGMT     = 0;
input int  InpAsiaStartMinGMT      = 0;
input int  InpAsiaEndHourGMT       = 6;
input int  InpAsiaEndMinGMT        = 0;

input group "=== Killzones (GMT, no DST shift) ==="
input bool InpKZLondonEnabled      = true;
input int  InpKZLondonStartH       = 7;
input int  InpKZLondonStartM       = 0;
input int  InpKZLondonEndH         = 10;
input int  InpKZLondonEndM         = 0;

input bool InpKZNYAMEnabled        = true;
input int  InpKZNYAMStartH         = 12;
input int  InpKZNYAMStartM         = 30;
input int  InpKZNYAMEndH           = 15;
input int  InpKZNYAMEndM           = 0;

input bool InpKZNYPMEnabled        = true;
input int  InpKZNYPMStartH         = 17;
input int  InpKZNYPMStartM         = 0;
input int  InpKZNYPMEndH           = 20;
input int  InpKZNYPMEndM           = 0;

input group "=== Opening Range Breakout ==="
input int  InpLondonORBMinutes     = 15;
input int  InpNYORBMinutes         = 15;

input group "=== Bias & confluence engine ==="
input int  InpMinBiasConviction    = 2;                    // |score| below this means no trade
input int  InpMinEntryScore        = 5;                    // confluence score threshold
input int  InpLevelProximityPoints = 0;                    // 0 = use per-symbol preset
input int  InpSweepLookbackBars    = 6;                    // bars to consider a sweep "recent"
input ENUM_TIMEFRAMES InpLTFTimeframe = PERIOD_M15;        // confluence engine timeframe
input ENUM_TIMEFRAMES InpHTFTimeframe = PERIOD_H4;         // bias / structure timeframe

input group "=== Display toggles ==="
input bool InpShowPDLevels         = true;
input bool InpShowPWLevels         = true;
input bool InpShowAsiaRange        = true;
input bool InpShowKillzones        = true;
input bool InpShowORB              = true;
input bool InpShowFVG              = true;
input bool InpShowOB               = true;
input bool InpShowSweepArrows      = true;
input bool InpShowVWAP             = true;
input bool InpShowVolumeProfile    = true;
input bool InpShowMidnightOpen     = true;
input bool InpShowEntryZone        = true;
input bool InpShowPanel            = true;

input group "=== Colours ==="
input color InpColorPDH            = clrDodgerBlue;
input color InpColorPDL            = clrDodgerBlue;
input color InpColorPDM            = clrSlateGray;
input color InpColorPWH            = clrMediumOrchid;
input color InpColorPWL            = clrMediumOrchid;
input color InpColorAsia           = clrGoldenrod;
input color InpColorKZLondon       = clrSteelBlue;
input color InpColorKZNYAM         = clrSeaGreen;
input color InpColorKZNYPM         = clrIndianRed;
input color InpColorORB            = clrOrange;
input color InpColorFVGBull        = clrLimeGreen;
input color InpColorFVGBear        = clrCrimson;
input color InpColorOBBull         = clrTeal;
input color InpColorOBBear         = clrMaroon;
input color InpColorVWAP           = clrYellow;
input color InpColorVPPOC          = clrAqua;
input color InpColorVPVA           = clrDarkSlateGray;
input color InpColorMidnight       = clrSilver;
input color InpColorEntryZone      = clrGold;
input color InpColorPanelBg        = clrBlack;
input color InpColorPanelFg        = clrWhite;

input group "=== Alerts ==="
input bool InpAlertPopup           = true;
input bool InpAlertPush            = false;
input bool InpAlertEmail           = false;
input int  InpAlertCooldownSeconds = 60;

input group "=== Telegram ==="
input bool   InpTelegramEnabled         = false;    // Enable Telegram notifications
input string InpTelegramToken           = "";       // Bot token from @BotFather
input string InpTelegramChatID          = "";       // Channel/group/user chat_id
input bool   InpTelegramProximityAlert  = true;     // Alert when price gets close to a key level
input int    InpTelegramProximityPoints = 0;        // 0 = use 2x InpLevelProximityPoints
input bool   InpTelegramSweepAlert      = true;     // Alert on confirmed sweep (wick-through-and-close)

//===================================================================//
//                  RESOLVED CONFIG (filled in OnInit)                //
//===================================================================//
struct BotenConfig
{
   string                 symbol;
   ENUM_BOTEN_INSTRUMENT  family;
   double                 level_proximity_price;   // converted from points
   int                    digits;
   double                 point;
};

BotenConfig g_boten_cfg;

//===================================================================//
//                         PER-SYMBOL PRESETS                         //
//===================================================================//
// Default proximity (in points) per family. Indices have point=1.0
// on most brokers, so 15 points = 15 index points (e.g. ~0.08% on NAS100).
int BotenConfig_DefaultProximityPoints(ENUM_BOTEN_INSTRUMENT fam)
{
   switch(fam)
   {
      case BOTEN_INSTRUMENT_NAS100: return 15;
      case BOTEN_INSTRUMENT_US30:   return 25;
      case BOTEN_INSTRUMENT_SPX500: return 4;
      case BOTEN_INSTRUMENT_GER40:  return 12;
      default:                      return 10;
   }
}

void BotenConfig_Resolve()
{
   g_boten_cfg.symbol = _Symbol;
   g_boten_cfg.digits = BotenSymbol_Digits(_Symbol);
   g_boten_cfg.point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(g_boten_cfg.point <= 0.0) g_boten_cfg.point = _Point;

   ENUM_BOTEN_INSTRUMENT fam = InpInstrumentPreset;
   if(fam == BOTEN_INSTRUMENT_AUTO)
      fam = BotenSymbol_DetectFromName(_Symbol);
   g_boten_cfg.family = fam;

   int prox_points = (InpLevelProximityPoints > 0)
                       ? InpLevelProximityPoints
                       : BotenConfig_DefaultProximityPoints(fam);
   g_boten_cfg.level_proximity_price = prox_points * g_boten_cfg.point;

   BotenLogInfo(StringFormat(
      "Config: symbol=%s family=%s digits=%d proximity=%.2f (%d pts)",
      g_boten_cfg.symbol,
      BotenSymbol_FamilyName(fam),
      g_boten_cfg.digits,
      g_boten_cfg.level_proximity_price,
      prox_points));
}

#endif // __BOTEN_CONFIG_MQH__
