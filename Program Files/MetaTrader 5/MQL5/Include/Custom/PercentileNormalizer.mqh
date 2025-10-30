//+------------------------------------------------------------------+
//|                                          PercentileNormalizer.mqh |
//|                              Reusable Percentile Rank Library    |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property link        "https://github.com/terrylica/mql5-crossover"
#property version     "2.00"
#property description "Percentile rank normalization and rate-of-change statistics library for MQL5 indicators"

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

//+------------------------------------------------------------------+
//| Rate of Change Statistics Class                                 |
//| Purpose: Calculate and normalize rate-of-change statistics      |
//|          for histogram values over rolling windows              |
//| Key Features:                                                    |
//|   - Calculates deltas (rate of change) between consecutive bars |
//|   - Computes 14-bar statistics on those deltas                  |
//|   - Normalizes statistics against 120-bar historical lookback   |
//|   - NO look-ahead bias (uses only data up to bar i-1)           |
//+------------------------------------------------------------------+
class CRateOfChangeStatistics
  {
private:
   int               m_short_window;     // Short window for delta statistics (e.g., 14)
   int               m_long_window;      // Long window for normalization (e.g., 120)
   double            m_threshold_low;    // Low threshold for normalization
   double            m_threshold_high;   // High threshold for normalization

   double            m_delta_buffer[];   // Buffer for calculated deltas

public:
   //--- Constructor
                     CRateOfChangeStatistics(int short_window = 14,
                                            int long_window = 120,
                                            double threshold_low = 0.30,
                                            double threshold_high = 0.70);

   //--- Destructor
                    ~CRateOfChangeStatistics() { ArrayFree(m_delta_buffer); }

   //--- Main calculation: Calculate all RoC statistics for current bar
   bool              Calculate(const double &data[],
                              int index,
                              int size,
                              double &mean_delta_normalized,
                              double &stddev_delta_normalized,
                              double &sum_delta_normalized,
                              double &max_abs_delta_normalized);

   //--- Static methods for individual statistics
   static double     CalculateMeanDelta(const double &deltas[], int size);
   static double     CalculateStdDevDelta(const double &deltas[], int size, double mean);
   static double     CalculateSumDelta(const double &deltas[], int size);
   static double     CalculateMaxAbsDelta(const double &deltas[], int size);

   //--- Getters
   int               ShortWindow() const { return m_short_window; }
   int               LongWindow() const { return m_long_window; }
   double            ThresholdLow() const { return m_threshold_low; }
   double            ThresholdHigh() const { return m_threshold_high; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRateOfChangeStatistics::CRateOfChangeStatistics(int short_window,
                                                 int long_window,
                                                 double threshold_low,
                                                 double threshold_high)
  {
   m_short_window = MathMax(2, short_window);
   m_long_window = MathMax(m_short_window + 1, long_window);
   m_threshold_low = threshold_low;
   m_threshold_high = threshold_high;

   ArrayResize(m_delta_buffer, m_long_window);
   ArrayInitialize(m_delta_buffer, 0.0);
  }

//+------------------------------------------------------------------+
//| Main Calculation Method                                         |
//| Parameters:                                                      |
//|   data  - source histogram values (percentile ranks 0.0-1.0)   |
//|   index - current bar index                                     |
//|   size  - total size of data array                              |
//|   [out] mean_delta_normalized - normalized mean RoC            |
//|   [out] stddev_delta_normalized - normalized std dev RoC       |
//|   [out] sum_delta_normalized - normalized sum RoC              |
//|   [out] max_abs_delta_normalized - normalized max abs RoC      |
//| Returns: true if calculation successful, false if insufficient data |
//| NO LOOK-AHEAD BIAS: Uses only data [0, index-1] for normalization |
//+------------------------------------------------------------------+
bool CRateOfChangeStatistics::Calculate(const double &data[],
                                        int index,
                                        int size,
                                        double &mean_delta_normalized,
                                        double &stddev_delta_normalized,
                                        double &sum_delta_normalized,
                                        double &max_abs_delta_normalized)
  {
   // Initialize outputs
   mean_delta_normalized = EMPTY_VALUE;
   stddev_delta_normalized = EMPTY_VALUE;
   sum_delta_normalized = EMPTY_VALUE;
   max_abs_delta_normalized = EMPTY_VALUE;

   // Check if we have enough data
   // Need: 1 bar for first delta + m_short_window for current stats + m_long_window for historical normalization
   int min_bars_required = m_long_window + m_short_window;
   if(index < min_bars_required)
      return false;

   //--- Step 1: Calculate deltas for historical lookback (NO LOOK-AHEAD)
   //    For bar i, use deltas from bars [i - m_long_window - m_short_window, i-1]
   //    This ensures we only use historical data for normalization

   int historical_start = index - m_long_window - m_short_window + 1;
   int historical_size = m_long_window + m_short_window - 1;

   double historical_deltas[];
   ArrayResize(historical_deltas, historical_size);

   for(int i = 0; i < historical_size; i++)
     {
      int data_idx = historical_start + i;
      if(data_idx >= 0 && data_idx + 1 < size)
        {
         historical_deltas[i] = MathAbs(data[data_idx + 1] - data[data_idx]);
        }
      else
        {
         historical_deltas[i] = 0.0;
        }
     }

   //--- Step 2: Calculate current short-window statistics
   //    Use the MOST RECENT m_short_window deltas from historical data
   double current_deltas[];
   ArrayResize(current_deltas, m_short_window);

   int current_start_idx = historical_size - m_short_window;
   for(int i = 0; i < m_short_window; i++)
     {
      current_deltas[i] = historical_deltas[current_start_idx + i];
     }

   double current_mean = CalculateMeanDelta(current_deltas, m_short_window);
   double current_stddev = CalculateStdDevDelta(current_deltas, m_short_window, current_mean);
   double current_sum = CalculateSumDelta(current_deltas, m_short_window);
   double current_max_abs = CalculateMaxAbsDelta(current_deltas, m_short_window);

   //--- Step 3: Calculate historical statistics for normalization
   //    Use all historical data EXCEPT the current short window (to avoid look-ahead)
   //    Calculate rolling m_short_window statistics across the m_long_window history

   int num_historical_windows = m_long_window - m_short_window + 1;

   double historical_means[];
   double historical_stddevs[];
   double historical_sums[];
   double historical_max_abs[];

   ArrayResize(historical_means, num_historical_windows);
   ArrayResize(historical_stddevs, num_historical_windows);
   ArrayResize(historical_sums, num_historical_windows);
   ArrayResize(historical_max_abs, num_historical_windows);

   for(int w = 0; w < num_historical_windows; w++)
     {
      double window_deltas[];
      ArrayResize(window_deltas, m_short_window);

      for(int i = 0; i < m_short_window; i++)
        {
         window_deltas[i] = historical_deltas[w + i];
        }

      double win_mean = CalculateMeanDelta(window_deltas, m_short_window);
      historical_means[w] = win_mean;
      historical_stddevs[w] = CalculateStdDevDelta(window_deltas, m_short_window, win_mean);
      historical_sums[w] = CalculateSumDelta(window_deltas, m_short_window);
      historical_max_abs[w] = CalculateMaxAbsDelta(window_deltas, m_short_window);
     }

   //--- Step 4: Normalize current statistics against historical distribution
   mean_delta_normalized = CPercentileNormalizer::CalculatePercentileRank(current_mean,
                                                                          historical_means,
                                                                          num_historical_windows);

   stddev_delta_normalized = CPercentileNormalizer::CalculatePercentileRank(current_stddev,
                                                                            historical_stddevs,
                                                                            num_historical_windows);

   sum_delta_normalized = CPercentileNormalizer::CalculatePercentileRank(current_sum,
                                                                         historical_sums,
                                                                         num_historical_windows);

   max_abs_delta_normalized = CPercentileNormalizer::CalculatePercentileRank(current_max_abs,
                                                                             historical_max_abs,
                                                                             num_historical_windows);

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate Mean of Deltas                                        |
//+------------------------------------------------------------------+
static double CRateOfChangeStatistics::CalculateMeanDelta(const double &deltas[], int size)
  {
   double sum = 0.0;
   for(int i = 0; i < size; i++)
      sum += deltas[i];
   return sum / size;
  }

//+------------------------------------------------------------------+
//| Calculate Standard Deviation of Deltas                          |
//+------------------------------------------------------------------+
static double CRateOfChangeStatistics::CalculateStdDevDelta(const double &deltas[],
                                                            int size,
                                                            double mean)
  {
   double variance = 0.0;
   for(int i = 0; i < size; i++)
     {
      double diff = deltas[i] - mean;
      variance += diff * diff;
     }
   return MathSqrt(variance / size);
  }

//+------------------------------------------------------------------+
//| Calculate Sum of Deltas (Net Directional Movement)              |
//+------------------------------------------------------------------+
static double CRateOfChangeStatistics::CalculateSumDelta(const double &deltas[], int size)
  {
   double sum = 0.0;
   for(int i = 0; i < size; i++)
      sum += deltas[i];
   return sum;
  }

//+------------------------------------------------------------------+
//| Calculate Maximum Absolute Delta (Largest Single Jump)          |
//+------------------------------------------------------------------+
static double CRateOfChangeStatistics::CalculateMaxAbsDelta(const double &deltas[], int size)
  {
   double max_abs = 0.0;
   for(int i = 0; i < size; i++)
     {
      double abs_delta = MathAbs(deltas[i]);
      if(abs_delta > max_abs)
         max_abs = abs_delta;
     }
   return max_abs;
  }

#endif // PERCENTILE_NORMALIZER_MQH
//+------------------------------------------------------------------+
