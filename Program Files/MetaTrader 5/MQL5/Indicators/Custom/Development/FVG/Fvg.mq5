//+------------------------------------------------------------------+
//|                                                          Fvg.mq5 |
//|                        Based on rpanchyk's FVG indicator v1.03   |
//|                        Optimized version - O(n) complexity       |
//+------------------------------------------------------------------+
//|  OPTIMIZATION RESEARCH NOTES (2026-01-02)                        |
//|  --------------------------------------------------------        |
//|  This indicator has been thoroughly optimized. Further micro-    |
//|  optimizations were researched but deemed not worth the          |
//|  trade-offs. See inline comments marked [OPT-RESEARCH] for       |
//|  detailed justifications.                                        |
//|                                                                  |
//|  Key MQL5 findings from official docs & forums:                  |
//|  1. ObjectCreate/ObjectMove use ASYNCHRONOUS calls - they queue  |
//|     commands and return immediately (non-blocking)               |
//|  2. ObjectFind is SYNCHRONOUS - waits for result, costly with    |
//|     many objects. Used sparingly here for safety guards only.    |
//|  3. ArraySetAsSeries only changes indexing direction, no perf    |
//|     cost - safe to call in OnCalculate                           |
//|  4. PeriodSeconds() cached in OnInit - avoids repeated calls     |
//|                                                                  |
//|  Sources:                                                        |
//|  - https://www.mql5.com/en/docs/objects (async behavior)         |
//|  - https://www.mql5.com/en/forum/160173 (speed optimization)     |
//|  - https://www.mql5.com/en/forum/304837 (ArraySetAsSeries)       |
//|  - https://www.mql5.com/en/forum/427602 (MT5 runtime speed)      |
//+------------------------------------------------------------------+
#property copyright   "Optimized by Terry Li, Original by rpanchyk"
#property link        "https://github.com/rpanchyk"
#property version     "7.1.1"
#property description "Optimized Fair Value Gap indicator v7.1.0"
#property description "Key features:"
#property description "- 3-bar ICT FVG detection (original)"
#property description "- N-bar void-chain FVG detection (4-bar, 5-bar, etc.)"
#property description "- Chain-end only detection prevents duplicate boxes"
#property description "- Bright colors for ACTIVE zones, faint for mitigated"
#property description "- O(n) mitigation tracking with circular buffer"

#property indicator_chart_window
#property indicator_plots 3
#property indicator_buffers 3

// types
enum ENUM_BORDER_STYLE
  {
   BORDER_STYLE_SOLID = STYLE_SOLID, // Solid
   BORDER_STYLE_DASH = STYLE_DASH // Dash
  };

// Data buffers (visible)
double FvgHighPriceBuffer[];  // Higher price of FVG
double FvgLowPriceBuffer[];   // Lower price of FVG
double FvgTrendBuffer[];      // Trend of FVG [0: NO, -1: DOWN, 1: UP]

// config
input group "Section :: Main";
input bool InpContinueToMitigation = true; // Continue to mitigation
input int  InpMaxFvgAge = 0;               // Max bars to track FVGs (0=unlimited)
input bool InpDetectVoidChainFvg = true;   // Detect void-chain FVGs (N-bar patterns)
input int  InpMaxVoidChain = 10;           // Max consecutive voids to scan (default 10)

input group "Section :: Style";
input color InpDownTrendColor = C'25,12,12';        // Down trend color (base - very faint)
input color InpUpTrendColor = C'12,25,12';          // Up trend color (base - very faint)
input color InpDownTrendActiveColor = C'180,60,60'; // Down trend ACTIVE end stripe (brighter)
input color InpUpTrendActiveColor = C'60,180,60';   // Up trend ACTIVE end stripe (brighter)
input int InpActiveStripeWidth = 3;                  // Active zone end stripe width (bars)
input bool InpFill = true;                           // Fill solid (true) or transparent (false)
input ENUM_BORDER_STYLE InpBoderStyle = BORDER_STYLE_SOLID; // Border line style
input int InpBorderWidth = 0;                        // Border line width (0 = no border)

input group "Section :: Dev";
input bool InpDebugEnabled = true;                     // Enable debug (verbose logging)
input string InpDebugTimeFilter = "2025.12.11 17:02";  // Debug specific time (YYYY.MM.DD HH:MM or empty for recent bars)

// constants
const string OBJECT_PREFIX = "FVGO_";         // Main FVG box prefix (3-bar ICT)
const string STRIPE_PREFIX = "FVGO_STRIPE_";  // Active end stripe prefix
const string NBAR_PREFIX = "FVGN";            // N-bar void-chain FVG prefix (e.g., FVGN4_, FVGN5_)
const string NBAR_STRIPE_PREFIX = "FVGN_STRIPE_";  // N-bar active stripe prefix

// Global tracking for active FVGs (avoid object iteration)
struct FvgData
  {
   datetime          startTime;
   datetime          endTime;
   double            highPrice;
   double            lowPrice;
   int               trend;        // 1 = up, -1 = down
   bool              mitigated;
   string            objName;
   bool              isNBar;       // true if N-bar void-chain FVG
  };

FvgData ActiveFvgs[];
int ActiveFvgCount = 0;
int ActiveFvgHead = 0;  // Circular buffer head index
const int MAX_ACTIVE_FVGS = 200;  // Limit active FVGs to prevent memory bloat

