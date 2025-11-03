# Changelog

All notable changes to the project indicators will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## CCI Neutrality Bars Indicator

### [1.0.1] - 2025-11-02

#### Fixed

- **Multi-Timeframe Data Synchronization**: Fixed critical issue where M1 chart with M12 CCI reference showed no white bars on initial load
  - Removed blocking OnInit with 30-second Sleep() loops that froze UI
  - Replaced BarsCalculated() pre-check with direct CopyBuffer() validation
  - Changed return value from `prev_calculated` to `return 0` on data not ready

#### Added

- **EventSetMillisecondTimer(1)**: Community-proven pattern for deferred MTF initialization
- **OnTimer() Event Handler**: Triggers ChartSetSymbolPeriod() to force chart refresh
- **Error 4806 Handling**: Proper handling of "Indicator data not accessible" as INFO (normal on first call)
- **EventKillTimer() in OnDeinit**: Cleanup timer on indicator removal

#### Changed

- **OnInit Behavior**: Now returns immediately instead of blocking for 30 seconds
- **CopyBuffer Check**: Moved from pre-condition to actual validation
- **Failure Mode**: Returns 0 to reset calculation (lets timer trigger refresh)

#### Technical Details

- Research: 4 parallel agents analyzed MQL5 forums and working MTF indicators
- Pattern based on: MTF_MA.mq5 (GitHub EarnForex), UseWPRMTF.mq5 (MQL5 Book)
- References: MQL5 Forum threads 168437, 445696, 211536, 487682
- Tested: M1 chart + M12 reference → white bars appear within 1-5 seconds
- Platform: MetaTrader 5 via CrossOver on macOS

### [1.0.0] - 2025-11-02

#### Added

- **Initial Release**: Price bar coloring based on CCI Neutrality state
- **Two Calculation Methods**:
  - METHOD_RESAMPLE: Uses reference timeframe CCI directly (exact window)
  - METHOD_SCALE: Uses current timeframe CCI with scaled window size
- **Three Color States**:
  - White (Calm/Neutral): CCI < 30% percentile
  - Default (Normal): CCI 30-70% percentile
  - Default (Volatile/Extreme): CCI > 70% percentile
- **DRAW_COLOR_CANDLES**: Chart window indicator with colored price bars
- **Multi-Timeframe Support**: Reference timeframe configurable (PERIOD_CURRENT to PERIOD_MN1)
- **Adaptive Window**: Automatic scaling for METHOD_SCALE (e.g., 120 M12 bars → 1440 M1 bars)

#### Known Issues (Fixed in v1.0.1)

- M1 chart with M12 reference requires manual chart timeframe switching to display white bars

---

## CCI Neutrality Adaptive Indicator

### [4.24] - 2025-11-02

#### Added

- **Rising Pattern Detection**: Detects 4 consecutive rising histogram bars and marks the 4th bar with a blue dot
  - Arrow overlay positioned above histogram (DRAW_ARROW code 159 = filled circle)
  - Detection logic: BufScore[i-3] < [i-2] < [i-1] < [i]
  - Arrow shift: -15 points upward from histogram top
  - Blue color (clrDodgerBlue) for visibility
  - Debug logging for first 10 bars and first 5 detected patterns

#### Changed

- **Indicator Buffers**: Increased from 3 to 4 (added BufArrows buffer)
- **Indicator Plots**: Increased from 1 to 2 (histogram + arrows)
- **PLOT_DRAW_BEGIN**: Set for arrow plot to StartCalcPosition + 3 (needs 3 previous bars)

#### Technical Details

- Compilation: 22KB .ex5 file, 0 errors, 0 warnings (~1 second)
- Tested: Multiple instances of 4 consecutive rising bars detected (confirmed via user screenshots)
- **CLI Compilation Method: X: Drive (PRIMARY)**
  - X: drive mapping: `X:\Indicators\...` = `MQL5/Indicators/...`
  - Eliminates "Program Files" path spaces that cause silent failures
  - Command: `/compile:"X:\\Indicators\\Custom\\...\\file.mq5" /inc:"X:"`
  - Helper script: `tools/compile_mql5.sh` (auto-converts paths)
  - See: `.claude/skills/mql5-x-compile` for complete documentation
