//+------------------------------------------------------------------+
//|                           Consecutive Pattern Combined.mq5       |
//|                                                        Terry Li |
//|                                                                 |
//+------------------------------------------------------------------+
#property copyright "Terry Li"
#property version   "1.35"
#property description "Detects consecutive expansions/contractions in bar body size (inside bars removed)"
#property indicator_chart_window
#property indicator_buffers 13
#property indicator_plots   3

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
input bool                InpShowColorBars    = false;      // Show colored bars

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
input double              InpDotOffsetPips    = 1.5;         // Dot distance from price in pips

// Extending line settings
input group "Extending Line Settings"
input bool                InpShowExtendingLines = true;      // Show extending lines from dots
input ENUM_LINE_STYLE     InpLineStyle        = STYLE_DOT;   // Line style
input int                 InpLineWidth        = 1;           // Line width (1=thinnest)
input int                 InpMaxLineHours     = 48;          // Max line duration in hours (0=unlimited)
input int                 InpLineDaysBack     = 30;          // Only create lines for last N days
input bool                InpLineDebug        = true;        // Enable debug logging for lines

// Noise filter settings
input group "Noise Filter Settings"
input double              InpMinBodyPips      = 0.0;         // Minimum body size in pips (0=disabled)

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

// Calculation buffers
double         BufferBodySizes[];       // Body sizes for calculations
double         BufferConsecutiveBullish[]; // Count of consecutive bullish signals
double         BufferConsecutiveBearish[]; // Count of consecutive bearish signals
double         BufferExpConsecutiveBullish[]; // Count of consecutive bullish expansion signals
double         BufferExpConsecutiveBearish[]; // Count of consecutive bearish expansion signals
double         BufferSignalBar[];       // Buffer to mark signal bars

//--- Line object constants
const string LINE_PREFIX = "CCEXP_";        // Prefix for expansion line objects
const string LINE_PREFIX_ACTIVE = "CCEXPA_"; // Prefix for active (unmitigated) lines

//--- Include helper functions (after variable declarations)
#include "lib/PatternHelpers.mqh"
#include "lib/BodySizePatterns.mqh"
// #include "lib/CandlePatterns.mqh"  // Removed: inside bar patterns disabled

//+------------------------------------------------------------------+
//| Create horizontal extending line from expansion signal           |
//+------------------------------------------------------------------+
void CreateExpansionLine(int bar, bool isBullish, double linePrice, datetime barTime)
{
   if(!InpShowExtendingLines)
      return;

   // Check if bar is within the allowed days back
   datetime currentTime = TimeCurrent();
   long maxAgeSec = (long)InpLineDaysBack * 24 * 3600;  // Days to seconds

   if((currentTime - barTime) > maxAgeSec)
   {
      // Bar is older than InpLineDaysBack days - skip
      return;
   }

   // Create unique name using ONLY barTime (stable) - NOT bar index (shifts with new bars)
   // Format: PREFIX_DIRECTION_TIMESTAMP
   string objName = LINE_PREFIX_ACTIVE
                    + (isBullish ? "BULL_" : "BEAR_")
                    + IntegerToString(barTime);

   // IDEMPOTENCY: If line already exists at this barTime, do NOT recreate
   // This prevents duplicates and geometry changes on recalculation
   if(ObjectFind(0, objName) >= 0)
      return;  // Line already exists - skip

   // Also check if a finalized (mitigated) line exists at this barTime
   string finalName = LINE_PREFIX
                    + (isBullish ? "BULL_" : "BEAR_")
                    + IntegerToString(barTime);
   if(ObjectFind(0, finalName) >= 0)
      return;  // Finalized line exists - skip

   // Create horizontal trend line (2 points at same price)
   datetime endTime = currentTime;
   bool created = ObjectCreate(0, objName, OBJ_TREND, 0,
                               barTime, linePrice,    // Start point
                               endTime, linePrice);   // End point (current time)
   if(!created)
   {
      if(InpLineDebug)
         PrintFormat("LINE DEBUG: FAILED to create line '%s' at bar %d, error=%d", objName, bar, GetLastError());
      return;
   }

   // Style the line
   color lineColor = isBullish ? InpBullishColor : InpBearishColor;
   ObjectSetInteger(0, objName, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, InpLineStyle);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpLineWidth);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);           // Behind candles
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);     // Don't extend infinitely
   ObjectSetInteger(0, objName, OBJPROP_RAY_LEFT, false);

   // Debug logging
   if(InpLineDebug)
   {
      double ageHours = (double)(currentTime - barTime) / 3600.0;
      PrintFormat("LINE DEBUG: CREATED %s line at bar %d | Price=%.5f | Time=%s | Age=%.1f hrs | Name=%s",
                  isBullish ? "BULL" : "BEAR",
                  bar,
                  linePrice,
                  TimeToString(barTime, TIME_DATE | TIME_MINUTES),
                  ageHours,
                  objName);
   }
}