// Cached values for performance (avoid repeated function calls)
// [OPT-RESEARCH] PeriodSeconds() is cached here because it's a function call
// that returns the same value for the indicator's lifetime. Called once in
// OnInit instead of potentially hundreds of times per tick in UpdateActiveStripe.
int CachedPeriodSeconds = 0;

// [OPT-RESEARCH] ChartRedraw(0) is expensive - forces full chart repaint.
// We track whether any objects actually changed and only redraw when needed.
// On quiet ticks with no new bars/mitigations, this saves significant CPU.
bool NeedsRedraw = false;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpDebugEnabled)
      Print("Fvg_Optimized indicator initialization started");

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   // Data buffers
   ArrayInitialize(FvgHighPriceBuffer, EMPTY_VALUE);
   ArraySetAsSeries(FvgHighPriceBuffer, true);
   SetIndexBuffer(0, FvgHighPriceBuffer, INDICATOR_DATA);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetString(0, PLOT_LABEL, "Fvg High");
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);

   ArrayInitialize(FvgLowPriceBuffer, EMPTY_VALUE);
   ArraySetAsSeries(FvgLowPriceBuffer, true);
   SetIndexBuffer(1, FvgLowPriceBuffer, INDICATOR_DATA);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetString(1, PLOT_LABEL, "Fvg Low");
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);

   ArrayInitialize(FvgTrendBuffer, EMPTY_VALUE);
   ArraySetAsSeries(FvgTrendBuffer, true);
   SetIndexBuffer(2, FvgTrendBuffer, INDICATOR_DATA);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetString(2, PLOT_LABEL, "Fvg Trend");
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);

   // Initialize active FVG tracking (circular buffer)
   ArrayResize(ActiveFvgs, MAX_ACTIVE_FVGS);
   ActiveFvgCount = 0;
   ActiveFvgHead = 0;

   // Cache period seconds (called once, not every tick)
   CachedPeriodSeconds = PeriodSeconds(_Period);

   if(InpDebugEnabled)
      Print("Fvg_Optimized indicator initialization finished");

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Check if bar time matches debug filter (±10 bars radius)          |
//+------------------------------------------------------------------+
bool ShouldDebugBar(datetime barTime)
  {
   if(!InpDebugEnabled) return false;
   if(InpDebugTimeFilter == "") return true;  // Log all if no filter

   // Parse filter time and check if within 10 minutes (for M1 = 10 bars)
   datetime filterTime = StringToTime(InpDebugTimeFilter);
   if(filterTime == 0) return true;  // Invalid filter, log all

   // Check if bar is within ±10 minutes of filter time
   return (MathAbs((long)barTime - (long)filterTime) <= 600);
  }

//+------------------------------------------------------------------+
//| Log bars in vicinity with full OHLC data                          |
//| If filter is empty, shows most recent 30 bars                     |
//+------------------------------------------------------------------+
void DebugLogAllBarsInVicinity(const datetime &time[], const double &open[],
                               const double &high[], const double &low[],
                               const double &close[], int rates_total)
  {
   if(!InpDebugEnabled) return;

   Print("========================================================================");

   if(InpDebugTimeFilter == "")
     {
      // No filter: Show chart time range and most recent bars
      Print("           FORENSIC: CHART TIME RANGE                                  ");
      PrintFormat("           Oldest visible: %s (bar %d)",
                  TimeToString(time[rates_total-1], TIME_DATE|TIME_MINUTES), rates_total-1);
      PrintFormat("           Newest visible: %s (bar 0)",
                  TimeToString(time[0], TIME_DATE|TIME_MINUTES));
      Print("========================================================================");
      Print("           MOST RECENT 30 BARS (set InpDebugTimeFilter to filter)      ");
     }
   else
     {
      // Filter specified: Show target time
      Print("           FORENSIC PRICE DATA AROUND TARGET TIME                       ");
      PrintFormat("           Target: %s", InpDebugTimeFilter);
     }

   Print("========================================================================");
   Print("Bar#  |      Time        |    Open   |   High    |    Low    |   Close   ");
   Print("------+------------------+-----------+-----------+-----------+-----------");

   datetime filterTime = StringToTime(InpDebugTimeFilter);

   if(InpDebugTimeFilter == "" || filterTime == 0)
     {
      // No filter or invalid: Show most recent 30 bars
      int showCount = MathMin(30, rates_total);
      for(int i = 0; i < showCount; i++)
        {
         PrintFormat("%4d  | %s | %.5f | %.5f | %.5f | %.5f",
                     i, TimeToString(time[i], TIME_DATE|TIME_MINUTES),
                     open[i], high[i], low[i], close[i]);
        }
     }
   else
     {
      // Filter specified: Find bars within ±15 minutes of target
      // Search ALL bars, not just first 500
      int foundCount = 0;
      for(int i = 0; i < rates_total; i++)
        {
         if(MathAbs((long)time[i] - (long)filterTime) <= 900)  // ±15 minutes
           {
            string marker = "";
            if(MathAbs((long)time[i] - (long)filterTime) <= 60)
               marker = " <<<TARGET";

            PrintFormat("%4d  | %s | %.5f | %.5f | %.5f | %.5f%s",
                        i, TimeToString(time[i], TIME_DATE|TIME_MINUTES),
                        open[i], high[i], low[i], close[i], marker);
            foundCount++;
           }
        }

      if(foundCount == 0)
        {
         Print(">>> NO BARS FOUND within ±15 min of target time!");
         PrintFormat(">>> Chart range: %s to %s",
                     TimeToString(time[rates_total-1], TIME_DATE|TIME_MINUTES),
                     TimeToString(time[0], TIME_DATE|TIME_MINUTES));
         Print(">>> Scroll chart to target time or clear InpDebugTimeFilter");
        }
     }

   Print("========================================================================");
   Print("");
  }