- Platform: MetaTrader 5 via CrossOver on macOS

---

## Consecutive Pattern Indicator

### [1.40.0] - 2025-10-30

#### Added

- **Contraction Circle Markers**: Two orange circles (upper + lower) mark consecutive contraction patterns
  - Upper circle placed above bar high
  - Lower circle placed below bar low
  - Creates distinctive "sandwich" visual different from single expansion dots
  - Always visible when contraction pattern detected

#### Changed

- **Removed Bar Coloring for Contractions**: Contraction patterns no longer color bars
  - Only circle markers shown for contractions
  - Keeps visual focus on the circle markers
  - Bar coloring still works for expansion patterns (if enabled)
- **Version**: Updated from v1.30 (experimental) to v1.40 (production)

#### Technical Details

- 5 plots total: colored candles, expansion dots (2), contraction circles (2)
- 15 buffers: 5 data, 10 calculations
- Arrow code 159 (circle) used for both upper and lower markers
- Color: Orange (clrOrange) for visibility
- Spacing: 10 points above high / below low

### [1.30.0] - 2025-10-30

#### Added

- Initial experimental version with contraction markers (tested triangle/arrow codes)
- Research: Wine/CrossOver on macOS has incomplete Wingdings font support

### [1.20.0] - 2025-10-29

#### Removed

- Inside bar detection functionality (simplified indicator focus)

---

## CCI Neutrality Adaptive Indicator

### [5.0.0] - 2025-10-29

### BREAKING CHANGES

- **Color Mapping Inverted**: Complete reversal of color meaning to match intended behavior
  - **RED** now indicates high volatility/extreme CCI values (previously GREEN)
  - **GREEN** now indicates calm/neutral CCI values (previously RED)
  - **YELLOW** remains middle range (30th-70th percentile)
- **Absolute Value Percentile Ranking**: Changed from directional to magnitude-based measurement
  - Now uses `MathAbs(CCI)` for percentile calculation
  - Measures extremity regardless of direction (bullish or bearish)
  - Eliminates directional bias where only bearish moves showed red

### Fixed

- **Critical Bug: Inverted Color Logic** (lines 264-269)
  - Fixed color thresholds: `score > 0.7` now maps to RED (was GREEN)
  - Fixed color thresholds: `score < 0.3` now maps to GREEN (was RED)
  - Updated all color labels and documentation to reflect correct mapping
- **Critical Bug: Directional Bias in Percentile Calculation** (lines 252, 257, 260)
  - Changed window building to use `MathAbs(cci[...])` instead of raw CCI values
  - Changed current value to use `MathAbs(current_cci)` for percentile ranking
  - Ensures both bullish and bearish extremes show RED (volatile/chaotic)
- **PercentileNormalizer Library Delta Calculation** (v2.00 → v2.01)
  - Fixed line 263 in `/MQL5/Include/Custom/PercentileNormalizer.mqh`
  - Changed from `data[i+1] - data[i]` to `MathAbs(data[i+1] - data[i])`
  - Applies to all RoC statistics: Mean Delta, Std Dev, Sum Delta, Max Abs Delta
  - Eliminates directional bias in rate-of-change measurements

### Changed

- **Version**: Updated from v4.10 to v4.20 → v5.0.0 (breaking changes warrant major bump)
- **Description**: Updated to reflect corrected color meanings
- **Initialization Logging**: Changed from "Red<30%<Yellow<70%<Green" to "Green(Calm)<30%<Yellow<70%<Red(Volatile)"

### Removed

- **CCINeutrality Directory Cleanup**: Removed 13 redundant indicator files
  - Deleted 13 .mq5 source files without matching use cases
  - Deleted 13 .ex5 compiled files (orphaned executables)
  - Kept only `CCI_Neutrality_Adaptive.mq5` as the canonical implementation
