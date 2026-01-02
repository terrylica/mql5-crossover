//+------------------------------------------------------------------+
//|                                           ZigZag_v5_Structure.mq5 |
//|                                                        Terry Li |
//|        Enhanced ZigZag with HH/HL/LH/LL and Level Lines          |
//+------------------------------------------------------------------+
#property copyright "Terry Li"
#property link      ""
#property version   "5.0"

//+------------------------------------------------------------------+
//| ALGORITHM OVERVIEW:                                              |
//+------------------------------------------------------------------+
// The ZigZag indicator identifies significant price reversals while filtering
// out minor price movements. The algorithm works as follows:
//
// 1. IDENTIFICATION OF EXTREME POINTS:
//    - Peaks (high points) and bottoms (low points) are identified
//    - Points must be separated by at least InpBackstep bars
//    - Price change must exceed InpDeviation points
//
// 2. ZIGZAG CONSTRUCTION:
//    - Identified extremes are connected to form the zigzag
//    - Each zigzag leg connects alternating peaks and bottoms
//    - The algorithm tracks high/low extreme positions and values
//
// 3. CONFIRMATION DISPLAY (optional):
//    - Arrows can be shown where a reversal is confirmed by a subsequent extreme
//    - Peak confirmations appear after a bottom is found
//    - Bottom confirmations appear after a peak is found
//
// 4. REPAINTING PREVENTION (optional):
//    - The most recent 1-2 zigzag legs can be hidden until confirmed
//    - This prevents the indicator from "repainting" historical signals
//
// CROSS-LANGUAGE PORTING CONSIDERATIONS:
// -------------------------------------
// When porting this indicator to other languages like Python or PineScript:
//
// 1. BUFFER ARRAYS:
//    - MQL uses multiple buffer arrays (HighMapBuffer, LowMapBuffer, ZigzagPeakBuffer, etc.)
//    - Implement these as separate arrays/series in your target language
//
// 2. DATA INDEXING:
//    - In MQL, arrays are indexed with newest bars at index 0
//    - In other platforms (like Python), oldest bars might be first
//    - Adjust array indexing and iteration direction accordingly
//
// 3. STATE MACHINE:
//    - The ZigZag uses a 3-state machine (SEARCH_FIRST_EXTREMUM/NEXT_PEAK/NEXT_BOTTOM)
//    - Maintain these exact states and transition logic
//    - Preserve the alternating pattern of peaks and bottoms
//
// 4. INITIALIZATION:
//    - Handle initial calculation vs. continuation differently
//    - For continuation, find recent extremes to maintain pattern
//
// 5. POINT VALUES:
//    - MQL uses _Point to represent the minimal price change
//    - Replace with the equivalent in your target language
//
// 6. BAR INDEXING:
//    - MQL uses bar indexing where current/newest bar is at index 0
//    - Adjust calculation direction if your platform uses different indexing
//+------------------------------------------------------------------+

//--- indicator settings
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   3
#property indicator_type1   DRAW_COLOR_ZIGZAG
#property indicator_color1  clrLimeGreen,clrPurple  // Define default zigzag colors here
#property indicator_width1  1                 // Thinnest line (1 pixel)
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrMagenta        // Default color for peak confirmations
#property indicator_width2  2                 // Make arrows bigger
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrCyan           // Default color for bottom confirmations
#property indicator_width3  2                 // Make arrows bigger
#property indicator_type4   DRAW_SECTION
#property indicator_color4  clrMagenta        // Default color for peak confirmation section
#property indicator_width4  1
#property indicator_style4  STYLE_DASH        // Dashed line style for better visibility
#property indicator_type5   DRAW_SECTION
#property indicator_color5  clrCyan           // Default color for bottom confirmation section
#property indicator_width5  1
#property indicator_style5  STYLE_DASH        // Dashed line style for better visibility
//--- input parameters
input group "=== ZigZag Core Settings ==="
input int InpDepth    =12;  // Depth
input int InpDeviation=5;   // Deviation
input int InpBackstep =3;   // Back Step
input bool InpNoRepaint=true; // Prevent last leg repainting
input bool InpShowConfirmation=true; // Show confirmation arrows at reversal points
input int InpArrowShift=50; // Arrow distance from price in pixels
input int InpConfirmArrowSize=1; // Confirmation arrow size (1-5)
input color InpUpColor=clrDarkOliveGreen;   // Uptrend color
input color InpDownColor=clrSaddleBrown;    // Downtrend color
input bool InpUpdateOnNewBarOnly=true; // Calculate only on bar completion

input group "=== Alert Settings ==="
input bool  InpEnableAlerts = true;      // Enable alerts
input bool  InpEnableSoundAlerts = true; // Enable sound alerts
input bool  InpEnablePushAlerts = false;  // Enable push notifications
input bool  InpEnableEmailAlerts = false; // Enable email alerts
input string InpSoundFile = "alert.wav";  // Sound file name

input group "=== Structure Labels (HH/HL/LH/LL) ==="
input bool   InpShowStructureLabels = true;     // Show structure labels
input color  InpHHColor = clrLime;              // Higher High color
input color  InpHLColor = clrDarkGreen;         // Higher Low color
input color  InpLHColor = clrRed;               // Lower High color
input color  InpLLColor = clrDarkRed;           // Lower Low color
input int    InpLabelFontSize = 8;              // Label font size
input double InpLabelOffsetPips = 1.0;          // Label offset in pips

input group "=== Level Lines (from Pivots) ==="
input bool   InpShowLevelLines = true;          // Show extending level lines
input ENUM_LINE_STYLE InpLevelLineStyle = STYLE_DOT; // Level line style
input int    InpLevelLineWidth = 1;             // Level line width
input int    InpMaxLevelHours = 48;             // Max level duration (hours, 0=unlimited)
input int    InpLevelDaysBack = 30;             // Only create levels for last N days

input group "=== Performance ==="
input int    InpMaxBarsBack = 1000;             // Max bars to process for drawings (0=all)

input group "=== Debug ==="
input bool   InpDebugMode = true;               // Enable debug logging (for testing)

//+------------------------------------------------------------------+
//| Get pip size for current symbol (universal: forex, JPY, metals)  |
//+------------------------------------------------------------------+
double PipSize()
{
   return 1.0 / MathPow(10, _Digits - 1);
}

//+------------------------------------------------------------------+
//| Get lookback start index based on InpMaxBarsBack                  |
//| Returns the oldest bar index to process (0 = all bars)            |
//+------------------------------------------------------------------+
int GetLookbackStartIndex(int rates_total)
{
   if(InpMaxBarsBack <= 0 || InpMaxBarsBack >= rates_total)
      return 0;  // Process all bars
   return rates_total - InpMaxBarsBack;  // Start from (rates_total - N) to only process last N bars
}

// Variables to track alerts
datetime last_alert_time = 0;
int last_alert_direction = 0; // 0: none, 1: peak confirmed by bottom, -1: bottom confirmed by peak
bool first_calculation = true;      // Flag to prevent alerts on first load

// Tracking specific zigzag positions for alerts
struct ZigzagExtremeTracker
{
   int peak_pos;            // Position of last confirmed peak
   int bottom_pos;          // Position of last confirmed bottom
   int confirming_peak_pos; // Position of last peak that confirmed a bottom
   int confirming_bottom_pos; // Position of last bottom that confirmed a peak
};

ZigzagExtremeTracker g_extremes = {-1, -1, -1, -1}; // Added 'g_' prefix to avoid conflicts

//+------------------------------------------------------------------+
//| V5 ENHANCEMENT: Structure Analysis Types                          |
//+------------------------------------------------------------------+

// Structure type enum for HH/HL/LH/LL classification
enum EnStructureType
{
   STRUCT_NONE = 0,    // No structure type assigned
   STRUCT_HH = 1,      // Higher High
   STRUCT_HL = 2,      // Higher Low
   STRUCT_LH = 3,      // Lower High
   STRUCT_LL = 4       // Lower Low
};

// Trend state enum
enum EnTrendState
{
   TREND_NONE = 0,     // No trend established
   TREND_BULLISH = 1,  // Bullish trend (HH + HL pattern)
   TREND_BEARISH = -1  // Bearish trend (LH + LL pattern)
};

// Structure tracker for maintaining swing point history
struct ZigzagStructureState
{
   // Current swing points
   int    last_peak_bar;
   double last_peak_price;
   int    last_bottom_bar;
   double last_bottom_price;

   // Previous swing points (for comparison)
   int    prev_peak_bar;
   double prev_peak_price;
   int    prev_bottom_bar;
   double prev_bottom_price;

   // Market structure state
   EnTrendState current_trend;
   EnStructureType last_structure_type;

};

// Global structure state
ZigzagStructureState g_structure = {-1, 0, -1, 0, -1, 0, -1, 0, TREND_NONE, STRUCT_NONE};

