//+------------------------------------------------------------------+
//| CCI Rising Test - Phase 5: Arrow Placement                      |
//| Version: 0.7.0 - Detection with arrows and CSV logging          |
//+------------------------------------------------------------------+
#property copyright   "Phase 5: Detection with arrows and CSV audit trail"
#property description "Detects 4 consecutive rising CCI bars, places arrows, logs to CSV"
#property version     "0.7.0"

// Libraries
#include "lib/ArrowManager.mqh"         // Phase 2: Arrow creation/deletion
#include "lib/PatternDetector.mqh"      // Phase 3: Detection logic
#include "lib/CSVLogger.mqh"            // Phase 4: Audit trail
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

// Histogram plot
#property indicator_label1  "CCI Score"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrRed, clrYellow, clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Input parameters
input int InpCCIPeriod = 20;        // CCI Period
input int InpWindowBars = 120;       // Adaptive Window Bars

// Buffers
double BufScore[];       // Histogram values (0-1 range)
double BufColor[];       // Color index: 0=RED, 1=YELLOW, 2=GREEN

// Global variables
int StartCalcPosition;  // CCI period + 1
CSVLogger logger;       // CSV audit trail logger

//+------------------------------------------------------------------+
//| Custom indicator initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("=== CCI Rising Test v0.7.0 - Phase 5: Arrow Placement ===");

   // Set canvas range: 0-5 (5x height for arrows at Y=1.1)
   IndicatorSetDouble(INDICATOR_MINIMUM, 0.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 5.0);

   // Map buffers
   SetIndexBuffer(0, BufScore, INDICATOR_DATA);
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX);

   // Set empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // Calculate start position (need CCI period bars)
   StartCalcPosition = InpCCIPeriod;

   // PHASE 4: Initialize CSV logger
   string symbol = Symbol();
   string timeframe = EnumToString(Period());
   string csv_filename = "CCI_Rising_" + symbol + "_" + timeframe + ".csv";

   if(logger.Open(csv_filename))
     {
      logger.WriteHeader();
      Print("Phase 5: CSV audit trail initialized: ", csv_filename);
     }
   else
      Print("WARNING: Failed to initialize CSV audit trail");

   // PHASE 5: Clean up any existing arrows from previous runs
   int deleted_arrows = DeleteAllArrows(0);
   if(deleted_arrows > 0)
      Print("Phase 5: Cleaned up ", deleted_arrows, " old arrows from previous run");

   Print("Initialization complete: Native CCI + detection + arrows + CSV logging, ", InpCCIPeriod, " period, ", InpWindowBars, "-bar window");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // PHASE 4: Close CSV file (destructor will handle it automatically, but explicit is better)
   logger.Close();

   // PHASE 5: Clean up all detection arrows
   int deleted_arrows = DeleteAllArrows(0);
   int deleted_markers = DeleteTestMarkers(0);

   Print("CCI Rising Test v0.7.0 removed (deleted ", deleted_arrows, " arrows, ", deleted_markers, " test markers)");
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration                                       |
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
   // Ensure we have enough data
   if(rates_total < StartCalcPosition)
      return 0;

   // Determine calculation range
   int start;
   if(prev_calculated == 0)
     {
      // First calculation: initialize all buffers
      ArrayInitialize(BufScore, EMPTY_VALUE);
      ArrayInitialize(BufColor, 0);
      start = StartCalcPosition;
     }
   else
     {
      // Recalculate from start (prevents bar shift issues)
      start = StartCalcPosition;
     }

   // Temporary array to store raw CCI values
   double cci_raw[];
   ArrayResize(cci_raw, rates_total);
   ArrayInitialize(cci_raw, EMPTY_VALUE);

   // Step 1: Calculate raw CCI values for all bars
   for(int i = InpCCIPeriod; i < rates_total; i++)
     {
      // Calculate Typical Price for current bar
      double tp_current = (high[i] + low[i] + close[i]) / 3.0;

      // Calculate SMA of Typical Price over CCI period
      double sum_tp = 0.0;
      for(int j = i - InpCCIPeriod + 1; j <= i; j++)
        {
         double tp = (high[j] + low[j] + close[j]) / 3.0;
         sum_tp += tp;
        }
      double sma_tp = sum_tp / InpCCIPeriod;

      // Calculate Mean Deviation
      double sum_deviation = 0.0;
      for(int j = i - InpCCIPeriod + 1; j <= i; j++)
        {
         double tp = (high[j] + low[j] + close[j]) / 3.0;
         sum_deviation += MathAbs(tp - sma_tp);
        }
      double mean_deviation = sum_deviation / InpCCIPeriod;

      // Calculate CCI
      if(mean_deviation < 0.0000001)
         cci_raw[i] = 0.0;  // Avoid division by zero
      else
         cci_raw[i] = (tp_current - sma_tp) / (0.015 * mean_deviation);
     }

   // Step 2: Normalize CCI values to 0-1 range using adaptive window
   // Use ABSOLUTE values to measure volatility (high |CCI| = volatile)
   for(int i = start; i < rates_total; i++)
     {
      // Skip bars where CCI couldn't be calculated
      if(cci_raw[i] == EMPTY_VALUE)
        {
         BufScore[i] = EMPTY_VALUE;
         BufColor[i] = 1;  // Yellow for empty
         continue;
        }

      // Adaptive window: look back N bars or to start
      int window_start = MathMax(InpCCIPeriod, i - InpWindowBars + 1);

      // Find min/max ABSOLUTE CCI in window (measures volatility magnitude)
      double min_abs_cci = MathAbs(cci_raw[i]);
      double max_abs_cci = MathAbs(cci_raw[i]);

      for(int j = window_start; j <= i; j++)
        {
         // Skip EMPTY_VALUE when finding min/max
         if(cci_raw[j] == EMPTY_VALUE)
            continue;

         double abs_cci = MathAbs(cci_raw[j]);
         if(abs_cci < min_abs_cci) min_abs_cci = abs_cci;
         if(abs_cci > max_abs_cci) max_abs_cci = abs_cci;
        }

      // Normalize ABSOLUTE CCI to 0-1 range (0=calm, 1=volatile)
      double range = max_abs_cci - min_abs_cci;
      double score;

      if(range < 0.0001)
         score = 0.5;  // Neutral if no variation
      else
        {
         double current_abs_cci = MathAbs(cci_raw[i]);
         score = (current_abs_cci - min_abs_cci) / range;
        }

      BufScore[i] = score;

      // DEBUG: Log last 3 bars
      if(i >= rates_total - 3)
        {
         Print("DEBUG Bar[", i, "]: CCI=", DoubleToString(cci_raw[i], 2),
               " |CCI|=", DoubleToString(MathAbs(cci_raw[i]), 2),
               " min_abs=", DoubleToString(min_abs_cci, 2),
               " max_abs=", DoubleToString(max_abs_cci, 2),
               " range=", DoubleToString(range, 4),
               " score=", DoubleToString(score, 4));
        }

      // Assign color based on volatility magnitude
      int color_index;
      if(score > 0.7)
         color_index = 0;  // RED: Top 30% (high volatility - |CCI| far from zero)
      else if(score > 0.3)
         color_index = 1;  // YELLOW: Middle 40% (moderate volatility)
      else
         color_index = 2;  // GREEN: Bottom 30% (low volatility - |CCI| near zero)

      BufColor[i] = color_index;
     }

   // PHASE 3-5: Detection logic + arrow placement
   // Need at least 4 bars to detect pattern (i-3, i-2, i-1, i)
   int pattern_length = 4;
   int detection_count = 0;
   int arrow_count = 0;

   // Get indicator window number for arrow placement
   int window_num = ChartWindowFind();

   for(int i = InpCCIPeriod + pattern_length - 1; i < rates_total; i++)
     {
      // Skip if any bar in the 4-bar window has EMPTY_VALUE
      if(cci_raw[i-3] == EMPTY_VALUE || cci_raw[i-2] == EMPTY_VALUE ||
         cci_raw[i-1] == EMPTY_VALUE || cci_raw[i] == EMPTY_VALUE)
         continue;

      // Get detection details for CSV logging
      DetectionDetails details = GetDetectionDetails(cci_raw, i);

      if(details.pattern_detected)
        {
         detection_count++;

         // PHASE 5: Create arrow at detection point
         double arrow_y = 1.1;  // Fixed Y position above histogram (0-1 range)
         bool arrow_created = CreateArrow(0, window_num, time[i], arrow_y, 108, clrYellow, 3);

         if(arrow_created)
            arrow_count++;

         // PHASE 4-5: Write detection to CSV with arrow placement status
         if(logger.IsOpen())
           {
            logger.WriteDetectionRow(i, time[i], details, arrow_created, arrow_y);
           }

         // Log detection to MT5 log (only last 5 to avoid spam)
         if(i >= rates_total - 5)
           {
            Print("DETECTED: 4 rising CCI bars at bar[", i, "] time=", TimeToString(time[i]),
                  " CCI[i-3]=", DoubleToString(cci_raw[i-3], 2),
                  " CCI[i-2]=", DoubleToString(cci_raw[i-2], 2),
                  " CCI[i-1]=", DoubleToString(cci_raw[i-1], 2),
                  " CCI[i]=", DoubleToString(cci_raw[i], 2),
                  " → Arrow placed at Y=", DoubleToString(arrow_y, 1));
           }
        }
     }

   // Log total detection and arrow counts (only on first calculation or when changed)
   static int last_detection_count = -1;
   static int last_arrow_count = -1;
   if(prev_calculated == 0 || detection_count != last_detection_count || arrow_count != last_arrow_count)
     {
      Print("Phase 5: Detected ", detection_count, " patterns, placed ", arrow_count, " arrows in ", rates_total, " bars");
      last_detection_count = detection_count;
      last_arrow_count = arrow_count;
     }

   return rates_total;
  }
//+------------------------------------------------------------------+
