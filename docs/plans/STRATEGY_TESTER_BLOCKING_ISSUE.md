# MT5 Strategy Tester Automation Blocking Issue

**Status**: BLOCKING
**Severity**: CRITICAL
**Date**: 2025-10-29
**Plan**: cci-neutrality-indicator v1.2.0

## Error Summary

**MT5 Strategy Tester does NOT auto-start from `/config` parameter on CrossOver/Wine.**

Terminal successfully loads the configuration file but **does not execute the Strategy Tester**. Instead, it restores the previous workspace and enters normal operation mode.

## Evidence

### Terminal Log Analysis (`logs/20251028.log`)

**First attempt (18:56:52)**:

```
18:56:52.631 Startup successfully initialized from start config "C:\users\crossover\Config\tester_cci_headless.ini"
18:56:52.836 Terminal launched with C:\users\crossover\Config\tester_cci_headless.ini
18:56:55.131 Indicators custom indicator ZigZag_Color_NoRepaint (USDJPY,M5) loaded successfully
18:56:55.249 Indicators custom indicator ZigZag_Color_NoRepaint (BTCUSD,M15) loaded successfully
... (restores previous workspace indicators) ...
```

**Second attempt (19:06:13)** with corrected `[Tester]` section format:

```
19:06:13.163 Startup successfully initialized from start config "C:\users\crossover\Config\tester_cci_headless.ini"
19:06:13.360 Terminal launched with C:\users\crossover\Config\tester_cci_headless.ini"
19:06:15.692 Indicators custom indicator ZigZag_Color_NoRepaint (USDJPY,M5) loaded successfully
... (restores previous workspace indicators) ...
```

**Critical observation**: In both attempts:

- ✅ Config file loads successfully
- ✅ Terminal starts normally
- ❌ NO "Tester: started" messages
- ❌ NO "Tester: loading expert" messages
- ❌ NO tester activity whatsoever

### Configuration File Formats Tested

#### Attempt 1: Flat format (FAILED)

```ini
TestExpert=CCINeutralityTester
TestSymbol=EURUSD
TestPeriod=M12
TestModel=0
TestOptimization=false
TestDateEnable=true
TestFromDate=2025.09.01
TestToDate=2025.10.29
TestShutdownTerminal=true
```

#### Attempt 2: [Tester] section format (FAILED)

```ini
[Tester]
Expert=CCINeutralityTester
Symbol=EURUSD
Period=M12
Model=0
Optimization=false
FromDate=2025.09.01
ToDate=2025.10.29
Visual=false
ShutdownTerminal=1
```

Both formats load successfully but neither triggers tester execution.

## Research Findings

### mql5.com Forum Research

**Source**: https://www.mql5.com/en/forum/457213

- Confirmed `[Tester]` section format is correct
- Multiple users report success with this approach **on Windows**
- One user warns: "A lot of them fail, for no apparent reason"

**Source**: https://www.mql5.com/en/forum/361861

- Discusses batch mode Strategy Tester execution
- Reliability issues noted even on Windows

**Source**: https://www.mql5.com/en/forum/127577

- Terminal command line parameters documented
- `/config` parameter confirmed for startup configuration
- **No parameter documented to force tester start**

### Created Artifacts (All Blocked)