//+------------------------------------------------------------------+
//| V5 ENHANCEMENT: Object Naming Prefixes                            |
//+------------------------------------------------------------------+
const string OBJ_PREFIX_STRUCT = "ZZSTRUCT_";      // Structure labels (HH/HL/LH/LL)
const string OBJ_PREFIX_LEVEL_ACTIVE = "ZZLVLA_";  // Active (extending) level lines
const string OBJ_PREFIX_LEVEL = "ZZLVL_";          // Finalized level lines

//--- indicator buffers
double ZigzagPeakBuffer[];
double ZigzagBottomBuffer[];
double HighMapBuffer[];
double LowMapBuffer[];
double ColorBuffer[];
double ConfirmPeakBuffer[];    // Buffer for confirmed peaks
double ConfirmBottomBuffer[];  // Buffer for confirmed bottoms

//--- global variables
int ExtRecalc=3; // recounting's depth
datetime g_last_bar_time = 0; // For tracking new bar formation

// ZigZag state machine enum - defines what type of extreme point we're looking for
enum EnSearchMode
  {
   /*
    * ZIGZAG STATE MACHINE STATES:
    * These states control the alternating search for peaks and bottoms
    * that forms the zigzag pattern.
    *
    * When porting to other languages:
    * - Maintain these exact numeric values (0, 1, -1)
    * - Preserve the state transition logic:
    *   FIRST → PEAK/BOTTOM → alternating between PEAK and BOTTOM
    */
   SEARCH_FIRST_EXTREMUM = 0,  // Initial state: searching for the first extremum (peak or bottom)
   SEARCH_NEXT_PEAK = 1,       // Looking for the next peak (after finding a bottom)
   SEARCH_NEXT_BOTTOM = -1     // Looking for the next bottom (after finding a peak)
  };

// Constants for clarity when porting to other languages
#define TREND_UP 0    // Index for uptrend color - needed for ColorBuffer assignments
#define TREND_DOWN 1  // Index for downtrend color - needed for ColorBuffer assignments

// Debug function - can be useful for troubleshooting
void DebugPrint(string message)
{
   if(InpDebugMode)
      Print("ZZ_v5: ", message);
}

//+------------------------------------------------------------------+
//| V5: Delete all objects with specified prefix                      |
//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(const string prefix)
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      if(StringFind(objName, prefix) == 0)
         ObjectDelete(0, objName);
   }
}

//+------------------------------------------------------------------+
//| V5: Delete all v5 enhancement objects                             |
//+------------------------------------------------------------------+
void DeleteAllV5Objects()
{
   DeleteObjectsByPrefix(OBJ_PREFIX_STRUCT);
   DeleteObjectsByPrefix(OBJ_PREFIX_LEVEL_ACTIVE);
   DeleteObjectsByPrefix(OBJ_PREFIX_LEVEL);
}

//+------------------------------------------------------------------+
//| V5: Reset structure state                                         |
//+------------------------------------------------------------------+
void ResetStructureState()
{
   g_structure.last_peak_bar = -1;
   g_structure.last_peak_price = 0;
   g_structure.last_bottom_bar = -1;
   g_structure.last_bottom_price = 0;
   g_structure.prev_peak_bar = -1;
   g_structure.prev_peak_price = 0;
   g_structure.prev_bottom_bar = -1;
   g_structure.prev_bottom_price = 0;
   g_structure.current_trend = TREND_NONE;
   g_structure.last_structure_type = STRUCT_NONE;
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
   // V5: Clean up all enhancement objects from previous instance
   DeleteAllV5Objects();
   ResetStructureState();

   SetupBuffers();
   SetupVisualElements();
   SetupLabels();

   // Set calculation mode to update only on bar completion if requested
   // Using the official approach with the correct enum name
#ifdef CALCULATIONS_ONLY_ON_BARS
   // If the constant is defined in this version, use it
   IndicatorSetInteger(CALCULATIONS_ONLY_ON_BARS, InpUpdateOnNewBarOnly);
#endif

   // V5: Log initialization
   if(InpDebugMode)
   {
      Print("=== ZigZag v5 Structure Initialized ===");
      PrintFormat("  Structure Labels: %s", InpShowStructureLabels ? "ON" : "OFF");
      PrintFormat("  Level Lines: %s", InpShowLevelLines ? "ON" : "OFF");
      Print("========================================");
   }
  }

//+------------------------------------------------------------------+
//| Setup indicator buffers and mapping                              |
//+------------------------------------------------------------------+
void SetupBuffers()
{
   //--- indicator buffers mapping
   SetIndexBuffer(0,ZigzagPeakBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,ZigzagBottomBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ColorBuffer,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(3,HighMapBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,LowMapBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(5,ConfirmPeakBuffer,INDICATOR_DATA);
   SetIndexBuffer(6,ConfirmBottomBuffer,INDICATOR_DATA);
   //--- set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
}

//+------------------------------------------------------------------+
//| Setup visual elements like arrows, colors and line styles        |
//+------------------------------------------------------------------+
void SetupVisualElements()
{
   //--- set arrow codes
   PlotIndexSetInteger(1,PLOT_ARROW,234); // Down arrow for peak confirmations
   PlotIndexSetInteger(2,PLOT_ARROW,233); // Up arrow for bottom confirmations
   //--- set arrow vertical shift in pixels
   PlotIndexSetInteger(1,PLOT_ARROW_SHIFT,-InpArrowShift); // Peak confirmations shifted UP (away from price)
   PlotIndexSetInteger(2,PLOT_ARROW_SHIFT,InpArrowShift); // Bottom confirmations shifted DOWN (away from price)

   //--- set arrow size (user-adjustable)
   PlotIndexSetInteger(1,PLOT_LINE_WIDTH,InpConfirmArrowSize); // Peak arrow size
   PlotIndexSetInteger(2,PLOT_LINE_WIDTH,InpConfirmArrowSize); // Bottom arrow size

   //--- Set ZigZag colors - critical for correct color display
   PlotIndexSetInteger(0,PLOT_COLOR_INDEXES,2);          // Number of colors
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,0,InpUpColor);  // Uptrend color (index 0)
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,1,InpDownColor);// Downtrend color (index 1)
   
   // Set up arrow colors to match opposite trend colors
   PlotIndexSetInteger(1,PLOT_LINE_COLOR,0,InpDownColor);  // Up arrows match downtrend color
   PlotIndexSetInteger(2,PLOT_LINE_COLOR,0,InpUpColor);    // Down arrows match uptrend color
   PlotIndexSetInteger(4,PLOT_LINE_COLOR,0,InpDownColor);  // Peak confirmation lines match downtrend color
   PlotIndexSetInteger(5,PLOT_LINE_COLOR,0,InpUpColor);    // Bottom confirmation lines match uptrend color

   // Hide or show the confirmation arrows based on InpShowConfirmation parameter
   if(!InpShowConfirmation)
     {
      // Hide arrow plots when confirmation display is disabled
      PlotIndexSetInteger(1,PLOT_DRAW_TYPE,DRAW_NONE);
      PlotIndexSetInteger(2,PLOT_DRAW_TYPE,DRAW_NONE);
      PlotIndexSetInteger(4,PLOT_DRAW_TYPE,DRAW_NONE);
      PlotIndexSetInteger(5,PLOT_DRAW_TYPE,DRAW_NONE);
     }
   else
     {
      // Make sure arrows are visible when enabled
      PlotIndexSetInteger(1,PLOT_DRAW_TYPE,DRAW_ARROW);
      PlotIndexSetInteger(2,PLOT_DRAW_TYPE,DRAW_ARROW);
      // Make sure arrow codes are set correctly
      PlotIndexSetInteger(1,PLOT_ARROW,234); // Down arrow for peak confirmations
      PlotIndexSetInteger(2,PLOT_ARROW,233); // Up arrow for bottom confirmations
      // Show section lines
      PlotIndexSetInteger(4,PLOT_DRAW_TYPE,DRAW_SECTION);
      PlotIndexSetInteger(5,PLOT_DRAW_TYPE,DRAW_SECTION);
     }
   
   //--- set an empty value for data plots
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,0.0);
}

//+------------------------------------------------------------------+
//| Setup indicator name and labels                                  |
//+------------------------------------------------------------------+
void SetupLabels()
{
   //--- name for DataWindow and indicator subwindow label
   string short_name=StringFormat("ZigZagColor(%d,%d,%d)",InpDepth,InpDeviation,InpBackstep);
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
   PlotIndexSetString(0,PLOT_LABEL,short_name);
   PlotIndexSetString(1,PLOT_LABEL,short_name+" Peak Confirmations");
   PlotIndexSetString(2,PLOT_LABEL,short_name+" Bottom Confirmations");
}

// Function declaration to be implemented in helper section
bool IsNewBar();

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // V5: Clean up all enhancement objects when indicator is removed
   DeleteAllV5Objects();

   if(InpDebugMode)
      Print("ZZ_v5: Deinitialized, all objects cleaned up");
}

