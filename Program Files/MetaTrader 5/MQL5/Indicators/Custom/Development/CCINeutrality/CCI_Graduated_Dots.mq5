//+------------------------------------------------------------------+
//|                                          CCI_Graduated_Dots.mq5 |
//|          Graduated Dot System - More dots = More extreme CCI     |
//|          Wine/CrossOver compatible (uses dot symbol 158)         |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property version     "2.0.0"
#property description "CCI Graduated Dot Signals (4-tier intensity)"
#property description "  ±100-199: 1 dot    ±200-299: 2 dots"
#property description "  ±300-399: 3 dots   ±400+: 4 dots"
#property description "  Positive = Green, Negative = Red"

#property indicator_chart_window
#property indicator_buffers 9   // 4 dot positions × 2 (value+color) + 1 hidden CCI
#property indicator_plots   4   // 4 visible dot plots

//--- Plot 1: Top dot (above high, offset up)
#property indicator_label1    "Dot1 Top"
#property indicator_type1     DRAW_COLOR_ARROW
#property indicator_color1    clrLime,clrRed
#property indicator_width1    2

//--- Plot 2: Upper dot (at high)
#property indicator_label2    "Dot2 Upper"
#property indicator_type2     DRAW_COLOR_ARROW
#property indicator_color2    clrLime,clrRed
#property indicator_width2    2

//--- Plot 3: Lower dot (at low)
#property indicator_label3    "Dot3 Lower"
#property indicator_type3     DRAW_COLOR_ARROW
#property indicator_color3    clrLime,clrRed
#property indicator_width3    2

//--- Plot 4: Bottom dot (below low, offset down)
#property indicator_label4    "Dot4 Bottom"
#property indicator_type4     DRAW_COLOR_ARROW
#property indicator_color4    clrLime,clrRed
#property indicator_width4    2

//--- Input parameters
input group "=== CCI Parameters ==="
input int              InpCCILength           = 20;             // CCI period

input group "=== Threshold Levels ==="
input double           InpThreshold1          = 100.0;          // Tier 1: 1 dot (±100)
input double           InpThreshold2          = 200.0;          // Tier 2: 2 dots (±200)
input double           InpThreshold3          = 300.0;          // Tier 3: 3 dots (±300)
input double           InpThreshold4          = 400.0;          // Tier 4: 4 dots (±400)

input group "=== Visual Style ==="
input int              InpDotSize             = 2;              // Dot size (1-5)
input int              InpPixelOffset         = 8;              // Pixel offset for outer dots

//--- Indicator buffers
double BufDot1[];         // Buffer 0: Top dot (above high)
double BufDot1Clr[];      // Buffer 1: Top dot color
double BufDot2[];         // Buffer 2: Upper dot (at high or close)
double BufDot2Clr[];      // Buffer 3: Upper dot color
double BufDot3[];         // Buffer 4: Lower dot (at low or close)
double BufDot3Clr[];      // Buffer 5: Lower dot color
double BufDot4[];         // Buffer 6: Bottom dot (below low)
double BufDot4Clr[];      // Buffer 7: Bottom dot color
double BufCCI[];          // Buffer 8: Hidden CCI values

//--- Indicator handle
int hCCI = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpCCILength < 1)
     {
      Print("ERROR: Invalid CCI period");
      return INIT_PARAMETERS_INCORRECT;
     }

//--- Set indicator buffers
   SetIndexBuffer(0, BufDot1, INDICATOR_DATA);
   SetIndexBuffer(1, BufDot1Clr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufDot2, INDICATOR_DATA);
   SetIndexBuffer(3, BufDot2Clr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, BufDot3, INDICATOR_DATA);
   SetIndexBuffer(5, BufDot3Clr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(6, BufDot4, INDICATOR_DATA);
   SetIndexBuffer(7, BufDot4Clr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(8, BufCCI, INDICATOR_CALCULATIONS);

//--- All plots use the smallest dot symbol (158 = small dot in Wingdings)
   PlotIndexSetInteger(0, PLOT_ARROW, 158);
   PlotIndexSetInteger(1, PLOT_ARROW, 158);
   PlotIndexSetInteger(2, PLOT_ARROW, 158);
   PlotIndexSetInteger(3, PLOT_ARROW, 158);

//--- Set arrow shifts for visual separation
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -InpPixelOffset);  // Dot1: above high
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, 0);                 // Dot2: at price
   PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, 0);                 // Dot3: at price
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT, InpPixelOffset);    // Dot4: below low

//--- Set line widths
   for(int i = 0; i < 4; i++)
      PlotIndexSetInteger(i, PLOT_LINE_WIDTH, InpDotSize);

//--- Set draw begin and empty value
   int startPos = InpCCILength;
   for(int i = 0; i < 4; i++)
     {
      PlotIndexSetInteger(i, PLOT_DRAW_BEGIN, startPos);
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);
     }

