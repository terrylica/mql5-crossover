//+------------------------------------------------------------------+
//|                          CCI_Neutrality_ScoreOnly_ColorHist.mq5 |
//|                Visual version - Color Histogram Neutrality Score |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property link        "https://github.com/terrylica/mql5-crossover"
#property version     "3.51"
#property description "CCI Neutrality Score - Color Histogram with diagnostics"

#property indicator_separate_window
#property indicator_buffers 3  // 3 buffers: Score (visible) + CCI (hidden) + Color (index)
#property indicator_plots   1  // Only 1 visible plot

// Force recalculation in Strategy Tester
#property tester_everytick_calculate

//--- Include modular CSV export
#include "CCINeutralityCSVExport.mqh"

// Plot 1: Neutrality Score Color Histogram (0-1)
#property indicator_label1    "Neutrality Score"
#property indicator_type1     DRAW_COLOR_HISTOGRAM
#property indicator_width1    3

//--- Input parameters
input group "=== CCI Parameters ==="
input int    InpCCILength     = 20;      // CCI period
input int    InpWindow        = 30;      // Window W for statistics

input group "=== Neutrality Thresholds ==="
input int    InpMinStreak     = 5;       // Min in-channel streak
input double InpMinInChannel  = 0.80;    // Min fraction inside [-100,100]
input double InpMaxMean       = 20.0;    // Max |mean CCI|
input double InpMaxStdev      = 30.0;    // Max stdev of CCI
input double InpMinScore      = 0.80;    // Score threshold (tau)

input group "=== Score Components ==="
input double InpC0            = 50.0;    // Centering constant C0
input double InpC1            = 50.0;    // Dispersion constant C1
input double InpC2            = 100.0;   // Breach magnitude constant C2

input group "=== Color Thresholds ==="
input double InpLowThreshold  = 0.03;    // Low/Chaotic threshold (Red below)
input double InpHighThreshold = 0.06;    // High/Neutral threshold (Green above)

input group "=== CSV Export ==="
input bool   InpEnableCSV     = false;   // Enable CSV export

//--- Indicator buffers
double BufScore[];  // Visible: Score values
double BufCCI[];    // Hidden: CCI (for recalculation handling)
double BufColor[];  // Color index: 0=Red, 1=Yellow, 2=Green

//--- Indicator handle
int hCCI = INVALID_HANDLE;

//--- CSV export module
CCINeutralityCSVExport csv_export;

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

   if(InpWindow < 2)
     {
      Print("ERROR: Window W must be >= 2");
      return INIT_PARAMETERS_INCORRECT;
     }

//--- Set indicator buffers
   SetIndexBuffer(0, BufScore, INDICATOR_DATA);       // Buffer 0: Visible Score
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX); // Buffer 1: Color indices
   SetIndexBuffer(2, BufCCI, INDICATOR_CALCULATIONS);  // Buffer 2: Hidden CCI

//--- Set draw begin (MQL5 idiomatic: CCI warmup + window warmup)
   int StartCalcPosition = InpCCILength + InpWindow - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, StartCalcPosition);

//--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Define 3-color palette
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrRed);       // Index 0: Low/Chaotic
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrYellow);    // Index 1: Medium
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrLime);      // Index 2: High/Neutral

//--- Explicitly set scale range for small values (FIX for blank display)
   // MT5 doesn't auto-scale well for very small values (0.00-0.05)
   // Explicitly force the visible range to 0.0 - 0.1
   IndicatorSetDouble(INDICATOR_MINIMUM, 0.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 0.1);

//--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("CCI Neutrality Score ColorHist(%d,%d)", InpCCILength, InpWindow));

//--- Create CCI indicator handle
   hCCI = iCCI(_Symbol, _Period, InpCCILength, PRICE_TYPICAL);
   if(hCCI == INVALID_HANDLE)
     {
      PrintFormat("ERROR: Failed to create CCI handle, error %d", GetLastError());
      return INIT_FAILED;
     }

   PrintFormat("CCI Neutrality Score ColorHist initialized: CCI=%d, W=%d, Colors: Red<%.2f<Yellow<%.2f<Green",
               InpCCILength, InpWindow, InpLowThreshold, InpHighThreshold);

//--- Initialize CSV export module
   if(!csv_export.Init(_Symbol, _Period, InpEnableCSV))
     {
      PrintFormat("WARNING: CSV export initialization failed");
     }
   else if(InpEnableCSV)
     {
      csv_export.WriteHeader(InpCCILength, InpWindow);
      PrintFormat("CSV export enabled");
     }

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

//--- CSV export cleanup handled by destructor

   PrintFormat("CCI Neutrality Score ColorHist deinitialized, reason: %d", reason);
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
//--- Calculate warmup requirement (MQL5 idiomatic pattern)
   int StartCalcPosition = InpCCILength + InpWindow - 1;

//--- Check if we have enough bars
   if(rates_total <= StartCalcPosition)
     {
      PrintFormat("DIAGNOSTIC: Not enough bars - have %d, need %d", rates_total, StartCalcPosition + 1);
      return 0;
     }

//--- Check CCI indicator readiness
   int ready = BarsCalculated(hCCI);
   if(ready < StartCalcPosition)
     {
      PrintFormat("DIAGNOSTIC: CCI not ready - %d bars calculated, need %d", ready, StartCalcPosition);
      return 0;
     }

