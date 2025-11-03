# CCI Neutrality Debug Workflow

## Overview

Debug version strips all visual complexity and outputs full calculation data to CSV for statistical analysis.

## Files

**Indicator**: `CCI_Neutrality_Debug.ex5` (18KB, compiled)
**Analyzer**: `/users/crossover/analyze_cci_debug.py`
**Output**: `MQL5/Files/cci_debug_SYMBOL_PERIOD_DATE.csv`

---

## Quick Start

### Step 1: Attach Debug Indicator

1. Open MT5
1. Open any chart (EURUSD M12 recommended)
1. Navigator → Indicators → Custom → Development → CCINeutrality → **CCI_Neutrality_Debug**
1. Drag to chart
1. **Leave all parameters as default** (CSV enabled by default)
1. Click OK

### Step 2: Verify CSV Output

Check MT5 Terminal → Journal tab for:

```
CCI Neutrality Debug initialized: CCI=20, W=30, CSV=enabled
CSV debug output: MQL5/Files/cci_debug_EURUSD_PERIOD_M12_2025.10.28.csv
```

CSV is written to:

```
~/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c/users/crossover/AppData/Roaming/MetaQuotes/Terminal/Common/Files/
```

### Step 3: Run Python Analysis

```bash
cd "/Users/terryli/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c/users/crossover"

python3 analyze_cci_debug.py
```

The script automatically finds the most recent `cci_debug_*.csv` file and analyzes it.

---

## CSV Output Columns

| Column     | Description                              |
| ---------- | ---------------------------------------- |
| time       | Bar timestamp                            |
| bar        | Bar index                                |
| cci        | CCI value                                |
| in_channel | 1 if \|CCI\| ≤ 100, else 0               |
| **p**      | In-channel ratio (percent in [-100,100]) |
| **mu**     | Mean CCI over window W                   |
| **sd**     | Standard deviation of CCI                |
| **e**      | Breach magnitude ratio                   |
| **c**      | Centering score (1 - min(1, \|mu\|/C0))  |
| **v**      | Dispersion score (1 - min(1, sd/C1))     |
| **q**      | Breach penalty score (1 - min(1, e))     |
| **score**  | Composite score (p · c · v · q)          |
| streak     | Consecutive in-channel bars              |
| coil       | 1 if coil signal, else 0                 |
| expansion  | 1 if expansion signal, else 0            |
| sum_b      | Rolling sum of in-channel flags (debug)  |
| sum_cci    | Rolling sum of CCI values (debug)        |
| sum_cci2   | Rolling sum of CCI² values (debug)       |
| sum_excess | Rolling sum of breach magnitudes (debug) |

---

## Python Analyzer Output

The `analyze_cci_debug.py` script performs **7 diagnostic checks**:

### 1. CCI Value Analysis

- Range, mean, std dev
- Percent time in [-100, 100]

### 2. Statistical Components

- Ranges for p, mu, sd, e
- Verify values are reasonable

### 3. Score Components Validation

- c, v, q must be in [0, 1]
- Flag if any violations

### 4. Composite Score Verification

- Recalculate S = p·c·v·q
- Compare to recorded score
- Max error should be < 1e-6

### 5. Signal Analysis

- Count coil and expansion signals
- Show coil statistics (avg streak, score, etc.)
- List first 5 coil signals with details

### 6. Rolling Window Sum Verification

- Spot check 5 random bars
- Manually recalculate sums
- Verify against recorded sums
- Max error should be < 1e-3

### 7. Coil Threshold Compliance

- All coil signals must meet 5 conditions:
  - Streak ≥ 5
  - p ≥ 0.80
  - |mu| ≤ 20.0
  - sd ≤ 30.0
  - score ≥ 0.80

### Summary

- Pass/fail for each diagnostic
- Overall health assessment

---

## Example Output

```
================================================================================
CCI Neutrality Debug Analysis
================================================================================
File: cci_debug_EURUSD_PERIOD_M12_2025.10.28.csv

Dataset: 500 bars
Period: 2025-10-24 00:00:00 to 2025-10-28 17:30:00

────────────────────────────────────────────────────────────────────────────────
1. CCI Value Analysis
────────────────────────────────────────────────────────────────────────────────
   Range: [-234.56, 198.43]
   Mean: -5.23
   Std Dev: 67.89
   In-channel [-100,100]: 78.2%

────────────────────────────────────────────────────────────────────────────────
2. Statistical Components
────────────────────────────────────────────────────────────────────────────────
   p (in-channel ratio):
      Range: [0.4000, 1.0000]
      Mean: 0.7823

   mu (mean CCI):
      Range: [-45.67, 42.31]
      Mean: -2.14

   sd (std dev CCI):
      Range: [8.45, 78.92]
      Mean: 35.67

   e (breach magnitude ratio):
      Range: [0.0000, 0.3456]
      Mean: 0.0421

────────────────────────────────────────────────────────────────────────────────
3. Score Components Validation (should be [0,1])
────────────────────────────────────────────────────────────────────────────────
   c: [0.0000, 1.0000] ✓
   v: [0.0000, 1.0000] ✓
   q: [0.6544, 1.0000] ✓

────────────────────────────────────────────────────────────────────────────────
4. Composite Score Verification
────────────────────────────────────────────────────────────────────────────────
   Score range: [0.0000, 0.9234]
   Formula verification (S = p·c·v·q):
      Max error: 0.000000 ✓

────────────────────────────────────────────────────────────────────────────────
5. Signal Analysis
────────────────────────────────────────────────────────────────────────────────
   Coil signals: 12 (2.40%)
   Expansion signals: 3 (0.60%)

   Coil signal stats:
      Avg streak: 8.3
      Avg score: 0.8456
      Avg p: 0.8923
      Avg |mu|: 8.45
      Avg sd: 15.23

   First 5 coil signals:
   Bar      Time                 CCI        Score      Streak
   45       2025-10-24 09:00:00  -15.23     0.8234     6
   67       2025-10-24 13:30:00  8.91       0.8567     7
   112      2025-10-25 08:00:00  -3.45      0.9012     9
   156      2025-10-25 17:00:00  12.34      0.8345     8
   203      2025-10-26 11:30:00  -7.89      0.8789     10

────────────────────────────────────────────────────────────────────────────────
6. Rolling Window Sum Verification (spot check)
────────────────────────────────────────────────────────────────────────────────
   Max rolling sum error: 0.000000 ✓

────────────────────────────────────────────────────────────────────────────────
7. Coil Threshold Compliance Check
────────────────────────────────────────────────────────────────────────────────
   Streak >= 5: ✓
   p >= 0.80: ✓
   |mu| <= 20.0: ✓
   sd <= 30.0: ✓
   score >= 0.80: ✓

   Overall compliance: ✓ PASS

================================================================================
Summary
================================================================================
   Score components in [0,1]                ✓ PASS
   Score formula S=p·c·v·q                  ✓ PASS
   Rolling window sums                      ✓ PASS
   Coil signals present                     ✓ PASS

================================================================================
```

