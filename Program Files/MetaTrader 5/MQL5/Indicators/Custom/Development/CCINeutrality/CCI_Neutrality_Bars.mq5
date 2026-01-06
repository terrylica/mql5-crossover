//+------------------------------------------------------------------+
//|                                           CCI_Neutrality_Bars.mq5 |
//|            Time-Aligned Trading Day Percentile Window Version    |
//|                                                                  |
//| ALGORITHM:                                                       |
//| For current bar at time T (e.g., 14:30):                         |
//| 1. Find bar at ~same time T on each of past N trading days       |
//| 2. From each anchor bar, take X bars BACKWARD only               |
//| 3. Collect all CCI values for percentile ranking                 |
//| 4. No look-ahead bias (backward only = no repainting)            |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property link        "https://github.com/terrylica/mql5-crossover"
#property version     "2.00"
#property description "Colors OHLC bars based on CCI percentile rank across trading days"
#property description "Time-aligned: compares same time-of-day across N trading days"

#property indicator_chart_window
#property indicator_buffers 7  // 7 buffers: OHLC (4) + Color (1) + CCI (1) + Score (1)
#property indicator_plots   1  // Only 1 visible plot (colored OHLC bars)

// Force recalculation in Strategy Tester
#property tester_everytick_calculate

// Plot 1: Colored OHLC Bars Based on CCI Neutrality
#property indicator_label1    "Open;High;Low;Close"
#property indicator_type1     DRAW_COLOR_BARS
#property indicator_color1    clrLightGray,clrNONE,clrNONE  // Index 0=White(Calm), 1=Default(Normal), 2=Default(Volatile)
#property indicator_width1    1

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== CCI Parameters ==="
input int              InpCCILength           = 20;             // CCI period

input group "=== Time-Aligned Window Parameters ==="
input int              InpTradingDays         = 120;            // Trading days to look back
input int              InpBarsPerDay          = 10;             // Backward bars per day anchor
input int              InpTimeToleranceSec    = 300;            // Time match tolerance (seconds)

input group "=== Percentile Threshold ==="
input double           InpCalmThreshold       = 30.0;           // Calm threshold % (volatile = 100 - this)

input group "=== Debug ==="
input bool             InpDebugMode           = false;          // Enable NDJSON debug logging to Files/

//+------------------------------------------------------------------+
//| Indicator Buffers                                                |
//+------------------------------------------------------------------+
double BufOpen[];   // Buffer 0: Open prices (visible)
double BufHigh[];   // Buffer 1: High prices (visible)
double BufLow[];    // Buffer 2: Low prices (visible)
double BufClose[];  // Buffer 3: Close prices (visible)
double BufColor[];  // Buffer 4: Color index (0=White/Calm, 1=Default/Normal, 2=Default/Volatile)
double BufCCI[];    // Buffer 5: Hidden CCI values (for calculation)
double BufScore[];  // Buffer 6: Hidden percentile rank (for calculation)

//+------------------------------------------------------------------+
//| Indicator Handle                                                 |
//+------------------------------------------------------------------+
int hCCI = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Day Boundary Structure                                           |
//| Stores the start of each unique trading day and its first bar    |
//+------------------------------------------------------------------+
struct DayBoundary
  {
   datetime          day_start;      // 00:00:00 of the trading day (midnight)
   int               first_bar_idx;  // Forward index of first bar of this day
  };

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
int g_TotalSampleSize = 0;           // InpTradingDays * InpBarsPerDay (max sample size)
int g_SecondsPerBar = 0;             // Cached PeriodSeconds(_Period)
double g_VolatileThreshold = 0.0;    // Derived volatile threshold (100 - calm threshold)

DayBoundary g_DayBoundaries[];       // Array of unique trading day boundaries
int g_DayBoundaryCount = 0;          // Number of unique trading days found

int g_DebugFileHandle = INVALID_HANDLE;  // File handle for NDJSON debug logging