1. **CCINeutralityTester.mq5** - Wrapper EA using iCustom()
   - Status: Compiled successfully (11KB, 0 errors)
   - Purpose: Load CCI_Neutrality_Debug indicator in Strategy Tester
   - Outcome: UNTESTED (tester won't start)

2. **tester_cci_headless.ini** - Strategy Tester configuration
   - Status: Created with correct [Tester] section format
   - Purpose: Configure headless tester execution
   - Outcome: INEFFECTIVE (loads but doesn't trigger tester)

3. **run_cci_validation_headless.sh** - Full automation script
   - Status: Created, executes without errors
   - Step 1 (Wine Python data generation): SUCCESS ✅
   - Step 2 (Strategy Tester execution): BLOCKED ❌
   - Step 3 (CSV analysis): BLOCKED ❌

## Root Cause Analysis

### Hypothesis 1: CrossOver/Wine Limitation

The `/config` parameter with `[Tester]` section may work on **Windows MT5** but not on **CrossOver/Wine MT5**. Wine may not fully implement the MT5 tester startup automation API.

**Evidence**:

- Forum posts report success on Windows
- Both correct and incorrect formats fail identically on CrossOver
- Terminal loads config (Wine translates this correctly)
- But tester subsystem doesn't start (Wine may not translate this)

### Hypothesis 2: Missing Trigger Command

The `/config` parameter may only **configure** the tester settings but not **trigger** its execution. There may be a separate undocumented command or API call needed to actually start the tester.

**Evidence**:

- No `/start-tester` or similar parameter found in documentation
- Terminal behavior suggests config is applied but not acted upon
- Workspace restore indicates normal startup, not tester startup

### Hypothesis 3: Additional Prerequisites

Strategy Tester automation may require:

- Pre-downloaded tick/bar data (one forum post mentions this)
- Prior manual tester execution to initialize tester subsystem
- Specific registry keys or configuration files not present on macOS Wine

## Impact Assessment

### Blocked Functionality

- ❌ Automated headless validation workflow
- ❌ Continuous integration testing
- ❌ Batch indicator validation
- ❌ Reproducible testing without GUI interaction

### Affected SLOs

- **Correctness**: 0% (target 100%) - Cannot validate calculations
- **Availability**: 100% (indicator compiles and loads)
- **Observability**: 100% (CSV logging functional)
- **Maintainability**: 100% (code follows audit compliance)

### Alternative Approaches Evaluated

| Approach                   | Viability       | Reason                                                                |
| -------------------------- | --------------- | --------------------------------------------------------------------- |
| Strategy Tester CLI        | ❌ BLOCKED      | This document                                                         |
| Python MT5 API             | ❌ NOT VIABLE   | No indicator buffer access (copy_buffer() requires running indicator) |
| GUI workflow (manual)      | ✅ VIABLE       | Requires user to attach indicator to chart                            |
| AppleScript/GUI automation | ❓ NOT EXPLORED | May work but adds complexity                                          |

## Error Propagation (No Workarounds)

Per project requirements: **"On any error, raise and propagate—no fallbacks, defaults, retries, or silent handling."**

**This error is being propagated WITHOUT attempting workarounds:**

- ❌ NO automatic fallback to GUI workflow
- ❌ NO retry with different parameters
- ❌ NO silent acceptance of partial functionality
- ✅ Explicit documentation of blocking issue
- ✅ Updated plan file to v1.2.0 with detailed findings
- ✅ Clear communication of impact and alternatives

## Files Modified

1. `/docs/plans/cci-neutrality-indicator.yaml`
   - Updated to v1.2.0
   - Added 3 new findings (EA, INI, blocking issue)
   - Updated blocked section with Strategy Tester non-start details
   - Added v1.2.0 changelog entry

2. `/docs/plans/STRATEGY_TESTER_BLOCKING_ISSUE.md` (this file)
   - Error propagation document
   - Evidence collection
   - Root cause analysis
   - No workarounds provided

3. Created but blocked artifacts:
   - `/Program Files/MetaTrader 5/MQL5/Experts/CCINeutralityTester.mq5`
   - `/Program Files/MetaTrader 5/MQL5/Experts/CCINeutralityTester.ex5`
   - `/users/crossover/Config/tester_cci_headless.ini`
   - `/users/crossover/run_cci_validation_headless.sh`

## Next Steps (User Decision Required)

The blocking issue has been raised and propagated. Three options available:

1. **Accept GUI workflow** - Manual indicator attachment required (2 minutes user effort)
2. **Explore AppleScript automation** - GUI automation via macOS AppleScript (unknown effort)
3. **Wait for Windows MT5 testing** - Test on native Windows to confirm hypothesis 1

**Decision point**: User must choose approach before validation can proceed.

## References

- Plan file: `/docs/plans/cci-neutrality-indicator.yaml` v1.2.0
- Terminal logs: `/Program Files/MetaTrader 5/logs/20251028.log`
- Research: mql5.com forums (links in plan file)
- Project requirements: CLAUDE.md "On any error, raise and propagate"
