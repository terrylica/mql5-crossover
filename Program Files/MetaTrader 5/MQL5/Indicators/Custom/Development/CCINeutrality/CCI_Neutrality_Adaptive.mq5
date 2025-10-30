//+------------------------------------------------------------------+
//|                                      CCI_Neutrality_Adaptive.mq5 |
//|                      Adaptive Percentile Rank Normalization      |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property link        "https://github.com/terrylica/mql5-crossover"
#property version     "4.20"
#property description "CCI Neutrality Score - Adaptive Percentile Rank with Timeframe Conversion (Red=Volatile/Extreme, Yellow=Normal, Green=Calm/Neutral)"

#property indicator_separate_window
#property indicator_buffers 3  // 3 buffers: Score (visible) + CCI (hidden) + Color (index)
#property indicator_plots   1  // Only 1 visible plot

// Force recalculation in Strategy Tester
#property tester_everytick_calculate

// Plot 1: Percentile Rank Score Color Histogram (0-1)
#property indicator_label1    "Percentile Rank"
#property indicator_type1     DRAW_COLOR_HISTOGRAM
#property indicator_width1    3

//--- Input parameters
input group "=== CCI Parameters ==="
input int              InpCCILength           = 20;             // CCI period

input group "=== Adaptive Window Parameters ==="
input ENUM_TIMEFRAMES  InpReferenceTimeframe  = PERIOD_CURRENT; // Reference timeframe
input int              InpReferenceWindowBars = 120;            // Window size (in reference timeframe bars)

//--- Indicator buffers
double BufScore[];  // Visible: Percentile rank values (0-1)
double BufCCI[];    // Hidden: CCI (for recalculation handling)
double BufColor[];  // Color index: 0=Red, 1=Yellow, 2=Green

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

//--- Calculate adaptive window size for current chart timeframe
   g_AdaptiveWindow = CalculateAdaptiveWindow(InpReferenceTimeframe, InpReferenceWindowBars);

   if(g_AdaptiveWindow < 2)
     {
      PrintFormat("ERROR: Calculated adaptive window (%d bars) is too small", g_AdaptiveWindow);
      return INIT_PARAMETERS_INCORRECT;
     }

//--- Set indicator buffers
   SetIndexBuffer(0, BufScore, INDICATOR_DATA);       // Buffer 0: Visible Score
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX); // Buffer 1: Color indices
   SetIndexBuffer(2, BufCCI, INDICATOR_CALCULATIONS);  // Buffer 2: Hidden CCI

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

//--- Create CCI indicator handle
   hCCI = iCCI(_Symbol, _Period, InpCCILength, PRICE_TYPICAL);
   if(hCCI == INVALID_HANDLE)
     {
      PrintFormat("ERROR: Failed to create CCI handle, error %d", GetLastError());
      return INIT_FAILED;
     }

   PrintFormat("CCI Adaptive v4.10 initialized:");
   PrintFormat("  CCI Period: %d", InpCCILength);
   PrintFormat("  Reference Timeframe: %s (%d seconds/bar)", ref_tf_str, PeriodSeconds(InpReferenceTimeframe));
   PrintFormat("  Reference Window: %d bars", InpReferenceWindowBars);
   PrintFormat("  Current Chart: %s (%d seconds/bar)", EnumToString(_Period), PeriodSeconds(_Period));
   PrintFormat("  Adaptive Window: %d bars (scaled for current timeframe)", g_AdaptiveWindow);
   PrintFormat("  Colors: Green(Calm)<30%%<Yellow<70%%<Red(Volatile)");

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
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
//--- Calculate warmup requirement
   int StartCalcPosition = InpCCILength + g_AdaptiveWindow - 1;

//--- Check if we have enough bars
   if(rates_total <= StartCalcPosition)
      return 0;

//--- Check CCI indicator readiness
   int ready = BarsCalculated(hCCI);
   if(ready < StartCalcPosition)
     {
      return 0;
     }

//--- Get CCI data
   static double cci[];
   ArrayResize(cci, rates_total);
   ArraySetAsSeries(cci, false);

   int copied = CopyBuffer(hCCI, 0, 0, rates_total, cci);
   if(copied < rates_total)
     {
      PrintFormat("ERROR: CopyBuffer failed, copied %d of %d bars", copied, rates_total);
      return prev_calculated;
     }

//--- Set arrays as forward-indexed
   ArraySetAsSeries(BufScore, false);
   ArraySetAsSeries(BufColor, false);
   ArraySetAsSeries(BufCCI, false);

//--- Calculate start position
   int start;
   if(prev_calculated == 0)
     {
      start = StartCalcPosition;

      // Initialize early bars (before warmup complete)
      for(int i = 0; i < start; i++)
        {
         BufScore[i] = EMPTY_VALUE;
         BufColor[i] = 0;
         BufCCI[i] = EMPTY_VALUE;
        }
     }
   else
     {
      start = prev_calculated - 1;
      if(start < StartCalcPosition)
         start = StartCalcPosition;
     }

//--- Rolling window for percentile rank calculation
   static double cci_window[];
   ArrayResize(cci_window, g_AdaptiveWindow);

//--- Main calculation loop
   for(int i = start; i < rates_total && !IsStopped(); i++)
     {
         //--- Build rolling window [i - g_AdaptiveWindow + 1, i]
      int window_start = i - g_AdaptiveWindow + 1;
      for(int j = 0; j < g_AdaptiveWindow; j++)
        {
         cci_window[j] = MathAbs(cci[window_start + j]);
        }

      //--- Get current CCI value (use absolute value for volatility measurement)
      double current_cci = cci[i];
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
     }

//--- Return value for next call
   return rates_total;
  }
//+------------------------------------------------------------------+