//+------------------------------------------------------------------+
//| ExtractDateOnly - Strip time component from datetime             |
//|                                                                  |
//| PURPOSE: Extract only the date portion (set time to 00:00:00)    |
//|          Used to detect unique trading days by comparing dates   |
//|                                                                  |
//| PARAMETERS:                                                      |
//|   dt - Input datetime value                                      |
//|                                                                  |
//| RETURNS: datetime at 00:00:00 (midnight) of the same day         |
//|                                                                  |
//| EXAMPLE: 2026.01.06 14:30:00 -> 2026.01.06 00:00:00              |
//+------------------------------------------------------------------+
datetime ExtractDateOnly(datetime dt)
  {
   MqlDateTime mdt;
   TimeToStruct(dt, mdt);  // Decompose datetime into components
   mdt.hour = 0;           // Zero out time components
   mdt.min = 0;
   mdt.sec = 0;
   return StructToTime(mdt);  // Recompose back to datetime
  }

//+------------------------------------------------------------------+
//| ExtractTimeOfDay - Get seconds since midnight                    |
//|                                                                  |
//| PURPOSE: Extract the time-of-day as seconds since midnight       |
//|          Used to find bars at same time across different days    |
//|                                                                  |
//| PARAMETERS:                                                      |
//|   dt - Input datetime value                                      |
//|                                                                  |
//| RETURNS: Integer 0-86399 representing seconds within the day     |
//|                                                                  |
//| EXAMPLE: 14:30:00 -> 52200 (14*3600 + 30*60 + 0)                 |
//+------------------------------------------------------------------+
int ExtractTimeOfDay(datetime dt)
  {
   MqlDateTime mdt;
   TimeToStruct(dt, mdt);
   return mdt.hour * 3600 + mdt.min * 60 + mdt.sec;
  }

//+------------------------------------------------------------------+
//| DebugLog - Write a JSON line to debug file                       |
//|                                                                  |
//| PURPOSE: Append NDJSON line to debug file for forensic analysis  |
//|          Each line is a self-contained JSON object               |
//|                                                                  |
//| PARAMETERS:                                                      |
//|   json_line - Complete JSON string (without newline)             |
//|                                                                  |
//| NOTES: FileFlush ensures immediate write for crash safety        |
//+------------------------------------------------------------------+
void DebugLog(string json_line)
  {
   if(g_DebugFileHandle != INVALID_HANDLE)
     {
      FileWriteString(g_DebugFileHandle, json_line + "\n");
      FileFlush(g_DebugFileHandle);  // Ensure immediate write to disk
     }
  }

//+------------------------------------------------------------------+
//| FormatDateTime - Format datetime as ISO 8601 string              |
//|                                                                  |
//| PURPOSE: Create JSON-friendly datetime string                    |
//|                                                                  |
//| RETURNS: String like "2026-01-06T14:30:00"                       |
//+------------------------------------------------------------------+
string FormatDateTime(datetime dt)
  {
   MqlDateTime mdt;
   TimeToStruct(dt, mdt);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:%02d",
                       mdt.year, mdt.mon, mdt.day,
                       mdt.hour, mdt.min, mdt.sec);
  }

//+------------------------------------------------------------------+
//| FormatDate - Format date only as ISO 8601 string                 |
//|                                                                  |
//| PURPOSE: Create JSON-friendly date string (no time)              |
//|                                                                  |
//| RETURNS: String like "2026-01-06"                                |
//+------------------------------------------------------------------+
string FormatDate(datetime dt)
  {
   MqlDateTime mdt;
   TimeToStruct(dt, mdt);
   return StringFormat("%04d-%02d-%02d", mdt.year, mdt.mon, mdt.day);
  }

