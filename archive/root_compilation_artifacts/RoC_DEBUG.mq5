//+------------------------------------------------------------------+
//|                              CCI_Neutrality_RoC_DEBUG.mq5        |
//|            Rate-of-Change Statistics DEBUG VERSION (Short Windows)|
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property link        "https://github.com/terrylica/mql5-crossover"
#property version     "1.00"
#property description "DEBUG: Calculates RoC statistics with SHORT windows for immediate visualization"
#property description "Uses 7-bar short window and 30-bar long window (vs 14/120 in production)"

#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   4

// Plot 1: Mean Delta (Trend Direction)
#property indicator_label1    "Mean Delta"
#property indicator_type1     DRAW_COLOR_HISTOGRAM
#property indicator_width1    2

// Plot 2: Std Dev Delta (Volatility)
#property indicator_label2    "Volatility"
#property indicator_type2     DRAW_COLOR_HISTOGRAM
#property indicator_width2    3

// Plot 3: Sum Delta (Net Movement)
#property indicator_label3    "Net Movement"
#property indicator_type3     DRAW_COLOR_HISTOGRAM
#property indicator_width3    2

// Plot 4: Max Abs Delta (Largest Jump)
#property indicator_label4    "Max Jump"
#property indicator_type4     DRAW_COLOR_HISTOGRAM
#property indicator_width4    2

//--- Include the reusable percentile normalizer library
#include <Custom/PercentileNormalizer.mqh>

//--- Input parameters (DEBUG: Much shorter windows!)
input group "=== Rate-of-Change Parameters (DEBUG MODE) ====="
input int              InpShortWindow        = 7;      // Short window (delta statistics) - DEBUG: 7 vs 14
input int              InpLongWindow         = 30;     // Long window (normalization) - DEBUG: 30 vs 120
input double           InpLowThreshold       = 0.30;   // Low threshold
input double           InpHighThreshold      = 0.70;   // High threshold

input group "=== Source Indicator Parameters ====="
input string           InpSourceIndicator    = "CCI_Neutrality_Adaptive"; // Source indicator name
input int              InpCCILength          = 20;     // CCI period (passed to source)
input ENUM_TIMEFRAMES  InpReferenceTimeframe = PERIOD_CURRENT; // Reference timeframe (passed to source)
input int              InpReferenceWindowBars = 120;   // Reference window bars (passed to source)

//--- Indicator buffers
double BufMeanDelta[];      // Visible: Mean delta normalized
double BufMeanColor[];      // Color index for mean delta
double BufStdDevDelta[];    // Visible: Std dev delta normalized (volatility)
double BufStdDevColor[];    // Color index for std dev
double BufSumDelta[];       // Visible: Sum delta normalized (net movement)
double BufSumColor[];       // Color index for sum
double BufMaxAbsDelta[];    // Visible: Max abs delta normalized (largest jump)
double BufMaxAbsColor[];    // Color index for max abs

//--- Handles
int hSourceIndicator = INVALID_HANDLE;

//--- RoC statistics calculator instance
CRateOfChangeStatistics *roc_stats = NULL;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate inputs
   if(InpShortWindow < 2)
     {
      Print("ERROR: Short window must be >= 2");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpLongWindow <= InpShortWindow)
     {
      Print("ERROR: Long window must be > short window");
      return INIT_PARAMETERS_INCORRECT;
     }

//--- Set indicator buffers
   SetIndexBuffer(0, BufMeanDelta, INDICATOR_DATA);
   SetIndexBuffer(1, BufMeanColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufStdDevDelta, INDICATOR_DATA);
   SetIndexBuffer(3, BufStdDevColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, BufSumDelta, INDICATOR_DATA);
   SetIndexBuffer(5, BufSumColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(6, BufMaxAbsDelta, INDICATOR_DATA);
   SetIndexBuffer(7, BufMaxAbsColor, INDICATOR_COLOR_INDEX);

//--- Set draw begin (source warmup + RoC calculation warmup)
   int source_warmup = InpCCILength + InpReferenceWindowBars - 1;
   int total_warmup = source_warmup + InpLongWindow + InpShortWindow;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, total_warmup);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, total_warmup);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, total_warmup);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, total_warmup);

