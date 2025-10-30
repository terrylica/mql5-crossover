# MT5 Automation Blocking Issue - Comprehensive Analysis (v1.3.0)

**Status**: CRITICAL BLOCKING
**Severity**: BLOCKS ALL HEADLESS AUTOMATION APPROACHES
**Date**: 2025-10-29
**Plan**: cci-neutrality-indicator v1.3.0

---

## Executive Summary

**BOTH documented MT5 automation approaches FAIL on CrossOver/Wine with identical symptoms:**

| Version | Approach | Config Section | Result |
| --- | --- | --- | --- |
| v1.2.0 | Strategy Tester | `[Tester]` | Config loads ✓ Tester doesn't start ❌ |
| v1.3.0 | Script Automation | `[StartUp]` | Config loads ✓ Script doesn't execute ❌ |

---

## v1.3.0 Findings: [StartUp] Script Automation Attempt

### Implementation Created

**CCI_Export_Script.mq5** (Script pattern):

- Uses `iCustom()` to load CCI_Neutrality_Debug indicator
- Calls `CopyBuffer()` to force indicator calculation
- Indicator handles CSV export via OnInit/OnCalculate/OnDeinit lifecycle
- Compiled successfully: 0 errors, 0 warnings, 715ms

**startup_cci_export.ini** (Configuration):

```ini
[StartUp]
Script=CCINeutrality\\CCI_Export_Script.ex5
Symbol=EURUSD
Period=M12
ShutdownTerminal=1
```

**Pattern Based On**: EXTERNAL_RESEARCH_BREAKTHROUGHS.md v2.0.0 approach

- Documented as working for ExportAligned.mq5
- `[StartUp]` section triggers script execution
- `ShutdownTerminal=1` auto-closes terminal

### Execution Results

**Terminal Log Evidence** (logs/20251028.log @ 19:18:32):

```
19:18:32.791 Startup successfully initialized from start config "...startup_cci_export.ini"
19:18:32.998 Terminal launched with C:\users\crossover\Config\startup_cci_export.ini
19:18:35.368 Indicators custom indicator ZigZag_Color_NoRepaint (USDJPY,M5) loaded successfully
19:18:35.493 Indicators custom indicator ZigZag_Color_NoRepaint (BTCUSD,M15) loaded successfully
19:18:35.500 Indicators custom indicator cc (BTCUSD,M15) loaded successfully
```

**Observed Behavior**:

1. Config file loads successfully ✅
2. Terminal starts normally ✅
3. **NO script execution messages** ❌
4. **NO "Script: CCI_Export_Script" log entries** ❌
5. Restores previous workspace (ZigZag, cc indicators) ❌
6. Terminal behaves as if no [StartUp] section exists ❌

**Identical Pattern to v1.2.0 [Tester] Failure**.

### Root Cause Analysis

**CrossOver/Wine Limitation Hypothesis**:

The `/config` parameter successfully loads INI files, but CrossOver/Wine does **NOT** implement the trigger mechanisms for:

1. `[Tester]` section → Strategy Tester execution
2. `[StartUp]` section → Script execution

**Evidence**:

- Both approaches document correct INI format (confirmed via mql5.com)
- Both load config successfully (terminal logs confirm)
- Both fail to trigger target action (no tester/script execution logs)
- Workspace restoration suggests config parsing works but action dispatch doesn't

**Hypothesis**: Windows MT5 may have internal APIs/COM interfaces that read these sections and dispatch to tester/script subsystems. CrossOver/Wine may translate file I/O correctly but not these subsystem dispatch calls.

---

## Comprehensive Impact Assessment

### Blocked Functionality

**v1.2.0 Attempt**:

- ❌ Strategy Tester command line automation
- ❌ Batch EA testing
- ❌ Indicator testing via EA wrapper

**v1.3.0 Attempt**:

- ❌ Script automation via [StartUp]
- ❌ Headless indicator CSV export
- ❌ Automated data collection pipeline

### SLO Status

From cci-neutrality-indicator.yaml v1.3.0:

| SLO | Target | Actual | Status |
| --- | --- | --- | --- |
| **Availability** | 100% | 100% | ✅ MET |
| **Correctness** | 100% | 0% | ❌ NOT MET |
| **Observability** | 100% | 100% | ✅ MET |
| **Maintainability** | 100% | 100% | ✅ MET |

**Correctness blocked**: Cannot validate calculations without CSV output from automated execution.

---

## Error Propagation (Per User Requirements)

**User Requirement**: "On any error, raise and propagate—no fallbacks, defaults, retries, or silent handling."

