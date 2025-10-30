# Adaptive Multi-Scale Distribution Normalization

**Version**: 2.0.0 (Data-Driven Recalibration)
**Date**: 2025-10-29
**Analysis**: 200,843 bars of EURUSD M12

---

## 📊 Executive Summary

**Problem**: Fixed thresholds (C0=50, C1=50, [-100,+100]) don't match actual market distribution

- Current thresholds capture only 59% of data (should be 75%)
- Result: 99.9% RED bars, 0.1% GREEN bars (insufficient signal)

**Solution**: Adaptive multi-scale percentile-based normalization

- Adjusts to changing market regimes automatically
- Provides consistent signal frequency across different volatility periods
- More robust to outliers and regime shifts

---

## 🔬 Empirical Findings from 200k Bars

### Raw CCI Distribution

```
Mean:           2.47
Std Dev:        114.05
Range:          [-664, +602]
IQR:            170.39 (Q1=-82, Q3=+88)

Current [-100, +100]:   59.2% coverage (should be 75%)
Suggested [-131, +131]: 75% coverage (P12.5-P87.5)
Actual [-150, +150]:    82.5% coverage (P10-P90)
```

### Rolling Window Analysis

| Window Size | Time Horizon | Avg IQR | Adaptive Bounds | Use Case |
| --- | --- | --- | --- | --- |
| 30 bars | 6 hours | 198 | [-196, +201] | Recent regime |
| 120 bars | 1 day | 256 | [-254, +259] | Daily cycle |
| 500 bars | 4 days | 297 | [-292, +301] | Weekly trend |
| 1440 bars | 12 days | 337 | [-332, +343] | Long-term baseline |

---

## 🎯 Proposed Architecture: Multi-Scale Adaptive Scoring

### Method 1: Percentile Rank (Recommended)

**Concept**: Score = percentile rank of current value within rolling window

**Advantages**:

- ✅ Bounded [0, 1] range (no outlier sensitivity)
- ✅ Automatically normalizes to local distribution
- ✅ Consistent spike frequency across regimes
- ✅ Robust to fat tails and non-normal distributions

**Implementation**:

```mql5
// Calculate percentile rank efficiently using sorted window
double PercentileRank(double value, double &window[], int size) {
    int count_below = 0;
    for(int i = 0; i < size; i++) {
        if(window[i] < value) count_below++;
    }
    return (double)count_below / size;
}

// Multi-scale ensemble
double score_short = PercentileRank(current_cci, window_30);
double score_med   = PercentileRank(current_cci, window_120);
double score_long  = PercentileRank(current_cci, window_500);

// Weighted average (favor recent)
double score = 0.5*score_short + 0.3*score_med + 0.2*score_long;

// Interpretation:
// score < 0.3  → RED (low neutral, CCI in bottom 30%)
// 0.3-0.7      → YELLOW (medium neutral)
// score > 0.7  → GREEN (high neutral, CCI in top 30%)
```

**Expected Results**:

- ~30% RED, ~40% YELLOW, ~30% GREEN (balanced distribution)
- Spikes increase from 0.1% to ~30%

---

### Method 2: Adaptive IQR Channel

**Concept**: Define "neutral" as distance from rolling median, normalized by IQR

**Advantages**:

- ✅ Robust to outliers (median + IQR)
- ✅ Clear statistical interpretation
- ✅ Adapts to volatility regime

**Implementation**:

```mql5
// Calculate rolling statistics
double rolling_median = CalculateMedian(cci_window, 120);
double rolling_Q1 = CalculatePercentile(cci_window, 120, 0.25);
double rolling_Q3 = CalculatePercentile(cci_window, 120, 0.75);
double rolling_IQR = rolling_Q3 - rolling_Q1;

// Distance from median, normalized by IQR
double normalized_distance = MathAbs(current_cci - rolling_median) / rolling_IQR;

// Score based on proximity to median
double score;
if(normalized_distance < 0.5)      score = 1.0;  // Within 0.5 IQR
else if(normalized_distance < 1.0) score = 0.5;  // Within 1.0 IQR
else                               score = 0.0;  // Beyond 1.0 IQR

// Color mapping
if(score > 0.7) color = GREEN;      // High neutral
else if(score > 0.3) color = YELLOW; // Medium
else color = RED;                    // Low neutral
```

**Expected Results**:

- ~40% GREEN (within 0.5 IQR)
- ~30% YELLOW (0.5-1.0 IQR)
- ~30% RED (beyond 1.0 IQR)

---

### Method 3: Z-Score with Adaptive Thresholds

**Concept**: Standardize CCI relative to rolling mean/stdev

**Advantages**:

- ✅ Classic statistical approach
- ✅ Easy interpretation (std devs from mean)
- ✅ Well-studied properties

**Implementation**:

