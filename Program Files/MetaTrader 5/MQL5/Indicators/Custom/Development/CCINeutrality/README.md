# CCI Neutrality Indicator

## Overview

Quantifies "consecutive CCI bounded near zero with few ±100 breaches" using standard technical analysis components. Detects coil (compression) and expansion phases based on a composite neutrality score.

**Version**: 1.00
**Status**: Development (Community-grade audit compliance)
**Branch**: feature/cci-neutrality-indicator

______________________________________________________________________

## Mathematical Foundation

### 1. Base CCI Calculation

Standard Commodity Channel Index:

```
CCI_t = (TP_t - SMA_n(TP)) / (0.015 · MAD_n(TP))
```

where TP = Typical Price = (High + Low + Close) / 3

### 2. In-Channel Tracking

Binary flag for CCI within \[-100, +100\]:

```
b_t = 1 if |CCI_t| ≤ 100, else 0
```

Consecutive streak calculation:

```
s_t = count of consecutive bars with b_t = 1
```

### 3. Statistical Components (Window W)

**Percent Time In Channel**:

```
p_t = (1/W) · Σ(i=0 to W-1) b_{t-i}
```

**Centering Near Zero**:

```
μ_t = SMA_W(CCI)
c_t = 1 - min(1, |μ_t| / C_0)
```

Default: C_0 = 50

**Tight Dispersion**:

```
σ_t = StDev_W(CCI)
v_t = 1 - min(1, σ_t / C_1)
```

Default: C_1 = 50

**Breach Magnitude Penalty**:

```
e_t = (1/W) · Σ(i=0 to W-1) max(0, |CCI_{t-i}| - 100) / C_2
q_t = 1 - min(1, e_t)
```

Default: C_2 = 100

### 4. Composite Neutrality Score

```
S_t = p_t · c_t · v_t · q_t ∈ [0,1]
```

### 5. Signals

**Neutral Coil** (compression phase):

- s_t ≥ S_min (default: 5)
- p_t ≥ p_min (default: 0.8)
- |μ_t| ≤ μ_max (default: 20)
- σ_t ≤ σ_max (default: 30)
- S_t ≥ τ (default: 0.8)

**Expansion Trigger**:

- Prior bar had coil signal
- |CCI_t| crosses 100 or -100

______________________________________________________________________

## Audit Compliance (Community-Grade)

### Issues Fixed from Initial Implementation

1. **prev_calculated Flow** ✅

   - Implements incremental calculation
   - Avoids full history recalculation on each tick
   - Recalculates only last bar on new data

1. **BarsCalculated Hygiene** ✅

   - Checks indicator readiness before CopyBuffer
   - Handles partial data availability
   - Reports errors with diagnostic messages

1. **O(1) Rolling Window** ✅

   - Maintains running sums (sum_b, sum_cci, sum_cci2, sum_excess)
   - Slides window with add/remove operations
   - Replaces O(N·W) nested loops with O(N) single loop

1. **Plot Configuration** ✅

   - Sets PLOT_DRAW_BEGIN = W - 1
   - Explicitly defines PLOT_EMPTY_VALUE
   - Configures arrow glyphs (159 = ●, 241 = ▲)

1. **Buffer Management** ✅

   - Uses forward indexing (ArraySetAsSeries = false)
   - Separates state tracking (prev_coil_bar) from output buffers
   - Proper buffer initialization with EMPTY_VALUE

1. **Error Handling** ✅

   - Validates input parameters
   - Handles CopyBuffer failures
   - Reports errors with context

### Performance Characteristics

| Operation            | Complexity | Notes                    |
| -------------------- | ---------- | ------------------------ |
| First calculation    | O(N)       | N = rates_total          |
| Incremental update   | O(1)       | Single bar recalculation |
| Rolling window slide | O(1)       | Running sum updates      |
| Memory               | O(N)       | Static arrays reused     |

______________________________________________________________________

## Installation

### 1. File Structure

```
MQL5/
├── Include/
│   └── CsvLogger.mqh              # CSV logging utility
└── Indicators/Custom/Development/CCINeutrality/
    ├── CCI_Neutrality.mq5         # Main indicator
    └── README.md                   # This file
```

### 2. Compilation

**CLI Method** (recommended):

```bash
CX="~/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
BOTTLE="MetaTrader 5"
ME="C:/Program Files/MetaTrader 5/MetaEditor64.exe"

"$CX" --bottle "$BOTTLE" --cx-app "$ME" \
  /log \
  /compile:"C:/Program Files/MetaTrader 5/MQL5/Indicators/Custom/Development/CCINeutrality/CCI_Neutrality.mq5" \
  /inc:"C:/Program Files/MetaTrader 5/MQL5"
```

