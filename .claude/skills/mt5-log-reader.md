# MT5 Log Reader Skill

**Purpose:** Read MT5 Print() output programmatically instead of asking user to check Experts pane

**When to use:** ANY time you need to verify MT5 Print() output from indicators/scripts/EAs

## Log File Location

```bash
Program Files/MetaTrader 5/MQL5/Logs/YYYYMMDD.log
```

**Today's log:**
```bash
Program Files/MetaTrader 5/MQL5/Logs/$(date +%Y%m%d).log
```

## File Format

- **Encoding:** UTF-16LE (with byte order mark)
- **Format:** Tab-separated fields with spaces between characters
- **Fields:** `<code>\t<chart_id>\t<timestamp>\t<indicator_name>\t<message>`

## Commands

### Read last 100 lines (most recent output)
```bash
tail -100 "Program Files/MetaTrader 5/MQL5/Logs/$(date +%Y%m%d).log"
```

### Search for specific indicator
```bash
grep -i "CCI_Rising_Test" "Program Files/MetaTrader 5/MQL5/Logs/$(date +%Y%m%d).log" | tail -50
```

### Search for error messages
```bash
grep -i "ERROR" "Program Files/MetaTrader 5/MQL5/Logs/$(date +%Y%m%d).log"
```

### Read full log for specific script
```bash
grep "Test_PatternDetector" "Program Files/MetaTrader 5/MQL5/Logs/$(date +%Y%m%d).log"
```

## Workflow Pattern

**NEVER ask user to:**
- "Check Experts pane"
- "Look at Toolbox"
- "Copy the output"

**ALWAYS do instead:**
```bash
# 1. Read the log
tail -100 "Program Files/MetaTrader 5/MQL5/Logs/$(date +%Y%m%d).log"

# 2. Parse and analyze
grep "Phase 2" "Program Files/MetaTrader 5/MQL5/Logs/$(date +%Y%m%d).log"

# 3. Tell user the results
```

## Example Usage

### Verify indicator loaded
```bash
grep "CCI Rising Test v0.3.0" "Program Files/MetaTrader 5/MQL5/Logs/$(date +%Y%m%d).log" | tail -5
```

### Check for compilation errors
```bash
grep -i "error\|failed" "Program Files/MetaTrader 5/MQL5/Logs/$(date +%Y%m%d).log" | tail -20
```

### Verify test results
```bash
grep "ALL TESTS PASSED\|Tests Failed" "Program Files/MetaTrader 5/MQL5/Logs/$(date +%Y%m%d).log"
```

## Integration with CSVLogger

**Dual logging pattern** (Option 3):

```mql5
// In MQL5 code
#include "lib/CSVLogger.mqh"

CSVLogger logger;

void LogBoth(string message)
{
  Print(message);              // MT5 log file (human-readable)
  // Future: logger.WriteLine(message);  // CSV file (structured data)
}

// Usage
LogBoth("Phase 2: Test arrow created at " + TimeToString(test_time));
```

**Benefits:**
- User sees output in real-time (Experts pane)
- Claude Code CLI reads logs programmatically (Bash commands)
- CSV provides structured data for analysis (Phase 3+)

## SLO

- **Availability:** 100% (log files always exist when MT5 runs)
- **Correctness:** 100% (log files contain exact Print() output)
- **Observability:** 100% (can grep/search/analyze programmatically)

## Version

- Created: 2025-11-03
- Status: Production
- Use: All MT5 development phases