```mql5
// Calculate rolling statistics
double rolling_mean = CalculateMean(cci_window, 120);
double rolling_stdev = CalculateStdev(cci_window, 120);

// Z-score
double z_score = (current_cci - rolling_mean) / rolling_stdev;

// Adaptive score (sigmoid to [0,1])
double score = 1.0 / (1.0 + MathAbs(z_score));

// Interpretation:
// z_score ≈ 0   → score ≈ 1.0 (highly neutral)
// z_score = ±1  → score ≈ 0.5 (1 stdev away)
// z_score = ±2  → score ≈ 0.33 (2 stdevs away)
```

---

## 🏗️ Implementation Roadmap

### Phase 1: Single-Window Percentile Rank (Quick Win)

**Complexity**: Low
**Expected Improvement**: 300x more spikes (0.1% → 30%)

```mql5
// Add to indicator inputs
input int InpAdaptiveWindow = 120;  // Adaptive normalization window

// In OnCalculate, maintain rolling window of CCI values
static double rolling_cci_window[];
ArrayResize(rolling_cci_window, InpAdaptiveWindow);

// Calculate percentile rank
double percentile_rank = PercentileRank(current_cci, rolling_cci_window, InpAdaptiveWindow);

// Simple threshold
if(percentile_rank > 0.6) color = GREEN;
else if(percentile_rank > 0.4) color = YELLOW;
else color = RED;
```

**Test First**: Change existing thresholds to adaptive ones, compare results

---

### Phase 2: Multi-Scale Ensemble (Robust)

**Complexity**: Medium
**Expected Improvement**: More robust across regimes

```mql5
// Maintain 3 rolling windows
static double window_short[30];
static double window_med[120];
static double window_long[500];

// Calculate percentile ranks at each scale
double pr_short = PercentileRank(current_cci, window_short, 30);
double pr_med   = PercentileRank(current_cci, window_med, 120);
double pr_long  = PercentileRank(current_cci, window_long, 500);

// Weighted ensemble (favor recent)
double score = 0.5*pr_short + 0.3*pr_med + 0.2*pr_long;
```

---

### Phase 3: Full Adaptive System (Production)

**Complexity**: High
**Expected Improvement**: Optimal robustness

**Features**:

- Adaptive window sizing based on volatility regime detection
- Regime-specific thresholds (trending vs ranging)
- Outlier detection and handling
- Dynamic weight adjustment

---

## 📈 Comparison: Fixed vs Adaptive

| Approach | Channel Bounds | Score Distribution | Spike Frequency | Regime Robustness |
| --- | --- | --- | --- | --- |
| **Current** | Fixed [-100,+100] | 99.9% RED, 0.1% GREEN | 0.1% | ❌ Poor |
| **Fixed Recalibrated** | Fixed [-150,+150] | ~90% RED, ~10% GREEN | ~10% | ⚠️ Better |
| **Adaptive Percentile** | Adaptive (P10-P90) | 30% RED, 40% YELLOW, 30% GREEN | ~30% | ✅ Excellent |
| **Multi-Scale Ensemble** | Multi-window adaptive | 30% RED, 40% YELLOW, 30% GREEN | ~30% | ✅✅ Best |

---

## 🎓 Statistical Justification

### Why Percentile Rank?

1. **Distribution-Free**: Works with any distribution (normal, skewed, fat-tailed)
2. **Bounded**: Always [0, 1], no overflow issues
3. **Interpretable**: Direct probability interpretation
4. **Stable**: Less sensitive to outliers than mean/stdev
5. **Consistent**: Maintains target spike frequency across regimes

### Why Multi-Scale?

1. **Noise Reduction**: Short-term captures recent moves, long-term filters noise
2. **Regime Adaptation**: Different scales excel in different market conditions
3. **Robustness**: Ensemble averages away individual window biases
4. **Predictive**: Combination of timeframes captures market structure

---

## 🔬 Validation Plan

### Metrics to Track:

1. **Spike Frequency**: Should be ~30% GREEN (vs current 0.1%)
2. **False Positive Rate**: Measure using forward-looking price action
3. **Regime Stability**: Track score volatility across different market periods
4. **Threshold Sensitivity**: Test different percentile cutoffs

### Backtesting Strategy:

1. Generate scores for full 200k bar dataset
2. Compare spike frequency: fixed vs adaptive
3. Measure regime adaptation: trending vs ranging periods
4. Validate statistical properties: mean, variance, autocorrelation

---

## 💡 Recommendation

**Start with Phase 1 (Percentile Rank, single window=120)**:

- Easiest to implement (20 lines of code)
- Immediate 300x improvement in spike frequency
- Can revert quickly if issues arise
- Validates the adaptive approach

**Then upgrade to Phase 2 (Multi-Scale)**:

- More robust
- Better regime adaptation
- Production-ready

**Key Insight**: The problem isn't the formula (multiplicative vs additive). The problem is **fixed thresholds don't match your market's distribution**. Adaptive normalization solves this fundamentally.
