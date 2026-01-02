//+------------------------------------------------------------------+
//|                                       Trading_Sessions_Lines.mq5 |
//|                    Lightweight Session Markers - Vertical Lines  |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property version     "2.3.0"
#property description "Lightweight session markers using vertical lines"
#property description "Supports: New York and London sessions with DST"
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
input color            InpNYColor             = C'40,80,120';   // NY Session color (muted blue)
input color            InpNYLabelColor        = clrCyan;        // NY Label color (bright)

input group "=== London Session (UK Time) ==="
input bool             InpShowLondon          = true;           // Show London Session
input int              InpLondonOpenHour      = 8;              // London Open Hour (0-23)
input int              InpLondonOpenMinute    = 0;              // London Open Minute (0-59)
input int              InpLondonCloseHour     = 16;             // London Close Hour (0-23)
input int              InpLondonCloseMinute   = 30;             // London Close Minute (0-59)
input color            InpLondonColor         = C'120,40,40';   // London Session color (muted red)
input color            InpLondonLabelColor    = clrCoral;       // London Label color (bright)

input group "=== Timezone Settings ==="
input bool             InpAutoDetectGMT       = true;           // Auto-detect broker GMT offset
input int              InpBrokerGMTOffset     = 2;              // Broker Server GMT Offset (hours)

input group "=== Visual Settings ==="
input ENUM_LINE_STYLE  InpLineStyle           = STYLE_DOT;      // Line style
input int              InpLineWidth           = 1;              // Line width (1-5)
input bool             InpShowLabel           = true;           // Show session labels at top
input int              InpLabelFontSize       = 8;              // Label font size
input bool             InpShowTopStrip        = true;           // Show horizontal strip at top
input int              InpStripHeight         = 3;              // Strip height in percent of chart

input group "=== Display Options ==="
input int              InpMaxDaysBack         = 10;             // Maximum days to draw back
input bool             InpDebugMode           = true;           // Enable debug logging

//--- Global variables
int    g_BrokerGMTOffset = 0;
string g_ObjPrefix = "SessionLines_";

//+------------------------------------------------------------------+
//| Get US Eastern Time GMT offset (EST/EDT)                         |
//+------------------------------------------------------------------+
int GetNYGMTOffset(datetime check_time)
  {
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
   march_dt.hour = 0;
   march_dt.min = 0;
   march_dt.sec = 0;
   datetime march_1st = StructToTime(march_dt);
   MqlDateTime m1;
   TimeToStruct(march_1st, m1);
   int march_dow = m1.day_of_week;
   int days_to_sunday = (march_dow == 0) ? 0 : (7 - march_dow);
   int dst_start_day = 1 + days_to_sunday + 7;

   // Find 1st Sunday of November
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
   int dst_end_day = 1 + days_to_nov_sunday;

   bool in_dst = false;
   if(month > 3 && month < 11)
      in_dst = true;
   else if(month == 3 && day >= dst_start_day)
      in_dst = true;
   else if(month == 11 && day < dst_end_day)
      in_dst = true;

   return in_dst ? -4 : -5;
  }

//+------------------------------------------------------------------+
//| Get UK GMT offset (GMT/BST)                                       |
//+------------------------------------------------------------------+
int GetLondonGMTOffset(datetime check_time)
  {
   MqlDateTime dt;
   TimeToStruct(check_time, dt);

   int year = dt.year;
   int month = dt.mon;
   int day = dt.day;

   // Find last Sunday of March
   MqlDateTime march_dt;
   march_dt.year = year;
   march_dt.mon = 3;
   march_dt.day = 31;
   march_dt.hour = 0;
   march_dt.min = 0;
   march_dt.sec = 0;
   datetime march_31 = StructToTime(march_dt);
   MqlDateTime m31;
   TimeToStruct(march_31, m31);
   int march_dow = m31.day_of_week;
   int dst_start_day = 31 - march_dow;

   // Find last Sunday of October
   MqlDateTime oct_dt;
   oct_dt.year = year;
   oct_dt.mon = 10;
   oct_dt.day = 31;
   oct_dt.hour = 0;
   oct_dt.min = 0;
   oct_dt.sec = 0;
   datetime oct_31 = StructToTime(oct_dt);
   MqlDateTime o31;
   TimeToStruct(oct_31, o31);
   int oct_dow = o31.day_of_week;
   int dst_end_day = 31 - oct_dow;

   bool in_bst = false;
   if(month > 3 && month < 10)
      in_bst = true;
   else if(month == 3 && day >= dst_start_day)
      in_bst = true;
   else if(month == 10 && day < dst_end_day)
      in_bst = true;

   return in_bst ? 1 : 0;
  }

