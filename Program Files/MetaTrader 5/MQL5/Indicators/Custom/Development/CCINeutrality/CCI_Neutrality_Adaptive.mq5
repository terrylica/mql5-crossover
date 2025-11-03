//+------------------------------------------------------------------+
//|                                      CCI_Neutrality_Adaptive.mq5 |
//|                      Adaptive Percentile Rank Normalization      |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property link        "https://github.com/terrylica/mql5-crossover"
#property version     "4.22"
#property description "CCI Neutrality Score - Adaptive Percentile Rank with Timeframe Conversion (Red=Volatile/Extreme, Yellow=Normal, Green=Calm/Neutral)"

#property indicator_separate_window
#property indicator_buffers 4  // 4 buffers: Score + CCI + Color + Arrows
#property indicator_plots   2  // 2 visible plots: histogram + arrows

// Force recalculation in Strategy Tester
#property tester_everytick_calculate

// Plot 1: Percentile Rank Score Color Histogram (0-1)
#property indicator_label1    "Percentile Rank"
#property indicator_type1     DRAW_COLOR_HISTOGRAM
#property indicator_width1    3

// Plot 2: Signal Arrows (4 consecutive rising bars)
#property indicator_label2    "Rising Signal"
#property indicator_type2     DRAW_ARROW
#property indicator_color2    clrDodgerBlue
#property indicator_width2    3

//--- Calculation method enum
enum ENUM_CALC_METHOD
{
   METHOD_RESAMPLE = 0,    // Method 1: Resample (use reference TF CCI, exact window)
   METHOD_SCALE    = 1     // Method 2: Scale window (use current TF CCI, scaled window)
};

//--- Input parameters
input group "=== CCI Parameters ==="
input int              InpCCILength           = 20;             // CCI period

input group "=== Calculation Method ==="
input ENUM_CALC_METHOD InpCalcMethod          = METHOD_RESAMPLE; // Calculation method (DEFAULT: Resample)

input group "=== Adaptive Window Parameters ==="
input ENUM_TIMEFRAMES  InpReferenceTimeframe  = PERIOD_CURRENT; // Reference timeframe
input int              InpReferenceWindowBars = 120;            // Window size (in reference timeframe bars)

//--- Indicator buffers
double BufScore[];  // Visible: Percentile rank values (0-1)
double BufCCI[];    // Hidden: CCI (for recalculation handling)
double BufColor[];  // Color index: 0=Red, 1=Yellow, 2=Green
double BufArrows[]; // Visible: Arrow positions (EMPTY_VALUE when no signal)

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

//--- Calculate adaptive window size (depends on calculation method)
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

//--- Set indicator buffers
   SetIndexBuffer(0, BufScore, INDICATOR_DATA);       // Buffer 0: Visible Score
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX); // Buffer 1: Color indices
   SetIndexBuffer(2, BufCCI, INDICATOR_CALCULATIONS);  // Buffer 2: Hidden CCI
   SetIndexBuffer(3, BufArrows, INDICATOR_DATA);      // Buffer 3: Visible Arrows

//--- Configure arrow plot
   PlotIndexSetInteger(1, PLOT_ARROW, 159);           // Arrow code 159 = filled circle
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, -15);     // Shift 15 points UP above histogram
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE); // Use EMPTY_VALUE for gaps
   PlotIndexSetString(1, PLOT_LABEL, "Rising Signal"); // Data window label

//--- Set draw begin (CCI warmup + adaptive window warmup)
   int StartCalcPosition = InpCCILength + g_AdaptiveWindow - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, StartCalcPosition);

//--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Define 3-color palette
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrRed);       // Index 0: Volatile/Extreme (|CCI| > 70th percentile)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrYellow);    // Index 1: Normal (30th-70th percentile)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrLime);      // Index 2: Calm/Neutral (|CCI| < 30th percentile)

//--- Set scale range for percentile rank (0.0 - 1.0)
   IndicatorSetDouble(INDICATOR_MINIMUM, 0.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 1.0);

//--- Set indicator name with timeframe info
   string ref_tf_str = EnumToString(InpReferenceTimeframe);
   if(InpReferenceTimeframe == PERIOD_CURRENT)
      ref_tf_str = EnumToString(_Period);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("CCI Adaptive(%d,TF=%s,W=%d→%d)",
                                   InpCCILength, ref_tf_str,
                                   InpReferenceWindowBars, g_AdaptiveWindow));

//--- Determine CCI timeframe based on calculation method
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

