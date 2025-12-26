## [2.0.1](https://github.com/terrylica/mql5-crossover/compare/v2.0.0...v2.0.1) (2025-12-26)


### Bug Fixes

* add lychee config and fix broken anchor link ([5043ab5](https://github.com/terrylica/mql5-crossover/commit/5043ab5c64985b58429e62bffcd38b6e770a9a90)), closes [#quick-start](https://github.com/terrylica/mql5-crossover/issues/quick-start) [#-quick-start](https://github.com/terrylica/mql5-crossover/issues/-quick-start)

# [2.0.0](https://github.com/terrylica/mql5-crossover/compare/v1.0.1...v2.0.0) (2025-12-25)


### Bug Fixes

* correct color mapping to match CCI_Neutrality_Adaptive v5.0.0 (v0.2.1) ([ecb1d3d](https://github.com/terrylica/mql5-crossover/commit/ecb1d3d6e29f7f6ede30c514b419685e23e8b523))
* **release:** add feature branch to semantic-release branches config ([038188f](https://github.com/terrylica/mql5-crossover/commit/038188fd96e171e74242f930437f58f6d27b6e21))
* **semantic-release:** revert repository URL to HTTPS (SSH not configured) ([c2d6d8a](https://github.com/terrylica/mql5-crossover/commit/c2d6d8a5dbd275a1d5a3f40bf0c1e9c7882420f4))


### Features

* add rising pattern arrow detection to CCI Neutrality Adaptive (v4.24) ([43f2033](https://github.com/terrylica/mql5-crossover/commit/43f2033c749fb3ca1ab626cf06f75c82de55086e))
* **CCI_Neutrality_Adaptive:** Add arrow markers for 4 consecutive rising bars (v4.22) ([568aca0](https://github.com/terrylica/mql5-crossover/commit/568aca05a707ada8d05cf82093ce2209e2ac708e))
* **CCI_Neutrality_Adaptive:** Add METHOD_RESAMPLE + MTF sync (v4.21) ([e1427fa](https://github.com/terrylica/mql5-crossover/commit/e1427fa3aac5260fd65cb19c761928f0efadf6cd))
* **cci-rising:** implement arrow placement (v0.7.0) ([52e0a04](https://github.com/terrylica/mql5-crossover/commit/52e0a04fc12070210d6c817d58691488e4f34403))
* enhance arrow visibility for rising pattern detection (v4.25) ([cc2ccfd](https://github.com/terrylica/mql5-crossover/commit/cc2ccfd146b31c1cd58c46b82dc2c783bf36a87f))
* Phase 1 - baseline histogram (v0.2.0) ([77cfaec](https://github.com/terrylica/mql5-crossover/commit/77cfaecadde70692b62e51d73023a656c62a4e4d))


### BREAKING CHANGES

* **cci-rising:** Phase numbering changed in plan file. Original Phase 6 Recalculation Test is now Phase 7 (v0.8.0), Original Phase 7 Production is now Phase 8 (v1.0.0) due to v0.4.0 Native CCI insertion.

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

## CCI Rising Pattern Marker

### [0.2.2] - 2025-11-03

#### Added

- **Library Architecture** - Extracted logic into .mqh libraries for separation of concerns
  - lib/PatternDetector.mqh: DetectRisingPattern(), GetDetectionDetails(), pure functions
  - lib/ArrowManager.mqh: CreateArrow(), DeleteArrow(), DeleteAllArrows(), CountArrows()
  - lib/CSVLogger.mqh: CSVLogger class (Open/WriteHeader/WriteDetectionRow/Close)
  - Unit test scripts: Test_PatternDetector.mq5 (12 tests), Test_ArrowManager.mq5 (12 tests)
  - Commented library includes in CCI_Rising_Test.mq5 (ready for Phase 2+)

#### Changed

- Version: 0.2.1 → 0.2.2
- Libraries not yet used in Phase 1 (histogram only), will be used in Phase 2+ (arrows/detection)

#### Technical Details

- PatternDetector: Testable detection logic, DetectionDetails struct for debugging
- ArrowManager: Window-aware arrow creation, time-based naming, bulk cleanup
- CSVLogger: Class-based API, file handle management, structured logging
- Plan file: Added Phase 1.5 (library extraction), x-implementation-findings entry
- Compilation: 9.2KB .ex5, 0 errors, 0 warnings

#### SLOs (Phase 1.5)

- Availability: 100% (all libraries compile without errors)
- Correctness: Pending (unit tests not yet validated by user)
- Maintainability: 100% (libraries testable in isolation, clear interfaces)

#### Rationale

User requested maximum separation of concerns for incremental testing and problem isolation

#### CSV vs SQLite Decision

- CSV chosen for Phase 2-7 (Claude Code CLI integration, debugging simplicity)
- SQLite available if needed for future analysis (>100k bars, complex queries)
- MQL5 native SQLite support confirmed, DuckDB not supported

### [0.2.1] - 2025-11-02

#### Fixed

- **Color Mapping Inverted** - Colors did not align with existing CCI_Neutrality_Adaptive indicator
  - HIGH score (>0.7) now maps to RED (volatile/extreme) - was GREEN
  - LOW score (<0.3) now maps to GREEN (calm/neutral) - was RED
  - Middle (0.3-0.7) remains YELLOW
  - Now matches CCI_Neutrality_Adaptive v5.0.0 logic exactly

#### Technical Details

- Lines 147-156: Color index assignment logic corrected
- Compilation: 9.6KB .ex5 file, 0 errors, 0 warnings (~1 second via X: drive)

### [0.2.0] - 2025-11-02

#### Added

- **Phase 1: Baseline Histogram** - Minimal CCI neutrality histogram for rising pattern detection
  - M1 timeframe only (no MTF complexity)
  - 120-bar adaptive window normalization
  - RED/YELLOW/GREEN color mapping (0-1 range)
  - 5x canvas height (0-5 scale) for future arrows
  - NO arrow code yet
  - NO CSV logging yet
  - Clean implementation starting from scratch

#### Technical Details

- File: `CCI_Rising_Test.mq5`
- Calculation method: Percentile rank normalization within 120-bar rolling window
- Color thresholds: RED < 0.3, YELLOW 0.3-0.7, GREEN > 0.7
- Canvas range: 0.0-5.0 (histogram occupies bottom 20%)
- Compilation: 9.1KB .ex5 file, 0 errors, 0 warnings (~1 second via X: drive)
- Platform: MetaTrader 5 via CrossOver on macOS

#### SLOs

- Correctness: 100% (histogram displays correctly)
- Observability: 100% (init message confirms v0.2.0)

#### Success Gate

User verifies RED/YELLOW/GREEN bars visible, Y-axis shows 0-5 range

#### Implementation Plan

OpenAPI 3.1.0 specification: `docs/plans/cci-rising-pattern-marker.yaml`

**7-Phase Ultra-Incremental Plan**:

- Phase 0 (v0.1.0): Nuclear cleanup - manual GUI object deletion ✅
- Phase 1 (v0.2.0): Baseline histogram ✅
- Phase 2 (v0.3.0): Single hard-coded arrow test (pending)
- Phase 3 (v0.4.0): Detection logic + logging (pending)
- Phase 4 (v0.5.0): CSV audit validation (pending)
- Phase 5 (v0.6.0): Connect arrows to detection (pending)
- Phase 6 (v0.7.0): Recalculation stress test (pending)
- Phase 7 (v1.0.0): Production release (pending)

---

## CCI Neutrality Adaptive Indicator

### [4.36] - 2025-11-02

#### Fixed

- **CRITICAL: Objects Persist After Indicator Removal** - Added aggressive cleanup in OnInit
  - **Issue**: User reloaded MT5 but incorrect markers still visible (e.g., 2025.11.03 04:57)
  - **Root Cause**: Objects created by previous indicator instances persist on chart
  - **Solution**: Delete ALL RisingArrow\_\* objects IMMEDIATELY in OnInit (before anything else)
  - **Verification**: Logs how many objects were cleaned up
  - **Now runs**: Every time indicator is added/reloaded, not just on first calculation

#### Technical Details

- Lines 210-224: Aggressive cleanup at start of OnInit
- Cleanup count logged to verify objects are being deleted
- Runs before timer, before CCI handle creation, before everything
- CSV proof: Bar 04:57 has Check2=FALSE, Check3=FALSE, MarkerPlaced=NO
- Compilation: 26KB .ex5 file, 0 errors, 0 warnings (~1 second via X: drive)

### [4.35] - 2025-11-02

#### Fixed

- **Leftover Objects Bug** - Markers from previous calculations not cleaned up properly
  - **Issue**: User reported marker showing at 2025.11.03 04:57 where CSV shows MarkerPlaced=NO
  - **Root Cause 1**: Object names included bar index, causing duplicates after bar shifts
  - **Root Cause 2**: No cleanup of old objects on full recalculation
  - **Solution 1**: Object name now uses ONLY time with seconds: `"RisingArrow_2025.11.03 04:57:00"`
  - **Solution 2**: Delete ALL RisingArrow\_\* objects when `prev_calculated == 0`
  - **Benefit**: Unique name per time prevents duplicates, cleanup prevents leftovers

#### Technical Details

- Line 564: `TimeToString(time[i], TIME_DATE|TIME_SECONDS)` for unique object names
- Lines 377-386: Object cleanup loop in OnCalculate when prev_calculated == 0
- CSV verification: Bar 04:57 shows Check2=FALSE, Check3=FALSE (drops 0.466→0.050→0.016)
- Compilation: 26KB .ex5 file, 0 errors, 0 warnings (~1 second via X: drive)

### [4.34] - 2025-11-02

#### Fixed

- **FOOLPROOF METHOD: Graphical Objects Instead of DRAW_ARROW** - Markers now use ObjectCreate
  - **Research Finding**: MQL5 forums and documentation reveal DRAW_ARROW in separate windows is UNRELIABLE
  - **Solution**: Use graphical objects (OBJ_ARROW) with explicit window number instead of buffer plots
  - **Method**: `ObjectCreate(0, name, OBJ_ARROW, window_num, time[i], 1.1)`
  - **Benefits**:
    - Direct placement at exact time and Y coordinate
    - Window-specific rendering (not dependent on buffer system)
    - Proven method from MQL5 community for separate window markers
  - **Cleanup**: OnDeinit now deletes all RisingArrow\_\* objects

#### Research Sources

- MQL5 Documentation: "DRAW_ARROW can be used in a separate subwindow"
- Forum consensus: Use ObjectCreate with window index for reliability in separate windows
- Key insight: Buffer plots can fail to render in separate windows, graphical objects are foolproof

#### Technical Details

- Lines 539-557: ObjectCreate with window_num from ChartWindowFind()
- Lines 270-279: Object cleanup loop in OnDeinit
- Arrow properties: Code 108 (bullet), Yellow, Width 3, Foreground
- Compilation: 26KB .ex5 file, 0 errors, 0 warnings (~1 second via X: drive)

### [4.33] - 2025-11-02

#### Fixed

- **CRITICAL: Bar Shift Bug** - Markers appeared on wrong bars after history changes
  - **Root Cause**: Bar indexes shift when MT5 history updates, but markers only calculated on new bars
  - **Evidence**: CSV showed bar 93110 at 19:39, then later bar 93109 at 19:39 (index shifted by 1)
  - **Result**: Marker placed at index 93110 (time 19:39) ended up showing at wrong time after shift
  - **Solution**: Force full recalculation from StartCalcPosition on every OnCalculate call
  - This ensures markers stay with correct TIME even when bar indexes change

#### Technical Details

- Changed line 377-380: Always start from `StartCalcPosition_Chart` (not `prev_calculated - 1`)
- Trade-off: Slightly more CPU per update, but guarantees correctness
- CSV audit proved: Logic was correct, but display was shifted due to incremental calculation
- User reported: "2025.10.13 19:39 should have marker but doesn't" - CSV showed YES at shifted index
- Compilation: 24KB .ex5 file, 0 errors, 0 warnings (~1 second via X: drive)

### [4.32] - 2025-11-02

#### Changed

- **CSV Logging Enhanced**: Now logs EVERY bar (not just detected patterns)
  - File: `MQL5/Files/rising_pattern_audit_ALL.csv` (new filename)
  - Shows bars WITH markers: MarkerPlaced=YES, ArrowValue=1.1
  - Shows bars WITHOUT markers: MarkerPlaced=NO, ArrowValue=EMPTY
  - Can identify which visually-rising bars are missing markers and WHY
  - All 4 bar values and 3 check results visible for every bar

#### Purpose

- User correctly identified the issue: v4.31 only logged detected patterns
- Without logging non-marker bars, cannot diagnose why visually-rising bars have no markers
- Complete audit trail enables proper debugging

#### Technical Details

- Moved CSV open to first bar (not first detection)
- Write operation inside main loop (logs all bars i >= 3)
- Added columns: "MarkerPlaced" (YES/NO), "ArrowValue" (1.1/EMPTY)
- File will be larger but complete
- Compilation: 24KB .ex5 file, 0 errors, 0 warnings (~1 second via X: drive)

### [4.31] - 2025-11-02

#### Added

- **CSV Audit Logging**: Every detected rising pattern now logged to CSV for verification
  - File: `MQL5/Files/rising_pattern_audit.csv`
  - Columns: BarIndex, Time, Bar[i-3], Bar[i-2], Bar[i-1], Bar[i], Check1, Check2, Check3, PatternDetected
  - Shows actual bar values and comparison results for each marker
  - Enables verification that conditions are truly met
  - File auto-closes on indicator removal

#### Purpose

- User reported many markers appear where conditions shouldn't be met
- CSV audit trail will prove whether logic is correct or values are unexpected
- Can examine actual bar values vs visual appearance on chart

#### Technical Details

- Global variable: `g_csv_handle` (file handle)
- Opens on first pattern detection, writes header
- Each detection writes data row with 6-decimal precision
- `FileFlush()` after each write for immediate examination
- Cleaned up in `OnDeinit()` with file close
- Compilation: 23KB .ex5 file, 0 errors, 0 warnings (~1 second via X: drive)

### [4.30] - 2025-11-02

#### Fixed

- **Wrong Marker Shape**: Arrow code 217 rendered as triangle instead of circle in Wine/CrossOver
  - Changed to arrow code 108 (bullet/large dot)
  - More reliable across platforms
  - Maintains high visibility with yellow color and width 5

#### Technical Details

- Line 144: `PlotIndexSetInteger(1, PLOT_ARROW, 108);` (was 217)
- Arrow code 108 = bullet/large dot (platform-independent)
- Arrow code 217 = platform-dependent rendering (triangle on Wine/CrossOver)
- Compilation: 24KB .ex5 file, 0 errors, 0 warnings (~1 second via X: drive)

### [4.29] - 2025-11-02

#### Fixed

- **Canvas Height Not Applied**: Fixed v4.28 issue where canvas remained at 0-1 scale
  - Root cause: `IndicatorSetDouble()` in OnInit (lines 166-167) was overriding compile-time `#property` settings
  - Changed `IndicatorSetDouble(INDICATOR_MAXIMUM, 1.0)` to `5.0`
  - Now canvas properly scales to 0-5 range
  - Histogram (0-1) appears in bottom 20%, arrows (Y=1.1) in upper portion

#### Technical Details

- Line 167: `IndicatorSetDouble(INDICATOR_MAXIMUM, 5.0);` (was 1.0)
- Compile-time properties (lines 11-12) now work correctly with runtime settings
- Compilation: 24KB .ex5 file, 0 errors, 0 warnings (~1 second via X: drive)

### [4.28] - 2025-11-02 ❌ FAILED

#### Changed

- **Indicator Canvas Height**: Attempted to set explicit minimum (0.0) and maximum (5.0)
  - Added `#property indicator_minimum 0.0` and `#property indicator_maximum 5.0`
  - **Did not work**: Runtime `IndicatorSetDouble()` calls overrode compile-time properties
  - Fixed in v4.29

### [4.27] - 2025-11-02

#### Fixed

- **Arrow Positioning**: Changed from relative (at histogram value) to absolute (fixed Y coordinate)
  - Arrows now positioned at Y=1.1 (above histogram 0-1 range)
  - Removed PLOT_ARROW_SHIFT (was -30, now 0)
  - Previous versions: arrows at score value (0-1) caused clipping/invisibility
  - Debug logging confirmed 70+ patterns detected but not visible

#### Technical Details

- Line 143: `PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, 0);`
- Lines 521-523: `BufArrows[i] = 1.1;` (was `score`)
- Compilation: 24KB .ex5 file, 0 errors, 0 warnings
- Log analysis: 70+ rising patterns detected (bars 98724-99446) but arrows invisible

### [4.26] - 2025-11-02

#### Added

- **Debug Logging**: Detailed pattern detection logging to diagnose arrow visibility issues
  - Logs first 20 comparisons with all 4 bar values
  - Shows check results for each comparison (true/false)
  - Confirms rising pattern detection and arrow assignment
  - Static counter prevents log spam

#### Technical Details

- Lines 472-516: Comprehensive debug output with bar values and comparison results
- Log confirmed detection logic works correctly (70+ patterns found)
- Proved issue was display-related, not detection-related

### [4.25] - 2025-11-02

#### Changed

- **Arrow Visibility Enhancement**: Increased arrow visibility with larger size and brighter color
  - Color: Yellow (clrYellow) instead of Blue (clrDodgerBlue)
  - Width: 5 instead of 3
  - Arrow code: 217 (large circle) instead of 159 (small circle)
  - Shift: -30 points instead of -15
- User reported most patterns still not visible despite enhancements

#### Technical Details

- Lines 25-26: Color and width changes
- Lines 142-143: Arrow code and shift changes
- Still had visibility issues (fixed in v4.27)

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
