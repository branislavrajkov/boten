//+------------------------------------------------------------------+
//|                                                     Telegram.mqh |
//|              Thin wrapper for Telegram Bot API sendMessage       |
//+------------------------------------------------------------------+
// SETUP (required before any message will arrive):
//   1. Create a bot via @BotFather → copy the token.
//   2. Add the bot to your channel/group as admin, or start a DM.
//   3. Get the chat_id:
//        - Channel:  "@your_channel_name"  or numeric  "-100xxxxxxxxxx"
//        - Group:    numeric "-xxxxxxxxxx"  (from api.telegram.org/bot<TOKEN>/getUpdates)
//        - Private:  your numeric user id
//   4. In MT5 → Tools → Options → Expert Advisors:
//        Enable "Allow WebRequest for listed URLs" and add:
//        https://api.telegram.org
//+------------------------------------------------------------------+
#ifndef __BOTEN_TELEGRAM_MQH__
#define __BOTEN_TELEGRAM_MQH__

#include <Boten/Utils/Logger.mqh>

bool   g_boten_tg_enabled  = false;
string g_boten_tg_token    = "";
string g_boten_tg_chat_id  = "";

void BotenTelegram_Configure(const bool enabled,
                              const string token,
                              const string chat_id)
{
   g_boten_tg_enabled = enabled;
   g_boten_tg_token   = token;
   g_boten_tg_chat_id = chat_id;
}

void BotenTelegram_Send(const string text)
{
   if(!g_boten_tg_enabled || g_boten_tg_token == "" || g_boten_tg_chat_id == "")
      return;

   // Minimal JSON escaping for the message body.
   string safe = text;
   StringReplace(safe, "\\", "\\\\");
   StringReplace(safe, "\"", "\\\"");
   StringReplace(safe, "\n", "\\n");
   StringReplace(safe, "\r", "");

   string url  = "https://api.telegram.org/bot" + g_boten_tg_token + "/sendMessage";
   string body = "{\"chat_id\":\"" + g_boten_tg_chat_id + "\",\"text\":\"" + safe + "\"}";

   // Build raw byte array for WebRequest.
   char   req[], res[];
   string res_hdrs;
   int    len = StringLen(body);
   ArrayResize(req, len);
   for(int i = 0; i < len; i++)
      req[i] = (char)StringGetCharacter(body, i);

   int code = WebRequest("POST", url, "Content-Type: application/json\r\n",
                          5000, req, res, res_hdrs);
   if(code == 200)
      BotenLogDebug("Telegram sent ok");
   else
      BotenLogWarn(StringFormat("Telegram send failed: HTTP %d", code));
}

#endif // __BOTEN_TELEGRAM_MQH__