//--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Define 3-color palette for all plots
   for(int plot = 0; plot < 4; plot++)
     {
      PlotIndexSetInteger(plot, PLOT_COLOR_INDEXES, 3);
      PlotIndexSetInteger(plot, PLOT_LINE_COLOR, 0, clrRed);       // Index 0: Low
      PlotIndexSetInteger(plot, PLOT_LINE_COLOR, 1, clrYellow);    // Index 1: Medium
      PlotIndexSetInteger(plot, PLOT_LINE_COLOR, 2, clrLime);      // Index 2: High
     }

//--- Set scale range
   IndicatorSetDouble(INDICATOR_MINIMUM, 0.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 1.0);

//--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("CCI RoC DEBUG(%d/%d on %s)",
                                   InpShortWindow, InpLongWindow, InpSourceIndicator));

//--- Create handle to source indicator (CCI_Neutrality_Adaptive)
   hSourceIndicator = iCustom(_Symbol, _Period,
                              "Custom\\Development\\CCINeutrality\\" + InpSourceIndicator,
                              InpCCILength,
                              InpReferenceTimeframe,
                              InpReferenceWindowBars);

   if(hSourceIndicator == INVALID_HANDLE)
     {
      PrintFormat("ERROR: Failed to create handle to %s, error %d",
                  InpSourceIndicator, GetLastError());
      return INIT_FAILED;
     }

//--- Initialize the RoC statistics calculator
   roc_stats = new CRateOfChangeStatistics(InpShortWindow,
                                           InpLongWindow,
                                           InpLowThreshold,
                                           InpHighThreshold);

   if(CheckPointer(roc_stats) == POINTER_INVALID)
     {
      Print("ERROR: Failed to create CRateOfChangeStatistics instance");
      return INIT_FAILED;
     }

   PrintFormat("CCI RoC Statistics DEBUG v1.00 initialized:");
   PrintFormat("  Source: %s", InpSourceIndicator);
   PrintFormat("  Short Window: %d bars (delta statistics) - DEBUG MODE", InpShortWindow);
   PrintFormat("  Long Window: %d bars (normalization) - DEBUG MODE", InpLongWindow);
   PrintFormat("  Total warmup: %d bars (%d source + %d RoC)",
               total_warmup, source_warmup, InpLongWindow + InpShortWindow);
   PrintFormat("  Colors: Red<%.0f%%<Yellow<%.0f%%<Green",
               InpLowThreshold * 100, InpHighThreshold * 100);

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Release source indicator handle
   if(hSourceIndicator != INVALID_HANDLE)
     {
      IndicatorRelease(hSourceIndicator);
      hSourceIndicator = INVALID_HANDLE;
     }

//--- Delete RoC statistics instance
   if(CheckPointer(roc_stats) == POINTER_DYNAMIC)
     {
      delete roc_stats;
      roc_stats = NULL;
     }

   PrintFormat("CCI RoC Statistics DEBUG deinitialized, reason: %d", reason);
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
   int source_warmup = InpCCILength + InpReferenceWindowBars - 1;
   int total_warmup = source_warmup + InpLongWindow + InpShortWindow;

//--- Check if we have enough bars
   if(rates_total <= total_warmup)
     {
      if(prev_calculated == 0)
         PrintFormat("DEBUG: Waiting for bars: %d/%d available", rates_total, total_warmup);
      return 0;
     }

//--- Check source indicator readiness
   int ready = BarsCalculated(hSourceIndicator);
   if(ready < source_warmup)
     {
      if(prev_calculated == 0)
         PrintFormat("DEBUG: Waiting for source indicator: %d/%d bars ready", ready, source_warmup);
      return 0;
     }

   if(prev_calculated == 0)
      PrintFormat("DEBUG: Starting calculations with %d total bars (warmup=%d)", rates_total, total_warmup);

//--- Get source indicator data (buffer 0 = percentile rank scores)
   static double source_data[];
   ArrayResize(source_data, rates_total);
   ArraySetAsSeries(source_data, false);

   int copied = CopyBuffer(hSourceIndicator, 0, 0, rates_total, source_data);
   if(copied < rates_total)
     {
      PrintFormat("ERROR: CopyBuffer failed, copied %d of %d bars", copied, rates_total);
      return prev_calculated;
     }

