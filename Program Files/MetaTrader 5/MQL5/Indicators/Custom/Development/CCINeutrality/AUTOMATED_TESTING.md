# CCI Neutrality - Automated Historical Testing

## Overview

Fast validation using **historical data** instead of waiting for live ticks. Leverages existing project infrastructure documented in:

- **[docs/guides/WINE_PYTHON_EXECUTION.md](../../../../../docs/guides/WINE_PYTHON_EXECUTION.md)** - v3.0.0 Wine Python headless execution
- **[docs/guides/INDICATOR_VALIDATION_METHODOLOGY.md](../../../../../docs/guides/INDICATOR_VALIDATION_METHODOLOGY.md)** - 5000-bar warmup requirement
- **[docs/MT5_REFERENCE_HUB.md](../../../../../docs/MT5_REFERENCE_HUB.md)** - Automation matrix and decision trees
- **[README.md](README.md)** - Strategy Tester workflow

______________________________________________________________________

## Why Historical Data?

### Problem with Live Data

- Must wait for market to generate new ticks
- EURUSD M1: 1 tick per minute = 100 minutes for 100 bars
- EURUSD M12: 1 tick per 12 minutes = 20 hours for 100 bars
- Slow feedback loop for development

### Solution: Historical Backtesting

- MT5 has years of historical data cached
- Load 5000 bars instantly
- Run calculations in seconds (not hours)
- Reproducible test conditions
- Per **INDICATOR_VALIDATION_METHODOLOGY.md**: 5000-bar minimum for warmup

______________________________________________________________________

## Quick Start (3 Steps)

### Step 1: Generate Test Dataset (FULLY AUTOMATED)

```bash
cd "/Users/terryli/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c/users/crossover"

CX_BOTTLE="MetaTrader 5" \
WINEPREFIX="$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5" \
wine "C:\\Program Files\\Python312\\python.exe" \
  "C:\\users\\crossover\\generate_test_data.py" \
  --symbol EURUSD --period M12 --bars 5000
```

**What it does**:

- Uses Wine Python + MT5 API (per **WINE_PYTHON_EXECUTION.md** v3.0.0 workflow)
- Fetches 5000 bars of historical EURUSD M12 data
- Calculates reference CCI values
- Outputs: `test_data_EURUSD_M12_5000bars.csv`
- Time: ~5 seconds (vs 20 hours for live data)

### Step 2: Attach Indicator (GUI - MT5 Limitation)

```bash
# Open MT5
# Open EURUSD M12 chart
# Press Home to load history
# Attach CCI_Neutrality_Debug indicator
# CSV written immediately
```

### Step 3: Analyze Results (FULLY AUTOMATED)

```bash
cd "/Users/terryli/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c/users/crossover"

python3 analyze_cci_debug.py
```

**What it does**:

- Auto-detects most recent `cci_debug_*.csv`
- Runs 7 diagnostic checks
- Validates all calculations
- Shows ✓ PASS or ✗ FAIL for each

______________________________________________________________________

## Complete Automated Workflow

For maximum automation, use the all-in-one script:

```bash
cd "/Users/terryli/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c/users/crossover"

./run_cci_validation.sh EURUSD M12 5000
```

**What it does**:

1. Generates 5000 bars of historical test data via Wine Python
1. Prompts you to attach indicator (GUI step)
1. Finds CSV output automatically
1. Runs analysis and shows results

**Total time**: ~1 minute (vs 20+ hours for live M12 data)

______________________________________________________________________

## Documentation References

### Primary Workflows

**[INDICATOR_VALIDATION_METHODOLOGY.md](../../../../../docs/guides/INDICATOR_VALIDATION_METHODOLOGY.md)**:

- Why 5000 bars required (warmup for ATR, adaptive periods)
- MQL5 expanding window behavior (divides by `period`, not available bars)
- Two-stage validation (fetch 5000 bars, calculate on all, compare last N)
- Correlation thresholds (≥0.999 = PASS)

**[WINE_PYTHON_EXECUTION.md](../../../../../docs/guides/WINE_PYTHON_EXECUTION.md)**:

- v3.0.0 Wine Python headless execution
- CX_BOTTLE + WINEPREFIX environment variables
- Path navigation (macOS ↔ Wine)
- MT5 Python API usage
- Cold start capability (any symbol/timeframe without GUI)