//+------------------------------------------------------------------+
//| BuildDayBoundaries - Pre-compute trading day start indices       |
//|                                                                  |
//| PURPOSE: Scan through all bars and identify unique trading days  |
//|          by detecting changes in the date portion of bar times.  |
//|          Results are cached in g_DayBoundaries[] for fast lookup |
//|                                                                  |
//| PARAMETERS:                                                      |
//|   time[]      - Array of bar times from OnCalculate              |
//|   rates_total - Total number of bars available                   |
//|                                                                  |
//| RETURNS: Number of unique trading days found                     |
//|                                                                  |
//| ALGORITHM:                                                       |
//| 1. Iterate through all bars (forward-indexed)                    |
//| 2. Extract date from each bar's time                             |
//| 3. When date changes, record new DayBoundary entry               |
//| 4. Automatically handles weekends/holidays (no data = no entry)  |
//|                                                                  |
//| COMPLEXITY: O(N) where N = rates_total                           |
//+------------------------------------------------------------------+
int BuildDayBoundaries(const datetime &time[], int rates_total)
  {
   // Reset day boundary array
   ArrayResize(g_DayBoundaries, 0);
   g_DayBoundaryCount = 0;

   if(rates_total == 0)
      return 0;

   datetime prev_date = 0;

   // Scan through all bars to find day transitions
   for(int i = 0; i < rates_total; i++)
     {
      datetime current_date = ExtractDateOnly(time[i]);

      // New trading day detected (date changed)
      if(current_date != prev_date)
        {
         // Expand array and store new boundary
         ArrayResize(g_DayBoundaries, g_DayBoundaryCount + 1);
         g_DayBoundaries[g_DayBoundaryCount].day_start = current_date;
         g_DayBoundaries[g_DayBoundaryCount].first_bar_idx = i;
         g_DayBoundaryCount++;
         prev_date = current_date;
        }
     }

   return g_DayBoundaryCount;
  }

//+------------------------------------------------------------------+
//| FindDayBoundaryIndex - Binary search for day in boundaries       |
//|                                                                  |
//| PURPOSE: Find the index in g_DayBoundaries[] for a target date   |
//|          Uses linear search (could optimize to binary if needed) |
//|                                                                  |
//| PARAMETERS:                                                      |
//|   target_date - Date to find (midnight datetime)                 |
//|                                                                  |
//| RETURNS: Index in g_DayBoundaries[] or -1 if not found           |
//+------------------------------------------------------------------+
int FindDayBoundaryIndex(datetime target_date)
  {
   for(int d = 0; d < g_DayBoundaryCount; d++)
     {
      if(g_DayBoundaries[d].day_start == target_date)
         return d;
     }
   return -1;  // Target date not in data
  }