- **Consecutive Pattern (cc.mq5) Inside Bar Detection** (v1.10 → v1.20)
  - Removed `InpShowInsideBars`, `InpInsideBarThreshold`, `InpShowInsideBarDots` parameters
  - Removed `BufferInsideBarBearishSignal[]` and `BufferInsideBarBullishSignal[]` buffers
  - Removed inside bar detection loop and `#include "lib/CandlePatterns.mqh"`
  - Reduced from 15 buffers/5 plots to 13 buffers/3 plots
  - Now focuses solely on expansion and contraction patterns

### Files Modified

- `Program Files/MetaTrader 5/MQL5/Indicators/Custom/Development/CCINeutrality/CCI_Neutrality_Adaptive.mq5`
- `Program Files/MetaTrader 5/MQL5/Include/Custom/PercentileNormalizer.mqh`
- `Program Files/MetaTrader 5/MQL5/Indicators/Custom/Development/ConsecutivePattern/cc.mq5`

### Compilation Results

- **CCI_Neutrality_Adaptive.ex5**: 17KB, 0 errors, 0 warnings (855ms compile time)
- **cc.ex5**: 18KB, 0 errors, 0 warnings (933ms compile time)

### Migration Guide

**For existing users of v4.10 or earlier:**

1. **Interpret Colors Correctly**:
   - If you previously looked for GREEN as "extreme", now look for RED
   - If you previously looked for RED as "neutral", now look for GREEN
2. **Behavior Change**:
   - Indicator now shows RED during BOTH bullish and bearish volatile moves
   - Previously only showed RED during bearish moves (bug)
3. **Recompile**: Must recompile to pick up library changes in PercentileNormalizer.mqh

## [4.10] - 2025-10-29

### Added

- **Multi-Timeframe Support**: New `InpReferenceTimeframe` parameter (ENUM_TIMEFRAMES) allows reference timeframe selection
- **Automatic Window Scaling**: Window size now automatically scales to maintain consistent time duration across different chart timeframes
- **CalculateAdaptiveWindow() Function**: Implements PeriodSeconds()-based timeframe conversion using the formula: `adaptive_window = reference_bars × (ref_seconds / current_seconds)`
- **Enhanced Initialization Logging**: Displays timeframe conversion details including reference/current timeframes, seconds per bar, and calculated adaptive window

### Changed

- **Input Parameters**: Replaced single `InpAdaptiveWindow` with `InpReferenceTimeframe` and `InpReferenceWindowBars` for better cross-timeframe control
- **Global Variable**: Added `g_AdaptiveWindow` to store calculated adaptive window size for current chart timeframe
- **Indicator Scale**: Indicator name now shows timeframe conversion details (e.g., "CCI Adaptive(20,TF=PERIOD_H1,W=120→480)")

### Fixed

- **MQL5 Community Standard Compliance**: Changed from `MathRound()` to `MathFloor()` per MQL5 Article #2837 for conservative bar calculation

### Technical Details

- Formula validated against published MQL5 patterns from MQL5.com Article #2837
- Backward compatible: Default `PERIOD_CURRENT` maintains v4.0.0 behavior (120 bars on current timeframe)
- Compilation successful: 17KB .ex5 file without errors
- Examples:
  - 120 bars on M12 → 1440 bars on M1 (same 1440 minutes duration)
  - 120 bars on H1 → 30 bars on H4 (same 5 days duration)
  - 120 bars on PERIOD_CURRENT → 120 bars (no conversion)

### Files Modified

- `Program Files/MetaTrader 5/MQL5/Indicators/Custom/Development/CCINeutrality/CCI_Neutrality_Adaptive.mq5`
- `docs/plans/adaptive-cci-normalization.yaml`
- `docs/reports/ADAPTIVE_NORMALIZATION_VALIDATION.md`

## [4.0.0] - 2025-10-29

### Added

