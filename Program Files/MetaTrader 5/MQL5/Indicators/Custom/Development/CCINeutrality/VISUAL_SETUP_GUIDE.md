# CCI Neutrality Indicator - Visual Setup Guide

## Quick Reference

**Compiled File**: `CCI_Neutrality_Simple.ex5` (16KB, 0 errors)
**Location**: `MQL5/Indicators/Custom/Development/CCINeutrality/`
**Type**: Separate window indicator
**Plots**: 4 (CCI line, Score line, Coil markers, Expansion markers)

---

## Step 1: Open MT5 and Access Navigator

1. **Launch MetaTrader 5**
2. **Open Navigator** (if not visible):
   - Press `Ctrl+N` (Windows/Wine) or `Cmd+N` (Mac)
   - Or: View → Navigator

3. **Navigate to Custom Indicators**:
   ```
   Navigator
   └── Indicators
       └── Custom
           └── Development
               └── CCINeutrality
                   └── CCI_Neutrality_Simple
   ```

**What to look for**: You should see the indicator listed with a small graph icon.

---

## Step 2: Attach Indicator to Chart

### Method 1: Drag and Drop (Recommended)

1. **Open a chart** (any symbol, any timeframe)
   - Suggested for testing: EURUSD M5 or M15

2. **Drag the indicator** from Navigator onto the chart
   - Click and hold `CCI_Neutrality_Simple`
   - Drag to chart window
   - Release mouse button

3. **Parameters dialog will appear** → Proceed to Step 3

### Method 2: Double-Click

1. **Double-click** `CCI_Neutrality_Simple` in Navigator
2. **Select chart** from dropdown (if multiple charts open)
3. **Parameters dialog will appear** → Proceed to Step 3

---

## Step 3: Configure Parameters

When the parameters dialog appears, you'll see **5 groups of settings**:

### CCI Parameters (Default: OK for testing)

```
CCI period: 20          ← Standard CCI lookback
Window W: 30            ← Statistics calculation window
```

**For first test**: Leave as default

### Neutrality Thresholds (Default: OK for testing)

```
Min in-channel streak: 5       ← Minimum consecutive bars in [-100,100]
Min fraction inside: 0.80      ← 80% of window must be in range
Max |mean CCI|: 20.0          ← Maximum absolute mean
Max stdev: 30.0               ← Maximum standard deviation
Score threshold: 0.80         ← Minimum composite score
```

**For first test**: Leave as default

### Score Components (Default: OK for testing)

```
C0: 50.0    ← Centering constant
C1: 50.0    ← Dispersion constant
C2: 100.0   ← Breach magnitude constant
```

**For first test**: Leave as default

### Display Settings (Adjust these for visibility)

```
Coil marker Y: 120.0        ← Vertical position for ● green circles
Expansion marker Y: 140.0   ← Vertical position for ▲ red triangles
```

**Tip**: Adjust these values to position markers above the indicator window for better visibility.

### Click "OK"

The indicator will attach to a **separate window** below your chart.

---

## Step 4: What You Should See

### Separate Indicator Window

The indicator opens in its own window below the price chart with:

#### 4 Horizontal Reference Lines

```
+140  ───────────────────  (Expansion marker position - red)
+120  ───────────────────  (Coil marker position - green)
+100  ───────────────────  (CCI upper threshold)
   0  ───────────────────  (Zero line)
-100  ───────────────────  (CCI lower threshold)
 +80  ───────────────────  (Score threshold - 80% line)
```

#### 2 Main Lines

1. **Blue Line (CCI)**: Oscillates around zero
   - Normal range: -100 to +100
   - Can breach above/below ±100

2. **Orange Line (Score x100)**: Neutrality score (0-100 scale)
   - Higher values = stronger neutrality
   - Threshold at 80 (score ≥ 0.80)

#### 2 Signal Markers

3. **Green Circles (●)**: Coil signals at Y=120
   - Appears when all 5 neutrality conditions are met
   - Indicates compression phase

4. **Red Triangles (▲)**: Expansion signals at Y=140
   - Appears when CCI breaches ±100 after a coil
   - Indicates breakout from compression

---

## Step 5: Verify Indicator is Working

### Check 1: Lines are Drawing

✅ **Expected**: Blue CCI line and orange Score line are visible
❌ **If not**: Indicator may need more historical bars (need at least Window W + 2 bars)

### Check 2: Signals Appear

✅ **Expected**: Green circles (●) appear when CCI is bounded near zero for multiple bars
✅ **Expected**: Red triangles (▲) appear when CCI breaches ±100 after a coil
⚠️ **Note**: Signals may be rare depending on market conditions

### Check 3: No Errors in Journal

1. **Open Terminal** (if not visible):
   - Press `Ctrl+T` or View → Terminal

2. **Click "Journal" tab**