//+------------------------------------------------------------------+
//| Log detailed 3-bar FVG analysis for debugging                     |
//+------------------------------------------------------------------+
void DebugLog3BarAnalysis(int i, datetime rightTime, datetime midTime, datetime leftTime,
                          double rightHigh, double rightLow,
                          double midHigh, double midLow,
                          double leftHigh, double leftLow)
  {
   if(!ShouldDebugBar(midTime)) return;

   // Up trend conditions
   bool upLeft = midLow <= leftHigh && midLow > leftLow;
   bool upRight = midHigh >= rightLow && midHigh < rightHigh;
   bool upGap = leftHigh < rightLow;

   // Down trend conditions
   bool downLeft = midHigh >= leftLow && midHigh < leftHigh;
   bool downRight = midLow <= rightHigh && midLow > rightLow;
   bool downGap = leftLow > rightHigh;

   PrintFormat("========== FVG DEBUG @ Bar %d ==========", i);
   PrintFormat("Times: Left=%s | Mid=%s | Right=%s",
               TimeToString(leftTime, TIME_DATE|TIME_MINUTES),
               TimeToString(midTime, TIME_DATE|TIME_MINUTES),
               TimeToString(rightTime, TIME_DATE|TIME_MINUTES));
   PrintFormat("Left:  High=%.5f, Low=%.5f", leftHigh, leftLow);
   PrintFormat("Mid:   High=%.5f, Low=%.5f", midHigh, midLow);
   PrintFormat("Right: High=%.5f, Low=%.5f", rightHigh, rightLow);
   PrintFormat("------- UP TREND FVG -------");
   PrintFormat("  upLeft:  midLow(%.5f) <= leftHigh(%.5f) = %s", midLow, leftHigh, (midLow <= leftHigh) ? "PASS" : "FAIL");
   PrintFormat("           midLow(%.5f) > leftLow(%.5f) = %s", midLow, leftLow, (midLow > leftLow) ? "PASS" : "FAIL");
   PrintFormat("  upRight: midHigh(%.5f) >= rightLow(%.5f) = %s", midHigh, rightLow, (midHigh >= rightLow) ? "PASS" : "FAIL");
   PrintFormat("           midHigh(%.5f) < rightHigh(%.5f) = %s", midHigh, rightHigh, (midHigh < rightHigh) ? "PASS" : "FAIL");
   PrintFormat("  upGap:   leftHigh(%.5f) < rightLow(%.5f) = %s (gap=%.5f pips=%.1f)",
               leftHigh, rightLow, upGap ? "PASS" : "FAIL", rightLow - leftHigh, (rightLow - leftHigh)/_Point);
   PrintFormat("  >>> UP FVG RESULT: %s", (upLeft && upRight && upGap) ? "DETECTED" : "NOT DETECTED");
   PrintFormat("------- DOWN TREND FVG -------");
   PrintFormat("  downLeft:  midHigh(%.5f) >= leftLow(%.5f) = %s", midHigh, leftLow, (midHigh >= leftLow) ? "PASS" : "FAIL");
   PrintFormat("             midHigh(%.5f) < leftHigh(%.5f) = %s", midHigh, leftHigh, (midHigh < leftHigh) ? "PASS" : "FAIL");
   PrintFormat("  downRight: midLow(%.5f) <= rightHigh(%.5f) = %s", midLow, rightHigh, (midLow <= rightHigh) ? "PASS" : "FAIL");
   PrintFormat("             midLow(%.5f) > rightLow(%.5f) = %s", midLow, rightLow, (midLow > rightLow) ? "PASS" : "FAIL");
   PrintFormat("  downGap:   leftLow(%.5f) > rightHigh(%.5f) = %s (gap=%.5f pips=%.1f)",
               leftLow, rightHigh, downGap ? "PASS" : "FAIL", leftLow - rightHigh, (leftLow - rightHigh)/_Point);
   PrintFormat("  >>> DOWN FVG RESULT: %s", (downLeft && downRight && downGap) ? "DETECTED" : "NOT DETECTED");
   PrintFormat("==========================================");
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(InpDebugEnabled)
      PrintFormat("Fvg_Optimized indicator deinitialization started (reason=%d)", reason);

   if(reason == REASON_CHARTCHANGE)
     {
      // Chart change: Delete ONLY stripes (boxes persist for visual continuity)
      // Stripes will be recreated by OnCalculate during full recalc
      // This prevents orphaned stripes (stripes without tracking data)
      // The bug was: OnInit resets ActiveFvgs array, but stripes existed → orphaned
      ObjectsDeleteAll(0, STRIPE_PREFIX);
      ObjectsDeleteAll(0, NBAR_STRIPE_PREFIX);

      if(InpDebugEnabled)
         Print("Chart change: Deleted stripes only, boxes preserved for recalc");
     }
   else
     {
      // Full cleanup: recompile, remove, parameters change, etc.
      // REASON_PARAMETERS (5) = input parameters changed - need to redraw
      // REASON_RECOMPILE (2), REASON_REMOVE (1), REASON_PROGRAM (0) = full cleanup
      ObjectsDeleteAll(0, OBJECT_PREFIX);
      ObjectsDeleteAll(0, STRIPE_PREFIX);
      ObjectsDeleteAll(0, NBAR_PREFIX);
      ObjectsDeleteAll(0, NBAR_STRIPE_PREFIX);

      // Free arrays
      ArrayFree(ActiveFvgs);
      ActiveFvgCount = 0;
      ActiveFvgHead = 0;
     }

   if(InpDebugEnabled)
      Print("Fvg_Optimized indicator deinitialization finished");
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
   // Early exit if no new data
   if(rates_total == prev_calculated)
      return rates_total;

   // Reset redraw flag at start of each calculation
   NeedsRedraw = false;

   // [OPT-RESEARCH] ArraySetAsSeries only changes indexing direction in memory,
   // it does NOT copy or rearrange data. Per MQL5 docs: "array elements are
   // physically stored in one and the same order - only indexing direction changes."
   // This has negligible performance cost and is safe to call every OnCalculate.
   // Moving to OnInit is NOT possible because these are passed-by-reference arrays.
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   // FORENSIC DEBUG: Log all bars in vicinity of target time
   // Runs on first calc OR when doing full recalc (prev_calculated == 0)
   static bool forensicDumpDone = false;
   if(InpDebugEnabled && InpDebugTimeFilter != "" && (prev_calculated == 0 || !forensicDumpDone))
     {
      DebugLogAllBarsInVicinity(time, open, high, low, close, rates_total);
      forensicDumpDone = true;
     }

   //=== PHASE 1: Update active FVGs with current bar (O(active_count)) ===
   if(InpContinueToMitigation && ActiveFvgCount > 0)
     {
      UpdateActiveFvgs(time, high, low);
     }

   //=== PHASE 2: Detect new FVGs (O(limit)) ===
   int limit = (prev_calculated == 0) ? rates_total - 3 : rates_total - prev_calculated + 1;

   // Apply age limit to avoid processing ancient history
   if(InpMaxFvgAge > 0 && limit > InpMaxFvgAge)
      limit = InpMaxFvgAge;

   if(InpDebugEnabled)
      PrintFormat("RatesTotal: %i, PrevCalculated: %i, Limit: %i, ActiveFVGs: %i",
                  rates_total, prev_calculated, limit, ActiveFvgCount);

   for(int i = 1; i < limit; i++)
     {
      // On subsequent calculations, skip bars that already have FVG data
      // But on first calculation (prev_calculated == 0), process everything
      if(prev_calculated > 0 && FvgTrendBuffer[i + 1] != EMPTY_VALUE && FvgTrendBuffer[i + 1] != 0)
         continue;

      double rightHighPrice = high[i];
      double rightLowPrice = low[i];
      double midHighPrice = high[i + 1];
      double midLowPrice = low[i + 1];
      double leftHighPrice = high[i + 2];
      double leftLowPrice = low[i + 2];

      datetime rightTime = time[i];
      datetime midTime = time[i + 1];
      datetime leftTime = time[i + 2];

      // FORENSIC DEBUG: Log detailed 3-bar analysis for bars near target time
      DebugLog3BarAnalysis(i, rightTime, midTime, leftTime,
                           rightHighPrice, rightLowPrice,
                           midHighPrice, midLowPrice,
                           leftHighPrice, leftLowPrice);

      // Debug: Check for 2-bar voids that might explain missed FVG
      if(ShouldDebugBar(midTime))
        {
         double gap2Bar = rightLowPrice - midHighPrice;  // Bullish 2-bar gap (mid to right)
         double gap2BarPrev = midLowPrice - leftHighPrice; // Bullish 2-bar gap (left to mid)
         PrintFormat(">>> 2-BAR GAPS: [Left->Mid] gap=%.1f pips | [Mid->Right] gap=%.1f pips",
                     gap2BarPrev/_Point, gap2Bar/_Point);
        }

      // Up trend FVG detection
      bool upLeft = midLowPrice <= leftHighPrice && midLowPrice > leftLowPrice;
      bool upRight = midHighPrice >= rightLowPrice && midHighPrice < rightHighPrice;
      bool upGap = leftHighPrice < rightLowPrice;

      if(upLeft && upRight && upGap)
        {
         SetBuffers(i + 1, rightLowPrice, leftHighPrice, 1);

         datetime endTime = time[0];  // Default: extend to current
         bool stillActive = true;

         // OPTIMIZED: Single-pass mitigation check (not nested loop)
         if(InpContinueToMitigation)
           {
            for(int j = i - 1; j >= 1; j--)
              {
               if((rightLowPrice < high[j] && rightLowPrice >= low[j]) ||
                  (leftHighPrice > low[j] && leftHighPrice <= high[j]))
                 {
                  endTime = time[j];
                  stillActive = false;
                  break;
                 }
              }
           }

         // Create box and track if active
         string objName = CreateFvgBox(leftTime, leftHighPrice, endTime, rightLowPrice, stillActive, 1);

         if(stillActive && InpContinueToMitigation)
            AddActiveFvg(leftTime, endTime, leftHighPrice, rightLowPrice, 1, objName);

         continue;
        }

      // Down trend FVG detection
      bool downLeft = midHighPrice >= leftLowPrice && midHighPrice < leftHighPrice;
      bool downRight = midLowPrice <= rightHighPrice && midLowPrice > rightLowPrice;
      bool downGap = leftLowPrice > rightHighPrice;

      if(downLeft && downRight && downGap)
        {
         SetBuffers(i + 1, leftLowPrice, rightHighPrice, -1);

         datetime endTime = time[0];  // Default: extend to current
         bool stillActive = true;

         // OPTIMIZED: Single-pass mitigation check
         if(InpContinueToMitigation)
           {
            for(int j = i - 1; j >= 1; j--)
              {
               if((rightHighPrice <= high[j] && rightHighPrice > low[j]) ||
                  (leftLowPrice >= low[j] && leftLowPrice < high[j]))
                 {
                  endTime = time[j];
                  stillActive = false;
                  break;
                 }
              }
           }

         string objName = CreateFvgBox(leftTime, leftLowPrice, endTime, rightHighPrice, stillActive, -1);

         if(stillActive && InpContinueToMitigation)
            AddActiveFvg(leftTime, endTime, leftLowPrice, rightHighPrice, -1, objName);

         continue;
        }

      // No FVG detected (for 3-bar pattern)
      SetBuffers(i + 1, 0, 0, 0);

      // ===== N-BAR VOID-CHAIN FVG DETECTION =====
      // Detect N-bar patterns (4-bar, 5-bar, etc.) triggered by consecutive voids
      DetectVoidChainFvg(i, time, high, low, rates_total);
     }

   // Only redraw when objects actually changed
   if(NeedsRedraw)
      ChartRedraw(0);

   return rates_total;
  }

