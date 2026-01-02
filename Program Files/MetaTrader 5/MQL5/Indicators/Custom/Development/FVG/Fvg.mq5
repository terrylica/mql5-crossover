//+------------------------------------------------------------------+
//|                                                          Fvg.mq5 |
//|                        Based on rpanchyk's FVG indicator v1.03   |
//|                        Optimized version - O(n) complexity       |
//+------------------------------------------------------------------+
#property copyright   "Optimized by Terry Li, Original by rpanchyk"
#property link        "https://github.com/rpanchyk"
#property version     "2.31"
#property description "Optimized Fair Value Gap indicator v2.31"
#property description "Key features:"
#property description "- Bright colors for ACTIVE zones, faint for mitigated"
#property description "- O(n) mitigation tracking vs O(n²) nested loops"
#property description "- O(1) circular buffer for active FVG management"

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
input bool InpDebugEnabled = false; // Enable debug (verbose logging)

// constants
const string OBJECT_PREFIX = "FVGO_";         // Main FVG box prefix
const string STRIPE_PREFIX = "FVGO_STRIPE_";  // Active end stripe prefix

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
  };

FvgData ActiveFvgs[];
int ActiveFvgCount = 0;
int ActiveFvgHead = 0;  // Circular buffer head index
const int MAX_ACTIVE_FVGS = 200;  // Limit active FVGs to prevent memory bloat

// Cached values for performance (avoid repeated function calls)
int CachedPeriodSeconds = 0;
bool NeedsRedraw = false;  // Only redraw when objects actually change

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
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(InpDebugEnabled)
      Print("Fvg_Optimized indicator deinitialization started");

   // Clean up objects (boxes and stripes)
   ObjectsDeleteAll(0, OBJECT_PREFIX);
   ObjectsDeleteAll(0, STRIPE_PREFIX);

   // Free arrays
   ArrayFree(ActiveFvgs);
   ActiveFvgCount = 0;
   ActiveFvgHead = 0;

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

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

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
      datetime leftTime = time[i + 2];

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

      // No FVG detected
      SetBuffers(i + 1, 0, 0, 0);
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

         // Delete the active stripe
         string stripeName = STRIPE_PREFIX + IntegerToString((int)ActiveFvgs[i].startTime) + "_" + IntegerToString(trend > 0 ? 1 : 0);
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

         // Verify main box still exists before updating
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
         string stripeName = STRIPE_PREFIX + IntegerToString((int)ActiveFvgs[i].startTime) + "_" + IntegerToString(trend > 0 ? 1 : 0);
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
                  double lowPrice, int trend, string objName)
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
