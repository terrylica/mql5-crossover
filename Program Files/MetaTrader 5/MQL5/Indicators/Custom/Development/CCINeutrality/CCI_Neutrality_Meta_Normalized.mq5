//+------------------------------------------------------------------+
//|                                CCI_Neutrality_Meta_Normalized.mq5 |
//|            Meta-Indicator: Normalizes CCI Adaptive over 14 bars  |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property link        "https://github.com/terrylica/mql5-crossover"
#property version     "1.00"
#property description "Applies 14-bar percentile normalization to CCI Adaptive indicator output"

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   1

// Plot 1: Normalized Score Color Histogram
#property indicator_label1    "Meta Normalized Score"
#property indicator_type1     DRAW_COLOR_HISTOGRAM
#property indicator_width1    3

//--- Include the reusable percentile normalizer library
#include <Custom/PercentileNormalizer.mqh>

//--- Input parameters
input group "=== Meta-Normalization Parameters ===="
input int              InpMetaWindow        = 14;     // Meta normalization window (bars)
input double           InpMetaLowThreshold  = 0.30;   // Low threshold
input double           InpMetaHighThreshold = 0.70;   // High threshold

input group "=== Source Indicator Parameters ===="
input string           InpSourceIndicator   = "CCI_Neutrality_Adaptive"; // Source indicator name
input int              InpCCILength         = 20;     // CCI period (passed to source)
input ENUM_TIMEFRAMES  InpReferenceTimeframe = PERIOD_CURRENT; // Reference timeframe (passed to source)
input int              InpReferenceWindowBars = 120;  // Reference window bars (passed to source)

//--- Indicator buffers
double BufMetaScore[];    // Visible: Meta-normalized score (0-1)
double BufMetaColor[];    // Color index: 0=Red, 1=Yellow, 2=Green
double BufSourceData[];   // Hidden: Source indicator values for rolling window

//--- Handles
int hSourceIndicator = INVALID_HANDLE;

//--- Normalizer instance
CPercentileNormalizer *normalizer = NULL;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate inputs
   if(InpMetaWindow < 2)
     {
      Print("ERROR: Meta normalization window must be >= 2");
      return INIT_PARAMETERS_INCORRECT;
     }

//--- Set indicator buffers
   SetIndexBuffer(0, BufMetaScore, INDICATOR_DATA);        // Buffer 0: Visible
   SetIndexBuffer(1, BufMetaColor, INDICATOR_COLOR_INDEX); // Buffer 1: Color
   SetIndexBuffer(2, BufSourceData, INDICATOR_CALCULATIONS); // Buffer 2: Hidden

//--- Set draw begin (source warmup + meta window warmup)
   // Source indicator needs: InpCCILength + InpReferenceWindowBars - 1
   // Meta normalization needs: InpMetaWindow
   int source_warmup = InpCCILength + InpReferenceWindowBars - 1;
   int total_warmup = source_warmup + InpMetaWindow - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, total_warmup);

//--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Define 3-color palette
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrRed);       // Index 0: Low
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrYellow);    // Index 1: Medium
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrLime);      // Index 2: High

//--- Set scale range
   IndicatorSetDouble(INDICATOR_MINIMUM, 0.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 1.0);

//--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("CCI Meta-Norm(%d bars on %s)",
                                   InpMetaWindow, InpSourceIndicator));

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

//--- Initialize the percentile normalizer
   normalizer = new CPercentileNormalizer(InpMetaWindow,
                                          InpMetaLowThreshold,
                                          InpMetaHighThreshold);

   if(CheckPointer(normalizer) == POINTER_INVALID)
     {
      Print("ERROR: Failed to create CPercentileNormalizer instance");
      return INIT_FAILED;
     }

   PrintFormat("CCI Meta-Normalized v1.00 initialized:");
   PrintFormat("  Source: %s", InpSourceIndicator);
   PrintFormat("  Meta Window: %d bars", InpMetaWindow);
   PrintFormat("  Colors: Red<%.0f%%<Yellow<%.0f%%<Green",
               InpMetaLowThreshold * 100, InpMetaHighThreshold * 100);

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

//--- Delete normalizer instance
   if(CheckPointer(normalizer) == POINTER_DYNAMIC)
     {
      delete normalizer;
      normalizer = NULL;
     }

   PrintFormat("CCI Meta-Normalized deinitialized, reason: %d", reason);
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
   int total_warmup = source_warmup + InpMetaWindow - 1;

//--- Check if we have enough bars
   if(rates_total <= total_warmup)
      return 0;

//--- Check source indicator readiness
   int ready = BarsCalculated(hSourceIndicator);
   if(ready < source_warmup)
      return 0;

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
   ArraySetAsSeries(BufMetaScore, false);
   ArraySetAsSeries(BufMetaColor, false);
   ArraySetAsSeries(BufSourceData, false);

//--- Calculate start position
   int start;
   if(prev_calculated == 0)
     {
      start = total_warmup;

      // Initialize early bars (before warmup complete)
      for(int i = 0; i < start; i++)
        {
         BufMetaScore[i] = EMPTY_VALUE;
         BufMetaColor[i] = 0;
         BufSourceData[i] = EMPTY_VALUE;
        }
     }
   else
     {
      start = prev_calculated - 1;
      if(start < total_warmup)
         start = total_warmup;
     }

//--- Main calculation loop
   for(int i = start; i < rates_total && !IsStopped(); i++)
     {
      // Store source value for rolling window
      BufSourceData[i] = source_data[i];

      // Skip if source has no data yet
      if(source_data[i] == EMPTY_VALUE)
        {
         BufMetaScore[i] = EMPTY_VALUE;
         BufMetaColor[i] = 0;
         continue;
        }

      //--- Apply meta-normalization using the library
      double meta_score = normalizer.Normalize(source_data[i],
                                               source_data,
                                               i,
                                               rates_total);

      if(meta_score == EMPTY_VALUE)
        {
         BufMetaScore[i] = EMPTY_VALUE;
         BufMetaColor[i] = 0;
         continue;
        }

      //--- Map to color index using the library
      int color_index = CPercentileNormalizer::MapToColorIndex(meta_score,
                                                                InpMetaLowThreshold,
                                                                InpMetaHighThreshold);

      //--- Store results
      BufMetaScore[i] = meta_score;
      BufMetaColor[i] = color_index;
     }

//--- Return value for next call
   return rates_total;
  }
//+------------------------------------------------------------------+