//+------------------------------------------------------------------+
//| FindTimeAlignedBar - Find bar at same time on specific day       |
//|                                                                  |
//| PURPOSE: Given a target date and time-of-day, find the bar index |
//|          that best matches that time on that specific day.       |
//|          Used to find "same time yesterday/last week/etc."       |
//|                                                                  |
//| PARAMETERS:                                                      |
//|   day_idx       - Index in g_DayBoundaries[] for target day      |
//|   target_tod    - Time-of-day in seconds (from ExtractTimeOfDay) |
//|   time[]        - Time array from OnCalculate                    |
//|   rates_total   - Total bars available                           |
//|   tolerance_sec - Maximum time difference allowed (0 = exact)    |
//|                                                                  |
//| RETURNS: Bar index (forward-indexed) or -1 if no match found     |
//|                                                                  |
//| ALGORITHM:                                                       |
//| 1. Get first and last bar indices for the target day             |
//| 2. Linear search through day's bars for closest time match       |
//| 3. Early exit if exact match found                               |
//| 4. Return -1 if best match exceeds tolerance                     |
//|                                                                  |
//| COMPLEXITY: O(bars_in_day), typically 24-288 bars                |
//+------------------------------------------------------------------+
int FindTimeAlignedBar(int day_idx, int target_tod,
                       const datetime &time[], int rates_total,
                       int tolerance_sec)
  {
   if(day_idx < 0 || day_idx >= g_DayBoundaryCount)
      return -1;

   // Get first bar index of this day
   int first_bar = g_DayBoundaries[day_idx].first_bar_idx;

   // Get last bar index of this day
   // (first bar of next day - 1, or rates_total - 1 if this is the last day)
   int last_bar;
   if(day_idx + 1 < g_DayBoundaryCount)
      last_bar = g_DayBoundaries[day_idx + 1].first_bar_idx - 1;
   else
      last_bar = rates_total - 1;

   // Search within day's bars for best time match
   int best_bar = -1;
   int best_diff = INT_MAX;

   for(int i = first_bar; i <= last_bar; i++)
     {
      int bar_tod = ExtractTimeOfDay(time[i]);
      int diff = MathAbs(bar_tod - target_tod);

      // Handle midnight wrap-around (e.g., comparing 23:59 to 00:01)
      // This is unlikely in trading data but safe to handle
      if(diff > 43200)  // More than 12 hours = probably wrap
         diff = 86400 - diff;

      if(diff < best_diff)
        {
         best_diff = diff;
         best_bar = i;
        }

      // Early exit if exact match found
      if(diff == 0)
         break;

      // For forward-indexed time[], bars are chronological
      // If we've passed the target time significantly, no need to continue
      if(bar_tod > target_tod + g_SecondsPerBar)
         break;
     }

   // Check tolerance - reject if best match exceeds allowed difference
   if(tolerance_sec > 0 && best_diff > tolerance_sec)
      return -1;  // Best match exceeds tolerance

   return best_bar;
  }

//+------------------------------------------------------------------+
//| BuildTimeAlignedWindow - Collect CCI values across trading days  |
//|                                                                  |
//| PURPOSE: Build the percentile window by finding time-aligned     |
//|          bars across past N trading days, collecting X bars      |
//|          backward from each anchor point.                        |
//|                                                                  |
//| PARAMETERS:                                                      |
//|   current_bar   - Index of current bar being calculated          |
//|   current_day_idx - Index in g_DayBoundaries for current bar's day|
//|   current_tod   - Time-of-day of current bar (seconds)           |
//|   time[]        - Time array from OnCalculate                    |
//|   cci[]         - CCI values array                               |
//|   rates_total   - Total bars available                           |
//|   window[]      - Output: CCI values for percentile calculation  |
//|   num_days      - Number of trading days to look back            |
//|   bars_per_day  - Bars to take backward from each anchor         |
//|   tolerance_sec - Time matching tolerance                        |
//|   days_sampled  - Output: actual number of days successfully sampled|
//|                                                                  |
//| RETURNS: Actual number of CCI values collected in window[]       |
//|                                                                  |
//| ALGORITHM:                                                       |
//| 1. Starting from current day, iterate BACKWARD through days      |
//| 2. For each day, find bar at same time-of-day as current bar     |
//| 3. From anchor bar, collect X bars BACKWARD (including anchor)   |
//| 4. Ensure all collected bars are in the PAST (no look-ahead)     |
//| 5. Stop after num_days trading days have been processed          |
//|                                                                  |
//| CRITICAL: All collected bar indices must be < current_bar        |
//|           This prevents look-ahead bias / repainting             |
//|                                                                  |
//| COMPLEXITY: O(num_days * bars_per_day)                           |
//+------------------------------------------------------------------+
int BuildTimeAlignedWindow(int current_bar, int current_day_idx, int current_tod,
                           const datetime &time[], const double &cci[],
                           int rates_total, double &window[],
                           int num_days, int bars_per_day, int tolerance_sec,
                           int &days_sampled)
  {
   int count = 0;
   int max_size = num_days * bars_per_day;
   days_sampled = 0;

   // Iterate BACKWARD through trading days starting from day BEFORE current
   // We start from current_day_idx - 1 because current day's bars at/after
   // current_bar would cause look-ahead bias
   for(int d = current_day_idx - 1; d >= 0 && days_sampled < num_days; d--)
     {
      // Find time-aligned anchor bar on this historical day
      int anchor_bar = FindTimeAlignedBar(d, current_tod, time, rates_total, tolerance_sec);

      if(anchor_bar < 0)
         continue;  // No matching bar on this day (gap, holiday, or tolerance exceeded)

      // Collect bars_per_day values BACKWARD from anchor (including anchor)
      // Sequence: anchor_bar, anchor_bar-1, anchor_bar-2, ..., anchor_bar-(bars_per_day-1)
      datetime anchor_date = g_DayBoundaries[d].day_start;
      int bars_collected_this_day = 0;

      for(int b = 0; b < bars_per_day; b++)
        {
         int bar_idx = anchor_bar - b;

         // Bounds check - can't go before start of data
         if(bar_idx < 0)
            break;

         // Ensure we don't cross into previous day
         // (each day should only contribute bars from that same day)
         datetime bar_date = ExtractDateOnly(time[bar_idx]);
         if(bar_date != anchor_date)
            break;

         // CRITICAL: Ensure bar is in the PAST relative to current bar
         // This prevents look-ahead bias / repainting
         if(bar_idx >= current_bar)
            continue;  // Skip - would be look-ahead

         // Collect absolute CCI value
         if(count < max_size)
           {
            window[count] = MathAbs(cci[bar_idx]);
            count++;
            bars_collected_this_day++;
           }
        }

      // Count this day as sampled if we got at least 1 bar
      if(bars_collected_this_day > 0)
         days_sampled++;
     }

   return count;
  }

