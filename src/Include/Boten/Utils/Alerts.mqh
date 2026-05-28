//+------------------------------------------------------------------+
//|                                                       Alerts.mqh |
//|              Dedup-aware alert dispatcher (popup/push/email)     |
//+------------------------------------------------------------------+
#ifndef __BOTEN_ALERTS_MQH__
#define __BOTEN_ALERTS_MQH__

#include <Boten/Utils/Logger.mqh>
#include <Boten/Utils/Telegram.mqh>

// Configuration toggles populated from inputs in Boten.mq5.
bool g_boten_alert_popup    = true;
bool g_boten_alert_push     = false;
bool g_boten_alert_email    = false;
int  g_boten_alert_cooldown = 60; // seconds between identical alerts

// Last alert state for dedup. We keep a small ring of recent setup ids
// so the same setup doesn't re-fire on every tick.
#define BOTEN_ALERTS_RING_SIZE 16

string   g_boten_alert_ids[BOTEN_ALERTS_RING_SIZE];
datetime g_boten_alert_times[BOTEN_ALERTS_RING_SIZE];
int      g_boten_alert_head = 0;

void BotenAlerts_Configure(const bool popup,
                            const bool push,
                            const bool email,
                            const int cooldown_seconds)
{
   g_boten_alert_popup    = popup;
   g_boten_alert_push     = push;
   g_boten_alert_email    = email;
   g_boten_alert_cooldown = cooldown_seconds;
}

void BotenAlerts_Reset()
{
   for(int i = 0; i < BOTEN_ALERTS_RING_SIZE; ++i)
   {
      g_boten_alert_ids[i]   = "";
      g_boten_alert_times[i] = 0;
   }
   g_boten_alert_head = 0;
}

// True if we already fired an alert with this id within the cooldown window.
bool BotenAlerts_AlreadyFired(const string id, const datetime now)
{
   for(int i = 0; i < BOTEN_ALERTS_RING_SIZE; ++i)
   {
      if(g_boten_alert_ids[i] == id)
      {
         if(now - g_boten_alert_times[i] < g_boten_alert_cooldown)
            return true;
      }
   }
   return false;
}

void BotenAlerts_Record(const string id, const datetime now)
{
   g_boten_alert_ids[g_boten_alert_head]   = id;
   g_boten_alert_times[g_boten_alert_head] = now;
   g_boten_alert_head = (g_boten_alert_head + 1) % BOTEN_ALERTS_RING_SIZE;
}

// Fire all configured alert channels for a setup. id is used for dedup;
// give the same id while the setup is the same setup.
void BotenAlerts_Fire(const string id,
                      const string title,
                      const string body)
{
   datetime now = TimeCurrent();
   if(BotenAlerts_AlreadyFired(id, now))
      return;
   BotenAlerts_Record(id, now);

   string full = title + " | " + body;

   if(g_boten_alert_popup)
      Alert(full);

   if(g_boten_alert_push)
      SendNotification(full);

   if(g_boten_alert_email)
      SendMail(title, body);

   BotenTelegram_Send(full);

   BotenLogInfo("ALERT " + id + " :: " + full);
}

#endif // __BOTEN_ALERTS_MQH__
