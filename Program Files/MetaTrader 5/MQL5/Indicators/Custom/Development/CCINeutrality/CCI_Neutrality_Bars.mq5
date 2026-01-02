//+------------------------------------------------------------------+
//|                                           CCI_Neutrality_Bars.mq5 |
//|                      Price Bar Coloring Based on CCI Neutrality  |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property link        "https://github.com/terrylica/mql5-crossover"
#property version     "1.1.0"
#property description "Colors OHLC bars (not candlesticks) based on CCI Neutrality: White=Calm/Neutral (Green state), Default=Normal/Volatile"

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

//--- Calculation method enum
enum ENUM_CALC_METHOD
  {
   METHOD_RESAMPLE = 0,    // Method 1: Resample (use reference TF CCI, exact window)
   METHOD_SCALE    = 1     // Method 2: Scale window (use current TF CCI, scaled window)
  };

//--- Input parameters
input group "=== CCI Parameters ==="
input int              InpCCILength           = 20;             // CCI period

input group "=== Adaptive Window Parameters ==="
input ENUM_CALC_METHOD InpCalcMethod          = METHOD_RESAMPLE; // Calculation method
input ENUM_TIMEFRAMES  InpReferenceTimeframe  = PERIOD_CURRENT; // Reference timeframe
input int              InpReferenceWindowBars = 120;            // Window size (in reference timeframe bars)

//--- Indicator buffers (DRAW_COLOR_CANDLES requires 4 OHLC + 1 color buffer)
double BufOpen[];   // Buffer 0: Open prices (visible)
double BufHigh[];   // Buffer 1: High prices (visible)
double BufLow[];    // Buffer 2: Low prices (visible)
double BufClose[];  // Buffer 3: Close prices (visible)
double BufColor[];  // Buffer 4: Color index (0=White/Calm, 1=Default/Normal, 2=Default/Volatile)
double BufCCI[];    // Buffer 5: Hidden CCI values (for calculation)
double BufScore[];  // Buffer 6: Hidden percentile rank (for calculation)

//--- Indicator handle
int hCCI = INVALID_HANDLE;

//--- Global variables
int g_AdaptiveWindow = 0;  // Calculated adaptive window size (in current chart timeframe bars)

//+------------------------------------------------------------------+
//| Percentile Rank Calculation Function                            |
//+------------------------------------------------------------------+
double PercentileRank(double value, const double &window[], int size)
  {
   int count_below = 0;
   for(int i = 0; i < size; i++)
     {
      if(window[i] < value)
         count_below++;
     }
   return (double)count_below / size;
  }

//+------------------------------------------------------------------+
//| Calculate Adaptive Window Size Based on Timeframe Conversion    |
//| MQL5 Best Practice: Scale window by timeframe ratio             |
//| Formula: WindowCurrent = WindowRef × (SecondsRef / SecondsCurrent)|
//+------------------------------------------------------------------+
int CalculateAdaptiveWindow(ENUM_TIMEFRAMES reference_tf, int reference_bars)
  {
   // Get seconds per bar for both timeframes
   int ref_seconds = PeriodSeconds(reference_tf);
   int current_seconds = PeriodSeconds(_Period);

   // Handle special case: PERIOD_CURRENT means use chart timeframe (no conversion)
   if(reference_tf == PERIOD_CURRENT || ref_seconds == current_seconds)
     {
      return reference_bars;  // No conversion needed
     }

   // Calculate equivalent bars: maintain same time duration
   // Example: 120 bars on M12 (120 × 12min = 1440min) = 1440 bars on M1
   double calculated_bars = (double)reference_bars * ref_seconds / current_seconds;

   // Use MathFloor (MQL5 community standard) - conservative approach
   int adaptive_window = (int)MathFloor(calculated_bars);

   return MathMax(2, adaptive_window);  // Minimum 2 bars for percentile calculation
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

   if(InpReferenceWindowBars < 2)
     {
      Print("ERROR: Reference window bars must be >= 2");
      return INIT_PARAMETERS_INCORRECT;
     }

//--- Calculate adaptive window size based on method
   if(InpCalcMethod == METHOD_RESAMPLE)
     {
      // Method 1: Use reference timeframe directly, exact window size
      g_AdaptiveWindow = InpReferenceWindowBars;
     }
   else // METHOD_SCALE
     {
      // Method 2: Scale window to current chart timeframe
      g_AdaptiveWindow = CalculateAdaptiveWindow(InpReferenceTimeframe, InpReferenceWindowBars);
     }

   if(g_AdaptiveWindow < 2)
     {
      PrintFormat("ERROR: Calculated adaptive window (%d bars) is too small", g_AdaptiveWindow);
      return INIT_PARAMETERS_INCORRECT;
     }

//--- Set indicator buffers (OHLC + Color + Calculations)
   SetIndexBuffer(0, BufOpen, INDICATOR_DATA);         // Buffer 0: Open (visible)
   SetIndexBuffer(1, BufHigh, INDICATOR_DATA);         // Buffer 1: High (visible)
   SetIndexBuffer(2, BufLow, INDICATOR_DATA);          // Buffer 2: Low (visible)
   SetIndexBuffer(3, BufClose, INDICATOR_DATA);        // Buffer 3: Close (visible)
   SetIndexBuffer(4, BufColor, INDICATOR_COLOR_INDEX); // Buffer 4: Color index
   SetIndexBuffer(5, BufCCI, INDICATOR_CALCULATIONS);  // Buffer 5: Hidden CCI
   SetIndexBuffer(6, BufScore, INDICATOR_CALCULATIONS);// Buffer 6: Hidden percentile rank

//--- Set draw begin (CCI warmup + adaptive window warmup)
   int StartCalcPosition = InpCCILength + g_AdaptiveWindow - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, StartCalcPosition);

