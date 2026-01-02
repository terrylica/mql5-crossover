//+------------------------------------------------------------------+
//|                                   Trading_Sessions_Background.mq5 |
//|                  NY & London Session Background Color Indicator   |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property version     "1.0.0"
#property description "Draws background color rectangles for trading sessions"
#property description "Supports: New York and London sessions"
#property description "Handles timezone conversion with DST for each region"
#property description ""
#property description "NY: 9:30 AM - 4:00 PM Eastern Time"
#property description "London: 8:00 AM - 4:30 PM UK Time"

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Input parameters
input group "=== New York Session (Eastern Time) ==="
input bool             InpShowNY              = true;           // Show NY Session
input int              InpNYOpenHour          = 9;              // NY Open Hour (0-23)
input int              InpNYOpenMinute        = 30;             // NY Open Minute (0-59)
input int              InpNYCloseHour         = 16;             // NY Close Hour (0-23)
input int              InpNYCloseMinute       = 0;              // NY Close Minute (0-59)
input color            InpNYColor             = C'12,12,20';    // NY Session color (very faint blue)

input group "=== London Session (UK Time) ==="
input bool             InpShowLondon          = true;           // Show London Session
input int              InpLondonOpenHour      = 8;              // London Open Hour (0-23)
input int              InpLondonOpenMinute    = 0;              // London Open Minute (0-59)
input int              InpLondonCloseHour     = 16;             // London Close Hour (0-23)
input int              InpLondonCloseMinute   = 30;             // London Close Minute (0-59)
input color            InpLondonColor         = C'20,12,12';    // London Session color (very faint red)

input group "=== Timezone Settings ==="
input int              InpBrokerGMTOffset     = 2;              // Broker Server GMT Offset (hours)
input bool             InpAutoDetectGMT       = true;           // Auto-detect broker GMT offset

input group "=== Visual Settings ==="
input bool             InpFillRectangle       = true;           // Fill rectangle (vs outline only)
input bool             InpDrawInBackground    = true;           // Draw behind candles
input bool             InpShowLabel           = true;           // Show session labels
input color            InpLabelColor          = clrWhite;       // Label color

input group "=== Display Options ==="
input int              InpMaxDaysBack         = 30;             // Maximum days to draw back
input bool             InpDebugMode           = false;          // Enable debug logging

//--- Global variables
int    g_BrokerGMTOffset = 0;
string g_ObjPrefix = "TradingSessions_";

//+------------------------------------------------------------------+
//| Get US Eastern Time GMT offset (EST/EDT)                         |
//| Returns -5 for EST (winter) or -4 for EDT (summer)               |
//| US DST: 2nd Sunday of March to 1st Sunday of November            |
//+------------------------------------------------------------------+
int GetNYGMTOffset(datetime check_time)
  {
   MqlDateTime dt;
   TimeToStruct(check_time, dt);

   int year = dt.year;
   int month = dt.mon;
   int day = dt.day;

   // Find 2nd Sunday of March (DST starts at 2:00 AM local)
   MqlDateTime march_dt;
   march_dt.year = year;
   march_dt.mon = 3;
   march_dt.day = 1;
   march_dt.hour = 0;
   march_dt.min = 0;
   march_dt.sec = 0;
   datetime march_1st = StructToTime(march_dt);
   MqlDateTime m1;
   TimeToStruct(march_1st, m1);
   int march_dow = m1.day_of_week;  // 0=Sunday
   int days_to_sunday = (march_dow == 0) ? 0 : (7 - march_dow);
   int dst_start_day = 1 + days_to_sunday + 7;  // 2nd Sunday

   // Find 1st Sunday of November (DST ends at 2:00 AM local)
   MqlDateTime nov_dt;
   nov_dt.year = year;
   nov_dt.mon = 11;
   nov_dt.day = 1;
   nov_dt.hour = 0;
   nov_dt.min = 0;
   nov_dt.sec = 0;
   datetime nov_1st = StructToTime(nov_dt);
   MqlDateTime n1;
   TimeToStruct(nov_1st, n1);
   int nov_dow = n1.day_of_week;
   int days_to_nov_sunday = (nov_dow == 0) ? 0 : (7 - nov_dow);
   int dst_end_day = 1 + days_to_nov_sunday;  // 1st Sunday

   // Determine if in DST
   bool in_dst = false;
   if(month > 3 && month < 11)
      in_dst = true;
   else if(month == 3 && day >= dst_start_day)
      in_dst = true;
   else if(month == 11 && day < dst_end_day)
      in_dst = true;

   if(InpDebugMode)
     {
      PrintFormat("DEBUG [NY DST]: Date=%s, Month=%d, Day=%d, DST_Start=%d (Mar), DST_End=%d (Nov), InDST=%s",
                  TimeToString(check_time, TIME_DATE), month, day, dst_start_day, dst_end_day, in_dst ? "YES (EDT)" : "NO (EST)");
     }

   return in_dst ? -4 : -5;  // EDT or EST
  }