//--- First run diagnostic
   static bool first_run = true;
   if(first_run)
     {
      PrintFormat("DIAGNOSTIC: OnCalculate first run - rates_total=%d, StartCalcPosition=%d", rates_total, StartCalcPosition);
      first_run = false;
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
   ArraySetAsSeries(time, false);

//--- Calculate start position (MQL5 idiomatic pattern)
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

//--- Rolling window state variables
   static double sum_b = 0.0;
   static double sum_cci = 0.0;
   static double sum_cci2 = 0.0;
   static double sum_excess = 0.0;
   static int    last_processed_bar = -1;

//--- Initialize rolling window sums on first run (MQL5 idiomatic: all values guaranteed valid)
   if(prev_calculated == 0 || start == StartCalcPosition)
     {
      sum_b = 0.0;
      sum_cci = 0.0;
      sum_cci2 = 0.0;
      sum_excess = 0.0;
      last_processed_bar = StartCalcPosition - 1;

      // Prime window: bars [StartCalcPosition - InpWindow + 1, StartCalcPosition]
      // All CCI values are valid here (CCI warmup already complete)
      for(int j = start - InpWindow + 1; j <= start; j++)
        {
         double x = cci[j];
         double b = (MathAbs(x) <= 100.0) ? 1.0 : 0.0;

         sum_b += b;
         sum_cci += x;
         sum_cci2 += x * x;
         sum_excess += MathMax(MathAbs(x) - 100.0, 0.0);
        }
     }

//--- Main calculation loop
   for(int i = start; i < rates_total && !IsStopped(); i++)
     {
      //--- Check if this is a NEW bar (not a recalculation of current bar)
      bool is_new_bar = (i > last_processed_bar);

      //--- Slide rolling window ONLY when moving to a NEW bar
      if(is_new_bar && i >= InpWindow)
        {
         // Remove oldest value
         int idx_out = i - InpWindow;
         double x_out = cci[idx_out];
         double b_out = (MathAbs(x_out) <= 100.0) ? 1.0 : 0.0;

         sum_b -= b_out;
         sum_cci -= x_out;
         sum_cci2 -= x_out * x_out;
         sum_excess -= MathMax(MathAbs(x_out) - 100.0, 0.0);
        }

      // Get current bar value
      double x_in = cci[i];
      double b_in = (MathAbs(x_in) <= 100.0) ? 1.0 : 0.0;

      //--- Update sums for NEW bar OR replace current bar value
      if(is_new_bar)
        {
         // Add new bar to window
         sum_b += b_in;
         sum_cci += x_in;
         sum_cci2 += x_in * x_in;
         sum_excess += MathMax(MathAbs(x_in) - 100.0, 0.0);
        }
      else
        {
         // Recalculating current bar - replace old value with new value
         // First remove the old contribution (if this bar was already processed)
         if(i == last_processed_bar)
           {
            // Get the old value from buffer (before update)
            double x_old = BufCCI[i];
            if(x_old != EMPTY_VALUE)
              {
               double b_old = (MathAbs(x_old) <= 100.0) ? 1.0 : 0.0;
               sum_b -= b_old;
               sum_cci -= x_old;
               sum_cci2 -= x_old * x_old;
               sum_excess -= MathMax(MathAbs(x_old) - 100.0, 0.0);
              }
           }

         // Add the new value
         sum_b += b_in;
         sum_cci += x_in;
         sum_cci2 += x_in * x_in;
         sum_excess += MathMax(MathAbs(x_in) - 100.0, 0.0);
        }

      //--- Update last processed bar
      last_processed_bar = i;

      //--- Calculate statistics
      double p = sum_b / InpWindow;
      double mu = sum_cci / InpWindow;
      double variance = (sum_cci2 / InpWindow) - (mu * mu);
      double sd = MathSqrt(MathMax(0.0, variance));
      double e = (sum_excess / InpWindow) / InpC2;

      //--- Calculate score components
      double c = 1.0 - MathMin(1.0, MathAbs(mu) / InpC0);
      double v = 1.0 - MathMin(1.0, sd / InpC1);
      double q = 1.0 - MathMin(1.0, e);

      //--- Composite score
      double score = p * c * v * q;

      //--- Assign color based on score thresholds
      int color_index;
      if(score < InpLowThreshold)
         color_index = 0;       // Red: Low/Chaotic
      else if(score < InpHighThreshold)
         color_index = 1;       // Yellow: Medium
      else
         color_index = 2;       // Green: High/Neutral

      //--- Store results
      BufCCI[i] = x_in;        // Hidden buffer for recalculation handling
      BufScore[i] = score;     // Visible buffer: pure 0-1 range
      BufColor[i] = color_index; // Color index: 0/1/2

      //--- Export to CSV if enabled
      if(csv_export.IsEnabled())
        {
         csv_export.WriteRow(i, time[i], x_in, score, p, mu, sd, e, c, v, q, color_index);
        }

      //--- Diagnostic: Print last bar values
      if(i == rates_total - 1 && prev_calculated == 0)
        {
         PrintFormat("DIAGNOSTIC: Last bar calculated - score=%.6f, color=%d, cci=%.2f", score, color_index, x_in);
         PrintFormat("DIAGNOSTIC: Components - p=%.3f, mu=%.2f, sd=%.2f, e=%.6f", p, mu, sd, e);
         PrintFormat("DIAGNOSTIC: BufScore[%d]=%.6f, BufColor[%d]=%d", i, BufScore[i], i, (int)BufColor[i]);
        }
     }

//--- Return value for next call
   return rates_total;
  }
//+------------------------------------------------------------------+
