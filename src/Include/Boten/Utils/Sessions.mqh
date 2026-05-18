//+------------------------------------------------------------------+
//|                                                     Sessions.mqh |
//|        Timezone, DST, and session window helpers (broker <-> GMT) |
//+------------------------------------------------------------------+
#ifndef __BOTEN_SESSIONS_MQH__
#define __BOTEN_SESSIONS_MQH__

#include <Boten/Utils/Logger.mqh>

// All session boundaries in this project are expressed in GMT and we
// convert to broker time on the fly. That keeps configuration stable
// across servers (London/NY broker offsets vary widely) and across DST.

// US DST: 2nd Sunday of March (start) to 1st Sunday of November (end).
bool BotenSessions_IsUSDST(const datetime t)
{
   MqlDateTime mt;
   TimeToStruct(t, mt);

   if(mt.mon < 3  || mt.mon > 11) return false;
   if(mt.mon > 3  && mt.mon < 11) return true;

   // Resolve March/November based on the day-of-month vs day-of-week.
   // mt.day_of_week: 0=Sun..6=Sat
   if(mt.mon == 3)
   {
      // Second Sunday: smallest Sunday with day >= 8.
      int second_sun_day = 0;
      for(int d = 8; d <= 14; ++d)
      {
         MqlDateTime probe = mt;
         probe.day = d;
         probe.hour = 0; probe.min = 0; probe.sec = 0;
         datetime ts = StructToTime(probe);
         MqlDateTime out;
         TimeToStruct(ts, out);
         if(out.day_of_week == 0) { second_sun_day = d; break; }
      }
      if(mt.day > second_sun_day) return true;
      if(mt.day < second_sun_day) return false;
      return mt.hour >= 2; // DST starts at 02:00 local
   }

   // November: first Sunday.
   int first_sun_day = 0;
   for(int d = 1; d <= 7; ++d)
   {
      MqlDateTime probe = mt;
      probe.day = d;
      probe.hour = 0; probe.min = 0; probe.sec = 0;
      datetime ts = StructToTime(probe);
      MqlDateTime out;
      TimeToStruct(ts, out);
      if(out.day_of_week == 0) { first_sun_day = d; break; }
   }
   if(mt.day < first_sun_day) return true;
   if(mt.day > first_sun_day) return false;
   return mt.hour < 2;
}

// EU DST: last Sunday of March to last Sunday of October, switch at 01:00 UTC.
bool BotenSessions_IsEUDST(const datetime t)
{
   MqlDateTime mt;
   TimeToStruct(t, mt);

   if(mt.mon < 3 || mt.mon > 10) return false;
   if(mt.mon > 3 && mt.mon < 10) return true;

   // Find last Sunday of the month.
   int last_sun_day = 0;
   for(int d = 31; d >= 24; --d)
   {
      MqlDateTime probe = mt;
      // Some months are shorter, but March and October always have 31 days.
      probe.day = d;
      probe.hour = 0; probe.min = 0; probe.sec = 0;
      datetime ts = StructToTime(probe);
      MqlDateTime out;
      TimeToStruct(ts, out);
      if(out.day_of_week == 0) { last_sun_day = d; break; }
   }

   if(mt.mon == 3)
   {
      if(mt.day > last_sun_day) return true;
      if(mt.day < last_sun_day) return false;
      return mt.hour >= 1;
   }
   // October
   if(mt.day < last_sun_day) return true;
   if(mt.day > last_sun_day) return false;
   return mt.hour < 1;
}

// Broker GMT offset in hours. If g_boten_auto_dst is true we use winter/summer inputs.
// Otherwise we use the manual fixed offset.
bool g_boten_auto_dst              = true;
int  g_boten_broker_offset_winter  = 2; // EET (most MT5 brokers)
int  g_boten_broker_offset_summer  = 3; // EEST

