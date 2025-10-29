//+------------------------------------------------------------------+
//|                                              CCI_Neutrality.mq5 |
//|                          CCI Neutrality Score - Community Grade  |
//|                                                                  |
//| Scores "consecutive CCI bounded near zero with few ±100 breaches"|
//| Implements audit feedback: prev_calculated flow, O(1) rolling   |
//| windows, BarsCalculated checks, CSV logging                     |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property link        "https://github.com/terrylica/mql5-crossover"
#property version     "1.00"
#property description "CCI Neutrality Score with coil and expansion signals"
#property description "Audit-compliant: O(1) rolling windows, proper prev_calculated flow"

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   4

// Plot 1: CCI
#property indicator_label1    "CCI"
#property indicator_type1     DRAW_LINE
#property indicator_color1    clrDodgerBlue
#property indicator_width1    1

// Plot 2: Neutrality Score x100
#property indicator_label2    "Score_x100"
#property indicator_type2     DRAW_LINE
#property indicator_color2    clrOrange
#property indicator_width2    1

// Plot 3: Coil signal
#property indicator_label3    "Coil"
#property indicator_type3     DRAW_ARROW
#property indicator_color3    clrLime
#property indicator_width3    2

// Plot 4: Expansion signal
#property indicator_label4    "Expansion"
#property indicator_type4     DRAW_ARROW
#property indicator_color4    clrRed
#property indicator_width4    2

// Force recalculation in Strategy Tester
#property tester_everytick_calculate

//--- Include CSV logger
#include <CsvLogger.mqh>

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

input group "=== Display ==="
input double InpCoilMarkY     = 120.0;   // Coil marker Y position
input double InpExpMarkY      = 140.0;   // Expansion marker Y position

input group "=== Logging ==="
input bool   InpLogCSV        = false;   // Enable CSV logging
input string InpLogTag        = "cci_neutrality"; // Log file prefix
input int    InpFlushInterval = 500;     // Flush every N bars

//--- Indicator buffers
double BufCCI[];
double BufScore[];
double BufCoil[];
double BufExpansion[];

//--- Indicator handle
int hCCI = INVALID_HANDLE;

//--- CSV logger
CsvLogger g_logger;
int g_log_count = 0;

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
   SetIndexBuffer(0, BufCCI, INDICATOR_DATA);
   SetIndexBuffer(1, BufScore, INDICATOR_DATA);
   SetIndexBuffer(2, BufCoil, INDICATOR_DATA);
   SetIndexBuffer(3, BufExpansion, INDICATOR_DATA);

//--- Set draw begin (community standard)
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpWindow - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpWindow - 1);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpWindow - 1);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, InpWindow - 1);

//--- Set empty values (community standard)
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Set arrow codes
   PlotIndexSetInteger(2, PLOT_ARROW, 159); // ● (circle)
   PlotIndexSetInteger(3, PLOT_ARROW, 241); // ▲ (triangle up)

//--- Set indicator levels
   IndicatorSetInteger(INDICATOR_LEVELS, 4);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, -100.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 0.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, 100.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, InpMinScore * 100.0); // Score threshold

//--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("CCI Neutrality(%d,%d)", InpCCILength, InpWindow));

//--- Create CCI indicator handle
   hCCI = iCCI(_Symbol, _Period, InpCCILength, PRICE_TYPICAL);
   if(hCCI == INVALID_HANDLE)
     {
      PrintFormat("ERROR: Failed to create CCI handle, error %d", GetLastError());
      return INIT_FAILED;
     }

//--- Initialize CSV logging
   if(InpLogCSV)
     {
      string filename = StringFormat("%s_%s_%s_%s.csv",
                                     InpLogTag,
                                     _Symbol,
                                     EnumToString(_Period),
                                     TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));

      if(g_logger.Open(filename))
        {
         g_logger.Header("time;bar;cci;in_channel;p;mu;sd;e;c;v;q;score;streak;coil;expansion");
         g_logger.Flush();
        }
      else
        {
         PrintFormat("WARNING: CSV logging failed, continuing without logging");
        }
     }

   PrintFormat("CCI Neutrality initialized: CCI=%d, W=%d, thresh=(streak=%d, p=%.2f, mu=%.1f, sd=%.1f, tau=%.2f)",
               InpCCILength, InpWindow, InpMinStreak, InpMinInChannel,
               InpMaxMean, InpMaxStdev, InpMinScore);

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

//--- Close logger
   if(InpLogCSV && g_logger.IsOpen())
     {
      g_logger.Close();
     }

   PrintFormat("CCI Neutrality deinitialized, reason: %d", reason);
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
//--- Check if we have enough bars
   if(rates_total <= InpWindow + 2)
      return 0;

//--- Check CCI indicator readiness (audit requirement)
   int ready = BarsCalculated(hCCI);
   if(ready < InpWindow)
     {
      PrintFormat("CCI not ready: %d bars calculated, need %d", ready, InpWindow);
      return 0;
     }