---

## Debugging Workflow

### If No Coil Signals Appear

**Diagnosis**: Check Section 5 (Signal Analysis)

**Possible causes**:

1. Market is trending (not range-bound)
1. Thresholds too strict

**Solutions**:

1. Try EURUSD M5 during Asian session (more range-bound)
1. Adjust thresholds in indicator parameters:
   - Score threshold: 0.80 → 0.70
   - Min fraction inside: 0.80 → 0.70

### If Score Components Out of Range

**Diagnosis**: Check Section 3 (Score Components Validation)

**Expected**: All c, v, q values in [0, 1]

**If violations**:

- Review formulas in code
- Check for overflow/underflow in calculations
- Verify constants (C0, C1, C2)

### If Score Formula Error

**Diagnosis**: Check Section 4 (Composite Score Verification)

**Expected**: Max error < 1e-6

**If error > 1e-6**:

- Bug in score calculation
- Precision loss in multiplication
- Review line 217 in CCI_Neutrality_Debug.mq5

### If Rolling Window Sum Errors

**Diagnosis**: Check Section 6 (Rolling Window Sum Verification)

**Expected**: Max error < 1e-3

**If error > 1e-3**:

- Bug in O(1) sliding window logic
- State not reset properly on first run
- Review lines 238-261 in CCI_Neutrality_Debug.mq5

### If Coil Threshold Violations

**Diagnosis**: Check Section 7 (Coil Threshold Compliance Check)

**Expected**: All 5 conditions pass for every coil signal

**If violations**:

- Bug in coil detection logic (line 281)
- Incorrect threshold comparisons
- Logic error in multi-condition AND

---

## Manual CSV Inspection

If you want to manually examine the CSV:

```bash
# View first 10 rows
head -10 "/path/to/cci_debug_EURUSD_PERIOD_M12_2025.10.28.csv"

# Find all coil signals
grep ";1;0$" "/path/to/cci_debug_*.csv" | head -5

# Find all expansion signals
grep ";1$" "/path/to/cci_debug_*.csv"

# Import to Excel/LibreOffice
# File → Open → Select CSV → Delimiter: semicolon (;)
```

---

## Parameters Reference

All debug parameters match the main indicator:

**CCI Parameters**:

- CCI period: 20
- Window W: 30

**Neutrality Thresholds**:

- Min in-channel streak: 5
- Min fraction inside: 0.80
- Max |mean CCI|: 20.0
- Max stdev: 30.0
- Score threshold: 0.80

**Score Components**:

- C0 (centering): 50.0
- C1 (dispersion): 50.0
- C2 (breach magnitude): 100.0

**Debug Output**:

- Enable CSV: true (default)
- Flush interval: 100 bars

---

## Cleanup

CSV files can grow large. To clean up old debug files:

```bash
cd "/Users/terryli/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c/users/crossover/AppData/Roaming/MetaQuotes/Terminal/Common/Files"

# List all debug CSVs
ls -lh cci_debug_*.csv

# Remove old files (keep last 3)
ls -t cci_debug_*.csv | tail -n +4 | xargs rm -f
```

---

## Next Steps After Validation

Once all diagnostics pass:

1. **Mathematical correctness confirmed** ✓
1. **Signal logic verified** ✓
1. **Performance validated (O(1) rolling window)** ✓

Then you can:

- Use the full version with CSV logging for production
- Integrate with trading strategies
- Backtest signal effectiveness
- Tune parameters for specific markets

---

## Support

For issues with the debug workflow:

1. Check MT5 Journal for error messages
1. Verify CSV file exists in MQL5/Files
1. Run Python analyzer and review diagnostics
1. Examine specific bars with violations in CSV

All source code available:

- `/CCI_Neutrality_Debug.mq5` (source)
- `/users/crossover/analyze_cci_debug.py` (analyzer)