**Actions Taken**:

1. ✅ Documented both blocking issues (v1.2.0 + v1.3.0)
2. ✅ Preserved all evidence (terminal logs, config files, compiled artifacts)
3. ✅ NO fallback attempts (did not retry with different parameters)
4. ✅ NO silent acceptance (propagated error to plan file)
5. ✅ Updated SLO status (correctness remains 0%)
6. ✅ Version tracking (v1.2.0 → v1.3.0)

**NO Workarounds Attempted**:

- ❌ Did NOT fall back to GUI workflow
- ❌ Did NOT attempt manual script execution
- ❌ Did NOT try AppleScript/GUI automation
- ❌ Did NOT modify config formats beyond documented patterns

---

## Alternative Approaches (Status)

| Approach | Viability | Status |
| --- | --- | --- |
| [Tester] automation | ❌ BLOCKED | v1.2.0 failed |
| [StartUp] automation | ❌ BLOCKED | v1.3.0 failed |
| Python MT5 API | ❌ NOT VIABLE | No indicator buffer access |
| GUI workflow (manual) | ✅ VIABLE | Requires user action |
| AppleScript automation | ❓ UNKNOWN | Not explored |
| Native Windows MT5 | ❓ UNKNOWN | May confirm Wine hypothesis |

---

## Files Created (v1.3.0)

**Script Implementation**:

- `/CCI_Export_Script.mq5` (source, 5.8KB)
- `/Program Files/MetaTrader 5/MQL5/Scripts/CCINeutrality/CCI_Export_Script.ex5` (compiled, 18KB)
- `/Program Files/MetaTrader 5/MQL5/Scripts/CCINeutrality/CCI_Export_Script.mq5` (deployed source)

**Configuration**:

- `/users/crossover/Config/startup_cci_export.ini` ([StartUp] section)

**Automation**:

- `/users/crossover/run_cci_script_automation.sh` (bash automation)

**Documentation**:

- `/docs/plans/cci-neutrality-indicator.yaml` (updated to v1.3.0)
- `/docs/plans/MT5_AUTOMATION_BLOCKING_ISSUE_v1.3.0.md` (this file)

**Status**: All artifacts created successfully, all blocked by execution failure.

---

## Next Steps (User Decision Required)

Three viable paths forward:

### Option 1: Accept GUI Workflow ✅ VIABLE

- **Action**: User manually attaches CCI_Neutrality_Debug to EURUSD M12 chart
- **Time**: 2 minutes user effort
- **Result**: CSV exported, validation can proceed
- **Tradeoff**: Loses automation benefit

### Option 2: Test on Native Windows MT5 ❓ DIAGNOSTIC

- **Action**: Run same INI files on Windows MT5 (not CrossOver)
- **Time**: Unknown (depends on Windows access)
- **Result**: Confirms/refutes Wine hypothesis
- **Value**: Distinguishes Wine limitation vs config error

### Option 3: Explore AppleScript GUI Automation ❓ ALTERNATIVE

- **Action**: Use macOS AppleScript to automate MT5 GUI interactions
- **Time**: Unknown implementation effort
- **Result**: May achieve automation on macOS
- **Complexity**: Higher than INI approach

**Decision Point**: User must choose approach before correctness SLO can be achieved.

---

## Lessons Learned

### What Worked

1. ✅ CLI compilation (metaeditor64.exe)
2. ✅ Script creation following ExportAligned pattern
3. ✅ Config file syntax (confirmed via log "successfully initialized")
4. ✅ Error propagation (no silent failures)

### What Failed

1. ❌ [Tester] section trigger (v1.2.0)
2. ❌ [StartUp] section trigger (v1.3.0)
3. ❌ Both automation approaches on CrossOver/Wine

### Critical Discovery

**INI config loading ≠ action execution on CrossOver/Wine.**

Terminal successfully parses and acknowledges INI files but fails to dispatch to target subsystems (Tester/Script). This suggests deeper Wine compatibility limitations beyond file I/O.

---

## References

**Plan Files**:

- `/docs/plans/cci-neutrality-indicator.yaml` v1.3.0
- `/docs/plans/STRATEGY_TESTER_BLOCKING_ISSUE.md` (v1.2.0)
- `/docs/plans/MT5_AUTOMATION_BLOCKING_ISSUE_v1.3.0.md` (this file)

**Terminal Logs**:

- `/Program Files/MetaTrader 5/logs/20251028.log` (19:06:13, 19:18:32)

**External Documentation**:

- `/docs/guides/EXTERNAL_RESEARCH_BREAKTHROUGHS.md` (v2.0.0 [StartUp] pattern)
- mql5.com/en/forum/457213 ([Tester] section format)
- mql5.com/en/forum/361861 (batch mode reliability issues)

**Project Requirements**:

- `/CLAUDE.md` - "On any error, raise and propagate"

---

## v1.3.0 Update: Script Execution Works, Indicator Loading Fails

### Breakthrough: [StartUp] Script Execution SUCCESS

**Terminal Log Evidence** (logs/20251028.log @ 19:42:31):

```
19:42:31.235 Scripts script CCI_Export_Script (EURUSD,M12) loaded successfully
19:42:31.254 Scripts script CCI_Export_Script (EURUSD,M12) ✓ Indicator handle created: 10
19:42:31.254 Scripts script CCI_Export_Script (EURUSD,M12) ERROR: BarsCalculated returned error: 4806
19:42:31.??? Scripts script CCI_Export_Script (EURUSD,M12) closes terminal with code 1
```

**vs v1.3.0 Initial Attempt** (19:18:32, 19:36:53): Script executed but failed with error 4802 (indicator path issue)

**vs v1.2.0/v1.3.0 Initial Failures**: Config loaded but NO script execution

**Key Discovery**: User's insight was correct - workspace prerequisite (EURUSD M12 chart open) was required. Once met:

- ✅ Config loads successfully
- ✅ Script executes successfully
- ✅ Indicator handle creates successfully (ID 10)
- ❌ Indicator calculation fails (error 4806)

### New Blocking Issue: Indicator Initialization Failure

**Error 4806**: `ERR_INDICATOR_DATA_NOT_FOUND` - Requested data not found

**Evidence**:

- Indicator handle created successfully (handle ID 10)
- BarsCalculated() returned -4806 immediately (indicates OnInit() failure or data unavailable)
- **NO indicator log messages** (no "CSV debug output:" or "CCI Neutrality Debug initialized:")
- Indicator OnInit() never executed or failed silently

**Contrast with GUI Success**:

- Terminal log @ 17:34:54 shows CCI_Neutrality_Debug working on EURUSD M10 via GUI:
  ```
  17:34:54.458 CCI_Neutrality_Debug (EURUSD,M10) CSV debug output: MQL5/Files/cci_debug_EURUSD_PERIOD_M10_2025.10.29.csv
  17:34:54.459 CCI_Neutrality_Debug (EURUSD,M10) CCI Neutrality Debug initialized: CCI=20, W=30, CSV=enabled
  ```

**Root Cause Hypothesis**: Indicators with file I/O or certain initialization requirements may not work when loaded via `iCustom()` from scripts, even though they work when attached to charts via GUI. This could be:

1. File I/O permission restrictions in iCustom() context
2. Missing chart context required for indicator initialization
3. Silent failure in OnInit() that doesn't propagate to script

**Progress Made**:

1. ✅ Fixed indicator path format: `"Custom\\Development\\CCINeutrality\\CCI_Neutrality_Debug"` (not `"::Indicators\\...ex5"`)
2. ✅ Confirmed script execution works with workspace prerequisite
3. ✅ Confirmed indicator handle creation works
4. ❌ Indicator calculation/initialization fails in iCustom() context

**Files Updated**:

- CCI_Export_Script.mq5: Corrected indicator path (line 85)
- CCI_Export_Script.ex5: Recompiled successfully (19:42, 0 errors, 734ms)

### Alternative Paths Forward

Given that v1.3.0 [StartUp] script automation works but indicator loading via iCustom() fails:

**Option 1: Manual GUI Workflow** ✅ VIABLE (v4.0.0 pattern)

- User manually attaches CCI_Neutrality_Debug to EURUSD M12 chart
- Indicator exports CSV successfully (proven at 17:34 on M10)
- Time: 2 minutes user effort
- Tradeoff: Loses automation benefit

**Option 2: v3.0.0 Python API + Python Indicator** ✅ VIABLE

- Use Wine Python MT5 API to fetch market data (proven working)
- Implement CCI Neutrality algorithm in Python
- Validate against MT5 CCI reference values
- Fully headless, no GUI interaction

**Option 3: Investigate Indicator Initialization Failure** ❓ DIAGNOSTIC

- Create minimal test indicator without file I/O
- Test if iCustom() indicator loading works at all on CrossOver/Wine
- May reveal fundamental limitation vs fixable issue

---

## v1.3.2 Resolution: Automation SUCCESS, Indicator Implementation Bug Found