//--- Set empty values for all OHLC buffers
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);

//--- Define 3-color palette for price bars
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrLightGray);  // Index 0: Calm/Neutral (GREEN state - faint white)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrNONE);       // Index 1: Normal (YELLOW state - default chart colors)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrNONE);       // Index 2: Volatile (RED state - default chart colors)

//--- Set indicator name with timeframe info
   string ref_tf_str = EnumToString(InpReferenceTimeframe);
   if(InpReferenceTimeframe == PERIOD_CURRENT)
      ref_tf_str = EnumToString(_Period);

   string method_str = (InpCalcMethod == METHOD_RESAMPLE) ? "Resample" : "Scale";
   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("CCI Bars(%s,%d,TF=%s,W=%d→%d)",
                                   method_str, InpCCILength, ref_tf_str,
                                   InpReferenceWindowBars, g_AdaptiveWindow));

//--- Create CCI indicator handle based on method
   ENUM_TIMEFRAMES cci_timeframe;
   if(InpCalcMethod == METHOD_RESAMPLE)
     {
      // Method 1: Use reference timeframe for CCI calculation
      cci_timeframe = (InpReferenceTimeframe == PERIOD_CURRENT) ? _Period : InpReferenceTimeframe;
     }
   else // METHOD_SCALE
     {
      // Method 2: Use current chart timeframe for CCI calculation
      cci_timeframe = _Period;
     }

   hCCI = iCCI(_Symbol, cci_timeframe, InpCCILength, PRICE_TYPICAL);
   if(hCCI == INVALID_HANDLE)
     {
      PrintFormat("ERROR: Failed to create CCI handle, error %d", GetLastError());
      return INIT_FAILED;
     }

//--- For Method 1: Trigger reference timeframe data loading (non-blocking)
   if(InpCalcMethod == METHOD_RESAMPLE && cci_timeframe != _Period)
     {
      // Trigger data loading (non-blocking - MT5 will load asynchronously)
      int ref_bars = Bars(_Symbol, cci_timeframe);
      PrintFormat("  Reference TF: Triggered data load, %d bars currently available", ref_bars);
      PrintFormat("  Note: Data readiness will be checked in OnCalculate()");
     }