//+------------------------------------------------------------------+
//| ZigZag calculation                                               |
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
   /*
    * ZIGZAG CALCULATION FLOW:
    * -----------------------
    * This function implements the main ZigZag calculation algorithm:
    * 1. Skip calculation if requested (on non-new bars)
    * 2. Initialize calculation variables based on previous state
    * 3. Find high/low extreme points in the price data
    * 4. Select and connect extremes to form the zigzag pattern
    * 5. Apply visual features (non-repainting, confirmation markers)
    * 
    * When porting to another language, maintain this sequence of steps.
    * Pay special attention to the state machine (extreme_search) that
    * alternates between finding peaks and bottoms.
    */
    
   // STEP 1: Check early exit conditions
   
   // Check if we should only update on new bars
   if(InpUpdateOnNewBarOnly && prev_calculated > 0)
   {
      // If user has selected to update only on bar completion and this is not a new bar
      if(!IsNewBar())
         return(prev_calculated); // Skip calculation on this tick
   }

   // Check if this is the first calculation after loading
   bool is_first_run = (prev_calculated <= 0);
     
   // Ensure we have enough data for calculation
   if(rates_total < 100)
      return(0);

   // STEP 2: Initialize calculation variables
   
   // Declare variables for tracking extreme points and search state
   int start = 0;                        // Bar index where calculation starts
   int extreme_search = SEARCH_FIRST_EXTREMUM; // Current state in the zigzag state machine
   double current_high = 0.0;            // Potential new high value being evaluated
   double current_low = 0.0;             // Potential new low value being evaluated
   double last_high = 0.0;               // Most recent confirmed high extreme
   double last_low = 0.0;                // Most recent confirmed low extreme
   int last_high_pos = 0;                // Bar index of the most recent high extreme
   int last_low_pos = 0;                 // Bar index of the most recent low extreme
   
   // Set up initial conditions based on previous calculation state
   bool initSuccess = InitializeCalculation(
      rates_total, 
      prev_calculated, 
      high, 
      low, 
      start, 
      extreme_search, 
      current_high, 
      current_low, 
      last_high, 
      last_low, 
      last_high_pos, 
      last_low_pos
   );
   
   // Exit if initialization failed
   if(!initSuccess)
      return rates_total;

   // STEP 3: Find high and low extremes in the price data
   FindExtremes(start, rates_total, high, low, last_high, last_low);

   // STEP 4: Set values for continuation in next calculation
   if(extreme_search == SEARCH_FIRST_EXTREMUM) // No extremes found yet
     {
      last_low = 0.0;
      last_high = 0.0;
     }
   else // Update with current values for next calculation
     {
      last_low = current_low;
      last_high = current_high;
     }
   
   // STEP 5: Select extreme points to form the ZigZag pattern
   SelectExtremePoints(
      start, 
      rates_total, 
      high, 
      low, 
      extreme_search,
      last_high, 
      last_low, 
      last_high_pos, 
      last_low_pos
   );

   // STEP 6: Handle non-repainting and confirmation visualizations if enabled
   if(InpNoRepaint || InpShowConfirmation)
     {
      HandleNonRepaintingAndConfirmation(rates_total, high, low);
     }

   // Reset first calculation flag after first complete run
   if(first_calculation && prev_calculated > 0)
   {
      first_calculation = false;
   }

   // V5: Process structure labels (HH/HL/LH/LL) after zigzag is complete
   if(InpShowStructureLabels)
   {
      // Delete old labels before creating new ones (on full recalculation)
      if(prev_calculated == 0)
         DeleteObjectsByPrefix(OBJ_PREFIX_STRUCT);

      ProcessStructureLabels(rates_total, time);
   }

   // V5: Process extending level lines from swing points
   if(InpShowLevelLines)
   {
      // Delete old level lines before creating new ones (on full recalculation)
      if(prev_calculated == 0)
      {
         DeleteObjectsByPrefix(OBJ_PREFIX_LEVEL_ACTIVE);
         DeleteObjectsByPrefix(OBJ_PREFIX_LEVEL);
      }

      ProcessLevelLines(high, low, time, rates_total);
   }

   // Return value for next calculation
   return rates_total;
  }

//+------------------------------------------------------------------+
//| Handle non-repainting and confirmation display                   |
//+------------------------------------------------------------------+
void HandleNonRepaintingAndConfirmation(const int rates_total,
                                       const double &high[],
                                       const double &low[])
{
    // Define a struct to store extreme point information
    struct ZigzagExtremePoint 
    {
       int position;     // Bar position (index) in the data arrays
       bool isPeak;      // True if this is a peak, false if it's a bottom
       double value;     // Price value of this extreme point
    };
    
    // Find the last three extremes (need three to confirm the middle one)
    int requiredExtremesCount = 3;  // We need to find this many recent extremes
    ZigzagExtremePoint extremes[3]; // Array to store the last three extremes
    
    // Initialize extreme points array
    for(int i=0; i<requiredExtremesCount; i++) {
       extremes[i].position = -1; // -1 means not found yet
       extremes[i].isPeak = false;
       extremes[i].value = 0.0;
    }
    
    // STEP 1: Find positions of the last extremes by scanning backward from the most recent bar
    int extremeCount = 0;
    // Start from the most recent bar (rates_total-1) and scan backward
    for(int barIndex=rates_total-1; barIndex>=0 && extremeCount < requiredExtremesCount; barIndex--)
     {
       // Check if this bar has either a peak or bottom extreme point
       bool hasPeakExtreme = (ZigzagPeakBuffer[barIndex] != 0);
       bool hasBottomExtreme = (ZigzagBottomBuffer[barIndex] != 0);
       bool isExtremePoint = (hasPeakExtreme || hasBottomExtreme);
       
       if(isExtremePoint)
         {
          // Record this extreme point's details
          extremes[extremeCount].position = barIndex;
          extremes[extremeCount].isPeak = hasPeakExtreme;
          extremes[extremeCount].value = hasPeakExtreme ? 
                                        ZigzagPeakBuffer[barIndex] : 
                                        ZigzagBottomBuffer[barIndex];
          extremeCount++;
         }
     }
    
    // STEP 2: Process zigzag points for confirmation markers if enabled
    if(InpShowConfirmation)
      {
       ProcessConfirmationMarkers(rates_total, high, low);
      }
    
    // STEP 3: Handle non-repainting if enabled
    if(InpNoRepaint && extremeCount > 0)
      {
       // Extract positions and types to pass to the function
       int positions[3];
       bool isPeaks[3];
       
       for(int i=0; i<extremeCount; i++) {
          positions[i] = extremes[i].position;
          isPeaks[i] = extremes[i].isPeak;
       }
       
       // Pass arrays directly rather than struct array
       HandleNonRepainting(positions, isPeaks, extremeCount, rates_total);
      }
}

