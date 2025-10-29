//+------------------------------------------------------------------+
//|                                         CCI_Neutrality_Visual.mq5 |
//|                          Visual version with score plot          |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property link        "https://github.com/terrylica/mql5-crossover"
#property version     "2.00"
#property description "CCI Neutrality Score - Visual indicator with score plot"

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

// Force recalculation in Strategy Tester
#property tester_everytick_calculate

// Plot 1: CCI
#property indicator_label1    "CCI"
#property indicator_type1     DRAW_LINE
#property indicator_color1    clrDodgerBlue
#property indicator_width1    2

// Plot 2: Score × 100
#property indicator_label2    "Score×100"
#property indicator_type2     DRAW_LINE
#property indicator_color2    clrOrange
#property indicator_width2    1
#property indicator_style2    STYLE_DOT

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

//--- Indicator buffers
double BufCCI[];
double BufScore[];

//--- Indicator handle
int hCCI = INVALID_HANDLE;

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

//--- Set draw begin (MQL5 idiomatic: CCI warmup + window warmup)
   int StartCalcPosition = InpCCILength + InpWindow - 1;
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, StartCalcPosition);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, StartCalcPosition);

//--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Set indicator levels
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, -100.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 0.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, 100.0);

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

   PrintFormat("CCI Neutrality Visual initialized: CCI=%d, W=%d",
               InpCCILength, InpWindow);

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

   PrintFormat("CCI Neutrality Visual deinitialized, reason: %d", reason);
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
   ArraySetAsSeries(BufCCI, false);
   ArraySetAsSeries(BufScore, false);
   ArraySetAsSeries(time, false);

//--- Calculate start position (MQL5 idiomatic pattern)
   int start;
   if(prev_calculated == 0)
     {
      start = StartCalcPosition;

      // Initialize early bars (before warmup complete)
      for(int i = 0; i < start; i++)
        {
         BufCCI[i] = EMPTY_VALUE;
         BufScore[i] = EMPTY_VALUE;
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

      //--- Store results
      BufCCI[i] = x_in;
      BufScore[i] = score * 100.0;  // Scale to 0-100 for visibility
     }

//--- Return value for next call
   return rates_total;
  }
//+------------------------------------------------------------------+