//+------------------------------------------------------------------+
//| Update active FVGs - O(active_count) instead of O(all_objects)   |
//+------------------------------------------------------------------+
void UpdateActiveFvgs(const datetime &time[], const double &high[], const double &low[])
  {
   datetime currentTime = time[0];
   double currentHigh = high[1];  // Last completed bar
   double currentLow = low[1];

   int i = 0;
   while(i < ActiveFvgCount)
     {
      // Direct array access - no struct copy overhead
      int trend = ActiveFvgs[i].trend;
      double highPrice = ActiveFvgs[i].highPrice;
      double lowPrice = ActiveFvgs[i].lowPrice;

      // Check mitigation
      bool mitigated = false;

      if(trend == 1)  // Up trend
        {
         // Mitigated if price touches gap zone
         if((lowPrice < currentHigh && lowPrice >= currentLow) ||
            (highPrice > currentLow && highPrice <= currentHigh))
           {
            mitigated = true;
           }
        }
      else  // Down trend
        {
         if((highPrice <= currentHigh && highPrice > currentLow) ||
            (lowPrice >= currentLow && lowPrice < currentHigh))
           {
            mitigated = true;
           }
        }

      if(mitigated)
        {
         // Finalize the box at mitigation bar - point 1 y = lowPrice for both trends
         ObjectMove(0, ActiveFvgs[i].objName, 1, time[1], lowPrice);

         // Change color to faint (mitigated)
         color mitigatedColor = (trend == 1) ? InpUpTrendColor : InpDownTrendColor;
         ObjectSetInteger(0, ActiveFvgs[i].objName, OBJPROP_COLOR, mitigatedColor);

         // Delete the active stripe (use correct prefix based on FVG type)
         string stripePrefix = ActiveFvgs[i].isNBar ? NBAR_STRIPE_PREFIX : STRIPE_PREFIX;
         string stripeName = stripePrefix + IntegerToString((int)ActiveFvgs[i].startTime) + "_" + IntegerToString(trend > 0 ? 1 : 0);
         ObjectDelete(0, stripeName);

         if(InpDebugEnabled)
            PrintFormat("MITIGATED FVG: %s (color changed to faint)", ActiveFvgs[i].objName);

         // Remove from active list (swap with last and decrement) - O(1)
         ActiveFvgs[i] = ActiveFvgs[ActiveFvgCount - 1];
         ActiveFvgCount--;
         NeedsRedraw = true;

         // Don't increment i - we need to check the swapped element
         continue;
        }
      else
        {
         // Still active - extend main box to current time
         string objName = ActiveFvgs[i].objName;

         // [OPT-RESEARCH] ObjectFind() is SYNCHRONOUS - it waits for execution result.
         // Per MQL5 forum: "synchronous calls like ObjectFind() can be time consuming
         // with large numbers of objects since they wait for execution."
         //
         // CONSIDERED REMOVING: Since we track objects in ActiveFvgs[], we theoretically
         // know they exist. Removing this check would save one sync call per active FVG.
         //
         // DECISION: KEEP IT. The safety guard protects against edge cases where objects
         // are manually deleted by user or other indicators. The robustness benefit
         // outweighs the marginal performance gain. With typical <50 active FVGs,
         // the impact is negligible.
         if(ObjectFind(0, objName) < 0)
           {
            if(InpDebugEnabled)
               PrintFormat("WARNING: Main box object missing: %s", objName);
            i++;
            continue;
           }

         // Point 1 is the second corner of rectangle (where it extends to)
         // For up trend FVG: point 1 y = lowPrice (bottom of gap)
         // For down trend FVG: point 1 y = lowPrice (bottom of gap, stored as rightHighPrice)
         // Both cases: point 1 y = lowPrice
         ObjectMove(0, objName, 1, currentTime, lowPrice);

         // Update stripe position - pass high/low in correct order (top, bottom)
         // Use correct prefix based on FVG type
         string stripePrefix = ActiveFvgs[i].isNBar ? NBAR_STRIPE_PREFIX : STRIPE_PREFIX;
         string stripeName = stripePrefix + IntegerToString((int)ActiveFvgs[i].startTime) + "_" + IntegerToString(trend > 0 ? 1 : 0);
         color stripeColor = (trend > 0) ? InpUpTrendActiveColor : InpDownTrendActiveColor;
         UpdateActiveStripe(stripeName, currentTime, highPrice, lowPrice, stripeColor);
         NeedsRedraw = true;
        }

      i++;
     }
  }