//+------------------------------------------------------------------+
//| Calculate broker GMT offset                                       |
//+------------------------------------------------------------------+
int CalculateBrokerGMTOffset()
  {
   datetime server_time = TimeCurrent();
   datetime gmt_time = TimeGMT();
   int offset_seconds = (int)(server_time - gmt_time);
   return offset_seconds / 3600;
  }

//+------------------------------------------------------------------+
//| Convert session time to server time                               |
//+------------------------------------------------------------------+
datetime SessionTimeToServerTime(int session_hour, int session_minute, datetime date, int session_gmt_offset)
  {
   MqlDateTime dt;
   TimeToStruct(date, dt);

   int gmt_hour = session_hour - session_gmt_offset;
   int gmt_minute = session_minute;
   int server_hour = gmt_hour + g_BrokerGMTOffset;
   int server_minute = gmt_minute;

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
//| Make color semi-transparent (add alpha channel)                  |
//| MQL5 color format: 0xAABBGGRR (AA=alpha, 00=opaque, FF=transparent)|
//+------------------------------------------------------------------+
color MakeTransparent(color clr, uchar alpha)
  {
   // Extract RGB components
   uchar r = (uchar)(clr & 0xFF);
   uchar g = (uchar)((clr >> 8) & 0xFF);
   uchar b = (uchar)((clr >> 16) & 0xFF);
   // Combine with alpha (for chart objects, higher alpha = more transparent)
   return (color)((alpha << 24) | (b << 16) | (g << 8) | r);
  }

//+------------------------------------------------------------------+
//| Create vertical line at specified time                           |
//+------------------------------------------------------------------+
void CreateVerticalLine(string name, datetime time, color clr, color label_clr, string label_text)
  {
   // Delete if exists
   ObjectDelete(0, name);

   // Create vertical line with semi-transparency
   bool created = ObjectCreate(0, name, OBJ_VLINE, 0, time, 0);
   if(!created)
     {
      if(InpDebugMode)
         PrintFormat("ERROR: Failed to create VLINE '%s' at %s, error=%d", name, TimeToString(time), GetLastError());
      return;
     }

   // Apply semi-transparent color (alpha 128 = 50% transparent)
   color transparentClr = MakeTransparent(clr, 128);
   ObjectSetInteger(0, name, OBJPROP_COLOR, transparentClr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, InpLineStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, InpLineWidth);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);           // Draw behind candles
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_RAY, true);

   // Create label at top if enabled
   if(InpShowLabel && StringLen(label_text) > 0)
     {
      string label_name = name + "_Lbl";
      ObjectDelete(0, label_name);

      double top_price = ChartGetDouble(0, CHART_PRICE_MAX);
      double bottom_price = ChartGetDouble(0, CHART_PRICE_MIN);
      double range = top_price - bottom_price;
      double label_price = top_price - (range * 0.03);

      bool label_created = ObjectCreate(0, label_name, OBJ_TEXT, 0, time, label_price);
      if(label_created)
        {
         ObjectSetString(0, label_name, OBJPROP_TEXT, label_text);
         ObjectSetInteger(0, label_name, OBJPROP_COLOR, label_clr);
         ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, InpLabelFontSize);
         ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
         ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, true);
        }
     }
  }

//+------------------------------------------------------------------+
//| Create horizontal strip at top of chart                          |
//+------------------------------------------------------------------+
void CreateTopStrip(string name, datetime time_start, datetime time_end, color clr)
  {
   if(!InpShowTopStrip)
      return;

   ObjectDelete(0, name);

   // Get chart price range
   double top_price = ChartGetDouble(0, CHART_PRICE_MAX);
   double bottom_price = ChartGetDouble(0, CHART_PRICE_MIN);
   double range = top_price - bottom_price;

   // Strip at top (height = InpStripHeight% of chart)
   double strip_top = top_price;
   double strip_bottom = top_price - (range * InpStripHeight / 100.0);

   bool created = ObjectCreate(0, name, OBJ_RECTANGLE, 0, time_start, strip_top, time_end, strip_bottom);
   if(!created)
     {
      if(InpDebugMode)
         PrintFormat("ERROR: Failed to create strip '%s', error=%d", name, GetLastError());
      return;
     }

   // Semi-transparent fill
   color transparentClr = MakeTransparent(clr, 160);  // More transparent than lines
   ObjectSetInteger(0, name, OBJPROP_COLOR, transparentClr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 0);  // No border
  }

