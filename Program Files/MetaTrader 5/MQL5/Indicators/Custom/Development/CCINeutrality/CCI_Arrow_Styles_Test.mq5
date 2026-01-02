//+------------------------------------------------------------------+
//|                                        CCI_Arrow_Styles_Test.mq5 |
//|            Test various DRAW_ARROW styles for CCI Neutrality     |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property version     "1.0.0"
#property description "Compare arrow/marker styles for CCI Neutrality visualization"
#property description "Shows 6 different marker styles - enable/disable to compare"

#property indicator_chart_window
#property indicator_buffers 13  // 6 arrow buffers + 6 color buffers + 1 CCI
#property indicator_plots   6   // 6 visible arrow plots

//--- Plot 1: Dots at High (small circles above bar)
#property indicator_label1    "Dots High"
#property indicator_type1     DRAW_COLOR_ARROW
#property indicator_color1    clrLime,clrGold,clrRed
#property indicator_width1    2

//--- Plot 2: Dots at Low (small circles below bar)
#property indicator_label2    "Dots Low"
#property indicator_type2     DRAW_COLOR_ARROW
#property indicator_color2    clrLime,clrGold,clrRed
#property indicator_width2    2

//--- Plot 3: Triangles at High (pointing up)
#property indicator_label3    "Triangles High"
#property indicator_type3     DRAW_COLOR_ARROW
#property indicator_color3    clrLime,clrGold,clrRed
#property indicator_width3    2

//--- Plot 4: Squares at Close
#property indicator_label4    "Squares Close"
#property indicator_type4     DRAW_COLOR_ARROW
#property indicator_color4    clrLime,clrGold,clrRed
#property indicator_width4    2

//--- Plot 5: Diamonds at Open
#property indicator_label5    "Diamonds Open"
#property indicator_type5     DRAW_COLOR_ARROW
#property indicator_color5    clrLime,clrGold,clrRed
#property indicator_width5    2

//--- Plot 6: Thick dots at body midpoint
#property indicator_label6    "Body Midpoint"
#property indicator_type6     DRAW_COLOR_ARROW
#property indicator_color6    clrLime,clrGold,clrRed
#property indicator_width6    3

//--- Input parameters
input group "=== CCI Parameters ==="
input int              InpCCILength           = 20;             // CCI period
input int              InpWindowBars          = 120;            // Lookback window for percentile

input group "=== Display Options (toggle to compare) ==="
input bool             InpShowDotsHigh        = true;           // Show dots at High
input bool             InpShowDotsLow         = false;          // Show dots at Low
input bool             InpShowTriangles       = false;          // Show triangles at High
input bool             InpShowSquares         = false;          // Show squares at Close
input bool             InpShowDiamonds        = false;          // Show diamonds at Open
input bool             InpShowMidpoint        = false;          // Show dots at body midpoint

input group "=== Arrow Codes (Wingdings font) ==="
input int              InpDotCode             = 159;            // Dot code (159=large circle, 158=small)
input int              InpTriangleCode        = 233;            // Triangle code (233=up, 234=down)
input int              InpSquareCode          = 110;            // Square code (110=filled)
input int              InpDiamondCode         = 116;            // Diamond code (116=filled)

//--- Indicator buffers
double BufDotsHigh[];      // Buffer 0
double BufDotsHighClr[];   // Buffer 1
double BufDotsLow[];       // Buffer 2
double BufDotsLowClr[];    // Buffer 3
double BufTriangles[];     // Buffer 4
double BufTrianglesClr[];  // Buffer 5
double BufSquares[];       // Buffer 6
double BufSquaresClr[];    // Buffer 7
double BufDiamonds[];      // Buffer 8
double BufDiamondsClr[];   // Buffer 9
double BufMidpoint[];      // Buffer 10
double BufMidpointClr[];   // Buffer 11
double BufCCI[];           // Buffer 12 (hidden)

//--- Indicator handle
int hCCI = INVALID_HANDLE;

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
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate inputs
   if(InpCCILength < 1 || InpWindowBars < 2)
     {
      Print("ERROR: Invalid parameters");
      return INIT_PARAMETERS_INCORRECT;
     }

//--- Set indicator buffers
   SetIndexBuffer(0, BufDotsHigh, INDICATOR_DATA);
   SetIndexBuffer(1, BufDotsHighClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufDotsLow, INDICATOR_DATA);
   SetIndexBuffer(3, BufDotsLowClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, BufTriangles, INDICATOR_DATA);
   SetIndexBuffer(5, BufTrianglesClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(6, BufSquares, INDICATOR_DATA);
   SetIndexBuffer(7, BufSquaresClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(8, BufDiamonds, INDICATOR_DATA);
   SetIndexBuffer(9, BufDiamondsClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(10, BufMidpoint, INDICATOR_DATA);
   SetIndexBuffer(11, BufMidpointClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(12, BufCCI, INDICATOR_CALCULATIONS);

//--- Set arrow codes (Wingdings font symbols)
   PlotIndexSetInteger(0, PLOT_ARROW, InpDotCode);      // Dots High
   PlotIndexSetInteger(1, PLOT_ARROW, InpDotCode);      // Dots Low
   PlotIndexSetInteger(2, PLOT_ARROW, InpTriangleCode); // Triangles
   PlotIndexSetInteger(3, PLOT_ARROW, InpSquareCode);   // Squares
   PlotIndexSetInteger(4, PLOT_ARROW, InpDiamondCode);  // Diamonds
   PlotIndexSetInteger(5, PLOT_ARROW, InpDotCode);      // Midpoint dots

//--- Set arrow shifts (vertical offset from price)
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -10);  // Above high
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, 10);   // Below low
   PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, -15);  // Further above high
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT, 0);    // At close
   PlotIndexSetInteger(4, PLOT_ARROW_SHIFT, 0);    // At open
   PlotIndexSetInteger(5, PLOT_ARROW_SHIFT, 0);    // At midpoint