//--- Get CCI data
   static double cci[];
   ArrayResize(cci, rates_total);
   ArraySetAsSeries(cci, false); // Use forward indexing

   int copied = CopyBuffer(hCCI, 0, 0, rates_total, cci);
   if(copied < rates_total)
     {
      PrintFormat("ERROR: CopyBuffer failed, copied %d of %d bars, error %d",
                  copied, rates_total, GetLastError());
      return prev_calculated;
     }

//--- Set arrays as forward-indexed (audit requirement)
   ArraySetAsSeries(BufCCI, false);
   ArraySetAsSeries(BufScore, false);
   ArraySetAsSeries(BufCoil, false);
   ArraySetAsSeries(BufExpansion, false);
   ArraySetAsSeries(time, false);

//--- Calculate start position using prev_calculated (audit requirement)
   int start;
   if(prev_calculated == 0)
     {
      // First calculation - start from first valid bar
      start = InpWindow - 1;

      // Initialize early bars with EMPTY_VALUE
      for(int i = 0; i < start; i++)
        {
         BufCCI[i] = EMPTY_VALUE;
         BufScore[i] = EMPTY_VALUE;
         BufCoil[i] = EMPTY_VALUE;
         BufExpansion[i] = EMPTY_VALUE;
        }
     }
   else
     {
      // Incremental calculation - recalculate last bar
      start = prev_calculated - 1;
      if(start < InpWindow - 1)
         start = InpWindow - 1;
     }

//--- Rolling window state variables (O(1) update strategy)
   static double sum_b = 0.0;        // Sum of in-channel flags
   static double sum_cci = 0.0;      // Sum of CCI values
   static double sum_cci2 = 0.0;     // Sum of CCI^2 values
   static double sum_excess = 0.0;   // Sum of breach magnitudes
   static int    prev_coil_bar = -1; // Last bar with coil signal

//--- Initialize rolling window sums on first run
   if(prev_calculated == 0 || start == InpWindow - 1)
     {
      sum_b = 0.0;
      sum_cci = 0.0;
      sum_cci2 = 0.0;
      sum_excess = 0.0;

      // Prime window for bar at start
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
      //--- Slide rolling window (O(1) update)
      if(i >= InpWindow)
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

      // Add newest value
      double x_in = cci[i];
      double b_in = (MathAbs(x_in) <= 100.0) ? 1.0 : 0.0;

      sum_b += b_in;
      sum_cci += x_in;
      sum_cci2 += x_in * x_in;
      sum_excess += MathMax(MathAbs(x_in) - 100.0, 0.0);

      //--- Calculate statistics
      double p = sum_b / InpWindow;                           // In-channel ratio
      double mu = sum_cci / InpWindow;                        // Mean CCI
      double variance = (sum_cci2 / InpWindow) - (mu * mu);
      double sd = MathSqrt(MathMax(0.0, variance));           // Stdev CCI
      double e = (sum_excess / InpWindow) / InpC2;           // Breach magnitude ratio

      //--- Calculate score components
      double c = 1.0 - MathMin(1.0, MathAbs(mu) / InpC0);   // Centering score
      double v = 1.0 - MathMin(1.0, sd / InpC1);             // Dispersion score
      double q = 1.0 - MathMin(1.0, e);                      // Breach penalty score

      //--- Composite score
      double score = p * c * v * q;  // [0,1]

      //--- Calculate streak (look back)
      int streak = 0;
      if(b_in == 1.0)
        {
         for(int j = i; j >= 0 && (MathAbs(cci[j]) <= 100.0); j--)
            streak++;
        }

      //--- Determine coil condition
      bool coil = (streak >= InpMinStreak) &&
                  (p >= InpMinInChannel) &&
                  (MathAbs(mu) <= InpMaxMean) &&
                  (sd <= InpMaxStdev) &&
                  (score >= InpMinScore);

      //--- Determine expansion (prior bar was coil, now breach ±100)
      bool expansion = false;
      if(i > 0 && prev_coil_bar == i - 1)
        {
         expansion = (MathAbs(x_in) > 100.0) && (MathAbs(cci[i - 1]) <= 100.0);
        }

      //--- Update coil tracking
      if(coil)
         prev_coil_bar = i;

      //--- Store results
      BufCCI[i] = x_in;
      BufScore[i] = score * 100.0;
      BufCoil[i] = coil ? InpCoilMarkY : EMPTY_VALUE;
      BufExpansion[i] = expansion ? InpExpMarkY : EMPTY_VALUE;

      //--- CSV logging
      if(InpLogCSV && g_logger.IsOpen())
        {
         string row = StringFormat("%s;%d;%.2f;%.0f;%.4f;%.2f;%.2f;%.4f;%.4f;%.4f;%.4f;%.4f;%d;%d;%d",
                                   TimeToString(time[i], TIME_DATE | TIME_SECONDS),
                                   i,
                                   x_in,
                                   b_in,
                                   p,
                                   mu,
                                   sd,
                                   e,
                                   c,
                                   v,
                                   q,
                                   score,
                                   streak,
                                   coil ? 1 : 0,
                                   expansion ? 1 : 0);
         g_logger.Row(row);

         g_log_count++;
         if(g_log_count % InpFlushInterval == 0)
            g_logger.Flush();
        }
     }

//--- Return value for next call
   return rates_total;
  }
//+------------------------------------------------------------------+