//+------------------------------------------------------------------+
//| Process confirmation markers at zigzag reversal points           |
//+------------------------------------------------------------------+
void ProcessConfirmationMarkers(const int rates_total,
                              const double &high[],
                              const double &low[])
{
   // First clear all confirmation buffers
   ArrayInitialize(ConfirmPeakBuffer, 0.0);
   ArrayInitialize(ConfirmBottomBuffer, 0.0);
   
   bool found_peak_confirmation = false;
   bool found_bottom_confirmation = false;
   int new_peak_confirmation_pos = -1;
   int new_bottom_confirmation_pos = -1;
   int confirming_extreme_pos = -1;
   
   // STEP 1: First scan through bars to identify zigzag extremes and mark confirmations
   // We'll build two separate lists: peaks and bottoms with their confirmations
   
   // Arrays to store extreme points and their confirmation positions - use dynamic arrays
   int peak_positions[], bottom_positions[];
   int peak_confirmation_positions[], bottom_confirmation_positions[];
   
   // Initialize arrays with enough capacity
   ArrayResize(peak_positions, rates_total);
   ArrayResize(bottom_positions, rates_total);
   ArrayResize(peak_confirmation_positions, rates_total);
   ArrayResize(bottom_confirmation_positions, rates_total);
   
   int peak_count = 0, bottom_count = 0;
   
   // First identify all peaks and bottoms
   for(int i = 0; i < rates_total; i++)
   {
      if(ZigzagPeakBuffer[i] != 0)
      {
         peak_positions[peak_count++] = i;
      }
      else if(ZigzagBottomBuffer[i] != 0)
      {
         bottom_positions[bottom_count++] = i;
      }
   }
   
   // Resize arrays to actual count for efficiency
   ArrayResize(peak_positions, peak_count);
   ArrayResize(bottom_positions, bottom_count);
   ArrayResize(peak_confirmation_positions, peak_count);
   ArrayResize(bottom_confirmation_positions, bottom_count);
   
   // Safety check
   if(peak_count == 0 || bottom_count == 0)
   {
      DebugPrint("No peaks or bottoms found");
      return; // Nothing to process
   }
   
   // Now find confirming extremes for each peak
   for(int p = 0; p < peak_count; p++)
   {
      peak_confirmation_positions[p] = -1;
      int peak_pos = peak_positions[p];
      
      // Find the first bottom that comes after this peak
      for(int b = 0; b < bottom_count; b++)
      {
         if(bottom_positions[b] > peak_pos)
         {
            peak_confirmation_positions[p] = bottom_positions[b];
            
            // Mark the confirmation on the chart
            ConfirmPeakBuffer[bottom_positions[b]] = high[bottom_positions[b]];
            break;
         }
      }
   }
   
   // Now find confirming extremes for each bottom
   for(int b = 0; b < bottom_count; b++)
   {
      bottom_confirmation_positions[b] = -1;
      int bottom_pos = bottom_positions[b];
      
      // Find the first peak that comes after this bottom
      for(int p = 0; p < peak_count; p++)
      {
         if(peak_positions[p] > bottom_pos)
         {
            bottom_confirmation_positions[b] = peak_positions[p];
            
            // Mark the confirmation on the chart
            ConfirmBottomBuffer[peak_positions[p]] = low[peak_positions[p]];
            break;
         }
      }
   }
   
   // STEP 2: Check for new confirmations that we haven't alerted about yet
   // For peak confirmations
   if(peak_count > 0)
   {
      for(int p = 0; p < peak_count; p++)
      {
         // Only consider peaks that have a confirmation
         if(peak_confirmation_positions[p] >= 0)
         {
            int peak_pos = peak_positions[p];
            int confirmation_pos = peak_confirmation_positions[p];
            
            // Check if this is a new confirmation we haven't alerted about yet
            if(peak_pos > g_extremes.peak_pos && confirmation_pos > g_extremes.confirming_bottom_pos)
            {
               // Only consider extremes near the end of the chart (recent)
               if(rates_total - 1 - confirmation_pos <= 3) // Within last 3 bars
               {
                  DebugPrint(StringFormat("New peak confirmed: Peak at %d confirmed by bottom at %d", 
                           peak_pos, confirmation_pos));
                  
                  found_peak_confirmation = true;
                  new_peak_confirmation_pos = confirmation_pos;
                  confirming_extreme_pos = peak_pos;
                  break;
               }
            }
         }
      }
   }
   
   // For bottom confirmations
   if(bottom_count > 0)
   {
      for(int b = 0; b < bottom_count; b++)
      {
         // Only consider bottoms that have a confirmation
         if(bottom_confirmation_positions[b] >= 0)
         {
            int bottom_pos = bottom_positions[b];
            int confirmation_pos = bottom_confirmation_positions[b];
            
            // Check if this is a new confirmation we haven't alerted about yet
            if(bottom_pos > g_extremes.bottom_pos && confirmation_pos > g_extremes.confirming_peak_pos)
            {
               // Only consider extremes near the end of the chart (recent)
               if(rates_total - 1 - confirmation_pos <= 3) // Within last 3 bars
               {
                  DebugPrint(StringFormat("New bottom confirmed: Bottom at %d confirmed by peak at %d", 
                           bottom_pos, confirmation_pos));
                  
                  found_bottom_confirmation = true;
                  new_bottom_confirmation_pos = confirmation_pos;
                  confirming_extreme_pos = bottom_pos;
                  break;
               }
            }
         }
      }
   }
   
   // STEP 3: ALERTS - Only trigger if this isn't the first calculation and we found new confirmations
   if(InpEnableAlerts && !first_calculation)
   {
      datetime current_time = iTime(_Symbol, PERIOD_CURRENT, 0);
      
      // Check if we should alert for a new peak confirmation
      if(found_peak_confirmation && 
         (last_alert_time != current_time || last_alert_direction != 1))
      {
         string message = StringFormat("ZigZag: %s - %s - Peak confirmed by bottom", 
                                     _Symbol, EnumToString(Period()));
         
         Alert(message);
         
         if(InpEnableSoundAlerts) 
            PlaySound(InpSoundFile);
            
         if(InpEnablePushAlerts) 
            SendNotification(message);
            
         if(InpEnableEmailAlerts) 
            SendMail("ZigZag Alert", message);
         
         // Update tracking variables
         last_alert_time = current_time;
         last_alert_direction = 1;
         g_extremes.peak_pos = confirming_extreme_pos;
         g_extremes.confirming_bottom_pos = new_peak_confirmation_pos;
         
         DebugPrint("Sent peak confirmation alert");
      }
      
      // Check if we should alert for a new bottom confirmation
      if(found_bottom_confirmation && 
         (last_alert_time != current_time || last_alert_direction != -1))
      {
         string message = StringFormat("ZigZag: %s - %s - Bottom confirmed by peak", 
                                     _Symbol, EnumToString(Period()));
         
         Alert(message);
         
         if(InpEnableSoundAlerts) 
            PlaySound(InpSoundFile);
            
         if(InpEnablePushAlerts) 
            SendNotification(message);
            
         if(InpEnableEmailAlerts) 
            SendMail("ZigZag Alert", message);
         
         // Update tracking variables
         last_alert_time = current_time;
         last_alert_direction = -1;
         g_extremes.bottom_pos = confirming_extreme_pos;
         g_extremes.confirming_peak_pos = new_bottom_confirmation_pos;
         
         DebugPrint("Sent bottom confirmation alert");
      }
   }
}

//+------------------------------------------------------------------+
//| Remove unconfirmed zigzag points to prevent repainting           |
//+------------------------------------------------------------------+
void HandleNonRepainting(const int &positions[], 
                       const bool &isPeaks[], 
                       const int extremeCount, 
                       const int rates_total)
{
   /*
    * NON-REPAINTING LOGIC OVERVIEW:
    * ------------------------------
    * To prevent repainting in a zigzag indicator, we hide (clear) the most recent
    * zigzag points that haven't been "confirmed" by subsequent price action.
    * 
    * A zigzag extreme point is considered "confirmed" only when the price has
    * reversed enough to create the next extreme point in the opposite direction.
    * 
    * In this implementation:
    * 1. The most recent extreme point is always hidden (cleared)
    * 2. If we don't have at least 3 extremes yet, the second-to-last one is also hidden
    * 
    * When porting to other languages, maintain this clearing logic to ensure
    * only confirmed zigzag points are displayed.
    */
   
   // We need at least one extreme point to apply non-repainting
   if(extremeCount < 1)
      return;
   
   // Extract positions from the arrays for easier access
   int lastExtremePos = positions[0];
   int prevExtremePos = (extremeCount > 1) ? positions[1] : -1;
   int thirdExtremePos = (extremeCount > 2) ? positions[2] : -1;
   
   // STEP 1: Always clear the most recent extreme as it's not confirmed yet
   if(lastExtremePos >= 0)
     {
      // Clear both buffers at this position (only one will have a non-zero value)
      ClearZigzagPoint(lastExtremePos);
      
      // If we have a previous extreme point, clear the zigzag line connecting to it
      if(prevExtremePos >= 0)
        {
         ClearZigzagLine(prevExtremePos, lastExtremePos);
        }
     }
   
   // STEP 2: If we don't have three extremes, the second-to-last one is also not confirmed
   if(thirdExtremePos == -1 && prevExtremePos >= 0)
     {
      // Clear the previous extreme point
      ClearZigzagPoint(prevExtremePos);
      
      // Scan backwards to find the previous extreme before our prevExtremePos
      int priorExtremePos = FindPreviousExtremePosition(prevExtremePos);
      
      // Clear connecting line if we found a prior extreme
      if(priorExtremePos >= 0)
        {
         ClearZigzagLine(priorExtremePos, prevExtremePos);
        }
     }
}

//+------------------------------------------------------------------+
//| Clear a zigzag point at the specified position                   |
//+------------------------------------------------------------------+
void ClearZigzagPoint(const int position)
{
   // Clear both peak and bottom buffers at this position
   ZigzagPeakBuffer[position] = 0;
   ZigzagBottomBuffer[position] = 0;
}

//+------------------------------------------------------------------+
//| Clear zigzag line between two positions (inclusive of end points) |
//+------------------------------------------------------------------+
void ClearZigzagLine(const int startPos, const int endPos)
{
   // Ensure startPos is less than endPos
   int start = MathMin(startPos, endPos);
   int end = MathMax(startPos, endPos);
   
   // Clear all zigzag points between start and end (exclusive of start)
   for(int i=start+1; i<=end; i++)
     {
      ClearZigzagPoint(i);
     }
}

//+------------------------------------------------------------------+
//| Find position of the previous extreme point before the given pos |
//+------------------------------------------------------------------+
int FindPreviousExtremePosition(const int currentPosition)
{
   // Scan backwards to find the previous extreme before the given position
   for(int i=currentPosition-1; i>=0; i--)
     {
      // Check if this position has either a peak or bottom extreme
      bool hasZigzagPoint = (ZigzagPeakBuffer[i] != 0 || ZigzagBottomBuffer[i] != 0);
      
      if(hasZigzagPoint)
         return i;  // Found a previous extreme point
     }
   
   return -1;  // No previous extreme found
}