//+------------------------------------------------------------------+
//| Get UK GMT offset (GMT/BST)                                       |
//| Returns 0 for GMT (winter) or +1 for BST (summer)                |
//| UK DST: Last Sunday of March to Last Sunday of October           |
//+------------------------------------------------------------------+
int GetLondonGMTOffset(datetime check_time)
  {
   MqlDateTime dt;
   TimeToStruct(check_time, dt);

   int year = dt.year;
   int month = dt.mon;
   int day = dt.day;

   // Find last Sunday of March (BST starts at 1:00 AM GMT)
   MqlDateTime march_dt;
   march_dt.year = year;
   march_dt.mon = 3;
   march_dt.day = 31;  // Start from end of March
   march_dt.hour = 0;
   march_dt.min = 0;
   march_dt.sec = 0;
   datetime march_31 = StructToTime(march_dt);
   MqlDateTime m31;
   TimeToStruct(march_31, m31);
   int march_dow = m31.day_of_week;
   int dst_start_day = 31 - march_dow;  // Last Sunday

   // Find last Sunday of October (BST ends at 2:00 AM BST = 1:00 AM GMT)
   MqlDateTime oct_dt;
   oct_dt.year = year;
   oct_dt.mon = 10;
   oct_dt.day = 31;  // Start from end of October
   oct_dt.hour = 0;
   oct_dt.min = 0;
   oct_dt.sec = 0;
   datetime oct_31 = StructToTime(oct_dt);
   MqlDateTime o31;
   TimeToStruct(oct_31, o31);
   int oct_dow = o31.day_of_week;
   int dst_end_day = 31 - oct_dow;  // Last Sunday

   // Determine if in BST
   bool in_bst = false;
   if(month > 3 && month < 10)
      in_bst = true;
   else if(month == 3 && day >= dst_start_day)
      in_bst = true;
   else if(month == 10 && day < dst_end_day)
      in_bst = true;

   if(InpDebugMode)
     {
      PrintFormat("DEBUG [UK DST]: Date=%s, Month=%d, Day=%d, BST_Start=%d (Mar), BST_End=%d (Oct), InBST=%s",
                  TimeToString(check_time, TIME_DATE), month, day, dst_start_day, dst_end_day, in_bst ? "YES (BST/GMT+1)" : "NO (GMT)");
     }

   return in_bst ? 1 : 0;  // BST or GMT
  }

//+------------------------------------------------------------------+
//| Calculate broker GMT offset from server time vs GMT              |
//+------------------------------------------------------------------+
int CalculateBrokerGMTOffset()
  {
   datetime server_time = TimeCurrent();
   datetime gmt_time = TimeGMT();
   int offset_seconds = (int)(server_time - gmt_time);
   int offset_hours = offset_seconds / 3600;
   return offset_hours;
  }

