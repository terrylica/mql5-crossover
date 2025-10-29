//+------------------------------------------------------------------+
//|                                          PercentileNormalizer.mqh |
//|                              Reusable Percentile Rank Library    |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property link        "https://github.com/terrylica/mql5-crossover"
#property version     "1.00"
#property description "Percentile rank normalization library for MQL5 indicators"

//--- Include guard (MQL5 best practice - prevents duplicate inclusion)
#ifndef PERCENTILE_NORMALIZER_MQH
#define PERCENTILE_NORMALIZER_MQH

//+------------------------------------------------------------------+
//| Percentile Rank Normalizer Class                                |
//| Usage: Instantiate once, call Normalize() per bar               |
//+------------------------------------------------------------------+
class CPercentileNormalizer
  {
private:
   int               m_window_size;      // Rolling window size
   double            m_threshold_low;    // Low threshold (e.g., 0.30 for 30%)
   double            m_threshold_high;   // High threshold (e.g., 0.70 for 70%)
   double            m_window[];         // Internal rolling window buffer

public:
   //--- Constructor
                     CPercentileNormalizer(int window_size = 120,
                                           double threshold_low = 0.30,
                                           double threshold_high = 0.70);

   //--- Destructor
                    ~CPercentileNormalizer() { ArrayFree(m_window); }

   //--- Main normalization method
   double            Normalize(const double value, const double &data[], int index, int size);

   //--- Percentile rank calculation (static - can be used standalone)
   static double     CalculatePercentileRank(double value, const double &window[], int size);

   //--- Color mapping (static - can be customized)
   static int        MapToColorIndex(double percentile_rank,
                                     double threshold_low = 0.30,
                                     double threshold_high = 0.70);

   //--- Getters
   int               WindowSize() const { return m_window_size; }
   double            ThresholdLow() const { return m_threshold_low; }
   double            ThresholdHigh() const { return m_threshold_high; }

   //--- Setters
   void              SetWindowSize(int size) { m_window_size = size; ArrayResize(m_window, size); }
   void              SetThresholds(double low, double high) { m_threshold_low = low; m_threshold_high = high; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPercentileNormalizer::CPercentileNormalizer(int window_size,
                                             double threshold_low,
                                             double threshold_high)
  {
   m_window_size = MathMax(2, window_size);  // Minimum 2 for percentile calculation
   m_threshold_low = threshold_low;
   m_threshold_high = threshold_high;

   ArrayResize(m_window, m_window_size);
   ArrayInitialize(m_window, 0.0);
  }

//+------------------------------------------------------------------+
//| Main Normalization Method                                       |
//| Parameters:                                                      |
//|   value - current value to normalize                            |
//|   data  - source data array (timeseries)                        |
//|   index - current bar index in data array                       |
//|   size  - total size of data array                              |
//| Returns: Percentile rank (0.0 - 1.0)                            |
//+------------------------------------------------------------------+
double CPercentileNormalizer::Normalize(const double value,
                                        const double &data[],
                                        int index,
                                        int size)
  {
   // Check if we have enough data
   if(index < m_window_size - 1)
      return EMPTY_VALUE;

   // Build rolling window [index - m_window_size + 1, index]
   int window_start = index - m_window_size + 1;
   for(int i = 0; i < m_window_size; i++)
     {
      m_window[i] = data[window_start + i];
     }

   // Calculate percentile rank
   return CalculatePercentileRank(value, m_window, m_window_size);
  }

//+------------------------------------------------------------------+
//| Static Percentile Rank Calculation                              |
//| Algorithm: Count values below current / total window size       |
//| Complexity: O(n) where n = window size                          |
//| Returns: Percentile rank [0.0, 1.0]                             |
//+------------------------------------------------------------------+
static double CPercentileNormalizer::CalculatePercentileRank(double value,
                                                             const double &window[],
                                                             int size)
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
//| Static Color Index Mapping                                      |
//| Maps percentile rank to 3-color index                           |
//| Returns: 0 (Red), 1 (Yellow), 2 (Green)                         |
//+------------------------------------------------------------------+
static int CPercentileNormalizer::MapToColorIndex(double percentile_rank,
                                                  double threshold_low,
                                                  double threshold_high)
  {
   if(percentile_rank > threshold_high)
      return 2;  // Green: Top 30%
   else if(percentile_rank > threshold_low)
      return 1;  // Yellow: Middle 40%
   else
      return 0;  // Red: Bottom 30%
  }

//+------------------------------------------------------------------+
//| Functional Interface (for quick one-off calculations)           |
//+------------------------------------------------------------------+
double PercentileRankSimple(double value, const double &window[], int size)
  {
   return CPercentileNormalizer::CalculatePercentileRank(value, window, size);
  }

#endif // PERCENTILE_NORMALIZER_MQH
//+------------------------------------------------------------------+
