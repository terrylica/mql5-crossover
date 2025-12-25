//+------------------------------------------------------------------+
//|                           Consecutive Pattern Combined.mq5       |
//|                                                        Terry Li |
//|                                                                 |
//+------------------------------------------------------------------+
#property copyright "Terry Li"
#property version   "1.30"
#property description "Detects consecutive expansions/contractions in bar body size (experimental v1.30)"
#property indicator_chart_window
#property indicator_buffers 15
#property indicator_plots   5

//--- plot ColorCandles
#property indicator_label1  "ColorCandles"
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- plot ExpansionSignals
#property indicator_label2  "ExpansionBearishSignal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrDeepPink
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- plot ExpansionBullish Signal
#property indicator_label3  "ExpansionBullishSignal"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLime
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

//--- plot ContractionTriangles (NEW for v1.30)
#property indicator_label4  "ContractionBearishTriangle"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

#property indicator_label5  "ContractionBullishTriangle"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrGreen
#property indicator_style5  STYLE_SOLID
#property indicator_width5  2

//--- color constants
#define COLOR_NONE 0     // Default color (no signal)
#define CLR_BULLISH 1    // Bullish signal color index
#define CLR_BEARISH 2    // Bearish signal color index
#define CLR_INSIDE_BAR 3 // Inside bar color index
#define CLR_BOTH 4       // Both contraction and inside bar

//--- input parameters
// Pattern detection parameters
input group "Pattern Detection Settings"
input int                 InpConsecutiveCount = 3;          // Number of consecutive patterns
input bool                InpSameDirection    = true;       // Require same direction for all bars

// Pattern type selection
input group "Pattern Types"
input bool                InpShowExpansions   = true;       // Detect expansion patterns
input bool                InpShowContractions = true;       // Detect contraction patterns

// Visualization settings
input group "Display Settings"
input bool                InpShowDots         = true;       // Show dot signals
input bool                InpShowColorBars    = true;       // Show colored bars

// Color settings
input group "Color Settings"
input color               InpBullishColor     = clrLime;     // Bullish signal color
input color               InpBearishColor     = clrDeepPink; // Bearish signal color
input color               InpDefaultColor     = clrNONE;     // Default bar color

// Dot settings
input group "Dot Signal Settings"
input int                 InpArrowCode        = 159;         // Arrow code
input int                 InpArrowSize        = 3;           // Arrow size
input int                 InpMaxDotSize       = 14;          // Maximum dot size for consecutive signals

//--- indicator buffers
// Price and color buffers for colored candles
double         BufferOpen[];            // Open prices buffer
double         BufferHigh[];            // High prices buffer
double         BufferLow[];             // Low prices buffer
double         BufferClose[];           // Close prices buffer
double         BufferColorIndex[];      // Color index buffer

// Signal buffers for expansion dots
double         BufferExpBearishSignal[];  // Expansion bearish signal buffer
double         BufferExpBullishSignal[];  // Expansion bullish signal buffer

// Signal buffers for contraction triangles (NEW for v1.30)
double         BufferContBearishSignal[];  // Contraction bearish triangle buffer
double         BufferContBullishSignal[];  // Contraction bullish triangle buffer

// Calculation buffers
double         BufferBodySizes[];       // Body sizes for calculations
double         BufferConsecutiveBullish[]; // Count of consecutive bullish signals
double         BufferConsecutiveBearish[]; // Count of consecutive bearish signals
double         BufferExpConsecutiveBullish[]; // Count of consecutive bullish expansion signals
double         BufferExpConsecutiveBearish[]; // Count of consecutive bearish expansion signals
double         BufferSignalBar[];       // Buffer to mark signal bars