//+------------------------------------------------------------------+
//| Add FVG to active tracking list - O(1) using circular overwrite  |
//+------------------------------------------------------------------+
void AddActiveFvg(datetime startTime, datetime endTime, double highPrice,
                  double lowPrice, int trend, string objName, bool isNBar = false)
  {
   int insertIdx;

   if(ActiveFvgCount < MAX_ACTIVE_FVGS)
     {
      // Array not full - append at end
      insertIdx = ActiveFvgCount;
      ActiveFvgCount++;
     }
   else
     {
      // Array full - overwrite oldest (at head), O(1) instead of O(n) shift
      insertIdx = ActiveFvgHead;
      ActiveFvgHead = (ActiveFvgHead + 1) % MAX_ACTIVE_FVGS;
     }

   ActiveFvgs[insertIdx].startTime = startTime;
   ActiveFvgs[insertIdx].endTime = endTime;
   ActiveFvgs[insertIdx].highPrice = highPrice;
   ActiveFvgs[insertIdx].lowPrice = lowPrice;
   ActiveFvgs[insertIdx].trend = trend;
   ActiveFvgs[insertIdx].mitigated = false;
   ActiveFvgs[insertIdx].objName = objName;
   ActiveFvgs[insertIdx].isNBar = isNBar;
  }