//--- Create CCI indicator handle
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

   PrintFormat("CCI Adaptive v4.22 initialized:");
   PrintFormat("  Method: %s", (InpCalcMethod == METHOD_RESAMPLE) ? "Resample (use ref TF CCI)" : "Scale (scale window size)");
   PrintFormat("  CCI Period: %d", InpCCILength);
   PrintFormat("  CCI Timeframe: %s (%d seconds/bar)", EnumToString(cci_timeframe), PeriodSeconds(cci_timeframe));
   PrintFormat("  Reference Timeframe: %s (%d seconds/bar)", ref_tf_str, PeriodSeconds((InpReferenceTimeframe == PERIOD_CURRENT) ? _Period : InpReferenceTimeframe));
   PrintFormat("  Reference Window: %d bars", InpReferenceWindowBars);
   PrintFormat("  Current Chart: %s (%d seconds/bar)", EnumToString(_Period), PeriodSeconds(_Period));
   PrintFormat("  Window Size: %d bars (%s)", g_AdaptiveWindow, (InpCalcMethod == METHOD_RESAMPLE) ? "exact ref TF" : "scaled to current TF");
   PrintFormat("  Colors: Green(Calm)<30%%<Yellow<70%%<Red(Volatile)");

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

   PrintFormat("CCI Adaptive deinitialized, reason: %d", reason);
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
         return(0);  // Reset - timer will trigger refresh
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
      return(0);  // Reset calculation - let timer trigger refresh
     }

//--- Verify we have minimum warmup bars
   if(cci_bars < StartCalcPosition_CCI)
     {
      PrintFormat("INFO: Need more data for warmup: have %d bars, need %d minimum", cci_bars, StartCalcPosition_CCI);
      return(0);  // Reset - need more historical data
     }

//--- Set arrays as forward-indexed
   ArraySetAsSeries(BufScore, false);
   ArraySetAsSeries(BufColor, false);
   ArraySetAsSeries(BufCCI, false);
   ArraySetAsSeries(BufArrows, false);

//--- Calculate start position
   int start;
   if(prev_calculated == 0)
     {
      start = StartCalcPosition_Chart;

      // Initialize early bars (before warmup complete)
      for(int i = 0; i < start; i++)
        {
         BufScore[i] = EMPTY_VALUE;
         BufColor[i] = 0;
         BufCCI[i] = EMPTY_VALUE;
         BufArrows[i] = EMPTY_VALUE;
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

//--- Main calculation loop
   for(int i = start; i < rates_total && !IsStopped(); i++)
     {
      //--- Determine CCI index and window start based on calculation method
      int cci_index;
      int window_start_cci;

      if(InpCalcMethod == METHOD_RESAMPLE)
        {
         // Method 1: Map current chart bar to reference TF bar using iBarShift
         ENUM_TIMEFRAMES ref_tf = (InpReferenceTimeframe == PERIOD_CURRENT) ? _Period : InpReferenceTimeframe;

         // Special case: if reference TF == current TF, use direct 1:1 mapping
         if(ref_tf == _Period)
           {
            // No resampling needed, 1:1 mapping
            cci_index = i;
            window_start_cci = i - g_AdaptiveWindow + 1;
           }
         else
           {
            // Map current chart bar to reference TF bar
            // iBarShift returns series-indexed position, convert to forward index
            int ref_bar_series = iBarShift(_Symbol, ref_tf, time[i], true);  // exact=true
            if(ref_bar_series < 0)
              {
               // Can't find exact corresponding bar, skip this bar
               continue;
              }

            // Validate returned index by checking actual bar time
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
               // Time mismatch too large, wrong bar returned
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

      //--- Skip if window would go before data starts
      if(window_start_cci < 0)
         continue;

      //--- Build rolling window [window_start_cci, cci_index]
      for(int j = 0; j < g_AdaptiveWindow; j++)
        {
         cci_window[j] = MathAbs(cci[window_start_cci + j]);
        }

      //--- Get current CCI value (use absolute value for volatility measurement)
      double current_cci = cci[cci_index];
      double current_cci_abs = MathAbs(current_cci);

      //--- Calculate percentile rank using absolute CCI (measures extremity, not direction)
      double score = PercentileRank(current_cci_abs, cci_window, g_AdaptiveWindow);

      //--- Assign color based on percentile rank thresholds
      int color_index;
      if(score > 0.7)
         color_index = 0;       // Red: Top 30% (high extremity = volatile/chaotic)
      else if(score > 0.3)
         color_index = 1;       // Yellow: Middle 40% (normal)
      else
         color_index = 2;       // Green: Bottom 30% (low extremity = calm/neutral)

      //--- Store results
      BufCCI[i] = current_cci;      // Hidden buffer
      BufScore[i] = score;          // Visible buffer: percentile rank (0-1)
      BufColor[i] = color_index;    // Color index: 0/1/2

      //--- ✅ Detect 4 consecutive rising histogram bars
      bool is_rising_pattern = false;
      if(i >= 3)  // Need 3 previous bars to check
        {
         // Check if each bar is higher than the previous: [i-3] < [i-2] < [i-1] < [i]
         if(BufScore[i-3] < BufScore[i-2] &&
            BufScore[i-2] < BufScore[i-1] &&
            BufScore[i-1] < BufScore[i])
           {
            is_rising_pattern = true;
           }
        }

      //--- Set arrow position
      if(is_rising_pattern)
        {
         // Position arrow at top of histogram bar
         // PLOT_ARROW_SHIFT (-15) will shift it upward automatically
         BufArrows[i] = score;
        }
      else
        {
         // No arrow on this bar
         BufArrows[i] = EMPTY_VALUE;
        }
     }

//--- Return value for next call
   return rates_total;
  }
//+------------------------------------------------------------------+