//+------------------------------------------------------------------+
//| PercentileRank - Calculate percentile rank of value in window    |
//|                                                                  |
//| PURPOSE: Determine what percentage of window values are below    |
//|          the given value. Used to rank CCI extremity.            |
//|                                                                  |
//| PARAMETERS:                                                      |
//|   value    - Value to rank                                       |
//|   window[] - Array of values to compare against                  |
//|   size     - Number of valid elements in window[]                |
//|                                                                  |
//| RETURNS: Percentile rank as decimal 0.0 to 1.0                   |
//|          0.0 = lowest in window, 1.0 = highest in window         |
//|                                                                  |
//| EXAMPLE: value=85, window=[30,80,150,45,200,60,90,120,75,40]     |
//|          Values below 85: [30,80,45,60,75,40] = 6                |
//|          Percentile = 6/10 = 0.60                                |
//+------------------------------------------------------------------+
double PercentileRank(double value, const double &window[], int size)
  {
   if(size <= 0)
      return 0.5;  // Default to middle if no data

   int count_below = 0;
   for(int i = 0; i < size; i++)
     {
      if(window[i] < value)
         count_below++;
     }
   return (double)count_below / size;
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate inputs
   if(InpCCILength < 1)
     {
      Print("ERROR: CCI period must be >= 1");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpTradingDays < 1)
     {
      Print("ERROR: Trading days must be >= 1");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpBarsPerDay < 1)
     {
      Print("ERROR: Bars per day must be >= 1");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpTimeToleranceSec < 0)
     {
      Print("ERROR: Time tolerance must be >= 0");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpCalmThreshold <= 0.0 || InpCalmThreshold >= 50.0)
     {
      Print("ERROR: Calm threshold must be > 0 and < 50 (percent)");
      return INIT_PARAMETERS_INCORRECT;
     }

//--- Calculate derived values
   g_VolatileThreshold = 100.0 - InpCalmThreshold;
   g_TotalSampleSize = InpTradingDays * InpBarsPerDay;
   g_SecondsPerBar = PeriodSeconds(_Period);

//--- Set indicator buffers (OHLC + Color + Calculations)
   SetIndexBuffer(0, BufOpen, INDICATOR_DATA);         // Buffer 0: Open (visible)
   SetIndexBuffer(1, BufHigh, INDICATOR_DATA);         // Buffer 1: High (visible)
   SetIndexBuffer(2, BufLow, INDICATOR_DATA);          // Buffer 2: Low (visible)
   SetIndexBuffer(3, BufClose, INDICATOR_DATA);        // Buffer 3: Close (visible)
   SetIndexBuffer(4, BufColor, INDICATOR_COLOR_INDEX); // Buffer 4: Color index
   SetIndexBuffer(5, BufCCI, INDICATOR_CALCULATIONS);  // Buffer 5: Hidden CCI
   SetIndexBuffer(6, BufScore, INDICATOR_CALCULATIONS);// Buffer 6: Hidden percentile rank

//--- Set draw begin (need some history before calculation starts)
   int StartCalcPosition = InpCCILength + InpBarsPerDay;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, StartCalcPosition);