//+------------------------------------------------------------------+
//| Convert local session time to broker server time                 |
//| session_hour/minute: time in session's local timezone            |
//| date: the date (in server time) to apply the session time to     |
//| session_gmt_offset: the GMT offset for the session's timezone    |
//+------------------------------------------------------------------+
datetime SessionTimeToServerTime(int session_hour, int session_minute, datetime date, int session_gmt_offset)
  {
   MqlDateTime dt;
   TimeToStruct(date, dt);

   // Session local time to GMT: local_time - local_offset
   // e.g., 9:30 NY (EST=-5) = 9:30 - (-5) = 14:30 GMT
   // e.g., 8:00 London (GMT=0) = 8:00 - 0 = 8:00 GMT
   int gmt_hour = session_hour - session_gmt_offset;
   int gmt_minute = session_minute;

   // GMT to broker time: gmt_time + broker_offset
   int server_hour = gmt_hour + g_BrokerGMTOffset;
   int server_minute = gmt_minute;

   // Handle day rollover
   while(server_hour < 0)
     {
      server_hour += 24;
      dt.day--;
     }
   while(server_hour >= 24)
     {
      server_hour -= 24;
      dt.day++;
     }

   dt.hour = server_hour;
   dt.min = server_minute;
   dt.sec = 0;

   return StructToTime(dt);
  }

//+------------------------------------------------------------------+
//| Delete all session objects                                       |
//+------------------------------------------------------------------+
void DeleteAllObjects()
  {
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, g_ObjPrefix) == 0)
         ObjectDelete(0, name);
     }
  }

//+------------------------------------------------------------------+
//| Create a session rectangle for a specific day                    |
//+------------------------------------------------------------------+
void CreateSessionRectangle(string session_name, datetime day_start, int index,
                            int open_hour, int open_minute, int close_hour, int close_minute,
                            int session_gmt_offset, color session_color)
  {
   // Calculate session start and end in server time
   datetime session_open = SessionTimeToServerTime(open_hour, open_minute, day_start, session_gmt_offset);
   datetime session_close = SessionTimeToServerTime(close_hour, close_minute, day_start, session_gmt_offset);

   // Skip if session times are invalid
   if(session_open >= session_close)
      return;

   // Skip weekends (Saturday=6, Sunday=0)
   MqlDateTime dt_open;
   TimeToStruct(session_open, dt_open);
   if(dt_open.day_of_week == 0 || dt_open.day_of_week == 6)
      return;

   // Get bar indices for the session
   int bar_start = iBarShift(_Symbol, _Period, session_open);
   int bar_end = iBarShift(_Symbol, _Period, session_close);

   if(bar_start < 0 || bar_end < 0)
      return;

   // Find high and low in the session range
   double high_price = 0;
   double low_price = DBL_MAX;

   int start_idx = MathMin(bar_start, bar_end);
   int end_idx = MathMax(bar_start, bar_end);

   for(int i = start_idx; i <= end_idx; i++)
     {
      double h = iHigh(_Symbol, _Period, i);
      double l = iLow(_Symbol, _Period, i);
      if(h > high_price) high_price = h;
      if(l < low_price) low_price = l;
     }

   // Add small margin to price range
   double range = high_price - low_price;
   double margin = range * 0.02;
   high_price += margin;
   low_price -= margin;

   // Create unique object names
   string rect_name = g_ObjPrefix + session_name + "_Rect_" + IntegerToString(index);
   string label_name = g_ObjPrefix + session_name + "_Label_" + IntegerToString(index);

   // Delete if exists
   ObjectDelete(0, rect_name);
   ObjectDelete(0, label_name);

   // Create rectangle
   ObjectCreate(0, rect_name, OBJ_RECTANGLE, 0, session_open, high_price, session_close, low_price);
   ObjectSetInteger(0, rect_name, OBJPROP_COLOR, session_color);
   ObjectSetInteger(0, rect_name, OBJPROP_FILL, InpFillRectangle);
   ObjectSetInteger(0, rect_name, OBJPROP_BACK, InpDrawInBackground);
   ObjectSetInteger(0, rect_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, rect_name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, rect_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, rect_name, OBJPROP_WIDTH, 1);

   // Create label if enabled
   if(InpShowLabel)
     {
      ObjectCreate(0, label_name, OBJ_TEXT, 0, session_open, high_price);
      ObjectSetString(0, label_name, OBJPROP_TEXT, session_name);
      ObjectSetInteger(0, label_name, OBJPROP_COLOR, InpLabelColor);
      ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, true);
     }

   // Debug logging
   if(InpDebugMode)
     {
      PrintFormat("DEBUG [%s]: Day=%s, Open=%s, Close=%s, GMT_Offset=%+d",
                  session_name, TimeToString(day_start, TIME_DATE),
                  TimeToString(session_open, TIME_DATE | TIME_MINUTES),
                  TimeToString(session_close, TIME_DATE | TIME_MINUTES),
                  session_gmt_offset);
     }
  }

