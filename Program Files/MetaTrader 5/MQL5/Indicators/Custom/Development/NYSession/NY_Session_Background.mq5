//+------------------------------------------------------------------+
//|                                        NY_Session_Background.mq5 |
//|                     New York Session Background Color Indicator  |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property version     "1.0.0"
#property description "Draws background color rectangles for NY trading session"
#property description "Handles timezone conversion from broker server time to NY time"
#property description ""
#property description "NY Regular Trading Hours: 9:30 AM - 4:00 PM Eastern Time"
#property description "NY Extended Hours: 4:00 AM - 8:00 PM Eastern Time (optional)"

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Input parameters
input group "=== NY Session Times (Eastern Time) ==="
input int              InpNYOpenHour          = 9;              // NY Open Hour (0-23)
input int              InpNYOpenMinute        = 30;             // NY Open Minute (0-59)
input int              InpNYCloseHour         = 16;             // NY Close Hour (0-23)
input int              InpNYCloseMinute       = 0;              // NY Close Minute (0-59)

input group "=== Timezone Settings ==="
input int              InpBrokerGMTOffset     = 2;              // Broker Server GMT Offset (hours)
input bool             InpAutoDetectGMT       = true;           // Auto-detect broker GMT offset
input bool             InpUseDST              = true;           // Account for US Daylight Saving Time

input group "=== Visual Settings ==="
input color            InpSessionColor        = C'25,25,35';    // Session background color (very faint on black)
input int              InpSessionAlpha        = 50;             // Transparency (0=solid, 100=invisible)
input bool             InpFillRectangle       = true;           // Fill rectangle (vs outline only)
input bool             InpDrawInBackground    = true;           // Draw behind candles

input group "=== Display Options ==="
input int              InpMaxDaysBack         = 30;             // Maximum days to draw back
input bool             InpShowLabel           = true;           // Show "NY" label on session

//--- Global variables
int    g_BrokerGMTOffset = 0;     // Calculated or input broker GMT offset
string g_ObjPrefix = "NYSession_"; // Object name prefix

//+------------------------------------------------------------------+
//| Get the current US Eastern Time offset from UTC                  |
//| Returns -5 for EST (winter) or -4 for EDT (summer/DST)          |
//+------------------------------------------------------------------+
int GetNYGMTOffset(datetime check_time)
  {
   if(!InpUseDST)
      return -5;  // Standard EST

   // US DST: 2nd Sunday of March to 1st Sunday of November
   MqlDateTime dt;
   TimeToStruct(check_time, dt);

   int year = dt.year;
   int month = dt.mon;
   int day = dt.day;

   // Find 2nd Sunday of March
   MqlDateTime march_dt;
   march_dt.year = year;
   march_dt.mon = 3;
   march_dt.day = 1;
   march_dt.hour = 2;
   march_dt.min = 0;
   march_dt.sec = 0;
   datetime march_1st = StructToTime(march_dt);
   MqlDateTime m1;
   TimeToStruct(march_1st, m1);
   int march_dow = m1.day_of_week;  // 0=Sunday
   int days_to_sunday = (march_dow == 0) ? 0 : (7 - march_dow);
   int dst_start_day = 1 + days_to_sunday + 7;  // 2nd Sunday

   // Find 1st Sunday of November
   MqlDateTime nov_dt;
   nov_dt.year = year;
   nov_dt.mon = 11;
   nov_dt.day = 1;
   nov_dt.hour = 2;
   nov_dt.min = 0;
   nov_dt.sec = 0;
   datetime nov_1st = StructToTime(nov_dt);
   MqlDateTime n1;
   TimeToStruct(nov_1st, n1);
   int nov_dow = n1.day_of_week;
   int days_to_nov_sunday = (nov_dow == 0) ? 0 : (7 - nov_dow);
   int dst_end_day = 1 + days_to_nov_sunday;  // 1st Sunday

   // Check if we're in DST period
   bool in_dst = false;
   if(month > 3 && month < 11)
      in_dst = true;
   else if(month == 3 && day >= dst_start_day)
      in_dst = true;
   else if(month == 11 && day < dst_end_day)
      in_dst = true;

   return in_dst ? -4 : -5;  // EDT or EST
  }