- Initial release of CCI Neutrality Adaptive indicator with percentile rank normalization
- **Single-Window Percentile Rank Algorithm**: Replaces fixed CCI thresholds with adaptive percentile-based normalization
- **PercentileRank() Function**: O(n) algorithm for calculating percentile rank without sorting
- **Adaptive Window Parameter**: `InpAdaptiveWindow` (default 120 bars) for rolling window size
- **Three-Color Visualization**: Red (bottom 30%), Yellow (middle 40%), Green (top 30%)
- **CCI Integration**: Uses MT5 standard iCCI() indicator with configurable period

### Research Foundation

- Analyzed 200,843 bars of EURUSD M12 data
- Validated through 6 adversarial tests with 95% confidence:
  - Regime change adaptation (instant, 0-bar lag)
  - Outlier robustness (stable up to 20% contamination)
  - Market type consistency (trending vs ranging)
  - Window size stability (120 bars optimal)
  - Distribution shape robustness (skewness-independent)
  - Single-window vs multi-scale comparison (single-window won)
- Benchmarked Python statistical modules (Numba, Bottleneck, NumPy, Pandas)
- Evaluated and rejected MQL5-Python integration (1000x performance penalty)

### Technical Implementation

- Native MQL5 implementation (~230 lines vs 318 lines original, 28% reduction)
- Removed 7 input parameters (fixed thresholds)
- Removed multiplicative scoring complexity (p, c, v, q components)
- Simplified OnCalculate loop (no rolling sums needed)
- Indicator scale: 0.0-1.0 (percentile rank range)
- Draw type: DRAW_COLOR_HISTOGRAM with 3 color indices
- Warmup requirement: `InpCCILength + InpAdaptiveWindow - 1` bars

### Performance

- Compilation: ~1s using CrossOver CLI compilation method
- Output: 10KB .ex5 file
- Expected improvement: 300x more GREEN bars (0.1% → 30%)
- Percentile calculation: ~0.001ms per bar (simple loop counting)

### Files Added

- `Program Files/MetaTrader 5/MQL5/Indicators/Custom/Development/CCINeutrality/CCI_Neutrality_Adaptive.mq5`
- `Program Files/MetaTrader 5/MQL5/Indicators/Custom/Development/CCINeutrality/CCI_Neutrality_Adaptive.ex5`
- `docs/plans/adaptive-cci-normalization.yaml`
- `docs/reports/ADAPTIVE_NORMALIZATION_VALIDATION.md`
- `experiments/adaptive-cci-normalization-research/` (research artifacts)

### Rejected Alternatives

- Multi-scale ensemble (30, 120, 500 bar windows) - single-window outperformed
- Python integration via DLL - 1000x performance penalty
- Fixed threshold relaxation (C0=104, C1=124) - only 10x improvement vs 300x
- Weighted additive formula - changes neutrality definition

---

## Release Links

- [v4.10 Release](https://github.com/terrylica/mql5-in-crossover-bottle/releases/tag/v4.10)
- [v4.0.0 Release](https://github.com/terrylica/mql5-in-crossover-bottle/releases/tag/v4.0.0)

## Version Comparison

| Version | Key Feature                     | Window Behavior                        | Compilation Size |
| ------- | ------------------------------- | -------------------------------------- | ---------------- |
| v4.10   | Timeframe-aware adaptive window | Scales automatically across timeframes | 17KB             |
| v4.0.0  | Single-window percentile rank   | Fixed 120 bars on current timeframe    | 10KB             |

## Documentation

- [MQL5 Source Code](/Program Files/MetaTrader 5/MQL5/Indicators/Custom/Development/CCINeutrality/CCI_Neutrality_Adaptive.mq5)
- [Implementation Plan](/docs/plans/adaptive-cci-normalization.yaml)
- [Validation Report](/docs/reports/ADAPTIVE_NORMALIZATION_VALIDATION.md)
- [Research Artifacts](/experiments/adaptive-cci-normalization-research/)