//+------------------------------------------------------------------+
//| Extend active lines to current time & check for mitigation       |
//| FIX v1.34: Check ALL bars from line creation to current, not just bar[1] |
//+------------------------------------------------------------------+
void ManageExpansionLines(const double &high[], const double &low[], int rates_total)
{
   if(!InpShowExtendingLines)
      return;

   datetime currentTime = TimeCurrent();
   int total = ObjectsTotal(0);

   // Calculate max duration in seconds (0 = unlimited)
   long maxDurationSec = (InpMaxLineHours > 0) ? (long)InpMaxLineHours * 3600 : 0;

   // Debug counters
   static int lastDebugBar = -1;
   int currentBar = Bars(_Symbol, _Period);
   int activeCount = 0;
   int mitigatedCount = 0;
   int expiredCount = 0;
   int extendedCount = 0;

   // Loop backwards for safe deletion
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);

      // Only process our active lines
      if(StringFind(objName, LINE_PREFIX_ACTIVE) != 0)
         continue;

      activeCount++;

      // Get line start time and price level
      datetime lineStartTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
      double linePrice = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);

      // Check if line is bullish or bearish from name
      bool isBullish = (StringFind(objName, "BULL_") > 0);

      // Find bar index where line was created
      int lineStartBar = iBarShift(_Symbol, _Period, lineStartTime);
      if(lineStartBar < 0)
         lineStartBar = rates_total - 1;  // Fallback to oldest bar

      // FIX: Check ALL bars from line creation to bar 1 (last completed bar)
      bool mitigated = false;
      string mitigationReason = "";
      int mitigationBar = -1;

      for(int b = lineStartBar; b >= 1; b--)
      {
         if(b >= rates_total)
            continue;  // Safety check

         if(isBullish)
         {
            // Bullish line above price - mitigated if high touches/exceeds
            if(high[b] >= linePrice)
            {
               mitigated = true;
               mitigationBar = b;
               mitigationReason = StringFormat("high[%d]=%.5f >= linePrice=%.5f", b, high[b], linePrice);
               break;  // Found first mitigation, stop searching
            }
         }
         else
         {
            // Bearish line below price - mitigated if low touches/drops below
            if(low[b] <= linePrice)
            {
               mitigated = true;
               mitigationBar = b;
               mitigationReason = StringFormat("low[%d]=%.5f <= linePrice=%.5f", b, low[b], linePrice);
               break;  // Found first mitigation, stop searching
            }
         }
      }

      // Check for time expiry (max duration reached)
      bool expired = false;
      double ageHours = (double)(currentTime - lineStartTime) / 3600.0;
      if(maxDurationSec > 0 && (currentTime - lineStartTime) >= maxDurationSec)
         expired = true;

      if(mitigated)
      {
         mitigatedCount++;
         datetime endTime = iTime(_Symbol, _Period, mitigationBar);

         // Move endpoint to mitigation bar
         ObjectMove(0, objName, 1, endTime, linePrice);

         // Rename to final (non-active) prefix
         string finalName = LINE_PREFIX + StringSubstr(objName, StringLen(LINE_PREFIX_ACTIVE));
         ObjectSetString(0, objName, OBJPROP_NAME, finalName);

         if(InpLineDebug)
         {
            PrintFormat("LINE DEBUG: MITIGATED %s line | Price=%.5f | Age=%.1f hrs | Bar=%d | Reason: %s | Name=%s",
                        isBullish ? "BULL" : "BEAR",
                        linePrice,
                        ageHours,
                        mitigationBar,
                        mitigationReason,
                        objName);
         }
      }
      else if(expired)
      {
         expiredCount++;

         // Move endpoint to current time
         ObjectMove(0, objName, 1, currentTime, linePrice);

         // Rename to final (non-active) prefix
         string finalName = LINE_PREFIX + StringSubstr(objName, StringLen(LINE_PREFIX_ACTIVE));
         ObjectSetString(0, objName, OBJPROP_NAME, finalName);

         if(InpLineDebug)
         {
            PrintFormat("LINE DEBUG: EXPIRED %s line | Price=%.5f | Age=%.1f hrs (max=%d hrs) | Name=%s",
                        isBullish ? "BULL" : "BEAR",
                        linePrice,
                        ageHours,
                        InpMaxLineHours,
                        objName);
         }
      }
      else
      {
         extendedCount++;
         // Still active - extend to current time
         ObjectMove(0, objName, 1, currentTime, linePrice);
      }
   }

   // Summary debug on new bar only
   if(InpLineDebug && currentBar != lastDebugBar && (activeCount > 0 || mitigatedCount > 0 || expiredCount > 0))
   {
      lastDebugBar = currentBar;
      PrintFormat("LINE DEBUG: === SUMMARY === Active=%d | Extended=%d | Mitigated=%d | Expired=%d | Time=%s",
                  activeCount,
                  extendedCount,
                  mitigatedCount,
                  expiredCount,
                  TimeToString(currentTime, TIME_DATE | TIME_MINUTES));
   }
}

