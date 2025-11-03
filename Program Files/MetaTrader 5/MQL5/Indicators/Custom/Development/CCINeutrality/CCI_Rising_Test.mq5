//+------------------------------------------------------------------+
//| CCI Rising Test - Phase 1: Baseline Histogram                   |
//| Version: 0.2.0                                                   |
//+------------------------------------------------------------------+
#property copyright   "Phase 1: Baseline histogram only"
#property description "M1 CCI with RED/YELLOW/GREEN histogram, 5x canvas for future arrows"
#property version     "0.2.0"
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
int HandleCCI_Chart;
int StartCalcPosition_Chart;

//+------------------------------------------------------------------+
//| Custom indicator initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("=== CCI Rising Test v0.2.0 - Phase 1: Baseline Histogram ===");

   // Set canvas range: 0-5 (5x height for future arrows at Y=1.1)
   IndicatorSetDouble(INDICATOR_MINIMUM, 0.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 5.0);

   // Map buffers
   SetIndexBuffer(0, BufScore, INDICATOR_DATA);
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX);

   // Set empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // Create M1 CCI indicator handle (chart timeframe)
   HandleCCI_Chart = iCCI(_Symbol, PERIOD_M1, InpCCIPeriod, PRICE_TYPICAL);
   if(HandleCCI_Chart == INVALID_HANDLE)
     {
      Print("ERROR: Failed to create M1 CCI indicator");
      return INIT_FAILED;
     }

   // Calculate start position (need 2 bars for CCI calculation)
   StartCalcPosition_Chart = 2;

   Print("Initialization complete: M1 CCI, 120-bar window, 5x canvas");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(HandleCCI_Chart != INVALID_HANDLE)
      IndicatorRelease(HandleCCI_Chart);

   Print("CCI Rising Test v0.2.0 removed");
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
   if(rates_total < StartCalcPosition_Chart)
      return 0;

   // Get CCI values
   double cci_values[];
   ArraySetAsSeries(cci_values, true);

   int copied = CopyBuffer(HandleCCI_Chart, 0, 0, rates_total, cci_values);
   if(copied <= 0)
     {
      Print("ERROR: Failed to copy CCI buffer");
      return 0;
     }

   // Determine calculation range
   int start;
   if(prev_calculated == 0)
     {
      // First calculation: initialize all buffers
      ArrayInitialize(BufScore, EMPTY_VALUE);
      ArrayInitialize(BufColor, 0);
      start = StartCalcPosition_Chart;
     }
   else
     {
      // Always recalculate from start (prevents bar shift issues)
      start = StartCalcPosition_Chart;
     }

   // Calculate normalized CCI scores
   for(int i = start; i < rates_total; i++)
     {
      // Adaptive window: look back N bars or to start
      int window_start = MathMax(0, i - InpWindowBars + 1);
      int window_size = i - window_start + 1;

      // Find min/max CCI in window
      double min_cci = cci_values[i];
      double max_cci = cci_values[i];

      for(int j = window_start; j <= i; j++)
        {
         if(cci_values[j] < min_cci) min_cci = cci_values[j];
         if(cci_values[j] > max_cci) max_cci = cci_values[j];
        }

      // Normalize to 0-1 range
      double range = max_cci - min_cci;
      double score;

      if(range < 0.0001)
         score = 0.5;  // Neutral if no variation
      else
         score = (cci_values[i] - min_cci) / range;

      BufScore[i] = score;

      // Assign color: RED (0) < 0.3, YELLOW (1) 0.3-0.7, GREEN (2) > 0.7
      if(score < 0.3)
         BufColor[i] = 0;  // RED
      else if(score < 0.7)
         BufColor[i] = 1;  // YELLOW
      else
         BufColor[i] = 2;  // GREEN
     }

   return rates_total;
  }
//+------------------------------------------------------------------+