//--- Include helper functions (after variable declarations)
#include "lib/PatternHelpers.mqh"
#include "lib/BodySizePatterns.mqh"
// #include "lib/CandlePatterns.mqh"  // Removed: inside bar patterns disabled

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping for DRAW_COLOR_CANDLES
   SetIndexBuffer(0, BufferOpen, INDICATOR_DATA);
   SetIndexBuffer(1, BufferHigh, INDICATOR_DATA);
   SetIndexBuffer(2, BufferLow, INDICATOR_DATA);
   SetIndexBuffer(3, BufferClose, INDICATOR_DATA);
   SetIndexBuffer(4, BufferColorIndex, INDICATOR_COLOR_INDEX);
   
   //--- indicator buffers for expansion signals
   SetIndexBuffer(5, BufferExpBearishSignal, INDICATOR_DATA);
   SetIndexBuffer(6, BufferExpBullishSignal, INDICATOR_DATA);

   //--- indicator buffers for contraction triangles (NEW for v1.30)
   SetIndexBuffer(7, BufferContBearishSignal, INDICATOR_DATA);
   SetIndexBuffer(8, BufferContBullishSignal, INDICATOR_DATA);

   //--- indicator buffers for calculations
   SetIndexBuffer(9, BufferBodySizes, INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, BufferConsecutiveBullish, INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, BufferConsecutiveBearish, INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, BufferExpConsecutiveBullish, INDICATOR_CALCULATIONS);
   SetIndexBuffer(13, BufferExpConsecutiveBearish, INDICATOR_CALCULATIONS);
   SetIndexBuffer(14, BufferSignalBar, INDICATOR_CALCULATIONS);
   
   //--- setting indicator parameters
   IndicatorSetString(INDICATOR_SHORTNAME, "Consecutive Pattern Combined (" + string(InpConsecutiveCount) + ")");
   
   //--- Set the number of colors in the color buffer
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 5); // 5 colors (default, bullish, bearish, inside bar, both)
   
   //--- Set the colors for the color buffer
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, COLOR_NONE, InpDefaultColor);  // Default color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, CLR_BULLISH, InpBullishColor);  // Bullish signal color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, CLR_BEARISH, InpBearishColor);  // Bearish signal color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, CLR_INSIDE_BAR, clrPurple);  // Inside bar signal color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, CLR_BOTH, clrWhite);  // Both patterns signal color

   //--- Set the drawing type and properties
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_CANDLES);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpConsecutiveCount);
   
   //--- Set arrow properties for bearish expansion signals
   PlotIndexSetInteger(1, PLOT_ARROW, InpArrowCode);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, 0);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpConsecutiveCount);
   PlotIndexSetInteger(1, PLOT_SHIFT, 0);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpBearishColor);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpArrowSize);
   
   //--- Set arrow properties for bullish expansion signals
   PlotIndexSetInteger(2, PLOT_ARROW, InpArrowCode);
   PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, 0);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpConsecutiveCount);
   PlotIndexSetInteger(2, PLOT_SHIFT, 0);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpBullishColor);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpArrowSize);

   //--- Set arrow properties for contraction UPPER circle (NEW for v1.30)
   // Two circles (upper + lower) = contraction pattern
   PlotIndexSetInteger(3, PLOT_ARROW, 159);  // Circle (same as default)
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT, 0);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, InpConsecutiveCount);
   PlotIndexSetInteger(3, PLOT_SHIFT, 0);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, clrOrange);  // Orange for visibility
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, 2);

   //--- Set arrow properties for contraction LOWER circle (NEW for v1.30)
   // Two circles (upper + lower) = contraction pattern
   PlotIndexSetInteger(4, PLOT_ARROW, 159);  // Circle (same as default)
   PlotIndexSetInteger(4, PLOT_ARROW_SHIFT, 0);
   PlotIndexSetInteger(4, PLOT_DRAW_BEGIN, InpConsecutiveCount);
   PlotIndexSetInteger(4, PLOT_SHIFT, 0);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, clrOrange);  // Orange for visibility
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, 2);

   //--- Enable/disable plots based on input settings
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, InpShowColorBars ? DRAW_COLOR_CANDLES : DRAW_NONE);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, InpShowDots ? DRAW_ARROW : DRAW_NONE);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, InpShowDots ? DRAW_ARROW : DRAW_NONE);
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_ARROW);  // Always show contraction triangles
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_ARROW);  // Always show contraction triangles
   
   //--- Set buffer as timeseries (newest bars at the lowest indices)
   ArraySetAsSeries(BufferOpen, true);
   ArraySetAsSeries(BufferHigh, true);
   ArraySetAsSeries(BufferLow, true);
   ArraySetAsSeries(BufferClose, true);
   ArraySetAsSeries(BufferColorIndex, true);
   ArraySetAsSeries(BufferExpBearishSignal, true);
   ArraySetAsSeries(BufferExpBullishSignal, true);
   ArraySetAsSeries(BufferContBearishSignal, true);  // NEW for v1.30
   ArraySetAsSeries(BufferContBullishSignal, true);  // NEW for v1.30
   ArraySetAsSeries(BufferBodySizes, true);
   ArraySetAsSeries(BufferConsecutiveBullish, true);
   ArraySetAsSeries(BufferConsecutiveBearish, true);
   ArraySetAsSeries(BufferExpConsecutiveBullish, true);
   ArraySetAsSeries(BufferExpConsecutiveBearish, true);
   ArraySetAsSeries(BufferSignalBar, true);
   
   //--- Initialize buffers with empty values
   ArrayInitialize(BufferExpBearishSignal, EMPTY_VALUE);
   ArrayInitialize(BufferExpBullishSignal, EMPTY_VALUE);
   ArrayInitialize(BufferContBearishSignal, EMPTY_VALUE);  // NEW for v1.30
   ArrayInitialize(BufferContBullishSignal, EMPTY_VALUE);  // NEW for v1.30
   ArrayInitialize(BufferConsecutiveBullish, 0);
   ArrayInitialize(BufferConsecutiveBearish, 0);
   ArrayInitialize(BufferExpConsecutiveBullish, 0);
   ArrayInitialize(BufferExpConsecutiveBearish, 0);
   ArrayInitialize(BufferSignalBar, 0);
   ArrayInitialize(BufferColorIndex, COLOR_NONE); // Default color index
   
   //--- initialization done
   return(INIT_SUCCEEDED);
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
   //--- Check for minimum bars required
   if(rates_total <= InpConsecutiveCount)
      return(0);
      
   //--- Make arrays as timeseries (newest bars at the lowest indices)
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);
   
   //--- Calculate the first bar to start from
   int start = (prev_calculated == 0) ? rates_total - 1 : prev_calculated - 1;
   
   //--- Initialize buffers if this is the first calculation
   if(prev_calculated == 0)
   {
      ArrayInitialize(BufferExpBearishSignal, EMPTY_VALUE);
      ArrayInitialize(BufferExpBullishSignal, EMPTY_VALUE);
      ArrayInitialize(BufferContBearishSignal, EMPTY_VALUE);  // NEW for v1.30
      ArrayInitialize(BufferContBullishSignal, EMPTY_VALUE);  // NEW for v1.30
      ArrayInitialize(BufferBodySizes, 0.0);
      ArrayInitialize(BufferConsecutiveBullish, 0);
      ArrayInitialize(BufferConsecutiveBearish, 0);
      ArrayInitialize(BufferExpConsecutiveBullish, 0);
      ArrayInitialize(BufferExpConsecutiveBearish, 0);
      ArrayInitialize(BufferSignalBar, 0);
      ArrayInitialize(BufferColorIndex, COLOR_NONE); // Default color index
   }
   
   //--- Copy price data to our buffers and calculate body sizes for all bars that need updating
   for(int i = start; i >= 0; i--)
   {
      //--- Copy price data
      BufferOpen[i] = open[i];
      BufferHigh[i] = high[i];
      BufferLow[i] = low[i];
      BufferClose[i] = close[i];
      
      //--- Calculate absolute body size
      BufferBodySizes[i] = MathAbs(close[i] - open[i]);
      
      //--- Reset signals and colors
      BufferExpBearishSignal[i] = EMPTY_VALUE;
      BufferExpBullishSignal[i] = EMPTY_VALUE;
      BufferContBearishSignal[i] = EMPTY_VALUE;  // NEW for v1.30
      BufferContBullishSignal[i] = EMPTY_VALUE;  // NEW for v1.30
      BufferColorIndex[i] = COLOR_NONE; // Default color
      
      // Reset consecutive counters and signal markers for this bar
      BufferConsecutiveBullish[i] = 0;
      BufferConsecutiveBearish[i] = 0;
      BufferExpConsecutiveBullish[i] = 0;
      BufferExpConsecutiveBearish[i] = 0;
      BufferSignalBar[i] = 0;
   }
   
   //--- Check for contraction patterns if enabled
   if(InpShowContractions)
   {
      for(int i = 1; i < rates_total - InpConsecutiveCount; i++)
      {
         //--- Skip bars that don't have enough preceding bars
         if(i + InpConsecutiveCount >= rates_total)
            continue;
         
         // Determine pattern direction based on the first signaling bar
         bool isPatternBullish = close[i] > open[i];
         
         // Check for same direction if required
         if(InpSameDirection && !CheckSameDirection(open, close, i, InpConsecutiveCount, isPatternBullish))
            continue;
         
         // Check for consecutive contractions
         if(!CheckConsecutiveContractions(BufferBodySizes, i, InpConsecutiveCount))
            continue;

         // We have a valid contraction pattern, mark the signal
         // SetContractionSignal(i, isPatternBullish, rates_total);  // DISABLED for v1.30: no bar coloring, only circles

         // NEW for v1.30: Place circle markers for contractions (two circles = sandwich pattern)
         // Place BOTH upper and lower circles regardless of direction to create distinctive visual
         BufferContBearishSignal[i] = high[i] + (10 * Point());  // Upper circle (plot 3, orange)
         BufferContBullishSignal[i] = low[i] - (10 * Point());   // Lower circle (plot 4, orange)

         // No bar coloring for contractions in v1.30 - circles only!
      }
   }
   
   //--- Check for expansion patterns if enabled
   if(InpShowExpansions)
   {
      for(int i = 1; i < rates_total - InpConsecutiveCount; i++)
      {
         //--- Skip bars that don't have enough preceding bars
         if(i + InpConsecutiveCount >= rates_total)
            continue;
         
         // Determine pattern direction based on the first signaling bar
         bool isPatternBullish = close[i] > open[i];
         
         // Check for same direction if required
         if(InpSameDirection && !CheckSameDirection(open, close, i, InpConsecutiveCount, isPatternBullish))
            continue;
         
         // Check for consecutive expansions
         if(!CheckConsecutiveExpansions(BufferBodySizes, i, InpConsecutiveCount))
            continue;
         
         // We have a valid expansion pattern, mark the signal
         SetExpansionSignal(i, isPatternBullish, high, low, rates_total);
      }
   }

   //--- return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+