//--- Set empty values for all OHLC buffers
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);

//--- Define 3-color palette for price bars
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrLightGray);  // Index 0: Calm/Neutral (WHITE)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrNONE);       // Index 1: Normal (default chart color)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrNONE);       // Index 2: Volatile (default chart color)

//--- Set indicator name with parameter info
   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("CCI Bars(TimeAlign,CCI=%d,Days=%d,BPD=%d)",
                                   InpCCILength, InpTradingDays, InpBarsPerDay));

//--- Create CCI indicator handle (always current timeframe)
   hCCI = iCCI(_Symbol, _Period, InpCCILength, PRICE_TYPICAL);
   if(hCCI == INVALID_HANDLE)
     {
      PrintFormat("ERROR: Failed to create CCI handle, error %d", GetLastError());
      return INIT_FAILED;
     }

//--- Open debug file if debug mode enabled
   if(InpDebugMode)
     {
      string filename = StringFormat("CCI_Neutrality_Debug_%s_%s.ndjson",
                                     _Symbol, EnumToString(_Period));
      g_DebugFileHandle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_ANSI);
      if(g_DebugFileHandle == INVALID_HANDLE)
         PrintFormat("WARNING: Could not open debug file: %s (error %d)", filename, GetLastError());
      else
        {
         // Write initialization event
         string init_json = StringFormat(
                               "{\"event\":\"init\",\"ts\":\"%s\",\"symbol\":\"%s\",\"period\":\"%s\","
                               "\"cci_length\":%d,\"trading_days\":%d,\"bars_per_day\":%d,"
                               "\"tolerance_sec\":%d,\"calm_threshold\":%.1f,\"volatile_threshold\":%.1f}",
                               FormatDateTime(TimeCurrent()), _Symbol, EnumToString(_Period),
                               InpCCILength, InpTradingDays, InpBarsPerDay,
                               InpTimeToleranceSec, InpCalmThreshold, g_VolatileThreshold);
         DebugLog(init_json);
        }
     }

//--- Print initialization summary
   PrintFormat("CCI Neutrality Bars v2.00 (Time-Aligned) initialized:");
   PrintFormat("  CCI Period: %d", InpCCILength);
   PrintFormat("  Trading Days: %d", InpTradingDays);
   PrintFormat("  Bars Per Day: %d", InpBarsPerDay);
   PrintFormat("  Max Sample Size: %d", g_TotalSampleSize);
   PrintFormat("  Time Tolerance: %d seconds", InpTimeToleranceSec);
   PrintFormat("  Bar Colors: White(Calm <%.0f%%), Default(Normal), Default(Volatile >%.0f%%)",
               InpCalmThreshold, g_VolatileThreshold);
   if(InpDebugMode)
      PrintFormat("  Debug Mode: ENABLED - logging to Files/");

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Close debug file if open
   if(g_DebugFileHandle != INVALID_HANDLE)
     {
      FileClose(g_DebugFileHandle);
      g_DebugFileHandle = INVALID_HANDLE;
     }

//--- Release CCI handle
   if(hCCI != INVALID_HANDLE)
     {
      IndicatorRelease(hCCI);
      hCCI = INVALID_HANDLE;
     }

   PrintFormat("CCI Neutrality Bars deinitialized, reason: %d", reason);
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
//--- Minimum bars check
   int min_bars_needed = InpCCILength + InpBarsPerDay;
   if(rates_total < min_bars_needed)
      return 0;