//--- Set arrays as forward-indexed
   ArraySetAsSeries(BufMeanDelta, false);
   ArraySetAsSeries(BufMeanColor, false);
   ArraySetAsSeries(BufStdDevDelta, false);
   ArraySetAsSeries(BufStdDevColor, false);
   ArraySetAsSeries(BufSumDelta, false);
   ArraySetAsSeries(BufSumColor, false);
   ArraySetAsSeries(BufMaxAbsDelta, false);
   ArraySetAsSeries(BufMaxAbsColor, false);

//--- Calculate start position
   int start;
   if(prev_calculated == 0)
     {
      start = total_warmup;

      // Initialize early bars (before warmup complete)
      for(int i = 0; i < start; i++)
        {
         BufMeanDelta[i] = EMPTY_VALUE;
         BufMeanColor[i] = 0;
         BufStdDevDelta[i] = EMPTY_VALUE;
         BufStdDevColor[i] = 0;
         BufSumDelta[i] = EMPTY_VALUE;
         BufSumColor[i] = 0;
         BufMaxAbsDelta[i] = EMPTY_VALUE;
         BufMaxAbsColor[i] = 0;
        }

      PrintFormat("DEBUG: Initialized %d warmup bars", start);
     }
   else
     {
      start = prev_calculated - 1;
      if(start < total_warmup)
         start = total_warmup;
     }

//--- Main calculation loop
   int calculated_count = 0;
   for(int i = start; i < rates_total && !IsStopped(); i++)
     {
      // Skip if source has no data yet
      if(source_data[i] == EMPTY_VALUE)
        {
         BufMeanDelta[i] = EMPTY_VALUE;
         BufMeanColor[i] = 0;
         BufStdDevDelta[i] = EMPTY_VALUE;
         BufStdDevColor[i] = 0;
         BufSumDelta[i] = EMPTY_VALUE;
         BufSumColor[i] = 0;
         BufMaxAbsDelta[i] = EMPTY_VALUE;
         BufMaxAbsColor[i] = 0;
         continue;
        }

      //--- Calculate RoC statistics using the library
      double mean_norm, stddev_norm, sum_norm, max_abs_norm;

      bool success = roc_stats.Calculate(source_data, i, rates_total,
                                         mean_norm, stddev_norm,
                                         sum_norm, max_abs_norm);

      if(!success || mean_norm == EMPTY_VALUE)
        {
         BufMeanDelta[i] = EMPTY_VALUE;
         BufMeanColor[i] = 0;
         BufStdDevDelta[i] = EMPTY_VALUE;
         BufStdDevColor[i] = 0;
         BufSumDelta[i] = EMPTY_VALUE;
         BufSumColor[i] = 0;
         BufMaxAbsDelta[i] = EMPTY_VALUE;
         BufMaxAbsColor[i] = 0;
         continue;
        }

      //--- Store results and map to color indices
      BufMeanDelta[i] = mean_norm;
      BufMeanColor[i] = CPercentileNormalizer::MapToColorIndex(mean_norm,
                                                                InpLowThreshold,
                                                                InpHighThreshold);

      BufStdDevDelta[i] = stddev_norm;
      BufStdDevColor[i] = CPercentileNormalizer::MapToColorIndex(stddev_norm,
                                                                  InpLowThreshold,
                                                                  InpHighThreshold);

      BufSumDelta[i] = sum_norm;
      BufSumColor[i] = CPercentileNormalizer::MapToColorIndex(sum_norm,
                                                               InpLowThreshold,
                                                               InpHighThreshold);

      BufMaxAbsDelta[i] = max_abs_norm;
      BufMaxAbsColor[i] = CPercentileNormalizer::MapToColorIndex(max_abs_norm,
                                                                  InpLowThreshold,
                                                                  InpHighThreshold);

      calculated_count++;
     }

   if(prev_calculated == 0 && calculated_count > 0)
      PrintFormat("DEBUG: Successfully calculated %d bars starting from bar %d", calculated_count, start);

//--- Return value for next call
   return rates_total;
  }
//+------------------------------------------------------------------+