3. **Check for messages**:
   - ✅ Should see: `"CCI Neutrality initialized: CCI=20, W=30, thresh=..."`
   - ❌ If errors: Check error message and refer to Troubleshooting section

---

## Step 6: Testing Different Scenarios

### Test 1: Range-Bound Market (Expect Many Coils)

**Symbols**: EURUSD, GBPUSD during Asian/early London session
**Timeframes**: M5, M15, M30
**Expected**: Multiple green coil markers (●) when price consolidates

### Test 2: Trending Market (Expect Expansions)

**Symbols**: Any major pair during strong trends
**Timeframes**: M15, H1
**Expected**: Green coils (●) followed by red expansions (▲) when trend accelerates

### Test 3: Adjust Sensitivity

**If too many signals**: Increase thresholds

```
Score threshold: 0.85 → 0.90
Max stdev: 30 → 25
```

**If too few signals**: Decrease thresholds

```
Score threshold: 0.80 → 0.75
Min fraction inside: 0.80 → 0.70
```

---

## Troubleshooting

### Issue 1: Indicator Window Not Appearing

**Cause**: Indicator may have failed to initialize
**Fix**:

1. Check Journal for error messages
2. Remove indicator from chart (right-click window → Indicator List → Delete)
3. Re-attach with default parameters

### Issue 2: No Lines Visible

**Cause**: Not enough historical bars
**Fix**:

1. Scroll chart back to load more history (Home key or scroll left)
2. Indicator needs at least `Window W + 2` bars (default: 32 bars minimum)
3. Check Journal for "CCI not ready" messages

### Issue 3: No Signals Appearing

**Causes**:

- Market is strongly trending (few coil opportunities)
- Thresholds too strict

**Fix**:

1. Try different symbol/timeframe (range-bound markets work best)
2. Reduce threshold strictness:
   ```
   Score threshold: 0.80 → 0.70
   Min fraction inside: 0.80 → 0.70
   ```

### Issue 4: "Failed to create CCI handle" Error

**Cause**: CCI indicator failed to initialize
**Fix**:

1. Restart MetaTrader 5
2. Ensure CCI period ≥ 1
3. Check if standard CCI indicator works (Insert → Indicators → Oscillators → Commodity Channel Index)

---

## Parameter Tuning Guide

### For Short Timeframes (M1, M5)

```
CCI period: 14-20
Window W: 20-30
Max |mean|: 30-40
Max stdev: 40-50
```

**Why**: More noise requires wider tolerance

### For Medium Timeframes (M15, M30, H1)

```
CCI period: 20-30
Window W: 30-40
Max |mean|: 20-30
Max stdev: 30-40
```

**Why**: Default parameters work well

### For Long Timeframes (H4, D1)

```
CCI period: 30-50
Window W: 40-60
Max |mean|: 10-15
Max stdev: 20-25
```

**Why**: Less noise allows tighter thresholds

---

## Understanding the Signals

### Coil Signal (Green ●)

**Meaning**: CCI is "coiled" near zero with tight distribution

**5 Conditions (all must be true)**:

1. Streak ≥ 5 consecutive bars in [-100, +100]
2. ≥80% of window W is inside [-100, +100]
3. Mean CCI ≤ 20 (centered near zero)
4. Standard deviation ≤ 30 (tight dispersion)
5. Composite score ≥ 0.80 (overall neutrality)

**Trading implication**: Price compression, potential breakout setup

### Expansion Signal (Red ▲)

**Meaning**: CCI just breached ±100 after being in coil

**Conditions**:

1. Previous bar had coil signal
2. Current bar breaches +100 or -100

**Trading implication**: Breakout from compression phase

---

## Next Steps

Once you verify the indicator is working correctly:

1. **Test on multiple symbols/timeframes** to understand signal frequency
2. **Adjust parameters** based on your trading style and market conditions
3. **Document signal behavior** for your typical trading pairs
4. **Consider enabling CSV logging** (full version with CsvLogger) for detailed analysis

For CSV logging and advanced features, refer to `README.md` in the CCINeutrality folder.

---

## File Locations Reference

**Source Code** (simplified version):

```
C:/CCI_Neutrality_Simple.mq5
```

**Compiled File** (ready to use):

```
C:/Program Files/MetaTrader 5/MQL5/Indicators/Custom/Development/CCINeutrality/CCI_Neutrality_Simple.ex5
```

**Full Version** (with CSV logging - requires CsvLogger.mqh):

```
C:/Program Files/MetaTrader 5/MQL5/Indicators/Custom/Development/CCINeutrality/CCI_Neutrality.mq5
```

**CSV Logger Library** (for full version):

```
C:/Program Files/MetaTrader 5/MQL5/Include/CsvLogger.mqh
```

---

## Support

For detailed mathematical specification and audit compliance details, see:

- `README.md` - Comprehensive documentation
- `AUDIT_COMPLIANCE.md` - Implementation validation

For questions or issues, check the Journal tab in MT5 Terminal for diagnostic messages.