//+------------------------------------------------------------------+
//| Select extreme points to form the ZigZag pattern                 |
//+------------------------------------------------------------------+
void SelectExtremePoints(const int start, 
                        const int rates_total, 
                        const double &high[], 
                        const double &low[],
                        int &extreme_search,
                        double &last_high, 
                        double &last_low, 
                        int &last_high_pos,
                        int &last_low_pos)
{
   /*
    * ZIGZAG STATE MACHINE OVERVIEW:
    * -------------------------------
    * The ZigZag uses a state machine with three states, represented by extreme_search:
    * 1. SEARCH_FIRST_EXTREMUM (0): Looking for the first extreme point (peak or bottom)
    * 2. SEARCH_NEXT_PEAK (1): Looking for a peak after finding a bottom
    * 3. SEARCH_NEXT_BOTTOM (-1): Looking for a bottom after finding a peak
    *
    * Each state follows a specific logic:
    * - In SEARCH_FIRST_EXTREMUM: We identify the first extreme point of any type
    * - In SEARCH_NEXT_PEAK: We either find a peak or a better (lower) bottom
    * - In SEARCH_NEXT_BOTTOM: We either find a bottom or a better (higher) peak
    *
    * When porting to other languages, maintain this state machine logic and the
    * alternating pattern of finding peaks and bottoms.
    */

   //--- final selection of extreme points for ZigZag
   for(int shift=start; shift<rates_total && !IsStopped(); shift++)
     {
      // Process bars based on our current search mode
      switch(extreme_search)
        {
         //--- Case 1: Initial search for the first extreme point of any type
         case SEARCH_FIRST_EXTREMUM:
           {
            // Only process if we haven't found any extremes yet
            bool noExtremesFoundYet = (last_low==0 && last_high==0);
            if(noExtremesFoundYet)
              {
               // Check if current bar is a high extreme (peak)
               double highExtreme = HighMapBuffer[shift];
               bool isHighExtreme = (highExtreme != 0);
               
               if(isHighExtreme)
                 {
                  // Record this as our first peak
                  last_high = high[shift];
                  last_high_pos = shift;
                  
                  // Now we'll start looking for a bottom next
                  extreme_search = SEARCH_NEXT_BOTTOM;
                  
                  // Mark this point on the zigzag line
                  ZigzagPeakBuffer[shift] = last_high;
                  ColorBuffer[shift] = TREND_UP;    // Set color for uptrend
                  
                  // Skip checking for a bottom at this same position
                  continue;
                 }
               
               // Check if current bar is a low extreme (bottom)
               double lowExtreme = LowMapBuffer[shift];
               bool isLowExtreme = (lowExtreme != 0);
               
               if(isLowExtreme)
                 {
                  // Record this as our first bottom
                  last_low = low[shift];
                  last_low_pos = shift;
                  
                  // Now we'll start looking for a peak next
                  extreme_search = SEARCH_NEXT_PEAK;
                  
                  // Mark this point on the zigzag line
                  ZigzagBottomBuffer[shift] = last_low;
                  ColorBuffer[shift] = TREND_DOWN;  // Set color for downtrend
                 }
              }
            break;
           }
         
         //--- Case 2: We found a bottom, now looking for next peak or a better bottom
         case SEARCH_NEXT_PEAK:
           {
            // SCENARIO 1: Check if we've found a better (lower) bottom than our last one
            double potentialNewBottom = LowMapBuffer[shift];
            bool isLowExtreme = (potentialNewBottom != 0.0);
            bool isLowerThanLastBottom = (isLowExtreme && potentialNewBottom < last_low);
            bool isNotAlsoHighPoint = (HighMapBuffer[shift] == 0.0);
            
            bool isNewLowerBottom = (isLowExtreme && isLowerThanLastBottom && isNotAlsoHighPoint);
            
            if(isNewLowerBottom)
              {
               // Remove the old bottom from zigzag line
               ZigzagBottomBuffer[last_low_pos] = 0.0;
               
               // Update our tracking to this better (lower) bottom
               last_low_pos = shift;
               last_low = potentialNewBottom;
               
               // Mark new bottom point on zigzag line
               ZigzagBottomBuffer[shift] = last_low;
               ColorBuffer[shift] = TREND_DOWN;  // Set color for downtrend
              }
            
            // SCENARIO 2: Check if we've found a peak to connect to
            double potentialPeak = HighMapBuffer[shift];
            bool isHighExtreme = (potentialPeak != 0.0);
            bool isNotAlsoLowPoint = (LowMapBuffer[shift] == 0.0);
            
            bool isValidPeak = (isHighExtreme && isNotAlsoLowPoint);
            
            if(isValidPeak)
              {
               // Record this peak
               last_high = potentialPeak;
               last_high_pos = shift;
               
               // Mark this point on zigzag line
               ZigzagPeakBuffer[shift] = last_high;
               ColorBuffer[shift] = TREND_UP;  // Set color for uptrend
               
               // Now switch to looking for the next bottom
               extreme_search = SEARCH_NEXT_BOTTOM;
              }
            break;
           }
         
         //--- Case 3: We found a peak, now looking for next bottom or a better peak
         case SEARCH_NEXT_BOTTOM:
           {
            // SCENARIO 1: Check if we've found a better (higher) peak than our last one
            double potentialNewPeak = HighMapBuffer[shift];
            bool isHighExtreme = (potentialNewPeak != 0.0);
            bool isHigherThanLastPeak = (isHighExtreme && potentialNewPeak > last_high);
            bool isNotAlsoLowPoint = (LowMapBuffer[shift] == 0.0);
            
            bool isNewHigherPeak = (isHighExtreme && isHigherThanLastPeak && isNotAlsoLowPoint);
            
            if(isNewHigherPeak)
              {
               // Remove the old peak from zigzag line
               ZigzagPeakBuffer[last_high_pos] = 0.0;
               
               // Update our tracking to this better (higher) peak
               last_high_pos = shift;
               last_high = potentialNewPeak;
               
               // Mark new peak point on zigzag line
               ZigzagPeakBuffer[shift] = last_high;
               ColorBuffer[shift] = TREND_UP;  // Set color for uptrend
              }
            
            // SCENARIO 2: Check if we've found a bottom to connect to
            double potentialBottom = LowMapBuffer[shift];
            bool isLowExtreme = (potentialBottom != 0.0);
            bool isNotAlsoHighPoint = (HighMapBuffer[shift] == 0.0);
            
            bool isValidBottom = (isLowExtreme && isNotAlsoHighPoint);
            
            if(isValidBottom)
              {
               // Record this bottom
               last_low = potentialBottom;
               last_low_pos = shift;
               
               // Mark this point on zigzag line
               ZigzagBottomBuffer[shift] = last_low;
               ColorBuffer[shift] = TREND_DOWN;  // Set color for downtrend
               
               // Now switch to looking for the next peak
               extreme_search = SEARCH_NEXT_PEAK;
              }
            break;
           }
         
         default:
            return;  // Safety exit for invalid state
        }
     }
}

//+------------------------------------------------------------------+
//| Search for high and low extremes in the price data               |
//+------------------------------------------------------------------+
void FindExtremes(const int start, 
                 const int rates_total, 
                 const double &high[], 
                 const double &low[], 
                 double &last_high, 
                 double &last_low)
{
   //--- searching for high and low extremes by iterating through each price bar
   for(int shift=start; shift<rates_total && !IsStopped(); shift++)
     {
      //--- SECTION 1: FIND LOW EXTREMES (BOTTOMS) ---//
      
      // Step 1: Find the lowest price within the specified depth
      double lowestValueInRange = Lowest(low, InpDepth, shift);
      
      // Step 2: Check if this lowest value is the same as the previous one we found
      bool isNewLowExtreme = (lowestValueInRange != last_low);
      
      // If we found a new low extreme value...
      if(isNewLowExtreme)
        {
         // Update our tracking variable for the last found low
         last_low = lowestValueInRange;
         
         // Step 3: Calculate the price difference to check deviation significance
         double priceDifference = low[shift] - lowestValueInRange;
         double minimumRequiredDeviation = InpDeviation * _Point;
         bool isDeviationSignificant = (priceDifference <= minimumRequiredDeviation);
         
         // Only consider points with significant deviation
         if(!isDeviationSignificant)
           {
            // Not significant enough - cancel this extreme point
            lowestValueInRange = 0.0;
           }
           else
           {
            // Step 4: Look back to check and possibly clear previous extremes
            // This prevents multiple extremes too close together
            for(int barsBack=InpBackstep; barsBack>=1; barsBack--)
              {
               int previousBarIndex = shift-barsBack;
               double previousLowExtreme = LowMapBuffer[previousBarIndex];
               
               // If previous value exists and is higher (worse) than current one, remove it
               if((previousLowExtreme != 0) && (previousLowExtreme > lowestValueInRange))
                  LowMapBuffer[previousBarIndex] = 0.0;
              }
           }
        }
      else
        {
         // Same as previous low extreme - skip it
         lowestValueInRange = 0.0;
        }
      
      // Step 5: Record the low extreme if this bar's low price exactly matches the lowest value
      bool isBarActualLowExtreme = (low[shift] == lowestValueInRange);
      
      // Store the extreme point in the buffer or clear it
      if(isBarActualLowExtreme)
         LowMapBuffer[shift] = lowestValueInRange;  // This is a low extreme point
      else
         LowMapBuffer[shift] = 0.0;  // Not an extreme point
      
      //--- SECTION 2: FIND HIGH EXTREMES (PEAKS) ---//
      // Process is symmetrical to the low extreme search above
      
      // Step 1: Find the highest price within the specified depth
      double highestValueInRange = Highest(high, InpDepth, shift);
      
      // Step 2: Check if this highest value is the same as the previous one we found
      bool isNewHighExtreme = (highestValueInRange != last_high);
      
      // If we found a new high extreme value...
      if(isNewHighExtreme)
        {
         // Update our tracking variable for the last found high
         last_high = highestValueInRange;
         
         // Step 3: Calculate the price difference to check deviation significance
         double priceDifference = highestValueInRange - high[shift];
         double minimumRequiredDeviation = InpDeviation * _Point;
         bool isDeviationSignificant = (priceDifference <= minimumRequiredDeviation);
         
         // Only consider points with significant deviation
         if(!isDeviationSignificant)
           {
            // Not significant enough - cancel this extreme point
            highestValueInRange = 0.0;
           }
           else
           {
            // Step 4: Look back to check and possibly clear previous extremes
            // This prevents multiple extremes too close together
            for(int barsBack=InpBackstep; barsBack>=1; barsBack--)
              {
               int previousBarIndex = shift-barsBack;
               double previousHighExtreme = HighMapBuffer[previousBarIndex];
               
               // If previous value exists and is lower (worse) than current one, remove it
               if((previousHighExtreme != 0) && (previousHighExtreme < highestValueInRange))
                  HighMapBuffer[previousBarIndex] = 0.0;
              }
           }
        }
      else
        {
         // Same as previous high extreme - skip it
         highestValueInRange = 0.0;
        }
      
      // Step 5: Record the high extreme if this bar's high price exactly matches the highest value
      bool isBarActualHighExtreme = (high[shift] == highestValueInRange);
      
      // Store the extreme point in the buffer or clear it
      if(isBarActualHighExtreme)
         HighMapBuffer[shift] = highestValueInRange;  // This is a high extreme point
      else
         HighMapBuffer[shift] = 0.0;  // Not an extreme point
     }
}