**[MT5_REFERENCE_HUB.md](../../../../../docs/MT5_REFERENCE_HUB.md)**:

- Decision trees (export data, compile, validate, parameters)
- Automation matrix (FULLY AUTOMATED vs SEMI-AUTOMATED vs MANUAL)
- Canonical source map (where to find each topic)

### Supporting Documentation

**[MQL5_TO_PYTHON_MIGRATION_GUIDE.md](../../../../../docs/guides/MQL5_TO_PYTHON_MIGRATION_GUIDE.md)**:

- 7-phase indicator migration workflow
- Algorithm analysis patterns
- Validation procedures

**[LESSONS_LEARNED_PLAYBOOK.md](../../../../../docs/guides/LESSONS_LEARNED_PLAYBOOK.md)**:

- 8 critical gotchas (185+ hours of debugging distilled)
- NaN traps, warmup requirements, pandas pitfalls

**[README.md](README.md)** (this indicator):

- Strategy Tester workflow
- Custom Symbol creation for synthetic data
- Parameter tuning guidelines

______________________________________________________________________

## Test Data Structure

Per **INDICATOR_VALIDATION_METHODOLOGY.md**, test data must include:

### Required Columns (OHLCV)

```csv
time,open,high,low,close,tick_volume,spread,real_volume
2025-10-24 00:00:00,1.08123,1.08156,1.08098,1.08134,4521,12,0
...
```

### Reference CCI Column (Optional)

```csv
time,open,high,low,close,cci
2025-10-24 00:00:00,1.08123,1.08156,1.08098,1.08134,-15.23
...
```

`generate_test_data.py` generates both formats.

______________________________________________________________________

## Debugging CSV Output Columns

CCI_Neutrality_Debug outputs **19 columns** for analysis:

| Column Group    | Columns                              | Purpose                        |
| --------------- | ------------------------------------ | ------------------------------ |
| **Base**        | time, bar, cci, in_channel           | Input data                     |
| **Statistics**  | p, mu, sd, e                         | Rolling window calculations    |
| **Score**       | c, v, q, score                       | Component and composite scores |
| **Signals**     | streak, coil, expansion              | Detection logic                |
| **Debug (O(1)** | sum_b, sum_cci, sum_cci2, sum_excess | Rolling sum verification       |

See **[DEBUG_WORKFLOW.md](DEBUG_WORKFLOW.md)** for complete column descriptions.

______________________________________________________________________

## Analysis Diagnostics

`analyze_cci_debug.py` performs **7 checks** (per **DEBUG_WORKFLOW.md**):

1. **CCI Value Analysis**: Range, mean, in-channel %
1. **Statistical Components**: p, mu, sd, e ranges
1. **Score Components Validation**: c, v, q ∈ [0,1]
1. **Composite Score Verification**: S = p·c·v·q (error < 1e-6)
1. **Signal Analysis**: Coil/expansion counts and stats
1. **Rolling Window Sum Verification**: Spot check 5 bars (error < 1e-3)
1. **Coil Threshold Compliance**: All 5 conditions must pass

All should show **✓ PASS** for production readiness.

______________________________________________________________________

## Comparison to Live Data Testing

| Aspect                 | Live Data              | Historical Data (This Approach) |
| ---------------------- | ---------------------- | ------------------------------- |
| **Time for 5000 bars** | 20-40 hours            | 5 seconds                       |
| **Reproducibility**    | No (market changes)    | Yes (same data every time)      |
| **GUI Required**       | Yes (attach indicator) | Partial (attach indicator)      |
| **Data Generation**    | Wait for ticks         | Instant (MT5 API)               |
| **Validation**         | Manual                 | Automated (Python script)       |
| **Reference Docs**     | N/A                    | 3+ existing guides              |

______________________________________________________________________

## Alternative: Strategy Tester (GUI Workflow)

Per **[README.md](README.md)** Section "Testing → Strategy Tester":

```
1. View → Strategy Tester
2. Mode: "Indicator"
3. Select CCI_Neutrality_Debug
4. Choose symbol, period, date range
5. Enable "Visual mode" for chart playback
6. Click Start
```

**Advantages**:

- Reproducible runs
- CSV logging works identically
- Fast forward/backward through history
- Visual verification

**Disadvantages**:

- GUI interaction required
- More steps than automated workflow

______________________________________________________________________

## Alternative: Custom Symbol (Synthetic Data)

For deterministic test patterns, create custom symbols:

```mq5
// Script: CreateCCITestSymbol.mq5
string sym = "SYNTH_CCI";
CustomSymbolCreate(sym, "Custom\\Lab", _Symbol);

MqlRates rates[];
ArrayResize(rates, 2000);

for(int i = 0; i < 2000; i++)
{
   double base = 1.2000 + 0.0010 * MathSin(i * 0.01);
   rates[i].open = base;
   rates[i].high = base + 0.0003;
   rates[i].low = base - 0.0003;
   rates[i].close = base + 0.0002 * MathSin(i * 0.07);
   // ...
}

CustomRatesUpdate(sym, rates);
```

See **[README.md](README.md)** Section "Testing → Custom Symbol" for complete code.

______________________________________________________________________

## Files

### Automation Scripts

**[run_cci_validation.sh](../../../../../users/crossover/run_cci_validation.sh)**:

- All-in-one automated workflow
- Generates data, runs analysis, shows results

**[generate_test_data.py](../../../../../users/crossover/generate_test_data.py)**:

- Wine Python script to fetch historical data via MT5 API
- Calculates reference CCI values
- Fully automated (no GUI)

**[analyze_cci_debug.py](../../../../../users/crossover/analyze_cci_debug.py)**:

- Python analyzer with 7 diagnostic checks
- Auto-detects CSV files
- Validates all calculations

**[test_cci_automated.py](../../../../../users/crossover/test_cci_automated.py)**:

- Alternative workflow using Strategy Tester
- Includes prerequisites check
- Wait for CSV generation

### Documentation

**Current file**: Automated testing workflow (historical data approach)

**[DEBUG_WORKFLOW.md](DEBUG_WORKFLOW.md)**: Complete debug workflow with CSV analysis

**[VISUAL_SETUP_GUIDE.md](VISUAL_SETUP_GUIDE.md)**: GUI setup steps (if needed)

**[README.md](README.md)**: Main indicator documentation

**[AUDIT_COMPLIANCE.md](AUDIT_COMPLIANCE.md)**: Implementation validation

______________________________________________________________________

## Next Steps

After all diagnostics pass:

1. **Mathematical correctness confirmed** ✓
1. **Signal logic verified** ✓
1. **Performance validated (O(1) rolling window)** ✓

Then:

- Integrate with trading strategies
- Backtest signal effectiveness
- Tune parameters for specific markets
- Use full version with CSV logging for production

______________________________________________________________________

## References

### Project Documentation (Canonical Sources)

- **[docs/guides/WINE_PYTHON_EXECUTION.md](../../../../../docs/guides/WINE_PYTHON_EXECUTION.md)** - v3.0.0 Wine Python workflow
- **[docs/guides/INDICATOR_VALIDATION_METHODOLOGY.md](../../../../../docs/guides/INDICATOR_VALIDATION_METHODOLOGY.md)** - 5000-bar warmup requirement
- **[docs/MT5_REFERENCE_HUB.md](../../../../../docs/MT5_REFERENCE_HUB.md)** - Decision trees and automation matrix
- **[docs/guides/MQL5_TO_PYTHON_MIGRATION_GUIDE.md](../../../../../docs/guides/MQL5_TO_PYTHON_MIGRATION_GUIDE.md)** - Migration workflow
- **[docs/guides/LESSONS_LEARNED_PLAYBOOK.md](../../../../../docs/guides/LESSONS_LEARNED_PLAYBOOK.md)** - Critical gotchas
- **[CLAUDE.md](../../../../../CLAUDE.md)** - Single Source of Truth table

### Indicator Documentation

- **[README.md](README.md)** - Main indicator documentation
- **[DEBUG_WORKFLOW.md](DEBUG_WORKFLOW.md)** - CSV debugging workflow
- **[AUDIT_COMPLIANCE.md](AUDIT_COMPLIANCE.md)** - Implementation validation
- **[VISUAL_SETUP_GUIDE.md](VISUAL_SETUP_GUIDE.md)** - GUI setup steps

______________________________________________________________________

## Support

For issues:

1. Check referenced documentation above
1. Review MT5 Terminal → Journal for errors
1. Verify prerequisites (Wine Python, MT5 API, pandas, numpy)
1. Run `python3 analyze_cci_debug.py` manually for detailed diagnostics

All scripts include inline documentation and reference the canonical guides.