void BotenSessions_Configure(const bool auto_dst,
                              const int  winter_offset,
                              const int  summer_offset)
{
   g_boten_auto_dst             = auto_dst;
   g_boten_broker_offset_winter = winter_offset;
   g_boten_broker_offset_summer = summer_offset;
}

// Returns the current broker-time offset from GMT in hours, given a moment
// in broker time. We use the EU DST schedule because most MT5 brokers run
// EET/EEST (Cyprus, Athens, etc.). If your broker doesn't, set
// InpBotenAutoDST=false and provide a fixed offset.
int BotenSessions_BrokerGMTOffset(const datetime broker_time)
{
   if(!g_boten_auto_dst)
      return g_boten_broker_offset_winter;

   return BotenSessions_IsEUDST(broker_time)
            ? g_boten_broker_offset_summer
            : g_boten_broker_offset_winter;
}

datetime BotenSessions_BrokerToGMT(const datetime broker_time)
{
   int off = BotenSessions_BrokerGMTOffset(broker_time);
   return broker_time - off * 3600;
}

datetime BotenSessions_GMTToBroker(const datetime gmt_time)
{
   // Compute offset from a *broker-time* perspective; first probe with the
   // winter offset so we are unlikely to misclassify boundary moments.
   datetime probe = gmt_time + g_boten_broker_offset_winter * 3600;
   int off = BotenSessions_BrokerGMTOffset(probe);
   return gmt_time + off * 3600;
}

// NY local time helpers (broker -> NY).
int BotenSessions_NYGMTOffset(const datetime gmt_time)
{
   return BotenSessions_IsUSDST(gmt_time) ? -4 : -5;
}

datetime BotenSessions_BrokerToNY(const datetime broker_time)
{
   datetime g = BotenSessions_BrokerToGMT(broker_time);
   return g + BotenSessions_NYGMTOffset(g) * 3600;
}

// Build a broker-time datetime for "today, hour:minute GMT".
datetime BotenSessions_TodayGMT(const datetime broker_now,
                                 const int hour_gmt,
                                 const int minute_gmt)
{
   datetime g = BotenSessions_BrokerToGMT(broker_now);
   MqlDateTime mt;
   TimeToStruct(g, mt);
   mt.hour = hour_gmt;
   mt.min  = minute_gmt;
   mt.sec  = 0;
   datetime gmt = StructToTime(mt);
   return BotenSessions_GMTToBroker(gmt);
}

// True iff broker_now falls within [start_gmt_h:m, end_gmt_h:m] today (GMT).
bool BotenSessions_IsInWindowGMT(const datetime broker_now,
                                  const int start_h, const int start_m,
                                  const int end_h,   const int end_m)
{
   datetime g = BotenSessions_BrokerToGMT(broker_now);
   MqlDateTime mt;
   TimeToStruct(g, mt);
   int now_minutes   = mt.hour * 60 + mt.min;
   int start_minutes = start_h * 60 + start_m;
   int end_minutes   = end_h   * 60 + end_m;

   // Same-day window only - we don't wrap across midnight here.
   return (now_minutes >= start_minutes && now_minutes < end_minutes);
}

// Given a broker datetime, return the broker datetime aligned to that
// day's NY midnight (00:00 NY) - useful as the "session day" boundary.
datetime BotenSessions_NYMidnightOfBroker(const datetime broker_time)
{
   datetime g = BotenSessions_BrokerToGMT(broker_time);
   int ny_off = BotenSessions_NYGMTOffset(g);
   datetime ny = g + ny_off * 3600;
   MqlDateTime mt;
   TimeToStruct(ny, mt);
   mt.hour = 0; mt.min = 0; mt.sec = 0;
   datetime ny_midnight = StructToTime(mt);
   datetime gmt_midnight = ny_midnight - ny_off * 3600;
   return BotenSessions_GMTToBroker(gmt_midnight);
}

#endif // __BOTEN_SESSIONS_MQH__
