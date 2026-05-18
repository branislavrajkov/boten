//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                  Boten - lightweight log helpers |
//+------------------------------------------------------------------+
#ifndef __BOTEN_LOGGER_MQH__
#define __BOTEN_LOGGER_MQH__

// Verbosity levels - higher prints more.
#define BOTEN_LOG_LEVEL_OFF   0
#define BOTEN_LOG_LEVEL_ERR   1
#define BOTEN_LOG_LEVEL_WARN  2
#define BOTEN_LOG_LEVEL_INFO  3
#define BOTEN_LOG_LEVEL_DEBUG 4

// Set in Boten.mq5 from inputs; default to INFO so first run is informative.
int g_boten_log_level = BOTEN_LOG_LEVEL_INFO;

void BotenLogSetLevel(int lvl) { g_boten_log_level = lvl; }

void BotenLogErr(const string msg)
{
   if(g_boten_log_level >= BOTEN_LOG_LEVEL_ERR)
      Print("[BOTEN][ERR ] ", msg);
}

void BotenLogWarn(const string msg)
{
   if(g_boten_log_level >= BOTEN_LOG_LEVEL_WARN)
      Print("[BOTEN][WARN] ", msg);
}

void BotenLogInfo(const string msg)
{
   if(g_boten_log_level >= BOTEN_LOG_LEVEL_INFO)
      Print("[BOTEN][INFO] ", msg);
}

void BotenLogDebug(const string msg)
{
   if(g_boten_log_level >= BOTEN_LOG_LEVEL_DEBUG)
      Print("[BOTEN][DBG ] ", msg);
}

#endif // __BOTEN_LOGGER_MQH__