//+------------------------------------------------------------------+
//| Initialize calculation parameters                                |
//| Returns false if there's an error or insufficient data           |
//+------------------------------------------------------------------+
bool InitializeCalculation(const int rates_total,
                         const int prev_calculated,
                         const double &high[],
                         const double &low[],
                         int &start,
                         int &extreme_search,
                         double &cur_high,
                         double &cur_low,
                         double &last_high,
                         double &last_low,
                         int &last_high_pos,
                         int &last_low_pos)
{
   /*
    * CALCULATION INITIALIZATION OVERVIEW:
    * ----------------------------------
    * This function determines where to start/resume calculations based on whether:
    * 1. This is the first calculation (prev_calculated == 0)
    * 2. We're continuing calculation from a previous state
    * 
    * For continuation, we need to find recent zigzag points to properly
    * resume the state machine. This is critical for maintaining the
    * alternating pattern of peaks and bottoms in the zigzag.
    * 
    * When porting to other languages, ensure this initialization logic
    * is properly translated to maintain calculation continuity.
    */
    
   // CASE 1: First calculation or recalculation from scratch
   if(prev_calculated == 0)
     {
      // Clear all indicator buffers to 0.0
      ArrayInitialize(ZigzagPeakBuffer, 0.0);
      ArrayInitialize(ZigzagBottomBuffer, 0.0);
      ArrayInitialize(HighMapBuffer, 0.0);
      ArrayInitialize(LowMapBuffer, 0.0);
      ArrayInitialize(ConfirmPeakBuffer, 0.0);
      ArrayInitialize(ConfirmBottomBuffer, 0.0);
      
      // Start calculation from bar number InpDepth (need enough bars for depth calculation)
      start = InpDepth - 1;
      
      // Begin in the initial state: searching for first extreme point
      extreme_search = SEARCH_FIRST_EXTREMUM;
      
      // No need to handle extremes - starting fresh
      return true;
     }
   
   // CASE 2: Continuing calculation - find where to restart from
   if(prev_calculated > 0)
     {
      // We need to find the point where we should resume calculation from
      int lastCalculatedBar = rates_total - 1;
      
      // Need to find the third extremum from the end to ensure proper zigzag continuation
      int extremesNeeded = ExtRecalc; // Looking for this many recent extremes
      int extremesFound = 0;
      int maxBarsToSearch = 100; // Limit search to recent bars for efficiency
      int searchStartBar = lastCalculatedBar;
      int searchEndBar = MathMax(lastCalculatedBar - maxBarsToSearch, 0);
      
      // STEP 1: Scan backwards looking for existing zigzag points
      int potentialStartBar = searchStartBar;
      
      // Continue searching while we need more extremes and haven't reached our search limit
      while(extremesFound < extremesNeeded && potentialStartBar > searchEndBar)
        {
         // Check if there's a zigzag point at this position
         bool hasPeakPoint = (ZigzagPeakBuffer[potentialStartBar] != 0);
         bool hasBottomPoint = (ZigzagBottomBuffer[potentialStartBar] != 0);
         bool isExtremePoint = (hasPeakPoint || hasBottomPoint);
         
         // Count it if found
         if(isExtremePoint)
           {
            extremesFound++;
           }
            
         // Continue searching backward
         potentialStartBar--;
        }
      
      // We went one position too far back in the loop
      potentialStartBar++;
      
      // STEP 2: This is where we'll restart calculation from
      start = potentialStartBar;
      
      // STEP 3: Determine what type of extreme we're looking for next based on the last extreme found
      bool isLastExtremeBottom = (LowMapBuffer[potentialStartBar] != 0);
      bool isLastExtremePeak = (HighMapBuffer[potentialStartBar] != 0);
      
      if(isLastExtremeBottom)
        {
         // Last extreme was a bottom - we're looking for a peak next
         cur_low = LowMapBuffer[potentialStartBar];
         extreme_search = SEARCH_NEXT_PEAK;
        }
      else if(isLastExtremePeak)
        {
         // Last extreme was a peak - we're looking for a bottom next
         cur_high = HighMapBuffer[potentialStartBar];
         extreme_search = SEARCH_NEXT_BOTTOM;
        }
      else
        {
         // Fallback - start with initial search state
         extreme_search = SEARCH_FIRST_EXTREMUM;
        }
      
      // STEP 4: Clear all indicator values beyond our starting point to recalculate them
      for(int i = start + 1; i < rates_total && !IsStopped(); i++)
        {
         ZigzagPeakBuffer[i] = 0.0;
         ZigzagBottomBuffer[i] = 0.0;
         LowMapBuffer[i] = 0.0;
         HighMapBuffer[i] = 0.0;
         ConfirmPeakBuffer[i] = 0.0;
         ConfirmBottomBuffer[i] = 0.0;
        }
     }
   
   return true;
}

//+------------------------------------------------------------------+
//| V5 ENHANCEMENT: STRUCTURE ANALYSIS FUNCTIONS                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Classify a swing point as HH/HL/LH/LL                            |
//+------------------------------------------------------------------+
EnStructureType ClassifySwingPoint(bool isPeak, double currentPrice, double previousPrice)
{
   if(previousPrice == 0)
      return STRUCT_NONE;  // No previous point to compare

   if(isPeak)
   {
      // Comparing highs
      if(currentPrice > previousPrice)
         return STRUCT_HH;  // Higher High
      else
         return STRUCT_LH;  // Lower High
   }
   else
   {
      // Comparing lows
      if(currentPrice > previousPrice)
         return STRUCT_HL;  // Higher Low
      else
         return STRUCT_LL;  // Lower Low
   }
}

//+------------------------------------------------------------------+
//| Get structure type name string                                    |
//+------------------------------------------------------------------+
string GetStructureTypeName(EnStructureType type)
{
   switch(type)
   {
      case STRUCT_HH: return "HH";
      case STRUCT_HL: return "HL";
      case STRUCT_LH: return "LH";
      case STRUCT_LL: return "LL";
      default: return "";
   }
}

//+------------------------------------------------------------------+
//| Get color for structure type                                      |
//+------------------------------------------------------------------+
color GetStructureColor(EnStructureType type)
{
   switch(type)
   {
      case STRUCT_HH: return InpHHColor;
      case STRUCT_HL: return InpHLColor;
      case STRUCT_LH: return InpLHColor;
      case STRUCT_LL: return InpLLColor;
      default: return clrWhite;
   }
}