//+------------------------------------------------------------------+
//| Create session markers for a specific day                        |
//+------------------------------------------------------------------+
void CreateSessionMarkers(string session_name, datetime day_start, int index,
                          int open_hour, int open_minute, int close_hour, int close_minute,
                          int session_gmt_offset, color session_color, color label_color)
  {
   datetime session_open = SessionTimeToServerTime(open_hour, open_minute, day_start, session_gmt_offset);
   datetime session_close = SessionTimeToServerTime(close_hour, close_minute, day_start, session_gmt_offset);

   if(InpDebugMode)
     {
      PrintFormat("DEBUG [%s] Day=%d: Input=%02d:%02d-%02d:%02d, GMT_Off=%+d, Calculated: Open=%s, Close=%s",
                  session_name, index, open_hour, open_minute, close_hour, close_minute,
                  session_gmt_offset,
                  TimeToString(session_open, TIME_DATE | TIME_MINUTES),
                  TimeToString(session_close, TIME_DATE | TIME_MINUTES));
     }

   if(session_open >= session_close)
     {
      if(InpDebugMode)
         PrintFormat("DEBUG [%s] Day=%d: SKIP - session_open >= session_close", session_name, index);
      return;
     }

   // Skip weekends
   MqlDateTime dt_open;
   TimeToStruct(session_open, dt_open);
   if(dt_open.day_of_week == 0 || dt_open.day_of_week == 6)
     {
      if(InpDebugMode)
         PrintFormat("DEBUG [%s] Day=%d: SKIP - weekend (dow=%d)", session_name, index, dt_open.day_of_week);
      return;
     }

   // Get bar indices
   int bar_start = iBarShift(_Symbol, _Period, session_open);
   int bar_end = iBarShift(_Symbol, _Period, session_close);

   if(InpDebugMode)
     {
      PrintFormat("DEBUG [%s] Day=%d: bar_start=%d, bar_end=%d", session_name, index, bar_start, bar_end);
     }

   // Don't skip if bar_end is -1 (session still open) - just draw the open line
   if(bar_start < 0)
     {
      if(InpDebugMode)
         PrintFormat("DEBUG [%s] Day=%d: SKIP - bar_start < 0", session_name, index);
      return;
     }

   // Create start line with label
   string open_name = g_ObjPrefix + session_name + "_Open_" + IntegerToString(index);
   CreateVerticalLine(open_name, session_open, session_color, label_color, session_name);
   if(InpDebugMode)
      PrintFormat("DEBUG [%s] Day=%d: Created open line at %s", session_name, index, TimeToString(session_open, TIME_DATE | TIME_MINUTES));

   // Create end line only if session has closed (bar_end >= 0)
   if(bar_end >= 0)
     {
      string close_name = g_ObjPrefix + session_name + "_Close_" + IntegerToString(index);
      CreateVerticalLine(close_name, session_close, session_color, label_color, "");
      if(InpDebugMode)
         PrintFormat("DEBUG [%s] Day=%d: Created close line at %s", session_name, index, TimeToString(session_close, TIME_DATE | TIME_MINUTES));

      // Create horizontal strip at top spanning the session
      string strip_name = g_ObjPrefix + session_name + "_Strip_" + IntegerToString(index);
      CreateTopStrip(strip_name, session_open, session_close, session_color);
     }
   else
     {
      // Session still open - create strip from open to current time
      string strip_name = g_ObjPrefix + session_name + "_Strip_" + IntegerToString(index);
      CreateTopStrip(strip_name, session_open, TimeCurrent(), session_color);
      if(InpDebugMode)
         PrintFormat("DEBUG [%s] Day=%d: Session still open, strip to current time", session_name, index);
     }
  }

//+------------------------------------------------------------------+
//| Update label positions to chart top                              |
//+------------------------------------------------------------------+
void UpdateLabelPositions()
  {
   double top_price = ChartGetDouble(0, CHART_PRICE_MAX);
   double bottom_price = ChartGetDouble(0, CHART_PRICE_MIN);
   double range = top_price - bottom_price;

   // Position labels 3% below top to ensure visibility
   double label_price = top_price - (range * 0.03);

   int total = ObjectsTotal(0);
   for(int i = 0; i < total; i++)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, g_ObjPrefix) == 0 && StringFind(name, "_Lbl") > 0)
        {
         // Move label to near-top price
         datetime label_time = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
         ObjectMove(0, name, 0, label_time, label_price);
        }
     }
  }

//+------------------------------------------------------------------+
//| Update strip positions to stay at chart top                      |
//+------------------------------------------------------------------+
void UpdateStripPositions()
  {
   if(!InpShowTopStrip)
      return;

   double top_price = ChartGetDouble(0, CHART_PRICE_MAX);
   double bottom_price = ChartGetDouble(0, CHART_PRICE_MIN);
   double range = top_price - bottom_price;

   // Strip at top (height = InpStripHeight% of chart)
   double strip_top = top_price;
   double strip_bottom = top_price - (range * InpStripHeight / 100.0);

   int total = ObjectsTotal(0);
   for(int i = 0; i < total; i++)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, g_ObjPrefix) == 0 && StringFind(name, "_Strip_") > 0)
        {
         // Get existing time coordinates
         datetime time_start = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
         datetime time_end = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);

         // Move both anchor points to new price levels
         ObjectMove(0, name, 0, time_start, strip_top);
         ObjectMove(0, name, 1, time_end, strip_bottom);
        }
     }
  }