//--- Get CCI data
   static double cci[];
   ArrayResize(cci, rates_total);
   ArraySetAsSeries(cci, false);

   int copied = CopyBuffer(hCCI, 0, 0, rates_total, cci);
   if(copied != rates_total)
     {
      int error = GetLastError();
      if(error == 4806)
         PrintFormat("INFO: CCI data not accessible yet (error 4806), waiting...");
      else
         PrintFormat("ERROR: CopyBuffer failed, copied %d of %d, error %d", copied, rates_total, error);
      return 0;
     }

//--- Build day boundaries on first calculation or after history change
   static int s_last_rates_total = 0;
   if(prev_calculated == 0 || rates_total != s_last_rates_total)
     {
      int days_found = BuildDayBoundaries(time, rates_total);
      PrintFormat("INFO: Built %d trading day boundaries from %d bars", days_found, rates_total);
      s_last_rates_total = rates_total;

      // Debug log: day boundaries event
      if(InpDebugMode && g_DebugFileHandle != INVALID_HANDLE && days_found > 0)
        {
         string first_day = FormatDate(g_DayBoundaries[0].day_start);
         string last_day = FormatDate(g_DayBoundaries[days_found - 1].day_start);
         string boundaries_json = StringFormat(
                                     "{\"event\":\"day_boundaries\",\"ts\":\"%s\",\"days_found\":%d,"
                                     "\"rates_total\":%d,\"first_day\":\"%s\",\"last_day\":\"%s\"}",
                                     FormatDateTime(TimeCurrent()), days_found, rates_total,
                                     first_day, last_day);
         DebugLog(boundaries_json);
        }
     }

//--- Check if we have enough trading days
   if(g_DayBoundaryCount < 2)
     {
      PrintFormat("INFO: Need at least 2 trading days, have %d", g_DayBoundaryCount);
      return 0;
     }

//--- Set arrays as forward-indexed
   ArraySetAsSeries(BufOpen, false);
   ArraySetAsSeries(BufHigh, false);
   ArraySetAsSeries(BufLow, false);
   ArraySetAsSeries(BufClose, false);
   ArraySetAsSeries(BufColor, false);
   ArraySetAsSeries(BufCCI, false);
   ArraySetAsSeries(BufScore, false);

//--- Calculate start position
   int start;
   if(prev_calculated == 0)
     {
      // Start from second trading day's first bar + warmup
      start = g_DayBoundaries[1].first_bar_idx + InpBarsPerDay;
      start = MathMax(start, InpCCILength);

      // Initialize early bars (before calculation starts)
      for(int i = 0; i < start && i < rates_total; i++)
        {
         BufOpen[i] = 0.0;
         BufHigh[i] = 0.0;
         BufLow[i] = 0.0;
         BufClose[i] = 0.0;
         BufColor[i] = 1;  // Default color (index 1 = clrNONE)
         BufCCI[i] = EMPTY_VALUE;
         BufScore[i] = EMPTY_VALUE;
        }
     }
   else
     {
      start = prev_calculated - 1;
     }

//--- Allocate window buffer for percentile calculation
   static double cci_window[];
   ArrayResize(cci_window, g_TotalSampleSize);

//--- Track current day index for efficiency (avoid repeated lookup)
   int cached_day_idx = -1;
   datetime cached_date = 0;