//+------------------------------------------------------------------+
//| Create structure label on chart                                   |
//+------------------------------------------------------------------+
void CreateStructureLabel(int bar, EnStructureType type, double price, datetime barTime, bool isPeak)
{
   if(!InpShowStructureLabels || type == STRUCT_NONE)
      return;

   // Create unique name
   string typeName = GetStructureTypeName(type);
   string objName = OBJ_PREFIX_STRUCT + typeName + "_" +
                    IntegerToString(bar) + "_" +
                    IntegerToString(barTime);

   // Delete if exists
   ObjectDelete(0, objName);

   // Calculate offset for label position
   double offset = InpLabelOffsetPips * PipSize();
   double labelPrice = isPeak ? (price + offset) : (price - offset);

   // Create text label
   if(!ObjectCreate(0, objName, OBJ_TEXT, 0, barTime, labelPrice))
   {
      if(InpDebugMode)
         PrintFormat("ZZ_v5: FAILED to create label %s, error=%d", objName, GetLastError());
      return;
   }

   // Set label properties
   ObjectSetString(0, objName, OBJPROP_TEXT, typeName);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, GetStructureColor(type));
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, InpLabelFontSize);
   ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, isPeak ? ANCHOR_LOWER : ANCHOR_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);

   if(InpDebugMode)
   {
      // Get previous comparison price for diagnostic clarity
      double prevPrice = isPeak ? g_structure.prev_peak_price : g_structure.prev_bottom_price;
      string comparison = (prevPrice > 0) ?
         StringFormat("(prev=%.5f, diff=%+.5f)", prevPrice, price - prevPrice) :
         "(first point)";

      PrintFormat("ZZ_v5: [%s] %s at bar=%d, price=%.5f %s, time=%s",
                  isPeak ? "PEAK" : "BOTTOM",
                  typeName, bar, price, comparison,
                  TimeToString(barTime, TIME_DATE | TIME_MINUTES));
   }
}

//+------------------------------------------------------------------+
//| Update structure state when new swing point is found              |
//| createLabel: if false, only update state without creating label   |
//+------------------------------------------------------------------+
void UpdateStructureState(int bar, bool isPeak, double price, datetime barTime, bool createLabel=true)
{
   EnStructureType structType = STRUCT_NONE;

   if(isPeak)
   {
      // Update peak history - compare to LAST peak (not prev_peak which is 2 peaks ago)
      structType = ClassifySwingPoint(true, price, g_structure.last_peak_price);

      g_structure.prev_peak_bar = g_structure.last_peak_bar;
      g_structure.prev_peak_price = g_structure.last_peak_price;
      g_structure.last_peak_bar = bar;
      g_structure.last_peak_price = price;
   }
   else
   {
      // Update bottom history - compare to LAST bottom (not prev_bottom which is 2 bottoms ago)
      structType = ClassifySwingPoint(false, price, g_structure.last_bottom_price);

      g_structure.prev_bottom_bar = g_structure.last_bottom_bar;
      g_structure.prev_bottom_price = g_structure.last_bottom_price;
      g_structure.last_bottom_bar = bar;
      g_structure.last_bottom_price = price;
   }

   // Store the structure type
   g_structure.last_structure_type = structType;

   // Update trend state based on structure sequence
   UpdateTrendState(structType);

   // Create the label (only if requested - skipped for old bars outside lookback)
   if(createLabel)
      CreateStructureLabel(bar, structType, price, barTime, isPeak);
}

//+------------------------------------------------------------------+
//| Update trend state based on structure pattern                     |
//+------------------------------------------------------------------+
void UpdateTrendState(EnStructureType newStructure)
{
   // Bullish trend: HH followed by HL (or continuing HH/HL pattern)
   // Bearish trend: LH followed by LL (or continuing LH/LL pattern)

   switch(newStructure)
   {
      case STRUCT_HH:
      case STRUCT_HL:
         // Bullish structure point
         if(g_structure.current_trend == TREND_BEARISH)
         {
            // Potential CHoCH - trend might be changing
            // Will be confirmed by subsequent structure
         }
         g_structure.current_trend = TREND_BULLISH;
         break;

      case STRUCT_LH:
      case STRUCT_LL:
         // Bearish structure point
         if(g_structure.current_trend == TREND_BULLISH)
         {
            // Potential CHoCH - trend might be changing
            // Will be confirmed by subsequent structure
         }
         g_structure.current_trend = TREND_BEARISH;
         break;

      default:
         // No change
         break;
   }
}

//+------------------------------------------------------------------+
//| EXTENDING LEVEL LINES - CC Indicator Pattern                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create level line from swing point                                |
//+------------------------------------------------------------------+
void CreateLevelLine(int bar, bool isPeak, double price, datetime barTime)
{
   if(!InpShowLevelLines)
      return;

   // Create unique name with ACTIVE prefix for extending lines
   string dirSuffix = isPeak ? "PEAK_" : "BOTTOM_";
   string objName = OBJ_PREFIX_LEVEL_ACTIVE + dirSuffix +
                    IntegerToString(bar) + "_" + IntegerToString(barTime);

   // Delete if exists
   ObjectDelete(0, objName);

   // Calculate end time (extend forward)
   datetime endTime = barTime + InpMaxLevelHours * 3600;

   // Create horizontal line (OBJ_TREND)
   if(!ObjectCreate(0, objName, OBJ_TREND, 0, barTime, price, endTime, price))
   {
      if(InpDebugMode)
         PrintFormat("ZZ_v5: FAILED to create level line %s, error=%d", objName, GetLastError());
      return;
   }

   // Set line properties - peaks are resistance (bearish), bottoms are support (bullish)
   color lineColor = isPeak ? InpLHColor : InpHLColor;  // Use structure colors
   ObjectSetInteger(0, objName, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);

   if(InpDebugMode)
   {
      PrintFormat("ZZ_v5: [LEVEL] Created %s line at bar=%d, price=%.5f, time=%s",
                  isPeak ? "RESISTANCE" : "SUPPORT",
                  bar, price, TimeToString(barTime, TIME_DATE | TIME_MINUTES));
   }
}

//+------------------------------------------------------------------+
//| Manage level lines - extend active ones, check mitigation        |
//+------------------------------------------------------------------+
void ManageLevelLines(const double &high[], const double &low[],
                       const datetime &time[], int rates_total)
{
   if(!InpShowLevelLines)
      return;

   datetime currentTime = time[rates_total - 1];
   int total = ObjectsTotal(0);

   // Calculate max duration in seconds
   long maxDurationSec = (InpMaxLevelHours > 0) ? (long)InpMaxLevelHours * 3600 : 0;

   int activeCount = 0;
   int mitigatedCount = 0;
   int extendedCount = 0;

   // Loop backwards for safe processing
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);

      // Only process our active level lines
      if(StringFind(objName, OBJ_PREFIX_LEVEL_ACTIVE) != 0)
         continue;

      activeCount++;

      // Get line start time and price level
      datetime lineStartTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
      double linePrice = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);

      // Check if line is from peak (resistance) or bottom (support)
      bool isPeak = (StringFind(objName, "PEAK_") > 0);

      // Find bar index where line was created - convert AS_SERIES to non-AS_SERIES
      int shiftBar = iBarShift(_Symbol, _Period, lineStartTime);
      int lineStartBar;
      if(shiftBar < 0)
         lineStartBar = 0;  // Fallback to oldest bar
      else
         lineStartBar = rates_total - 1 - shiftBar;  // Convert: AS_SERIES -> non-AS_SERIES

      bool mitigated = false;
      int mitigationBar = -1;
      string mitigationReason = "";

      // Check bars AFTER the creation bar (non-AS_SERIES: larger index = newer bar)
      for(int b = lineStartBar + 1; b < rates_total - 1; b++)  // Skip current forming bar
      {
         // Peak lines (resistance) are mitigated when price goes above
         // Bottom lines (support) are mitigated when price goes below
         if(isPeak)
         {
            if(high[b] > linePrice)
            {
               mitigated = true;
               mitigationBar = b;
               mitigationReason = StringFormat("high[%d]=%.5f > linePrice=%.5f", b, high[b], linePrice);
               break;
            }
         }
         else
         {
            if(low[b] < linePrice)
            {
               mitigated = true;
               mitigationBar = b;
               mitigationReason = StringFormat("low[%d]=%.5f < linePrice=%.5f", b, low[b], linePrice);
               break;
            }
         }
      }

      if(mitigated && mitigationBar > 0)
      {
         // Rename line (remove ACTIVE prefix)
         string finalName = OBJ_PREFIX_LEVEL + (isPeak ? "PEAK_" : "BOTTOM_") +
                            StringSubstr(objName, StringLen(OBJ_PREFIX_LEVEL_ACTIVE) +
                            (isPeak ? 5 : 7));  // Skip "PEAK_" or "BOTTOM_"

         // Shorten line to mitigation point
         datetime mitigationTime = time[mitigationBar];
         ObjectSetInteger(0, objName, OBJPROP_TIME, 1, mitigationTime);

         mitigatedCount++;

         if(InpDebugMode)
         {
            PrintFormat("ZZ_v5: [MITIGATED] %s level at price=%.5f, bar=%d (%s)",
                        isPeak ? "RESISTANCE" : "SUPPORT",
                        linePrice, mitigationBar, mitigationReason);
         }
      }
      else
      {
         // Check for time expiry
         long lineDuration = (long)(currentTime - lineStartTime);
         if(maxDurationSec > 0 && lineDuration > maxDurationSec)
         {
            // Mark as expired by removing ACTIVE prefix
            ObjectDelete(0, objName);
         }
         else
         {
            // Extend active line to current bar
            ObjectSetInteger(0, objName, OBJPROP_TIME, 1, currentTime);
            extendedCount++;
         }
      }
   }

   if(InpDebugMode && activeCount > 0)
   {
      PrintFormat("ZZ_v5: [LEVELS] Active=%d, Extended=%d, Mitigated=%d",
                  activeCount, extendedCount, mitigatedCount);
   }
}