//+------------------------------------------------------------------+
//| Delete all expansion line objects                                |
//+------------------------------------------------------------------+
void DeleteAllExpansionLines()
{
   int deleted = 0;
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      // Check for both prefixes (active and finalized lines)
      if(StringFind(objName, LINE_PREFIX_ACTIVE) == 0 || StringFind(objName, LINE_PREFIX) == 0)
      {
         ObjectDelete(0, objName);
         deleted++;
      }
   }
   // Force chart redraw to ensure visual cleanup
   if(deleted > 0)
      ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Clean up any existing expansion lines from previous instance
   DeleteAllExpansionLines();

   //--- indicator buffers mapping for DRAW_COLOR_CANDLES
   SetIndexBuffer(0, BufferOpen, INDICATOR_DATA);
   SetIndexBuffer(1, BufferHigh, INDICATOR_DATA);
   SetIndexBuffer(2, BufferLow, INDICATOR_DATA);
   SetIndexBuffer(3, BufferClose, INDICATOR_DATA);
   SetIndexBuffer(4, BufferColorIndex, INDICATOR_COLOR_INDEX);
   
   //--- indicator buffers for expansion signals
   SetIndexBuffer(5, BufferExpBearishSignal, INDICATOR_DATA);
   SetIndexBuffer(6, BufferExpBullishSignal, INDICATOR_DATA);

   //--- indicator buffers for calculations
   SetIndexBuffer(7, BufferBodySizes, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, BufferConsecutiveBullish, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, BufferConsecutiveBearish, INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, BufferExpConsecutiveBullish, INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, BufferExpConsecutiveBearish, INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, BufferSignalBar, INDICATOR_CALCULATIONS);
   
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

   //--- Enable/disable plots based on input settings
   //--- CRITICAL FIX v1.27: Don't use DRAW_NONE for plot 0 - it breaks buffer mapping for plots 1 & 2
   //--- Instead, keep DRAW_COLOR_CANDLES but set width to 0 to hide it
   if(InpShowColorBars)
   {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_CANDLES);
      PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 1);
   }
   else
   {
      // Keep DRAW_COLOR_CANDLES to preserve buffer mapping, but make invisible
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_CANDLES);
      PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 0);  // Width 0 = invisible
   }
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, InpShowDots ? DRAW_ARROW : DRAW_NONE);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, InpShowDots ? DRAW_ARROW : DRAW_NONE);
   
   //--- Set buffer as timeseries (newest bars at the lowest indices)
   ArraySetAsSeries(BufferOpen, true);
   ArraySetAsSeries(BufferHigh, true);
   ArraySetAsSeries(BufferLow, true);
   ArraySetAsSeries(BufferClose, true);
   ArraySetAsSeries(BufferColorIndex, true);
   ArraySetAsSeries(BufferExpBearishSignal, true);
   ArraySetAsSeries(BufferExpBullishSignal, true);
   ArraySetAsSeries(BufferBodySizes, true);
   ArraySetAsSeries(BufferConsecutiveBullish, true);
   ArraySetAsSeries(BufferConsecutiveBearish, true);
   ArraySetAsSeries(BufferExpConsecutiveBullish, true);
   ArraySetAsSeries(BufferExpConsecutiveBearish, true);
   ArraySetAsSeries(BufferSignalBar, true);
   
   //--- Initialize buffers with empty values
   //--- CRITICAL: Use 0.0 for arrow buffers (not EMPTY_VALUE/DBL_MAX)
   //--- 0.0 is more reliable as "no draw" since prices are always positive
   ArrayInitialize(BufferExpBearishSignal, 0.0);
   ArrayInitialize(BufferExpBullishSignal, 0.0);
   ArrayInitialize(BufferConsecutiveBullish, 0);
   ArrayInitialize(BufferConsecutiveBearish, 0);
   ArrayInitialize(BufferExpConsecutiveBullish, 0);
   ArrayInitialize(BufferExpConsecutiveBearish, 0);
   ArrayInitialize(BufferSignalBar, 0);
   ArrayInitialize(BufferColorIndex, COLOR_NONE); // Default color index

   //--- Set 0.0 as "no draw" value for arrow plots
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);

   //--- Debug: Log line settings
   if(InpLineDebug && InpShowExtendingLines)
   {
      Print("=== CC INDICATOR v1.35 - LINE SETTINGS ===");
      PrintFormat("  Extending Lines: ENABLED");
      PrintFormat("  Line Style: %s",
                  InpLineStyle == STYLE_DOT ? "DOTTED" :
                  InpLineStyle == STYLE_DASH ? "DASHED" :
                  InpLineStyle == STYLE_SOLID ? "SOLID" : "OTHER");
      PrintFormat("  Line Width: %d", InpLineWidth);
      PrintFormat("  Max Duration: %d hours", InpMaxLineHours);
      PrintFormat("  Days Back Limit: %d days", InpLineDaysBack);
      PrintFormat("  Dot Offset: %d pips", InpDotOffsetPips);
      Print("==========================================");
   }

   //--- initialization done
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Clean up all expansion line objects
   //--- Critical for timeframe changes (REASON_CHARTCHANGE) and recompilation
   DeleteAllExpansionLines();

   //--- Force immediate visual update
   ChartRedraw(0);
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
      ArrayInitialize(BufferExpBearishSignal, 0.0);  // Use 0.0, not EMPTY_VALUE
      ArrayInitialize(BufferExpBullishSignal, 0.0);  // Use 0.0, not EMPTY_VALUE
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

      //--- SYNC FIX: Check if line exists at this bar's time before resetting buffer
      //--- This keeps dot (buffer) in sync with line (object)
      datetime barTime = time[i];
      string bullLineName = LINE_PREFIX_ACTIVE + "BULL_" + IntegerToString(barTime);
      string bearLineName = LINE_PREFIX_ACTIVE + "BEAR_" + IntegerToString(barTime);
      string bullFinalName = LINE_PREFIX + "BULL_" + IntegerToString(barTime);
      string bearFinalName = LINE_PREFIX + "BEAR_" + IntegerToString(barTime);

      // Check for bullish line (active or finalized)
      if(ObjectFind(0, bullLineName) >= 0)
      {
         // Line exists - restore buffer from line price
         BufferExpBullishSignal[i] = ObjectGetDouble(0, bullLineName, OBJPROP_PRICE, 0);
      }
      else if(ObjectFind(0, bullFinalName) >= 0)
      {
         BufferExpBullishSignal[i] = ObjectGetDouble(0, bullFinalName, OBJPROP_PRICE, 0);
      }
      else
      {
         BufferExpBullishSignal[i] = 0.0;  // No line - reset to empty
      }

      // Check for bearish line (active or finalized)
      if(ObjectFind(0, bearLineName) >= 0)
      {
         BufferExpBearishSignal[i] = ObjectGetDouble(0, bearLineName, OBJPROP_PRICE, 0);
      }
      else if(ObjectFind(0, bearFinalName) >= 0)
      {
         BufferExpBearishSignal[i] = ObjectGetDouble(0, bearFinalName, OBJPROP_PRICE, 0);
      }
      else
      {
         BufferExpBearishSignal[i] = 0.0;  // No line - reset to empty
      }

      BufferColorIndex[i] = COLOR_NONE; // Default color

      // Reset consecutive counters and signal markers for this bar
      BufferConsecutiveBullish[i] = 0;
      BufferConsecutiveBearish[i] = 0;
      BufferExpConsecutiveBullish[i] = 0;
      BufferExpConsecutiveBearish[i] = 0;
      BufferSignalBar[i] = 0;
   }
   
   //--- Calculate minimum body size in price units
   double minBodyPrice = InpMinBodyPips * PipSize();  // Universal pip conversion

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

         // Check minimum body size filter
         if(!CheckMinimumBodySize(BufferBodySizes, i, InpConsecutiveCount, minBodyPrice))
            continue;

         // Check for same direction if required
         if(InpSameDirection && !CheckSameDirection(open, close, i, InpConsecutiveCount, isPatternBullish))
            continue;

         // Check for consecutive contractions
         if(!CheckConsecutiveContractions(BufferBodySizes, i, InpConsecutiveCount))
            continue;

         // We have a valid contraction pattern, mark the signal
         SetContractionSignal(i, isPatternBullish, rates_total);
      }
   }

   //--- Check for expansion patterns if enabled
   if(InpShowExpansions)
   {
      int debugCount = 0;
      int signalCount = 0;

      for(int i = 1; i < rates_total - InpConsecutiveCount; i++)
      {
         //--- Skip bars that don't have enough preceding bars
         if(i + InpConsecutiveCount >= rates_total)
            continue;

         // Determine pattern direction based on the first signaling bar
         bool isPatternBullish = close[i] > open[i];

         // Check minimum body size filter
         if(!CheckMinimumBodySize(BufferBodySizes, i, InpConsecutiveCount, minBodyPrice))
            continue;

         // Check for same direction if required
         if(InpSameDirection && !CheckSameDirection(open, close, i, InpConsecutiveCount, isPatternBullish))
            continue;

         // Check for consecutive expansions
         if(!CheckConsecutiveExpansions(BufferBodySizes, i, InpConsecutiveCount))
            continue;

         // === OVERLAPPING PATTERN FIX ===
         // Only signal at the END of an expansion sequence (where pattern doesn't extend further)
         // Check if the pattern would also be valid one bar earlier (i-1, i, i+1)
         // If yes, this bar is part of a longer sequence - skip it, wait for the end
         if(i > 0)
         {
            bool prevBarSameDirection = true;
            if(InpSameDirection)
            {
               bool isPrevBarBullish = close[i-1] > open[i-1];
               prevBarSameDirection = (isPrevBarBullish == isPatternBullish);
            }

            // Check if expansion extends one bar earlier
            bool extendsEarlier = prevBarSameDirection &&
                                  CheckMinimumBodySize(BufferBodySizes, i-1, InpConsecutiveCount, minBodyPrice) &&
                                  (BufferBodySizes[i-1] > BufferBodySizes[i]); // Expansion continues

            if(extendsEarlier)
               continue; // Skip - this is part of a longer sequence, not the end
         }

         // DEBUG: Log first 10 signals to understand what's triggering
         if(debugCount < 10 && prev_calculated == 0)
         {
            Print("DEBUG Expansion bar ", i, ": bodies=[",
                  DoubleToString(BufferBodySizes[i], 5), ", ",
                  DoubleToString(BufferBodySizes[i+1], 5), ", ",
                  DoubleToString(BufferBodySizes[i+2], 5), "] ",
                  isPatternBullish ? "BULL" : "BEAR");
            debugCount++;
         }
         signalCount++;

         // We have a valid expansion pattern, mark the signal
         SetExpansionSignal(i, isPatternBullish, high, low, time, rates_total);
      }

      // Log total signal count on first calculation
      if(prev_calculated == 0)
         Print("DEBUG: Total expansion signals: ", signalCount, " out of ", rates_total, " bars");
   }

   //--- DIAGNOSTIC: Verify actual buffer state after all processing
   if(prev_calculated == 0)
   {
      int bullishDotCount = 0;
      int bearishDotCount = 0;
      int coloredBarCount = 0;
      int firstBullBar = -1, lastBullBar = -1;
      int firstBearBar = -1, lastBearBar = -1;

      for(int i = 0; i < rates_total; i++)
      {
         if(BufferExpBullishSignal[i] != 0.0)  // Check for 0.0, not EMPTY_VALUE
         {
            bullishDotCount++;
            if(firstBullBar == -1) firstBullBar = i;
            lastBullBar = i;
         }
         if(BufferExpBearishSignal[i] != 0.0)  // Check for 0.0, not EMPTY_VALUE
         {
            bearishDotCount++;
            if(firstBearBar == -1) firstBearBar = i;
            lastBearBar = i;
         }
         if(BufferColorIndex[i] != COLOR_NONE)
         {
            coloredBarCount++;
         }
      }

      Print("=== BUFFER STATE DIAGNOSTIC v1.27 ===");
      Print("Bullish dots in buffer: ", bullishDotCount, " (first=", firstBullBar, ", last=", lastBullBar, ")");
      Print("Bearish dots in buffer: ", bearishDotCount, " (first=", firstBearBar, ", last=", lastBearBar, ")");
      Print("Colored bars in buffer: ", coloredBarCount);
      Print("Total dots: ", bullishDotCount + bearishDotCount);
      Print("InpShowDots=", InpShowDots, " InpShowColorBars=", InpShowColorBars);

      // Additional diagnostic: Sample buffer values
      Print("--- Sample Buffer Values ---");
      Print("Bar 0 (newest): Bull=", BufferExpBullishSignal[0], " Bear=", BufferExpBearishSignal[0]);
      Print("Bar 1: Bull=", BufferExpBullishSignal[1], " Bear=", BufferExpBearishSignal[1]);
      Print("Bar 2: Bull=", BufferExpBullishSignal[2], " Bear=", BufferExpBearishSignal[2]);
      Print("Bar 3: Bull=", BufferExpBullishSignal[3], " Bear=", BufferExpBearishSignal[3]);
      Print("Bar 4: Bull=", BufferExpBullishSignal[4], " Bear=", BufferExpBearishSignal[4]);
      Print("Bar 5: Bull=", BufferExpBullishSignal[5], " Bear=", BufferExpBearishSignal[5]);

      // Find and show first signal bar values
      for(int i = 0; i < 100 && i < rates_total; i++)
      {
         if(BufferExpBullishSignal[i] != 0.0)
         {
            Print("FIRST BULL SIGNAL at bar ", i, ": value=", BufferExpBullishSignal[i], " high=", BufferHigh[i]);
            break;
         }
      }
      for(int i = 0; i < 100 && i < rates_total; i++)
      {
         if(BufferExpBearishSignal[i] != 0.0)
         {
            Print("FIRST BEAR SIGNAL at bar ", i, ": value=", BufferExpBearishSignal[i], " low=", BufferLow[i]);
            break;
         }
      }

      // Plot properties diagnostic
      Print("--- Plot Properties ---");
      Print("Plot 1 (bear): DRAW_TYPE=", PlotIndexGetInteger(1, PLOT_DRAW_TYPE), " ARROW=", PlotIndexGetInteger(1, PLOT_ARROW));
      Print("Plot 2 (bull): DRAW_TYPE=", PlotIndexGetInteger(2, PLOT_DRAW_TYPE), " ARROW=", PlotIndexGetInteger(2, PLOT_ARROW));
      Print("=====================================");
   }

   //--- Manage extending lines: extend active ones to current bar, finalize mitigated ones
   ManageExpansionLines(high, low, rates_total);

   //--- return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+