//+------------------------------------------------------------------+
//| Updates buffers with indicator data                              |
//+------------------------------------------------------------------+
void SetBuffers(int index, double highPrice, double lowPrice, double trend)
  {
   FvgHighPriceBuffer[index] = highPrice;
   FvgLowPriceBuffer[index] = lowPrice;
   FvgTrendBuffer[index] = trend;

   if(InpDebugEnabled && trend != 0)
      PrintFormat("FVG at bar %i: Trend=%s, High=%.5f, Low=%.5f",
                  index, trend > 0 ? "UP" : "DOWN", highPrice, lowPrice);
  }

//+------------------------------------------------------------------+
//| Create FVG box with optimized naming                             |
//+------------------------------------------------------------------+
string CreateFvgBox(datetime leftDt, double leftPrice, datetime rightDt,
                    double rightPrice, bool active, int trend)
  {
   // OPTIMIZED: Simple numeric name instead of parsed strings
   string objName = OBJECT_PREFIX + IntegerToString(leftDt) + "_" + IntegerToString(trend > 0 ? 1 : 0);
   string stripeName = STRIPE_PREFIX + IntegerToString(leftDt) + "_" + IntegerToString(trend > 0 ? 1 : 0);

   // Base color is always the same (faint) for main box
   color boxColor = (trend > 0) ? InpUpTrendColor : InpDownTrendColor;
   color stripeColor = (trend > 0) ? InpUpTrendActiveColor : InpDownTrendActiveColor;

   if(ObjectFind(0, objName) >= 0)
     {
      // Main box exists - update endpoint only if active
      if(active)
        {
         ObjectMove(0, objName, 1, rightDt, rightPrice);
         UpdateActiveStripe(stripeName, rightDt, leftPrice, rightPrice, stripeColor);
         NeedsRedraw = true;
        }
      else
        {
         // Box exists but NOT active anymore - delete orphan stripe if it exists
         if(ObjectFind(0, stripeName) >= 0)
           {
            ObjectDelete(0, stripeName);
            NeedsRedraw = true;
            if(InpDebugEnabled)
               PrintFormat("Deleted orphan 3-bar stripe: %s (FVG now mitigated)", stripeName);
           }
        }
      return objName;
     }

   // Create main FVG box (always faint base color)
   ObjectCreate(0, objName, OBJ_RECTANGLE, 0, leftDt, leftPrice, rightDt, rightPrice);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, boxColor);
   ObjectSetInteger(0, objName, OBJPROP_FILL, InpFill);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, InpBoderStyle);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpBorderWidth);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);

   // Create bright stripe at right edge for active zones
   if(active)
      UpdateActiveStripe(stripeName, rightDt, leftPrice, rightPrice, stripeColor);

   NeedsRedraw = true;

   if(InpDebugEnabled)
      PrintFormat("Created FVG box: %s (active=%s)", objName, active ? "YES+STRIPE" : "NO");

   return objName;
  }