//--- Create CCI handle
   hCCI = iCCI(_Symbol, _Period, InpCCILength, PRICE_TYPICAL);
   if(hCCI == INVALID_HANDLE)
     {
      PrintFormat("ERROR: Failed to create CCI handle, error %d", GetLastError());
      return INIT_FAILED;
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("CCI Dots(%d)", InpCCILength));

   Print("=== CCI Graduated Dot Signals v2.0.0 ===");
   PrintFormat("  Tier 1: |CCI| >= %.0f and < %.0f = 1 dot", InpThreshold1, InpThreshold2);
   PrintFormat("  Tier 2: |CCI| >= %.0f and < %.0f = 2 dots", InpThreshold2, InpThreshold3);
   PrintFormat("  Tier 3: |CCI| >= %.0f and < %.0f = 3 dots", InpThreshold3, InpThreshold4);
   PrintFormat("  Tier 4: |CCI| >= %.0f = 4 dots", InpThreshold4);
   Print("  Positive CCI = Green, Negative CCI = Red");
   Print("  Neutral (inside ±100) = No dots");

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
//| Get the tier (0-4) based on absolute CCI value                   |
//| Returns: 0 = neutral, 1-4 = dot count                            |
//+------------------------------------------------------------------+
int GetTier(double abs_cci)
  {
   if(abs_cci >= InpThreshold4) return 4;
   if(abs_cci >= InpThreshold3) return 3;
   if(abs_cci >= InpThreshold2) return 2;
   if(abs_cci >= InpThreshold1) return 1;
   return 0;  // Neutral
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
   int startPos = InpCCILength;

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
   ArraySetAsSeries(BufDot1, false);
   ArraySetAsSeries(BufDot1Clr, false);
   ArraySetAsSeries(BufDot2, false);
   ArraySetAsSeries(BufDot2Clr, false);
   ArraySetAsSeries(BufDot3, false);
   ArraySetAsSeries(BufDot3Clr, false);
   ArraySetAsSeries(BufDot4, false);
   ArraySetAsSeries(BufDot4Clr, false);
   ArraySetAsSeries(BufCCI, false);

//--- Calculate start position
   int start = (prev_calculated == 0) ? startPos : prev_calculated - 1;

   // Initialize early bars
   if(prev_calculated == 0)
     {
      for(int i = 0; i < startPos; i++)
        {
         BufDot1[i] = EMPTY_VALUE;
         BufDot2[i] = EMPTY_VALUE;
         BufDot3[i] = EMPTY_VALUE;
         BufDot4[i] = EMPTY_VALUE;
        }
     }

//--- Main calculation loop
   for(int i = start; i < rates_total && !IsStopped(); i++)
     {
      double current_cci = cci[i];
      double abs_cci = MathAbs(current_cci);

      //--- Store hidden CCI value
      BufCCI[i] = current_cci;

      //--- Determine tier (0-4)
      int tier = GetTier(abs_cci);

      //--- Determine color: 0 = Green (positive), 1 = Red (negative)
      int color_idx = (current_cci >= 0) ? 0 : 1;

      //--- Calculate bar midpoint for single dot placement
      double mid_price = (high[i] + low[i]) / 2.0;

      //--- Clear all dots first
      BufDot1[i] = EMPTY_VALUE;
      BufDot2[i] = EMPTY_VALUE;
      BufDot3[i] = EMPTY_VALUE;
      BufDot4[i] = EMPTY_VALUE;

      //--- Set dots based on tier (Replace mode: show exactly that tier's pattern)
      switch(tier)
        {
         case 1:  // 1 dot: at close/midpoint
            BufDot2[i] = close[i];
            BufDot2Clr[i] = color_idx;
            break;

         case 2:  // 2 dots: high + low
            BufDot2[i] = high[i];
            BufDot2Clr[i] = color_idx;
            BufDot3[i] = low[i];
            BufDot3Clr[i] = color_idx;
            break;

         case 3:  // 3 dots: above high + high + low
            BufDot1[i] = high[i];  // Will be shifted up by pixel offset
            BufDot1Clr[i] = color_idx;
            BufDot2[i] = mid_price;
            BufDot2Clr[i] = color_idx;
            BufDot3[i] = low[i];
            BufDot3Clr[i] = color_idx;
            break;

         case 4:  // 4 dots: above high + high + low + below low
            BufDot1[i] = high[i];  // Will be shifted up by pixel offset
            BufDot1Clr[i] = color_idx;
            BufDot2[i] = high[i];
            BufDot2Clr[i] = color_idx;
            BufDot3[i] = low[i];
            BufDot3Clr[i] = color_idx;
            BufDot4[i] = low[i];  // Will be shifted down by pixel offset
            BufDot4Clr[i] = color_idx;
            break;

         default: // Tier 0: Neutral - no dots
            break;
        }
     }

   return rates_total;
  }
//+------------------------------------------------------------------+