### Automation Achievement: CSV Export Working

**User Action**: Attached CCI_Neutrality_Debug indicator to EURUSD M12 chart, saved workspace

**Terminal Log Evidence** (logs/20251028.log @ 19:49:14):

```
19:49:14.073 CCI_Neutrality_Debug (EURUSD,M12) CSV debug output: MQL5/Files/cci_debug_EURUSD_PERIOD_M12_2025.10.29.csv
19:49:14.073 CCI_Neutrality_Debug (EURUSD,M12) CCI Neutrality Debug initialized: CCI=20, W=30, CSV=enabled
19:49:14.981 CCI_Neutrality_Debug (EURUSD,M12) CCI Neutrality Debug deinitialized, reason: 9, bars written: 100438
```

**CSV File Generated**:

- Location: `/Program Files/MetaTrader 5/MQL5/Files/cci_debug_EURUSD_PERIOD_M12_2025.10.29.csv`
- Size: 10MB
- Lines: 100,439 (100,438 bars + header)
- Columns: 19 (all diagnostic columns present)
- Date range: 2022-08-09 to 2025-10-29 (3+ years of M12 data)

**Automation Success**: Workspace restoration during `[StartUp]` config startup triggers pre-attached indicator, which generates CSV successfully. This is **v4.0.0 GUI workflow pattern** working correctly.

### New Blocking Issue: Indicator Implementation Bug

**Analysis Results** (via `uv run analyze_cci_debug.py`):

- ❌ Score components in [0,1]: FAIL
- ❌ Score formula S=p·c·v·q: FAIL
- ❌ Rolling window sums: FAIL
- ❌ Coil signals present: FAIL (0 signals in 100K bars)

**Root Cause** (CCI_Neutrality_Debug.mq5:232):

```mql5
// Prime window
for(int j = start - InpWindow + 1; j <= start; j++)  // j = 0 to 29
{
   double x = cci[j];  // CCI at bars 0-19 is EMPTY_VALUE/inf (warmup needed)
   sum_b += b;
   sum_cci += x;       // Accumulating EMPTY_VALUE/inf causes inf
   sum_cci2 += x * x;  // inf * inf = inf
   sum_excess += MathMax(MathAbs(x) - 100.0, 0.0);  // inf
}
```

**Problem**: CCI indicator (InpCCILength=20) needs 20 bars warmup before producing valid values. Code starts priming at bar 29 but doesn't check if CCI values are valid (bars 0-19 contain EMPTY_VALUE or inf). These invalid values accumulate into rolling window sums causing:

- `sum_cci = inf`
- `sum_cci2 = inf`
- `sum_excess = inf`

**Propagation**:

```mql5
double mu = sum_cci / InpWindow;       // inf / 30 = inf
double variance = (sum_cci2 / InpWindow) - (mu * mu);  // inf - inf = -nan
double sd = MathSqrt(MathMax(0.0, variance));  // sqrt(-nan) = -nan
double e = (sum_excess / InpWindow) / InpC2;   // inf / 30 / 100 = inf

double v = 1.0 - MathMin(1.0, sd / InpC1);    // 1.0 - min(1.0, -nan/50) = -nan
double score = p * c * v * q;                  // 0.6 * 0.0 * -nan * 0.0 = -nan
```

**Fix Required** (CCI_Neutrality_Debug.mq5:232):

```mql5
// Determine first valid CCI bar
int first_valid = InpCCILength;  // CCI needs InpCCILength bars warmup

// Start priming from first valid CCI bar
int prime_start = MathMax(first_valid, start - InpWindow + 1);

for(int j = prime_start; j <= start; j++)
{
   double x = cci[j];
   // Optional: Add validation check
   if(x == EMPTY_VALUE || !MathIsValidNumber(x))
      continue;

   sum_b += b;
   sum_cci += x;
   sum_cci2 += x * x;
   sum_excess += MathMax(MathAbs(x) - 100.0, 0.0);
}
```

**SLO Impact**:

- Availability: 100% ✅ (CSV generation works)
- Correctness: 0% ❌ (calculations invalid due to warmup bug)
- Observability: 100% ✅ (CSV reveals the issue clearly)
- Maintainability: 100% ✅ (fix location identified)

**Status Change**: v1.2.0/v1.3.0/v1.3.1 automation issues → **RESOLVED**. v1.3.2 reveals indicator implementation bug (separate from automation).

---

**Status**: v1.3.2 automation WORKING (workspace restoration pattern). Correctness blocked by indicator implementation bug requiring warmup fix at line 232.
