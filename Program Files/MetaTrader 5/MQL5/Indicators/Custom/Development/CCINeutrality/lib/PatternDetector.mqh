//+------------------------------------------------------------------+
//| PatternDetector.mqh                                              |
//| Rising pattern detection logic (pure functions, no state)        |
//| Version: 1.0.0                                                   |
//+------------------------------------------------------------------+
#property copyright "2025"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Detect 4 consecutive rising bars                                 |
//| Returns: true if bar[i-3] < bar[i-2] < bar[i-1] < bar[i]       |
//| Parameters:                                                       |
//|   - scores[]: Array of histogram values (as series, index 0 = newest) |
//|   - index: Current bar index to check                            |
//| Requires: index >= 3 (need 3 previous bars)                      |
//+------------------------------------------------------------------+
bool DetectRisingPattern(const double &scores[], int index)
  {
   // Validate index
   if(index < 3)
      return false;

   // Check if array has enough elements
   if(ArraySize(scores) <= index)
      return false;

   // Detect: each bar must be strictly higher than previous
   bool check1 = scores[index - 3] < scores[index - 2];
   bool check2 = scores[index - 2] < scores[index - 1];
   bool check3 = scores[index - 1] < scores[index];

   return (check1 && check2 && check3);
  }

//+------------------------------------------------------------------+
//| Get detection details for logging/debugging                      |
//| Returns: Struct with all comparison values and results           |
//+------------------------------------------------------------------+
struct DetectionDetails
  {
   double            val_i_minus_3;
   double            val_i_minus_2;
   double            val_i_minus_1;
   double            val_i;
   bool              check1;  // i-3 < i-2
   bool              check2;  // i-2 < i-1
   bool              check3;  // i-1 < i
   bool              pattern_detected;
  };

DetectionDetails GetDetectionDetails(const double &scores[], int index)
  {
   DetectionDetails details;

   // Initialize with defaults
   details.val_i_minus_3 = 0.0;
   details.val_i_minus_2 = 0.0;
   details.val_i_minus_1 = 0.0;
   details.val_i = 0.0;
   details.check1 = false;
   details.check2 = false;
   details.check3 = false;
   details.pattern_detected = false;

   // Validate index
   if(index < 3 || ArraySize(scores) <= index)
      return details;

   // Extract values
   details.val_i_minus_3 = scores[index - 3];
   details.val_i_minus_2 = scores[index - 2];
   details.val_i_minus_1 = scores[index - 1];
   details.val_i = scores[index];

   // Perform checks
   details.check1 = details.val_i_minus_3 < details.val_i_minus_2;
   details.check2 = details.val_i_minus_2 < details.val_i_minus_1;
   details.check3 = details.val_i_minus_1 < details.val_i;

   details.pattern_detected = (details.check1 && details.check2 && details.check3);

   return details;
  }

//+------------------------------------------------------------------+
//| Convert bool to string for CSV logging                           |
//+------------------------------------------------------------------+
string BoolToString(bool value)
  {
   return value ? "TRUE" : "FALSE";
  }
//+------------------------------------------------------------------+