**GUI Method**:

1. Open MetaEditor
1. File → Open → Navigate to CCI_Neutrality.mq5
1. Press F7 to compile

### 3. Verification

Check compilation log:

```bash
tail -1 "$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c/Program Files/MetaTrader 5/logs/metaeditor.log"
# Expected: "0 errors, X warnings, YYY msec elapsed"
```

______________________________________________________________________

## Usage

### Basic Setup

1. Open MT5 chart (any symbol, any timeframe)
1. Navigator → Indicators → Custom → Development → CCINeutrality → CCI_Neutrality
1. Drag to chart
1. Configure parameters (see below)

### Input Parameters

#### CCI Parameters

- **CCI period** (default: 20): Standard CCI lookback period
- **Window W** (default: 30): Statistics calculation window

#### Neutrality Thresholds

- **Min in-channel streak** (default: 5): Minimum consecutive bars in [-100,100]
- **Min fraction inside** (default: 0.80): Minimum 80% of window inside range
- **Max |mean CCI|** (default: 20): Maximum absolute mean for centering
- **Max stdev** (default: 30): Maximum standard deviation for tightness
- **Score threshold** (default: 0.80): Minimum composite score

#### Score Components

- **C0** (default: 50): Centering constant
- **C1** (default: 50): Dispersion constant
- **C2** (default: 100): Breach magnitude constant

#### Display

- **Coil marker Y** (default: 120): Vertical position for ● markers
- **Expansion marker Y** (default: 140): Vertical position for ▲ markers

#### Logging

- **Enable CSV logging** (default: false): Write diagnostics to CSV
- **Log file prefix** (default: "cci_neutrality"): Filename prefix
- **Flush interval** (default: 500): Write buffer every N bars

______________________________________________________________________

## CSV Logging

### Enable Logging

Set `Enable CSV logging = true` in indicator inputs.

### Output Location

Files written to:

```
~/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c/users/crossover/AppData/Roaming/MetaQuotes/Terminal/Common/Files/
```

Filename format:

```
cci_neutrality_SYMBOL_TIMEFRAME_DATE_TIME.csv
```

Example:

```
cci_neutrality_EURUSD_PERIOD_M1_2025.10.27_14.30.csv
```

### CSV Columns

```
time;bar;cci;in_channel;p;mu;sd;e;c;v;q;score;streak;coil;expansion
```

| Column     | Description                   |
| ---------- | ----------------------------- |
| time       | Bar timestamp                 |
| bar        | Bar index                     |
| cci        | CCI value                     |
| in_channel | 1 if \|CCI\| ≤ 100, else 0    |
| p          | Percent in channel (window)   |
| mu         | Mean CCI (window)             |
| sd         | Standard deviation (window)   |
| e          | Breach magnitude ratio        |
| c          | Centering score [0,1]         |
| v          | Dispersion score [0,1]        |
| q          | Breach penalty score [0,1]    |
| score      | Composite score [0,1]         |
| streak     | Consecutive in-channel bars   |
| coil       | 1 if coil signal, else 0      |
| expansion  | 1 if expansion signal, else 0 |

______________________________________________________________________

## Testing

### 1. Strategy Tester (Recommended)

**Setup**:

1. View → Strategy Tester
1. Mode: "Indicator"
1. Select CCI_Neutrality
1. Choose symbol, period, date range
1. Enable "Visual mode" for chart playback

**Why Use Tester**:

- Reproducible historical runs
- CSV logging works identically
- No live market data required
- Fast forward/backward through history

### 2. Custom Symbol (Synthetic Data)

Create deterministic test data:

```mq5
// Script: CreateCCITestSymbol.mq5
void OnStart()
{
   string sym = "SYNTH_CCI";
   if(!CustomSymbolCreate(sym, "Custom\\Lab", _Symbol))
      Print("Create failed: ", GetLastError());

   MqlRates rates[];
   datetime t0 = D'2024.01.01 00:00';
   int N = 2000;

   ArrayResize(rates, N);
   for(int i = 0; i < N; i++)
   {
      double base = 1.2000 + 0.0010 * MathSin(i * 0.01); // Smooth path
      rates[i].time = t0 + i * PeriodSeconds(PERIOD_M1);
      rates[i].open = base;
      rates[i].high = base + 0.0003;
      rates[i].low = base - 0.0003;
      rates[i].close = base + 0.0002 * MathSin(i * 0.07);
      rates[i].tick_volume = 1;
      rates[i].real_volume = 1;
      rates[i].spread = 10;
   }

   CustomRatesUpdate(sym, rates);
   SymbolSelect(sym, true);
}
```

Attach indicator to SYNTH_CCI chart.

### 3. Validation Against Original Pine Script