//--- Set 1ms timer to trigger OnTimer after first OnCalculate pass
//    This is the community-proven workaround for MTF data synchronization
   EventSetMillisecondTimer(1);
   PrintFormat("  Timer set: OnTimer will refresh chart after first OnCalculate pass");

   PrintFormat("CCI Neutrality Bars v1.0.1 initialized:");
   PrintFormat("  Method: %s", (InpCalcMethod == METHOD_RESAMPLE) ? "Resample (use ref TF CCI)" : "Scale (scale window size)");
   PrintFormat("  CCI Period: %d", InpCCILength);
   PrintFormat("  CCI Timeframe: %s (%d seconds/bar)", EnumToString(cci_timeframe), PeriodSeconds(cci_timeframe));
   PrintFormat("  Reference Timeframe: %s (%d seconds/bar)", ref_tf_str, PeriodSeconds((InpReferenceTimeframe == PERIOD_CURRENT) ? _Period : InpReferenceTimeframe));
   PrintFormat("  Reference Window: %d bars", InpReferenceWindowBars);
   PrintFormat("  Current Chart: %s (%d seconds/bar)", EnumToString(_Period), PeriodSeconds(_Period));
   PrintFormat("  Window Size: %d bars (%s)", g_AdaptiveWindow, (InpCalcMethod == METHOD_RESAMPLE) ? "exact ref TF" : "scaled to current TF");
   PrintFormat("  Bar Colors: White(Calm/Green<30%%), Default(Yellow 30-70%%), Default(Red>70%%)");

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Timer event handler - triggers chart refresh for MTF data sync  |
//+------------------------------------------------------------------+
void OnTimer()
  {
//--- Kill timer immediately (only need one event)
   EventKillTimer();

//--- Force chart refresh to ensure reference TF data is loaded
//    This mimics the "manual chart switch" that makes bars appear
   PrintFormat("OnTimer: Forcing chart refresh to synchronize reference TF data...");
   ChartSetSymbolPeriod(0, _Symbol, _Period);

//--- Optional: Trigger chart redraw
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Clean up timer (if still running)
   EventKillTimer();

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
//--- Calculate warmup requirement (varies by method)
   int StartCalcPosition_Chart = InpCCILength + g_AdaptiveWindow - 1;  // For current chart
   int StartCalcPosition_CCI;  // For CCI indicator

   if(InpCalcMethod == METHOD_RESAMPLE)
     {
      // Method 1: CCI is on reference TF, needs fewer bars (exact window size)
      StartCalcPosition_CCI = InpCCILength + InpReferenceWindowBars - 1;
     }
   else // METHOD_SCALE
     {
      // Method 2: CCI is on current TF, same warmup as chart
      StartCalcPosition_CCI = StartCalcPosition_Chart;
     }

//--- Check if we have enough bars on current chart
   if(rates_total <= StartCalcPosition_Chart)
      return 0;

//--- Get CCI data (simplified pattern from MTF_MA.mq5)
   static double cci[];
   int cci_bars;

   if(InpCalcMethod == METHOD_RESAMPLE)
     {
      // Method 1: CCI is on reference timeframe, get available bars from that TF
      cci_bars = BarsCalculated(hCCI);
      if(cci_bars <= 0)
        {
         PrintFormat("INFO: CCI not ready yet, BarsCalculated returned %d (waiting...)", cci_bars);
         return(0);  // ✅ Reset - timer will trigger refresh
        }
      ArrayResize(cci, cci_bars);
     }
   else // METHOD_SCALE
     {
      // Method 2: CCI is on current timeframe, same as rates_total
      cci_bars = rates_total;
      ArrayResize(cci, rates_total);
     }

   ArraySetAsSeries(cci, false);

//--- ✅ CHECK COPYBUFFER DIRECTLY - this is the actual validation
   int copied = CopyBuffer(hCCI, 0, 0, cci_bars, cci);
   if(copied != cci_bars)
     {
      // Data not ready - this is NORMAL on first call
      int error = GetLastError();
      if(error == 4806)
        {
         PrintFormat("INFO: CCI data not accessible yet (error 4806), waiting for next tick...");
        }
      else
        {
         PrintFormat("ERROR: CopyBuffer failed, copied %d of %d bars, error %d", copied, cci_bars, error);
        }
      return(0);  // ✅ Reset calculation - let timer trigger refresh
     }

//--- Verify we have minimum warmup bars
   if(cci_bars < StartCalcPosition_CCI)
     {
      PrintFormat("INFO: Need more data for warmup: have %d bars, need %d minimum", cci_bars, StartCalcPosition_CCI);
      return(0);  // Reset - need more historical data
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
      start = StartCalcPosition_Chart;

      // Initialize early bars (before warmup complete)
      for(int i = 0; i < start; i++)
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
      if(start < StartCalcPosition_Chart)
         start = StartCalcPosition_Chart;
     }

//--- Rolling window for percentile rank calculation
   static double cci_window[];
   ArrayResize(cci_window, g_AdaptiveWindow);

//--- For Method 1: Ensure reference timeframe data is available
   if(InpCalcMethod == METHOD_RESAMPLE)
     {
      ENUM_TIMEFRAMES ref_tf = (InpReferenceTimeframe == PERIOD_CURRENT) ? _Period : InpReferenceTimeframe;

      // Force MT5 to synchronize reference timeframe data
      int ref_bars = Bars(_Symbol, ref_tf);
      if(ref_bars < StartCalcPosition_CCI)
        {
         PrintFormat("DEBUG: Ref TF not ready: %d bars available, need %d (waiting...)",
                     ref_bars, StartCalcPosition_CCI);
         return prev_calculated;  // Wait for more data
        }

      // Verify we can copy time data
      static datetime ref_times[];
      ArrayResize(ref_times, MathMin(100, ref_bars));  // Just need a sample for iBarShift
      int time_copied = CopyTime(_Symbol, ref_tf, 0, ArraySize(ref_times), ref_times);
      if(time_copied <= 0)
        {
         PrintFormat("DEBUG: Cannot copy ref TF time data (error %d), waiting...", GetLastError());
         return prev_calculated;  // Data not synchronized yet
        }
     }

//--- Main calculation loop
   for(int i = start; i < rates_total && !IsStopped(); i++)
     {
      int cci_index;  // Index to use for CCI array
      int window_start_cci;  // Window start in CCI array

      if(InpCalcMethod == METHOD_RESAMPLE)
        {
         ENUM_TIMEFRAMES ref_tf = (InpReferenceTimeframe == PERIOD_CURRENT) ? _Period : InpReferenceTimeframe;

         // Special case: if reference TF == current TF, use direct mapping (same as Method 2)
         if(ref_tf == _Period)
           {
            // No resampling needed, 1:1 mapping
            cci_index = i;
            window_start_cci = i - g_AdaptiveWindow + 1;
           }
         else
           {
            // Method 1: Map current chart bar to reference TF bar
            // iBarShift returns series-indexed position, convert to forward index
            // ✅ FIX: Use exact=true to force -1 on mismatch instead of approximate match
            int ref_bar_series = iBarShift(_Symbol, ref_tf, time[i], true);
            if(ref_bar_series < 0)
              {
               // Can't find exact corresponding bar, skip this bar
               // This is normal for bars at the edge of available data
               continue;
              }

            // ✅ FIX: Validate returned index by checking actual bar time
            datetime ref_bar_time[1];
            if(CopyTime(_Symbol, ref_tf, ref_bar_series, 1, ref_bar_time) <= 0)
              {
               // Can't read bar time, data not synchronized
               continue;
              }

            // Allow tolerance of 1 reference TF period (bars may not align perfectly)
            int time_delta = (int)MathAbs(ref_bar_time[0] - time[i]);
            int max_delta = PeriodSeconds(ref_tf);
            if(time_delta > max_delta)
              {
               // Time mismatch too large, wrong bar returned (should not happen with exact=true)
               PrintFormat("WARNING: iBarShift returned wrong bar at i=%d: requested=%s, got=%s, delta=%d sec",
                          i, TimeToString(time[i]), TimeToString(ref_bar_time[0]), time_delta);
               continue;
              }
            // Convert series index to forward index: forward = total_bars - series - 1
            cci_index = cci_bars - ref_bar_series - 1;
            if(cci_index < 0 || cci_index >= cci_bars)
              {
               continue;
              }
            window_start_cci = cci_index - g_AdaptiveWindow + 1;
           }
        }
      else // METHOD_SCALE
        {
         // Method 2: Direct 1:1 mapping
         cci_index = i;
         window_start_cci = i - g_AdaptiveWindow + 1;
        }

      //--- Skip if window extends before available data
      if(window_start_cci < 0)
         continue;

      //--- Build rolling window
      for(int j = 0; j < g_AdaptiveWindow; j++)
        {
         cci_window[j] = MathAbs(cci[window_start_cci + j]);
        }

      //--- Get current CCI value (use absolute value for volatility measurement)
      double current_cci = cci[cci_index];
      double current_cci_abs = MathAbs(current_cci);

      //--- Calculate percentile rank using absolute CCI (measures extremity, not direction)
      double score = PercentileRank(current_cci_abs, cci_window, g_AdaptiveWindow);

      //--- Copy OHLC prices from chart data
      BufOpen[i] = open[i];
      BufHigh[i] = high[i];
      BufLow[i] = low[i];
      BufClose[i] = close[i];

      //--- Assign color based on percentile rank thresholds
      // NOTE: Color index mapping is REVERSED from histogram version
      // Index 0 = Calm/White (GREEN state), Index 1 = Normal (YELLOW state), Index 2 = Volatile (RED state)
      int color_index;
      if(score < 0.3)
         color_index = 0;       // Index 0: Calm/Neutral (GREEN state - paint white)
      else if(score <= 0.7)
         color_index = 1;       // Index 1: Normal (YELLOW state - default colors)
      else
         color_index = 2;       // Index 2: Volatile/Extreme (RED state - default colors)

      //--- Store results
      BufColor[i] = color_index;    // Color index: 0=White, 1=Default, 2=Default
      BufCCI[i] = current_cci;      // Hidden buffer: CCI value
      BufScore[i] = score;          // Hidden buffer: percentile rank (0-1)
     }

//--- Return value for next call
   return rates_total;
  }
//+------------------------------------------------------------------+
