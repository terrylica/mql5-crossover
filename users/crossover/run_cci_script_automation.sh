#!/bin/bash
#
# CCI Neutrality Indicator - Script Automation via [StartUp] Section
#
# APPROACH: Uses proven v2.0.0 [StartUp] script pattern instead of [Tester]
# Based on EXTERNAL_RESEARCH_BREAKTHROUGHS.md findings:
# - [StartUp] section triggers script execution (documented as working)
# - [Tester] section fails to start tester on CrossOver/Wine (v1.2.0 finding)
#
# This is the creative alternative discovered after Strategy Tester blocking issue.
#

set -euo pipefail

# Configuration
SYMBOL="${1:-EURUSD}"
PERIOD="${2:-M12}"
BARS="${3:-5000}"

# Paths
BOTTLE_ROOT="$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5"
WINEPREFIX="$BOTTLE_ROOT"
CX_BOTTLE="MetaTrader 5"
CROSSOVER_BIN="$HOME/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin"
TERMINAL_EXE="C:\\\\Program Files\\\\MetaTrader 5\\\\terminal64.exe"
CONFIG_FILE="C:\\\\users\\\\crossover\\\\Config\\\\startup_cci_export.ini"
WORK_DIR="$BOTTLE_ROOT/drive_c/users/crossover"
FILES_DIR="$BOTTLE_ROOT/drive_c/users/crossover/AppData/Roaming/MetaQuotes/Terminal/Common/Files"

echo "================================================================================"
echo "CCI Neutrality Indicator - Script Automation via [StartUp]"
echo "================================================================================"
echo "APPROACH: v2.0.0 Script Pattern (not v1.2.0 Strategy Tester)"
echo "Symbol: $SYMBOL"
echo "Timeframe: $PERIOD"
echo "Bars: $BARS (historical data)"
echo ""
echo "Reference:"
echo "  - docs/guides/EXTERNAL_RESEARCH_BREAKTHROUGHS.md (Script automation)"
echo "  - [StartUp] section + ShutdownTerminal=1 pattern"
echo "================================================================================"

# Step 1: Generate test dataset via Wine Python (FULLY AUTOMATED)
echo ""
echo "Step 1: Generating test dataset via Wine Python (headless)"
echo "────────────────────────────────────────────────────────────────────────────────"

CX_BOTTLE="$CX_BOTTLE" \
WINEPREFIX="$WINEPREFIX" \
wine "C:\\Program Files\\Python312\\python.exe" \
  "C:\\users\\crossover\\generate_test_data.py" \
  --symbol "$SYMBOL" \
  --period "$PERIOD" \
  --bars "$BARS"

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Test data generation FAILED"
    exit 1
fi

echo ""
echo "✅ Test data generated successfully"

# Step 2: Run Script via [StartUp] automation (FULLY AUTOMATED)
echo ""
echo "Step 2: Running CCI_Export_Script via [StartUp] section"
echo "────────────────────────────────────────────────────────────────────────────────"
echo "This will:"
echo "  - Launch MT5 terminal64.exe with startup config"
echo "  - Execute CCI_Export_Script.ex5 (loads indicator via iCustom)"
echo "  - Indicator runs OnInit (opens CSV), OnCalculate (writes data), OnDeinit (closes CSV)"
echo "  - Shutdown terminal automatically"
echo ""
echo "Expected duration: 10-20 seconds"
echo ""

# Kill any existing MT5 processes
echo "Checking for running MT5 processes..."
MT5_PIDS=$(ps aux | grep -E "terminal64|wineserver" | grep -v grep | awk '{print $2}' || true)
if [ -n "$MT5_PIDS" ]; then
    echo "Killing existing MT5 processes: $MT5_PIDS"
    echo "$MT5_PIDS" | xargs kill -9 2>/dev/null || true
    sleep 3
fi

# Run Script via [StartUp]
echo "Launching Script automation..."

CX_BOTTLE="$CX_BOTTLE" \
WINEPREFIX="$WINEPREFIX" \
timeout 120 "$CROSSOVER_BIN/wine" "$TERMINAL_EXE" \
  /portable \
  /skipupdate \
  /config:"$CONFIG_FILE" &

TERMINAL_PID=$!
echo "Terminal PID: $TERMINAL_PID"

# Wait for script to complete (monitor for shutdown)
echo "Waiting for script execution to complete..."
wait $TERMINAL_PID 2>/dev/null || true

echo ""
echo "✅ Script execution complete"

# Give filesystem time to sync
sleep 2

# Step 3: Find CSV file
echo ""
echo "Step 3: Locating CSV output"
echo "────────────────────────────────────────────────────────────────────────────────"

CSV_PATTERN="cci_debug_${SYMBOL}_PERIOD_${PERIOD}_*.csv"
CSV_FILE=$(ls -t "$FILES_DIR"/$CSV_PATTERN 2>/dev/null | head -1 || true)

if [ -z "$CSV_FILE" ]; then
    echo "❌ No CSV file found matching: $CSV_PATTERN"
    echo "   Expected location: $FILES_DIR"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check if script actually ran (look for Terminal/Journal logs)"
    echo "  2. Check MT5 logs: $BOTTLE_ROOT/drive_c/Program Files/MetaTrader 5/logs/"
    echo "  3. Verify script is in correct location: MQL5/Scripts/CCINeutrality/"
    echo ""
    echo "This error is propagated per user requirement (no silent handling)."
    exit 1
fi

echo "✅ Found CSV: $(basename "$CSV_FILE")"
echo "   Size: $(du -h "$CSV_FILE" | cut -f1)"
echo "   Lines: $(wc -l < "$CSV_FILE")"

# Step 4: Run Python analysis
echo ""
echo "Step 4: Running automated analysis"
echo "────────────────────────────────────────────────────────────────────────────────"

cd "$WORK_DIR"
python3 analyze_cci_debug.py

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Analysis FAILED"
    exit 1
fi

# Summary
echo ""
echo "================================================================================"
echo "Validation Complete ([StartUp] Script Automation)"
echo "================================================================================"
echo ""
echo "✅ Script automation successful - no GUI interaction required!"
echo ""
echo "Review the analysis output above. All diagnostics should show ✓ PASS."
echo ""
echo "Approach used:"
echo "  ✓ [StartUp] section (v2.0.0 pattern)"
echo "  ✓ CCI_Export_Script.ex5 (loads indicator via iCustom)"
echo "  ✓ Indicator CSV export (built-in functionality)"
echo ""
echo "Files generated:"
echo "  - Test data: $WORK_DIR/test_data_${SYMBOL}_${PERIOD}_${BARS}bars.csv"
echo "  - Debug CSV: $CSV_FILE"
echo ""
echo "================================================================================"