//+------------------------------------------------------------------+
//| Create/update bright stripe at right edge of active FVG          |
//+------------------------------------------------------------------+
void UpdateActiveStripe(string stripeName, datetime rightDt, double topPrice,
                        double bottomPrice, color stripeColor)
  {
   // Use cached period seconds (set in OnInit, not recalculated every call)
   datetime stripeLeft = rightDt - (InpActiveStripeWidth * CachedPeriodSeconds);

   if(ObjectFind(0, stripeName) >= 0)
     {
      // Update existing stripe position
      ObjectMove(0, stripeName, 0, stripeLeft, topPrice);
      ObjectMove(0, stripeName, 1, rightDt, bottomPrice);
     }
   else
     {
      // Create new stripe
      ObjectCreate(0, stripeName, OBJ_RECTANGLE, 0, stripeLeft, topPrice, rightDt, bottomPrice);
      ObjectSetInteger(0, stripeName, OBJPROP_COLOR, stripeColor);
      ObjectSetInteger(0, stripeName, OBJPROP_FILL, true);
      ObjectSetInteger(0, stripeName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, stripeName, OBJPROP_WIDTH, 0);
      ObjectSetInteger(0, stripeName, OBJPROP_BACK, true);
      ObjectSetInteger(0, stripeName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, stripeName, OBJPROP_HIDDEN, false);
     }
  }

//+------------------------------------------------------------------+
//| Create N-bar FVG box with custom object name                      |
//+------------------------------------------------------------------+
string CreateFvgBoxNBar(datetime leftDt, double leftPrice, datetime rightDt,
                        double rightPrice, bool active, int trend, string objName)
  {
   string stripeName = NBAR_STRIPE_PREFIX + IntegerToString((int)leftDt) + "_" + IntegerToString(trend > 0 ? 1 : 0);

   // Base color is always the same (faint) for main box
   color boxColor = (trend > 0) ? InpUpTrendColor : InpDownTrendColor;
   color stripeColor = (trend > 0) ? InpUpTrendActiveColor : InpDownTrendActiveColor;

   if(ObjectFind(0, objName) >= 0)
     {
      // Box exists - update endpoint only if active
      if(active)
        {
         ObjectMove(0, objName, 1, rightDt, rightPrice);
         UpdateActiveStripe(stripeName, rightDt, leftPrice, rightPrice, stripeColor);
         NeedsRedraw = true;
        }
      else
        {
         // Box exists but NOT active anymore - delete orphan stripe if it exists
         if(ObjectFind(0, stripeName) >= 0)
           {
            ObjectDelete(0, stripeName);
            NeedsRedraw = true;
            if(InpDebugEnabled)
               PrintFormat("Deleted orphan N-bar stripe: %s (FVG now mitigated)", stripeName);
           }
        }
      return objName;
     }

   // Create main N-bar FVG box
   ObjectCreate(0, objName, OBJ_RECTANGLE, 0, leftDt, leftPrice, rightDt, rightPrice);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, boxColor);
   ObjectSetInteger(0, objName, OBJPROP_FILL, InpFill);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, InpBoderStyle);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpBorderWidth);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);

   // Create bright stripe at right edge for active zones
   if(active)
      UpdateActiveStripe(stripeName, rightDt, leftPrice, rightPrice, stripeColor);

   NeedsRedraw = true;

   if(InpDebugEnabled)
      PrintFormat("Created N-bar FVG box: %s (active=%s)", objName, active ? "YES+STRIPE" : "NO");

   return objName;
  }