//+------------------------------------------------------------------+
//| Draw all session markers                                          |
//+------------------------------------------------------------------+
void DrawSessions()
  {
   DeleteAllObjects();

   datetime current_time = TimeCurrent();

   if(InpDebugMode)
     {
      PrintFormat("=== DrawSessions START === CurrentTime=%s, BrokerGMT=%+d, MaxDays=%d",
                  TimeToString(current_time, TIME_DATE | TIME_MINUTES), g_BrokerGMTOffset, InpMaxDaysBack);
     }

   for(int day = 0; day < InpMaxDaysBack; day++)
     {
      datetime check_date = current_time - day * 86400;

      MqlDateTime day_dt;
      TimeToStruct(check_date, day_dt);
      day_dt.hour = 12;
      day_dt.min = 0;
      day_dt.sec = 0;
      datetime day_start = StructToTime(day_dt);

      if(InpShowNY)
        {
         int ny_offset = GetNYGMTOffset(day_start);
         CreateSessionMarkers("NY", day_start, day,
                              InpNYOpenHour, InpNYOpenMinute,
                              InpNYCloseHour, InpNYCloseMinute,
                              ny_offset, InpNYColor, InpNYLabelColor);
        }

      if(InpShowLondon)
        {
         int london_offset = GetLondonGMTOffset(day_start);
         CreateSessionMarkers("LDN", day_start, day,
                              InpLondonOpenHour, InpLondonOpenMinute,
                              InpLondonCloseHour, InpLondonCloseMinute,
                              london_offset, InpLondonColor, InpLondonLabelColor);
        }
     }

   // Count objects created
   int obj_count = 0;
   int total = ObjectsTotal(0);
   for(int i = 0; i < total; i++)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, g_ObjPrefix) == 0)
         obj_count++;
     }

   if(InpDebugMode)
      PrintFormat("=== DrawSessions END === Objects created: %d", obj_count);

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpNYOpenHour < 0 || InpNYOpenHour > 23 ||
      InpNYCloseHour < 0 || InpNYCloseHour > 23 ||
      InpLondonOpenHour < 0 || InpLondonOpenHour > 23 ||
      InpLondonCloseHour < 0 || InpLondonCloseHour > 23)
     {
      Print("ERROR: Invalid time parameters");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpAutoDetectGMT)
     {
      g_BrokerGMTOffset = CalculateBrokerGMTOffset();
      PrintFormat("Auto-detected broker GMT offset: %+d hours", g_BrokerGMTOffset);
     }
   else
     {
      g_BrokerGMTOffset = InpBrokerGMTOffset;
     }

   datetime now = TimeCurrent();
   int ny_offset = GetNYGMTOffset(now);
   int london_offset = GetLondonGMTOffset(now);

   Print("Trading Sessions Lines v2.0.0 - Lightweight Markers");
   PrintFormat("  Max days back: %d", InpMaxDaysBack);

   if(InpShowNY)
      PrintFormat("  NY: %02d:%02d - %02d:%02d ET (GMT%+d)",
                  InpNYOpenHour, InpNYOpenMinute, InpNYCloseHour, InpNYCloseMinute, ny_offset);

   if(InpShowLondon)
      PrintFormat("  London: %02d:%02d - %02d:%02d UK (GMT%+d)",
                  InpLondonOpenHour, InpLondonOpenMinute, InpLondonCloseHour, InpLondonCloseMinute, london_offset);

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
   static ENUM_TIMEFRAMES last_period = PERIOD_CURRENT;
   datetime current_bar_time = iTime(_Symbol, _Period, 0);

   // Force redraw on timeframe change or first calculation
   if(prev_calculated == 0 || _Period != last_period)
     {
      last_bar_time = 0;  // Reset to force redraw
      last_period = _Period;
      if(InpDebugMode)
         PrintFormat("DEBUG: Timeframe changed or first calc, forcing redraw. Period=%d", _Period);
     }

   if(last_bar_time != current_bar_time)
     {
      last_bar_time = current_bar_time;
      DrawSessions();
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| ChartEvent handler - update labels and strips when chart scales  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id == CHARTEVENT_CHART_CHANGE)
     {
      // Update positions to keep them at chart top during scaling
      UpdateLabelPositions();
      UpdateStripPositions();
      ChartRedraw(0);
     }
  }
//+------------------------------------------------------------------+