//+------------------------------------------------------------------+
//| Calculate broker GMT offset from server time vs GMT              |
//+------------------------------------------------------------------+
int CalculateBrokerGMTOffset()
  {
   datetime server_time = TimeCurrent();
   datetime gmt_time = TimeGMT();

   // Difference in seconds, convert to hours
   int offset_seconds = (int)(server_time - gmt_time);
   int offset_hours = offset_seconds / 3600;

   return offset_hours;
  }

//+------------------------------------------------------------------+
//| Convert NY time to broker server time                            |
//| ny_hour/ny_minute: time in NY timezone                          |
//| date: the date (in server time) to apply the NY time to         |
//+------------------------------------------------------------------+
datetime NYTimeToServerTime(int ny_hour, int ny_minute, datetime date)
  {
   MqlDateTime dt;
   TimeToStruct(date, dt);

   // Get NY GMT offset for this date
   int ny_gmt_offset = GetNYGMTOffset(date);

   // NY time in GMT: ny_time - ny_offset (e.g., 9:30 NY = 9:30 - (-5) = 14:30 GMT)
   int gmt_hour = ny_hour - ny_gmt_offset;
   int gmt_minute = ny_minute;

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
void CreateSessionRectangle(datetime day_start, int index)
  {
   // Calculate session start and end in server time
   datetime session_open = NYTimeToServerTime(InpNYOpenHour, InpNYOpenMinute, day_start);
   datetime session_close = NYTimeToServerTime(InpNYCloseHour, InpNYCloseMinute, day_start);

   // Skip if session times are invalid
   if(session_open >= session_close)
      return;

   // Skip weekends (Saturday=6, Sunday=0)
   MqlDateTime dt_open;
   TimeToStruct(session_open, dt_open);
   if(dt_open.day_of_week == 0 || dt_open.day_of_week == 6)
      return;

   // Get price range for the session
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

   // Create unique object name
   string rect_name = g_ObjPrefix + "Rect_" + IntegerToString(index);
   string label_name = g_ObjPrefix + "Label_" + IntegerToString(index);

   // Delete if exists
   ObjectDelete(0, rect_name);
   ObjectDelete(0, label_name);

   // Create rectangle
   ObjectCreate(0, rect_name, OBJ_RECTANGLE, 0, session_open, high_price, session_close, low_price);
   ObjectSetInteger(0, rect_name, OBJPROP_COLOR, InpSessionColor);
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
      ObjectSetString(0, label_name, OBJPROP_TEXT, "NY");
      ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, true);
     }
  }

//+------------------------------------------------------------------+
//| Draw all session rectangles                                       |
//+------------------------------------------------------------------+
void DrawSessions()
  {
   DeleteAllObjects();

   datetime current_time = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(current_time, dt);

   // Start from today and go back
   for(int day = 0; day < InpMaxDaysBack; day++)
     {
      // Calculate the date for this iteration
      datetime check_date = current_time - day * 86400;  // 86400 seconds per day

      // Normalize to start of day
      MqlDateTime day_dt;
      TimeToStruct(check_date, day_dt);
      day_dt.hour = 12;  // Noon to avoid timezone edge cases
      day_dt.min = 0;
      day_dt.sec = 0;
      datetime day_start = StructToTime(day_dt);

      CreateSessionRectangle(day_start, day);
     }

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate inputs
   if(InpNYOpenHour < 0 || InpNYOpenHour > 23 ||
      InpNYCloseHour < 0 || InpNYCloseHour > 23 ||
      InpNYOpenMinute < 0 || InpNYOpenMinute > 59 ||
      InpNYCloseMinute < 0 || InpNYCloseMinute > 59)
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
   int ny_offset = GetNYGMTOffset(TimeCurrent());
   PrintFormat("NY Session Indicator initialized:");
   PrintFormat("  NY Open: %02d:%02d ET", InpNYOpenHour, InpNYOpenMinute);
   PrintFormat("  NY Close: %02d:%02d ET", InpNYCloseHour, InpNYCloseMinute);
   PrintFormat("  Current NY GMT offset: %+d (DST: %s)", ny_offset, InpUseDST ? "enabled" : "disabled");
   PrintFormat("  Broker GMT offset: %+d", g_BrokerGMTOffset);

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
//--- Redraw sessions on new bars or first calculation
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
   // Redraw on chart changes
   if(id == CHARTEVENT_CHART_CHANGE)
     {
      DrawSessions();
     }
  }
//+------------------------------------------------------------------+