**MT5 Export**:

1. Enable CSV logging
1. Run on historical data
1. Collect CSV output

**Pine Script Reference**:

```pinescript
//@version=5
indicator("CCI Neutrality Score", overlay=false)
len  = input.int(20, "CCI length")
W    = input.int(30, "Window W")
// ... (full implementation from spec)
```

**Compare**:

- CCI values (should match standard CCI)
- Score values (composite calculation)
- Coil/expansion signals (threshold logic)

______________________________________________________________________

## Tuning Guidelines

### Timeframe-Specific Adjustments

**Short Timeframes (M1, M5)**:

- Increase `Max |mean|` (30-40)
- Increase `Max stdev` (40-50)
- Shorter CCI period (14-20)

**Medium Timeframes (M15, M30, H1)**:

- Default parameters work well
- CCI period (20-30)

**Long Timeframes (H4, D1)**:

- Tighten thresholds:
  - `Max |mean|` (10-15)
  - `Max stdev` (20-25)
- Longer CCI period (30-50)

### Market Characteristics

**Trending Markets**:

- Reduce `Min fraction inside` (0.6-0.7)
- Increase `Score threshold` (0.85-0.9)
- Expect fewer coil signals

**Range-Bound Markets**:

- Increase `Min fraction inside` (0.85-0.95)
- Reduce `Score threshold` (0.7-0.75)
- Expect more coil signals

______________________________________________________________________

## Implementation Notes

### State Management

**Rolling Window Sums** (static variables):

```cpp
static double sum_b;        // In-channel count
static double sum_cci;      // CCI sum
static double sum_cci2;     // CCI² sum
static double sum_excess;   // Breach magnitudes
```

Reset on first calculation or history reload.

### Streak Calculation

Lookback approach (not recursive):

```cpp
int streak = 0;
if(b_in == 1.0)
{
   for(int j = i; j >= 0 && (MathAbs(cci[j]) <= 100.0); j--)
      streak++;
}
```

**Why Not Recursive**: Avoids state carry-over issues with prev_calculated flow.

### Expansion Detection

Tracks previous coil bar index:

```cpp
static int prev_coil_bar = -1;

if(coil)
   prev_coil_bar = i;

bool expansion = (prev_coil_bar == i - 1) &&
                 (MathAbs(cci[i]) > 100.0) &&
                 (MathAbs(cci[i - 1]) <= 100.0);
```

**Why Separate State**: Output buffers (BufCoil) use EMPTY_VALUE for non-signals, unsuitable for state tracking.

______________________________________________________________________

## Troubleshooting

### Indicator Not Appearing

**Check**:

1. Compilation errors: View → Toolbox → Errors tab
1. Journal messages: Tools → Options → Expert Advisors → Enable Journal
1. Indicator handle validity: Check for "ERROR: Failed to create CCI handle"

### No Signals Visible

**Check**:

1. Enough bars: Need at least W + 2 bars
1. Thresholds too strict: Try default parameters first
1. CCI range: Most signals occur when CCI oscillates near [-100,100]

### CSV Logging Not Working

**Check**:

1. `Enable CSV logging = true`
1. File permissions: Terminal may need write access
1. Log location: Check Common Files path in Journal output
1. File open errors: Look for "CsvLogger: Failed to open file"

### Performance Issues

**Check**:

1. Window W size: Larger windows = more memory
1. Flush interval: Increase to 1000+ for large datasets
1. CSV logging: Disable if not needed

______________________________________________________________________

## References

### MQL5 Documentation

- [OnCalculate Event Handler](https://www.mql5.com/en/docs/event_handlers/oncalculate)
- [BarsCalculated Function](https://www.mql5.com/en/docs/series/barscalculated)
- [CopyBuffer Function](https://www.mql5.com/en/docs/series/copybuffer)
- [File Functions](https://www.mql5.com/en/docs/files/fileopen)
- [Custom Symbols](https://www.mql5.com/en/docs/customsymbols/customsymbolcreate)

### Project Documentation

- [MQL5_TO_PYTHON_MIGRATION_GUIDE.md](../../../../docs/guides/MQL5_TO_PYTHON_MIGRATION_GUIDE.md)
- [LESSONS_LEARNED_PLAYBOOK.md](../../../../docs/guides/LESSONS_LEARNED_PLAYBOOK.md)
- [MQL5_CLI_COMPILATION_SUCCESS.md](../../../../docs/guides/MQL5_CLI_COMPILATION_SUCCESS.md)

______________________________________________________________________

## Version History

### v1.00 (2025-10-27)

- Initial implementation
- Community-grade audit compliance
- O(1) rolling window calculations
- CSV logging integration
- Comprehensive testing documentation
