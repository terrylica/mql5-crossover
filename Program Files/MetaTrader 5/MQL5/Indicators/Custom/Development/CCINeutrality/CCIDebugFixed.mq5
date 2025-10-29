//+------------------------------------------------------------------+
//|                                         CCI_Neutrality_Debug.mq5 |
//|                          Debug version with CSV output only      |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property link        "https://github.com/terrylica/mql5-crossover"
#property version     "1.00"
#property description "CCI Neutrality - Debug version with full calculation CSV output"

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

// Force recalculation in Strategy Tester
#property tester_everytick_calculate

// Single plot: CCI only
#property indicator_label1    "CCI"
#property indicator_type1     DRAW_LINE
#property indicator_color1    clrDodgerBlue
#property indicator_width1    1

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

input group "=== Debug Output ==="
input bool   InpEnableCSV     = true;    // Enable CSV output
input int    InpFlushInterval = 100;     // Flush every N bars

//--- Indicator buffers
double BufCCI[];

//--- Indicator handle
int hCCI = INVALID_HANDLE;

//--- CSV file handle
int hFile = INVALID_HANDLE;
int g_bar_count = 0;

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

//--- Set draw begin
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpWindow - 1);

//--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Set indicator levels
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, -100.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 0.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, 100.0);

//--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("CCI Neutrality Debug(%d,%d)", InpCCILength, InpWindow));

//--- Create CCI indicator handle
   hCCI = iCCI(_Symbol, _Period, InpCCILength, PRICE_TYPICAL);
   if(hCCI == INVALID_HANDLE)
     {
      PrintFormat("ERROR: Failed to create CCI handle, error %d", GetLastError());
      return INIT_FAILED;
     }

//--- Open CSV file
   if(InpEnableCSV)
     {
      string filename = StringFormat("cci_debug_%s_%s_%s.csv",
                                     _Symbol,
                                     EnumToString(_Period),
                                     TimeToString(TimeCurrent(), TIME_DATE));

      hFile = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_ANSI, ";");

      if(hFile != INVALID_HANDLE)
        {
         // Write header
         FileWrite(hFile, "time", "bar", "cci", "in_channel",
                   "p", "mu", "sd", "e",
                   "c", "v", "q", "score",
                   "streak", "coil", "expansion",
                   "sum_b", "sum_cci", "sum_cci2", "sum_excess");
         FileFlush(hFile);
         PrintFormat("CSV debug output: MQL5/Files/%s", filename);
        }
      else
        {
         PrintFormat("WARNING: Failed to open CSV file, error %d", GetLastError());
        }
     }

   PrintFormat("CCI Neutrality Debug initialized: CCI=%d, W=%d, CSV=%s",
               InpCCILength, InpWindow, InpEnableCSV ? "enabled" : "disabled");

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

//--- Close CSV file
   if(hFile != INVALID_HANDLE)
     {
      FileFlush(hFile);
      FileClose(hFile);
      hFile = INVALID_HANDLE;
     }

   PrintFormat("CCI Neutrality Debug deinitialized, reason: %d, bars written: %d",
               reason, g_bar_count);
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

//--- Check CCI indicator readiness
   int ready = BarsCalculated(hCCI);
   if(ready < InpWindow)
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
   ArraySetAsSeries(BufCCI, false);
   ArraySetAsSeries(time, false);

//--- Calculate start position
   int start;
   if(prev_calculated == 0)
     {
      start = InpWindow - 1;

      // Initialize early bars
      for(int i = 0; i < start; i++)
        {
         BufCCI[i] = EMPTY_VALUE;
        }
     }
   else
     {
      start = prev_calculated - 1;
      if(start < InpWindow - 1)
         start = InpWindow - 1;
     }

//--- Rolling window state variables
   static double sum_b = 0.0;
   static double sum_cci = 0.0;
   static double sum_cci2 = 0.0;
   static double sum_excess = 0.0;
   static int    prev_coil_bar = -1;

//--- Initialize rolling window sums on first run
   if(prev_calculated == 0 || start == InpWindow - 1)
     {
      sum_b = 0.0;
      sum_cci = 0.0;
      sum_cci2 = 0.0;
      sum_excess = 0.0;

      // Prime window - start from first valid CCI bar
      // CCI needs InpCCILength bars warmup before producing valid values
      int first_valid = InpCCILength;
      int prime_start = MathMax(first_valid, start - InpWindow + 1);

      for(int j = prime_start; j <= start; j++)
        {
         double x = cci[j];

         // Skip invalid CCI values (EMPTY_VALUE or non-finite numbers)
         if(x == EMPTY_VALUE || !MathIsValidNumber(x))
            continue;

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
      //--- Slide rolling window
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

      //--- Calculate streak
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

      //--- Determine expansion
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

      //--- Write to CSV
      if(InpEnableCSV && hFile != INVALID_HANDLE)
        {
         FileWrite(hFile,
                   TimeToString(time[i], TIME_DATE | TIME_SECONDS),
                   i,
                   DoubleToString(x_in, 2),
                   (int)b_in,
                   DoubleToString(p, 4),
                   DoubleToString(mu, 2),
                   DoubleToString(sd, 2),
                   DoubleToString(e, 4),
                   DoubleToString(c, 4),
                   DoubleToString(v, 4),
                   DoubleToString(q, 4),
                   DoubleToString(score, 4),
                   streak,
                   coil ? 1 : 0,
                   expansion ? 1 : 0,
                   DoubleToString(sum_b, 2),
                   DoubleToString(sum_cci, 2),
                   DoubleToString(sum_cci2, 2),
                   DoubleToString(sum_excess, 2));

         g_bar_count++;

         if(g_bar_count % InpFlushInterval == 0)
            FileFlush(hFile);
        }
     }

//--- Final flush
   if(InpEnableCSV && hFile != INVALID_HANDLE)
      FileFlush(hFile);

//--- Return value for next call
   return rates_total;
  }
//+------------------------------------------------------------------+