//+------------------------------------------------------------------+
//| Draw all session rectangles                                       |
//+------------------------------------------------------------------+
void DrawSessions()
  {
   DeleteAllObjects();

   datetime current_time = TimeCurrent();

   // Draw sessions for each day
   for(int day = 0; day < InpMaxDaysBack; day++)
     {
      // Calculate the date for this iteration
      datetime check_date = current_time - day * 86400;

      // Normalize to noon to avoid timezone edge cases
      MqlDateTime day_dt;
      TimeToStruct(check_date, day_dt);
      day_dt.hour = 12;
      day_dt.min = 0;
      day_dt.sec = 0;
      datetime day_start = StructToTime(day_dt);

      // Draw NY session
      if(InpShowNY)
        {
         int ny_offset = GetNYGMTOffset(day_start);
         CreateSessionRectangle("NY", day_start, day,
                                InpNYOpenHour, InpNYOpenMinute,
                                InpNYCloseHour, InpNYCloseMinute,
                                ny_offset, InpNYColor);
        }

      // Draw London session
      if(InpShowLondon)
        {
         int london_offset = GetLondonGMTOffset(day_start);
         CreateSessionRectangle("LDN", day_start, day,
                                InpLondonOpenHour, InpLondonOpenMinute,
                                InpLondonCloseHour, InpLondonCloseMinute,
                                london_offset, InpLondonColor);
        }
     }

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Calculate the Nth occurrence of a weekday in a month             |
//| weekday: 0=Sunday, 1=Monday, etc.                                |
//| n: 1=1st, 2=2nd, etc. Use -1 for last occurrence                |
//+------------------------------------------------------------------+
int GetNthWeekdayOfMonth(int year, int month, int weekday, int n)
  {
   if(n == -1)
     {
      // Last occurrence: start from end of month
      int days_in_month = 31;
      if(month == 4 || month == 6 || month == 9 || month == 11)
         days_in_month = 30;
      else if(month == 2)
         days_in_month = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 29 : 28;

      MqlDateTime dt;
      dt.year = year;
      dt.mon = month;
      dt.day = days_in_month;
      dt.hour = 12;
      dt.min = 0;
      dt.sec = 0;
      datetime last_day = StructToTime(dt);
      MqlDateTime ld;
      TimeToStruct(last_day, ld);
      int last_dow = ld.day_of_week;
      int days_back = (last_dow >= weekday) ? (last_dow - weekday) : (7 - weekday + last_dow);
      return days_in_month - days_back;
     }
   else
     {
      // Nth occurrence: start from beginning
      MqlDateTime dt;
      dt.year = year;
      dt.mon = month;
      dt.day = 1;
      dt.hour = 12;
      dt.min = 0;
      dt.sec = 0;
      datetime first_day = StructToTime(dt);
      MqlDateTime fd;
      TimeToStruct(first_day, fd);
      int first_dow = fd.day_of_week;
      int days_to_weekday = (weekday >= first_dow) ? (weekday - first_dow) : (7 - first_dow + weekday);
      return 1 + days_to_weekday + (n - 1) * 7;
     }
  }

//+------------------------------------------------------------------+
//| Log current time in all relevant timezones                       |
//+------------------------------------------------------------------+
void LogCurrentTimeAllZones()
  {
   datetime server_time = TimeCurrent();
   datetime gmt_time = TimeGMT();

   int ny_offset = GetNYGMTOffset(server_time);
   int london_offset = GetLondonGMTOffset(server_time);

   // Calculate local times
   datetime ny_time = gmt_time + ny_offset * 3600;
   datetime london_time = gmt_time + london_offset * 3600;

   Print("╔══════════════════════════════════════════════════════════════╗");
   Print("║              CURRENT TIME - ALL TIMEZONES                    ║");
   Print("╠══════════════════════════════════════════════════════════════╣");
   PrintFormat("║ Broker Server (GMT%+d):  %s              ║", g_BrokerGMTOffset, TimeToString(server_time, TIME_DATE | TIME_SECONDS));
   PrintFormat("║ UTC/GMT:                 %s              ║", TimeToString(gmt_time, TIME_DATE | TIME_SECONDS));
   PrintFormat("║ New York (%s, GMT%+d):   %s              ║", (ny_offset == -4) ? "EDT" : "EST", ny_offset, TimeToString(ny_time, TIME_DATE | TIME_SECONDS));
   PrintFormat("║ London (%s, GMT%+d):     %s              ║", (london_offset == 1) ? "BST" : "GMT", london_offset, TimeToString(london_time, TIME_DATE | TIME_SECONDS));
   Print("╚══════════════════════════════════════════════════════════════╝");
  }

//+------------------------------------------------------------------+
//| Log DST transition dates for a specific year                      |
//+------------------------------------------------------------------+
void LogDSTTransitionsForYear(int year)
  {
   // Calculate actual DST transition dates
   int us_dst_start = GetNthWeekdayOfMonth(year, 3, 0, 2);   // 2nd Sunday of March
   int us_dst_end = GetNthWeekdayOfMonth(year, 11, 0, 1);    // 1st Sunday of November
   int uk_bst_start = GetNthWeekdayOfMonth(year, 3, 0, -1);  // Last Sunday of March
   int uk_bst_end = GetNthWeekdayOfMonth(year, 10, 0, -1);   // Last Sunday of October

   PrintFormat("╔══════════════════════════════════════════════════════════════╗");
   PrintFormat("║                DST TRANSITIONS FOR %d                        ║", year);
   PrintFormat("╠══════════════════════════════════════════════════════════════╣");
   PrintFormat("║ US (Eastern Time):                                           ║");
   PrintFormat("║   DST Starts: March %d, %d (2:00 AM EST → 3:00 AM EDT)     ║", us_dst_start, year);
   PrintFormat("║   DST Ends:   November %d, %d (2:00 AM EDT → 1:00 AM EST)  ║", us_dst_end, year);
   PrintFormat("║   Rule: 2nd Sunday March → 1st Sunday November               ║");
   PrintFormat("╠══════════════════════════════════════════════════════════════╣");
   PrintFormat("║ UK (British Time):                                           ║");
   PrintFormat("║   BST Starts: March %d, %d (1:00 AM GMT → 2:00 AM BST)     ║", uk_bst_start, year);
   PrintFormat("║   BST Ends:   October %d, %d (2:00 AM BST → 1:00 AM GMT)   ║", uk_bst_end, year);
   PrintFormat("║   Rule: Last Sunday March → Last Sunday October              ║");
   PrintFormat("╚══════════════════════════════════════════════════════════════╝");
  }

//+------------------------------------------------------------------+
//| Validate DST calculation against expected dates                   |
//+------------------------------------------------------------------+
void ValidateDSTCalculations()
  {
   Print("");
   Print("╔══════════════════════════════════════════════════════════════╗");
   Print("║            DST CALCULATION VALIDATION                        ║");
   Print("║  Compare these dates with: https://www.timeanddate.com/time/change/  ║");
   Print("╚══════════════════════════════════════════════════════════════╝");
   Print("");

   // Test multiple years to ensure algorithm works
   int test_years[] = {2024, 2025, 2026, 2027, 2028};

   for(int y = 0; y < ArraySize(test_years); y++)
     {
      int year = test_years[y];
      LogDSTTransitionsForYear(year);
      Print("");
     }

   // Now test specific dates around transitions
   Print("╔══════════════════════════════════════════════════════════════╗");
   Print("║            TRANSITION DATE VERIFICATION                      ║");
   Print("║  Testing dates before/after each DST transition              ║");
   Print("╚══════════════════════════════════════════════════════════════╝");
   Print("");

   // 2025 transitions
   int year = 2025;
   int us_start = GetNthWeekdayOfMonth(year, 3, 0, 2);
   int us_end = GetNthWeekdayOfMonth(year, 11, 0, 1);
   int uk_start = GetNthWeekdayOfMonth(year, 3, 0, -1);
   int uk_end = GetNthWeekdayOfMonth(year, 10, 0, -1);

   // Create test dates: day before and day after each transition
   datetime test_dates[8];
   string test_labels[8];

   // US DST Start
   MqlDateTime dt;
   dt.year = year; dt.mon = 3; dt.day = us_start - 1; dt.hour = 12; dt.min = 0; dt.sec = 0;
   test_dates[0] = StructToTime(dt);
   test_labels[0] = StringFormat("March %d (day BEFORE US DST starts)", us_start - 1);

   dt.day = us_start + 1;
   test_dates[1] = StructToTime(dt);
   test_labels[1] = StringFormat("March %d (day AFTER US DST starts)", us_start + 1);

   // UK BST Start
   dt.day = uk_start - 1;
   test_dates[2] = StructToTime(dt);
   test_labels[2] = StringFormat("March %d (day BEFORE UK BST starts)", uk_start - 1);

   dt.day = uk_start + 1;
   test_dates[3] = StructToTime(dt);
   test_labels[3] = StringFormat("March %d (day AFTER UK BST starts)", uk_start + 1);

   // UK BST End
   dt.mon = 10; dt.day = uk_end - 1;
   test_dates[4] = StructToTime(dt);
   test_labels[4] = StringFormat("October %d (day BEFORE UK BST ends)", uk_end - 1);

   dt.day = uk_end + 1;
   test_dates[5] = StructToTime(dt);
   test_labels[5] = StringFormat("October %d (day AFTER UK BST ends)", uk_end + 1);

   // US DST End
   dt.mon = 11; dt.day = us_end - 1;
   test_dates[6] = StructToTime(dt);
   test_labels[6] = StringFormat("November %d (day BEFORE US DST ends)", us_end - 1);

   dt.day = us_end + 1;
   test_dates[7] = StructToTime(dt);
   test_labels[7] = StringFormat("November %d (day AFTER US DST ends)", us_end + 1);

   PrintFormat("Testing %d DST transitions:", year);
   Print("─────────────────────────────────────────────────────────────────");
   PrintFormat("%-45s | %-12s | %-12s", "Date", "NY Offset", "London Offset");
   Print("─────────────────────────────────────────────────────────────────");

   for(int i = 0; i < 8; i++)
     {
      int ny_off = GetNYGMTOffset(test_dates[i]);
      int london_off = GetLondonGMTOffset(test_dates[i]);

      string ny_str = StringFormat("GMT%+d (%s)", ny_off, (ny_off == -4) ? "EDT" : "EST");
      string london_str = StringFormat("GMT%+d (%s)", london_off, (london_off == 1) ? "BST" : "GMT");

      PrintFormat("%-45s | %-12s | %-12s", test_labels[i], ny_str, london_str);

      // Add separator between transition pairs
      if(i % 2 == 1 && i < 7)
         Print("─────────────────────────────────────────────────────────────────");
     }

   Print("─────────────────────────────────────────────────────────────────");
   Print("");
  }

//+------------------------------------------------------------------+
//| Log session times in all timezones for verification              |
//+------------------------------------------------------------------+
void LogSessionTimesAllZones()
  {
   datetime now = TimeCurrent();
   int ny_offset = GetNYGMTOffset(now);
   int london_offset = GetLondonGMTOffset(now);

   Print("╔══════════════════════════════════════════════════════════════╗");
   Print("║            SESSION TIMES IN ALL TIMEZONES                    ║");
   Print("╚══════════════════════════════════════════════════════════════╝");
   Print("");

   if(InpShowNY)
     {
      // NY session times
      int ny_open_gmt_hour = InpNYOpenHour - ny_offset;
      int ny_close_gmt_hour = InpNYCloseHour - ny_offset;
      int ny_open_broker_hour = ny_open_gmt_hour + g_BrokerGMTOffset;
      int ny_close_broker_hour = ny_close_gmt_hour + g_BrokerGMTOffset;

      Print("NY SESSION:");
      PrintFormat("  Local (ET):     %02d:%02d - %02d:%02d %s",
                  InpNYOpenHour, InpNYOpenMinute, InpNYCloseHour, InpNYCloseMinute,
                  (ny_offset == -4) ? "EDT" : "EST");
      PrintFormat("  UTC/GMT:        %02d:%02d - %02d:%02d",
                  ny_open_gmt_hour, InpNYOpenMinute, ny_close_gmt_hour, InpNYCloseMinute);
      PrintFormat("  Broker (GMT%+d): %02d:%02d - %02d:%02d  ← These times should appear on chart",
                  g_BrokerGMTOffset, ny_open_broker_hour, InpNYOpenMinute, ny_close_broker_hour, InpNYCloseMinute);
      Print("");
     }

   if(InpShowLondon)
     {
      // London session times
      int london_open_gmt_hour = InpLondonOpenHour - london_offset;
      int london_close_gmt_hour = InpLondonCloseHour - london_offset;
      int london_open_broker_hour = london_open_gmt_hour + g_BrokerGMTOffset;
      int london_close_broker_hour = london_close_gmt_hour + g_BrokerGMTOffset;

      Print("LONDON SESSION:");
      PrintFormat("  Local (UK):     %02d:%02d - %02d:%02d %s",
                  InpLondonOpenHour, InpLondonOpenMinute, InpLondonCloseHour, InpLondonCloseMinute,
                  (london_offset == 1) ? "BST" : "GMT");
      PrintFormat("  UTC/GMT:        %02d:%02d - %02d:%02d",
                  london_open_gmt_hour, InpLondonOpenMinute, london_close_gmt_hour, InpLondonCloseMinute);
      PrintFormat("  Broker (GMT%+d): %02d:%02d - %02d:%02d  ← These times should appear on chart",
                  g_BrokerGMTOffset, london_open_broker_hour, InpLondonOpenMinute, london_close_broker_hour, InpLondonCloseMinute);
      Print("");
     }
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate inputs
   if(InpNYOpenHour < 0 || InpNYOpenHour > 23 ||
      InpNYCloseHour < 0 || InpNYCloseHour > 23 ||
      InpLondonOpenHour < 0 || InpLondonOpenHour > 23 ||
      InpLondonCloseHour < 0 || InpLondonCloseHour > 23)
     {
      Print("ERROR: Invalid time parameters");
      return INIT_PARAMETERS_INCORRECT;
     }

//--- Calculate or use input GMT offset
   if(InpAutoDetectGMT)
     {
      g_BrokerGMTOffset = CalculateBrokerGMTOffset();
      PrintFormat("Auto-detected broker GMT offset: %+d hours", g_BrokerGMTOffset);
     }
   else
     {
      g_BrokerGMTOffset = InpBrokerGMTOffset;
      PrintFormat("Using manual broker GMT offset: %+d hours", g_BrokerGMTOffset);
     }

//--- Print session info
   datetime now = TimeCurrent();
   int ny_offset = GetNYGMTOffset(now);
   int london_offset = GetLondonGMTOffset(now);

   Print("Trading Sessions Background Indicator initialized:");
   PrintFormat("  Broker GMT offset: %+d", g_BrokerGMTOffset);

   if(InpShowNY)
     {
      PrintFormat("  NY Session: %02d:%02d - %02d:%02d ET (currently GMT%+d)",
                  InpNYOpenHour, InpNYOpenMinute, InpNYCloseHour, InpNYCloseMinute, ny_offset);
     }

   if(InpShowLondon)
     {
      PrintFormat("  London Session: %02d:%02d - %02d:%02d UK (currently GMT%+d)",
                  InpLondonOpenHour, InpLondonOpenMinute, InpLondonCloseHour, InpLondonCloseMinute, london_offset);
     }

//--- Log comprehensive debug info if debug mode enabled
   if(InpDebugMode)
     {
      LogCurrentTimeAllZones();
      Print("");
      LogSessionTimesAllZones();
      ValidateDSTCalculations();
     }

//--- Draw initial sessions
   DrawSessions();

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DeleteAllObjects();
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   static datetime last_bar_time = 0;
   datetime current_bar_time = iTime(_Symbol, _Period, 0);

   if(last_bar_time != current_bar_time)
     {
      last_bar_time = current_bar_time;
      DrawSessions();
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| ChartEvent handler for manual refresh                            |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id == CHARTEVENT_CHART_CHANGE)
     {
      DrawSessions();
     }
  }
//+------------------------------------------------------------------+