//--- Set draw begin
   int startPos = InpCCILength + InpWindowBars - 1;
   for(int i = 0; i < 6; i++)
      PlotIndexSetInteger(i, PLOT_DRAW_BEGIN, startPos);

//--- Set empty values
   for(int i = 0; i < 6; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Hide disabled plots
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, InpShowDotsHigh ? DRAW_COLOR_ARROW : DRAW_NONE);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, InpShowDotsLow ? DRAW_COLOR_ARROW : DRAW_NONE);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, InpShowTriangles ? DRAW_COLOR_ARROW : DRAW_NONE);
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, InpShowSquares ? DRAW_COLOR_ARROW : DRAW_NONE);
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, InpShowDiamonds ? DRAW_COLOR_ARROW : DRAW_NONE);
   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, InpShowMidpoint ? DRAW_COLOR_ARROW : DRAW_NONE);

//--- Create CCI handle
   hCCI = iCCI(_Symbol, _Period, InpCCILength, PRICE_TYPICAL);
   if(hCCI == INVALID_HANDLE)
     {
      PrintFormat("ERROR: Failed to create CCI handle, error %d", GetLastError());
      return INIT_FAILED;
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CCI Arrow Test(%d,%d)", InpCCILength, InpWindowBars));

   Print("=== Arrow Style Test Initialized ===");
   Print("Enable different options in settings to compare styles:");
   Print("  - Dots High/Low: Small circles above/below bars");
   Print("  - Triangles: Pointing markers at high");
   Print("  - Squares: Filled squares at close price");
   Print("  - Diamonds: Diamond shapes at open price");
   Print("  - Midpoint: Thick dots at candle body center");
   Print("Colors: Lime=Calm(<30%), Gold=Normal(30-70%), Red=Volatile(>70%)");

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hCCI != INVALID_HANDLE)
     {
      IndicatorRelease(hCCI);
      hCCI = INVALID_HANDLE;
     }
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
   int startPos = InpCCILength + InpWindowBars - 1;

   if(rates_total <= startPos)
      return 0;

//--- Get CCI data
   static double cci[];
   ArrayResize(cci, rates_total);
   ArraySetAsSeries(cci, false);

   int copied = CopyBuffer(hCCI, 0, 0, rates_total, cci);
   if(copied != rates_total)
      return 0;

//--- Set arrays as forward-indexed
   ArraySetAsSeries(BufDotsHigh, false);
   ArraySetAsSeries(BufDotsHighClr, false);
   ArraySetAsSeries(BufDotsLow, false);
   ArraySetAsSeries(BufDotsLowClr, false);
   ArraySetAsSeries(BufTriangles, false);
   ArraySetAsSeries(BufTrianglesClr, false);
   ArraySetAsSeries(BufSquares, false);
   ArraySetAsSeries(BufSquaresClr, false);
   ArraySetAsSeries(BufDiamonds, false);
   ArraySetAsSeries(BufDiamondsClr, false);
   ArraySetAsSeries(BufMidpoint, false);
   ArraySetAsSeries(BufMidpointClr, false);
   ArraySetAsSeries(BufCCI, false);

//--- Calculate start position
   int start = (prev_calculated == 0) ? startPos : prev_calculated - 1;

   // Initialize early bars
   if(prev_calculated == 0)
     {
      for(int i = 0; i < startPos; i++)
        {
         BufDotsHigh[i] = EMPTY_VALUE;
         BufDotsLow[i] = EMPTY_VALUE;
         BufTriangles[i] = EMPTY_VALUE;
         BufSquares[i] = EMPTY_VALUE;
         BufDiamonds[i] = EMPTY_VALUE;
         BufMidpoint[i] = EMPTY_VALUE;
        }
     }

//--- Rolling window for percentile
   static double cci_window[];
   ArrayResize(cci_window, InpWindowBars);

//--- Main calculation loop
   for(int i = start; i < rates_total && !IsStopped(); i++)
     {
      int window_start = i - InpWindowBars + 1;
      if(window_start < 0)
         continue;

      //--- Build rolling window (absolute CCI values)
      for(int j = 0; j < InpWindowBars; j++)
         cci_window[j] = MathAbs(cci[window_start + j]);

      //--- Calculate percentile rank
      double current_cci_abs = MathAbs(cci[i]);
      double score = PercentileRank(current_cci_abs, cci_window, InpWindowBars);

      //--- Determine color index (0=Calm/Lime, 1=Normal/Gold, 2=Volatile/Red)
      int color_idx;
      if(score < 0.3)
         color_idx = 0;       // Calm (green)
      else if(score <= 0.7)
         color_idx = 1;       // Normal (yellow/gold)
      else
         color_idx = 2;       // Volatile (red)

      //--- Calculate body midpoint
      double body_mid = (open[i] + close[i]) / 2.0;

      //--- Set arrow positions and colors
      BufDotsHigh[i] = high[i];
      BufDotsHighClr[i] = color_idx;

      BufDotsLow[i] = low[i];
      BufDotsLowClr[i] = color_idx;

      BufTriangles[i] = high[i];
      BufTrianglesClr[i] = color_idx;

      BufSquares[i] = close[i];
      BufSquaresClr[i] = color_idx;

      BufDiamonds[i] = open[i];
      BufDiamondsClr[i] = color_idx;

      BufMidpoint[i] = body_mid;
      BufMidpointClr[i] = color_idx;

      BufCCI[i] = cci[i];
     }

   return rates_total;
  }
//+------------------------------------------------------------------+