//+------------------------------------------------------------------+
//| Process level lines from all zigzag swing points                  |
//+------------------------------------------------------------------+
void ProcessLevelLines(const double &high[], const double &low[],
                        const datetime &time[], int rates_total)
{
   if(!InpShowLevelLines)
      return;

   // Calculate lookback limit (use both bar count and days back)
   int startIdx = GetLookbackStartIndex(rates_total);
   datetime lookbackLimit = time[rates_total - 1] - (InpLevelDaysBack * 86400);

   int levelsCreated = 0;
   int peakLevels = 0, bottomLevels = 0;

   if(InpDebugMode)
      PrintFormat("ZZ_v5: === Starting Level Line creation (from bar %d) ===", startIdx);

   // Scan through bars and create level lines at zigzag points
   // Only create lines within the lookback period (bar limit AND days back)
   for(int i = startIdx; i < rates_total; i++)
   {
      // Skip bars older than days-back limit
      if(time[i] < lookbackLimit)
         continue;

      // Check for zigzag peaks and bottoms
      if(ZigzagPeakBuffer[i] != 0)
      {
         CreateLevelLine(i, true, ZigzagPeakBuffer[i], time[i]);
         peakLevels++;
         levelsCreated++;
      }

      if(ZigzagBottomBuffer[i] != 0)
      {
         CreateLevelLine(i, false, ZigzagBottomBuffer[i], time[i]);
         bottomLevels++;
         levelsCreated++;
      }
   }

   // Now manage all lines (extend or mitigate)
   ManageLevelLines(high, low, time, rates_total);

   if(InpDebugMode)
   {
      Print("ZZ_v5: === Level Lines Summary ===");
      PrintFormat("ZZ_v5:   Created: %d (Peaks=%d, Bottoms=%d)",
                  levelsCreated, peakLevels, bottomLevels);
      Print("ZZ_v5: ================================");
   }
}

//+------------------------------------------------------------------+
//| Process structure labels for all zigzag points                    |
//+------------------------------------------------------------------+
void ProcessStructureLabels(const int rates_total, const datetime &time[])
{
   if(!InpShowStructureLabels)
      return;

   // Reset structure state for fresh calculation
   ResetStructureState();

   // Calculate lookback start index for label creation
   // We still process ALL bars for structure state, but only create labels within lookback
   int lookbackStartIdx = GetLookbackStartIndex(rates_total);

   // Counters for debug summary
   int totalPeaks = 0, totalBottoms = 0;
   int hhCount = 0, hlCount = 0, lhCount = 0, llCount = 0;
   int labelsCreated = 0;

   if(InpDebugMode)
      PrintFormat("ZZ_v5: === Starting structure label processing (labels from bar %d) ===", lookbackStartIdx);

   // Scan through all bars and find zigzag points (oldest to newest for proper comparison)
   // In MQL5 with AS_SERIES=false: index 0 = oldest, rates_total-1 = newest
   // Process ALL bars for structure state, but only create labels within lookback
   for(int i = 0; i < rates_total; i++)
   {
      bool hasPeak = (ZigzagPeakBuffer[i] != 0);
      bool hasBottom = (ZigzagBottomBuffer[i] != 0);

      // Determine if we should create labels for this bar (within lookback limit)
      bool createLabel = (i >= lookbackStartIdx);

      if(hasPeak)
      {
         totalPeaks++;
         UpdateStructureState(i, true, ZigzagPeakBuffer[i], time[i], createLabel);

         // Count structure types (only count labels actually created)
         if(createLabel)
         {
            if(g_structure.last_structure_type == STRUCT_HH) { hhCount++; labelsCreated++; }
            else if(g_structure.last_structure_type == STRUCT_LH) { lhCount++; labelsCreated++; }
            else if(g_structure.last_structure_type != STRUCT_NONE) labelsCreated++;
         }
      }
      else if(hasBottom)
      {
         totalBottoms++;
         UpdateStructureState(i, false, ZigzagBottomBuffer[i], time[i], createLabel);

         // Count structure types (only count labels actually created)
         if(createLabel)
         {
            if(g_structure.last_structure_type == STRUCT_HL) { hlCount++; labelsCreated++; }
            else if(g_structure.last_structure_type == STRUCT_LL) { llCount++; labelsCreated++; }
            else if(g_structure.last_structure_type != STRUCT_NONE) labelsCreated++;
         }
      }
   }

   if(InpDebugMode)
   {
      Print("ZZ_v5: === Structure Label Summary ===");
      PrintFormat("ZZ_v5:   Total zigzag points: %d peaks, %d bottoms", totalPeaks, totalBottoms);
      PrintFormat("ZZ_v5:   Labels created: %d (HH=%d, HL=%d, LH=%d, LL=%d)",
                  labelsCreated, hhCount, hlCount, lhCount, llCount);
      PrintFormat("ZZ_v5:   Final trend: %s",
                  g_structure.current_trend == TREND_BULLISH ? "BULLISH" :
                  g_structure.current_trend == TREND_BEARISH ? "BEARISH" : "NONE");
      PrintFormat("ZZ_v5:   Last peak: bar=%d price=%.5f | Last bottom: bar=%d price=%.5f",
                  g_structure.last_peak_bar, g_structure.last_peak_price,
                  g_structure.last_bottom_bar, g_structure.last_bottom_price);
      Print("ZZ_v5: ================================");
   }
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if a new bar has formed                                    |
//| Used to: Only calculate the indicator on new bars when requested |
//| Returns: True if a new bar has formed, False otherwise           |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   // Get the timestamp of the most recent (current) bar
   // In MQL, bar 0 is the current forming bar
   datetime currentBarTimestamp = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   // Compare with our stored timestamp of the last bar we've seen
   bool isNewBarFormed = (currentBarTimestamp != g_last_bar_time);
   
   // If this is a new bar, update our stored timestamp
   if(isNewBarFormed)
   {
      // Update the global variable to remember this bar's timestamp
      g_last_bar_time = currentBarTimestamp;
      return true;  // Yes, this is a new bar
   }
   
   return false;  // No new bar formed yet
}

//+------------------------------------------------------------------+
//| Get highest value for range                                      |
//| Used to: Find the highest price in a specified range of bars     |
//| Input:  array - price array to search in                         |
//|         count - number of bars to look back                      |
//|         start - starting position for the search                 |
//| Returns: The highest price value found                           |
//+------------------------------------------------------------------+
double Highest(const double &array[], int count, int start)
{
   /*
    * This function finds the highest value in a range of bars.
    * 
    * Important notes for cross-language porting:
    * - In MQL, arrays are indexed with newest bars at index 0.
    * - Other platforms (like Python) may have oldest bars first.
    * - When porting, ensure the lookback direction is preserved.
    */
    
   // Start with the price at the starting position
   double highestValue = array[start];
   
   // Calculate the oldest bar to check (ensure we don't go beyond array bounds)
   int oldestBarToCheck = MathMax(start - count + 1, 0);
   
   // Search each bar in the range for a higher value (moving from newer to older bars)
   for(int barIndex = start - 1; barIndex >= oldestBarToCheck; barIndex--)
   {
      // If we found a higher value, update our highest value
      if(array[barIndex] > highestValue)
         highestValue = array[barIndex];
   }
   
   return highestValue;
}

//+------------------------------------------------------------------+
//| Get lowest value for range                                       |
//| Used to: Find the lowest price in a specified range of bars      |
//| Input:  array - price array to search in                         |
//|         count - number of bars to look back                      |
//|         start - starting position for the search                 |
//| Returns: The lowest price value found                            |
//+------------------------------------------------------------------+
double Lowest(const double &array[], int count, int start)
{
   /*
    * This function finds the lowest value in a range of bars.
    * 
    * Important notes for cross-language porting:
    * - In MQL, arrays are indexed with newest bars at index 0.
    * - Other platforms (like Python) may have oldest bars first.
    * - When porting, ensure the lookback direction is preserved.
    */
    
   // Start with the price at the starting position
   double lowestValue = array[start];
   
   // Calculate the oldest bar to check (ensure we don't go beyond array bounds)
   int oldestBarToCheck = MathMax(start - count + 1, 0);
   
   // Search each bar in the range for a lower value (moving from newer to older bars)
   for(int barIndex = start - 1; barIndex >= oldestBarToCheck; barIndex--)
   {
      // If we found a lower value, update our lowest value
      if(array[barIndex] < lowestValue)
         lowestValue = array[barIndex];
   }
   
   return lowestValue;
}