//--- Main calculation loop
   for(int i = start; i < rates_total && !IsStopped(); i++)
     {
      // Determine which trading day this bar belongs to
      datetime bar_date = ExtractDateOnly(time[i]);

      // Update cached day index if date changed
      if(bar_date != cached_date)
        {
         cached_day_idx = FindDayBoundaryIndex(bar_date);
         cached_date = bar_date;
        }

      // Skip if we can't find this bar's day (shouldn't happen)
      if(cached_day_idx < 0)
        {
         BufOpen[i] = 0.0;
         BufHigh[i] = 0.0;
         BufLow[i] = 0.0;
         BufClose[i] = 0.0;
         BufColor[i] = 1;
         BufCCI[i] = cci[i];
         BufScore[i] = EMPTY_VALUE;
         continue;
        }

      // Get current bar's time-of-day
      int current_tod = ExtractTimeOfDay(time[i]);

      // Build time-aligned window across past trading days
      int days_sampled = 0;
      int window_size = BuildTimeAlignedWindow(i, cached_day_idx, current_tod,
                                               time, cci, rates_total,
                                               cci_window, InpTradingDays,
                                               InpBarsPerDay, InpTimeToleranceSec,
                                               days_sampled);

      // Get current CCI value
      double current_cci = cci[i];
      double current_cci_abs = MathAbs(current_cci);

      // Skip if insufficient data (need at least some samples)
      if(window_size < InpBarsPerDay)  // At least one day's worth of samples
        {
         BufOpen[i] = 0.0;
         BufHigh[i] = 0.0;
         BufLow[i] = 0.0;
         BufClose[i] = 0.0;
         BufColor[i] = 1;
         BufCCI[i] = current_cci;
         BufScore[i] = EMPTY_VALUE;

         // Debug log: skip event
         if(InpDebugMode && g_DebugFileHandle != INVALID_HANDLE)
           {
            string skip_json = StringFormat(
                                  "{\"event\":\"skip\",\"bar_idx\":%d,\"bar_time\":\"%s\","
                                  "\"reason\":\"insufficient_data\",\"values_collected\":%d,\"min_required\":%d}",
                                  i, FormatDateTime(time[i]), window_size, InpBarsPerDay);
            DebugLog(skip_json);
           }
         continue;
        }

      // Calculate percentile rank
      double score = PercentileRank(current_cci_abs, cci_window, window_size);

      // Copy OHLC prices from chart data
      BufOpen[i] = open[i];
      BufHigh[i] = high[i];
      BufLow[i] = low[i];
      BufClose[i] = close[i];

      // Assign color based on percentile rank thresholds
      int color_index;
      double score_pct = score * 100.0;  // Convert 0-1 to 0-100 for comparison
      if(score_pct < InpCalmThreshold)
         color_index = 0;       // Index 0: Calm/Neutral (WHITE - paint white)
      else
         if(score_pct <= g_VolatileThreshold)
            color_index = 1;       // Index 1: Normal (default chart colors)
         else
            color_index = 2;       // Index 2: Volatile/Extreme (default chart colors)

      // Store results
      BufColor[i] = color_index;
      BufCCI[i] = current_cci;
      BufScore[i] = score;

      // Debug log: bar calculation (sample every 100th bar during full recalc,
      // or every bar during real-time updates)
      if(InpDebugMode && g_DebugFileHandle != INVALID_HANDLE)
        {
         bool should_log = (prev_calculated == 0 && i % 100 == 0) ||  // Every 100th during full recalc
                           (prev_calculated > 0 && i == rates_total - 1);  // Last bar during real-time

         if(should_log)
           {
            string bar_json = StringFormat(
                                 "{\"event\":\"bar_calc\",\"bar_idx\":%d,\"bar_time\":\"%s\","
                                 "\"bar_tod_sec\":%d,\"cci\":%.2f,\"abs_cci\":%.2f,"
                                 "\"days_sampled\":%d,\"values_collected\":%d,"
                                 "\"score\":%.4f,\"score_pct\":%.1f,\"color_idx\":%d}",
                                 i, FormatDateTime(time[i]), current_tod,
                                 current_cci, current_cci_abs,
                                 days_sampled, window_size,
                                 score, score_pct, color_index);
            DebugLog(bar_json);
           }
        }
     }

//--- Return value for next call
   return rates_total;
  }
//+------------------------------------------------------------------+