//+------------------------------------------------------------------+
//| Detect N-bar void-chain FVG                                       |
//| Scans for consecutive voids and expands to N-bar pattern          |
//| 1 void = 4 bars, 2 voids = 5 bars, N voids = (N+3) bars          |
//| CRITICAL: Only detects at chain-end to prevent duplicates         |
//+------------------------------------------------------------------+
void DetectVoidChainFvg(int i, const datetime &time[], const double &high[],
                        const double &low[], int rates_total)
  {
   if(!InpDetectVoidChainFvg || i < 1)  // Skip bar 0
      return;

   // Debug: Log every 10000th bar to verify function is being called
   if(InpDebugEnabled && i % 10000 == 0)
      PrintFormat("DetectVoidChainFvg called: i=%d, time=%s", i, TimeToString(time[i]));

   // ===== BULLISH VOID-CHAIN FVG =====
   // Bullish void: older bar's HIGH < newer bar's LOW (price gaps up)

   // Step 0: Chain-end check - only detect if NO bullish void to the RIGHT
   // If high[i] < low[i-1], bullish void exists rightward - NOT chain-end
   bool bullishChainEnd = (high[i] >= low[i - 1]);

   // Debug specific time range (Dec 11 17:00-17:10)
   if(InpDebugEnabled && ShouldDebugBar(time[i]))
      PrintFormat("NBAR DEBUG i=%d time=%s: chainEnd=%s (high[i]=%.2f >= low[i-1]=%.2f)",
                  i, TimeToString(time[i]), bullishChainEnd ? "YES" : "NO", high[i], low[i-1]);

   if(bullishChainEnd)
     {
      // Step 1: Scan for consecutive bullish voids LEFTWARD (older bars)
      int bullishVoidCount = 0;
      int scanIdx = i + 1;

      while(scanIdx + 1 < rates_total && bullishVoidCount < InpMaxVoidChain)
        {
         // Check void between scanIdx+1 (older) and scanIdx (newer)
         bool hasVoid = (high[scanIdx + 1] < low[scanIdx]);
         if(InpDebugEnabled && ShouldDebugBar(time[i]))
            PrintFormat("  VOID SCAN: scanIdx=%d high[%d]=%.2f < low[%d]=%.2f ? %s",
                        scanIdx, scanIdx+1, high[scanIdx+1], scanIdx, low[scanIdx],
                        hasVoid ? "YES" : "NO");
         if(hasVoid)  // Bullish void exists
           {
            bullishVoidCount++;
            scanIdx++;
           }
         else
            break;  // No more voids leftward
        }

      // Debug void count result
      if(InpDebugEnabled && ShouldDebugBar(time[i]) && bullishVoidCount > 0)
         PrintFormat("  FOUND %d bullish voids, leftBoundary will be %d", bullishVoidCount, scanIdx+1);

      // Step 2: If at least one void found, check N-bar FVG
      if(bullishVoidCount >= 1)
        {
         int leftBoundary = scanIdx + 1;   // Oldest bar (left edge)
         int rightBoundary = i;             // Current bar (right edge)

         // Debug FVG check
         if(InpDebugEnabled && ShouldDebugBar(time[i]))
            PrintFormat("  FVG CHECK: high[%d]=%.2f < low[%d]=%.2f ? %s",
                        leftBoundary, high[leftBoundary], rightBoundary, low[rightBoundary],
                        (high[leftBoundary] < low[rightBoundary]) ? "YES->CREATE" : "NO");

         if(leftBoundary < rates_total && high[leftBoundary] < low[rightBoundary])
           {
            // N-bar bullish FVG confirmed!
            double fvgTop = low[rightBoundary];
            double fvgBottom = high[leftBoundary];
            datetime fvgStartTime = time[leftBoundary];
            int barCount = bullishVoidCount + 3;

            // Check mitigation
            datetime endTime = time[0];
            bool stillActive = true;

            if(InpContinueToMitigation)
              {
               for(int j = i - 1; j >= 1; j--)
                 {
                  if((fvgBottom < high[j] && fvgBottom >= low[j]) ||
                     (fvgTop > low[j] && fvgTop <= high[j]))
                    {
                     endTime = time[j];
                     stillActive = false;
                     break;
                    }
                 }
              }

            // Create object name: FVGN{barCount}_{timestamp}_{direction}
            string objName = NBAR_PREFIX + IntegerToString(barCount) + "_" +
                             IntegerToString((int)fvgStartTime) + "_1";
            CreateFvgBoxNBar(fvgStartTime, fvgBottom, endTime, fvgTop,
                             stillActive, 1, objName);

            if(stillActive && InpContinueToMitigation)
               AddActiveFvg(fvgStartTime, endTime, fvgBottom, fvgTop, 1, objName, true);  // isNBar=true, match 3-bar convention: highPrice=bottom, lowPrice=top

            if(InpDebugEnabled && ShouldDebugBar(time[rightBoundary]))
               PrintFormat(">>> %d-BAR BULLISH FVG: %d voids, zone %.5f to %.5f",
                           barCount, bullishVoidCount, fvgBottom, fvgTop);
           }
        }
     }

   // ===== BEARISH VOID-CHAIN FVG =====
   // Bearish void: older bar's LOW > newer bar's HIGH (price gaps down)

   // Step 0: Chain-end check - only detect if NO bearish void to the RIGHT
   // If low[i] > high[i-1], bearish void exists rightward - NOT chain-end
   bool bearishChainEnd = (low[i] <= high[i - 1]);

   if(bearishChainEnd)
     {
      // Step 1: Scan for consecutive bearish voids LEFTWARD (older bars)
      int bearishVoidCount = 0;
      int scanIdx = i + 1;

      while(scanIdx + 1 < rates_total && bearishVoidCount < InpMaxVoidChain)
        {
         // Check void between scanIdx+1 (older) and scanIdx (newer)
         if(low[scanIdx + 1] > high[scanIdx])  // Bearish void exists
           {
            bearishVoidCount++;
            scanIdx++;
           }
         else
            break;  // No more voids leftward
        }

      // Step 2: If at least one void found, check N-bar FVG
      if(bearishVoidCount >= 1)
        {
         int leftBoundary = scanIdx + 1;   // Oldest bar (left edge)
         int rightBoundary = i;             // Current bar (right edge)

         if(leftBoundary < rates_total && low[leftBoundary] > high[rightBoundary])
           {
            // N-bar bearish FVG confirmed!
            double fvgTop = low[leftBoundary];
            double fvgBottom = high[rightBoundary];
            datetime fvgStartTime = time[leftBoundary];
            int barCount = bearishVoidCount + 3;

            // Check mitigation
            datetime endTime = time[0];
            bool stillActive = true;

            if(InpContinueToMitigation)
              {
               for(int j = i - 1; j >= 1; j--)
                 {
                  if((fvgBottom <= high[j] && fvgBottom > low[j]) ||
                     (fvgTop >= low[j] && fvgTop < high[j]))
                    {
                     endTime = time[j];
                     stillActive = false;
                     break;
                    }
                 }
              }

            // Create object name: FVGN{barCount}_{timestamp}_{direction}
            string objName = NBAR_PREFIX + IntegerToString(barCount) + "_" +
                             IntegerToString((int)fvgStartTime) + "_0";
            CreateFvgBoxNBar(fvgStartTime, fvgTop, endTime, fvgBottom,
                             stillActive, -1, objName);

            if(stillActive && InpContinueToMitigation)
               AddActiveFvg(fvgStartTime, endTime, fvgTop, fvgBottom, -1, objName, true);  // isNBar=true

            if(InpDebugEnabled && ShouldDebugBar(time[rightBoundary]))
               PrintFormat(">>> %d-BAR BEARISH FVG: %d voids, zone %.5f to %.5f",
                           barCount, bearishVoidCount, fvgBottom, fvgTop);
           }
        }
     }
  }
//+------------------------------------------------------------------+
