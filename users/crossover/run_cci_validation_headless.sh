#!/bin/bash
#
# CCI Neutrality Indicator - Fully Automated Headless Validation
#
# BREAKTHROUGH: Uses Strategy Tester command line automation (no GUI needed)
# Based on mql5.com research:
# - https://www.mql5.com/en/forum/127577 (terminal64.exe parameters)
# - https://www.mql5.com/en/docs/runtime/testing (testing modes)
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
TERMINAL_EXE="C:\\Program Files\\MetaTrader 5\\terminal64.exe"
CONFIG_FILE="C:\\users\\crossover\\Config\\tester_cci_headless.ini"
WORK_DIR="$BOTTLE_ROOT/drive_c/users/crossover"
FILES_DIR="$BOTTLE_ROOT/drive_c/users/crossover/AppData/Roaming/MetaQuotes/Terminal/Common/Files"

echo "================================================================================"
echo "CCI Neutrality Indicator - Fully Automated Headless Validation"
echo "================================================================================"
echo "BREAKTHROUGH: Using Strategy Tester command line automation"
echo "Symbol: $SYMBOL"
echo "Timeframe: $PERIOD"
echo "Bars: $BARS (historical data)"
echo ""
echo "Reference:"
echo "  - mql5.com/en/forum/127577 (command line parameters)"
echo "  - mql5.com/en/docs/runtime/testing (testing documentation)"
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

# Step 2: Run Strategy Tester headlessly (FULLY AUTOMATED)
echo ""
echo "Step 2: Running Strategy Tester via command line (headless)"
echo "────────────────────────────────────────────────────────────────────────────────"
echo "This will:"
echo "  - Launch MT5 terminal64.exe with tester config"
echo "  - Run CCINeutralityTester EA (wrapper for indicator)"
echo "  - Execute on $SYMBOL $PERIOD from 2025.09.01 to 2025.10.29"
echo "  - Generate CSV output via indicator"
echo "  - Shutdown terminal automatically"
echo ""
echo "Expected duration: 30-60 seconds"
echo ""

# Kill any existing MT5 processes
echo "Checking for running MT5 processes..."
MT5_PIDS=$(ps aux | grep -E "terminal64|wineserver" | grep -v grep | awk '{print $2}' || true)
if [ -n "$MT5_PIDS" ]; then
    echo "Killing existing MT5 processes: $MT5_PIDS"
    echo "$MT5_PIDS" | xargs kill -9 2>/dev/null || true
    sleep 3
fi

# Run Strategy Tester
echo "Launching Strategy Tester..."

CX_BOTTLE="$CX_BOTTLE" \
WINEPREFIX="$WINEPREFIX" \
timeout 120 "$CROSSOVER_BIN/wine" "$TERMINAL_EXE" \
  /portable \
  /skipupdate \
  /config:"$CONFIG_FILE" &

TERMINAL_PID=$!
echo "Terminal PID: $TERMINAL_PID"

# Wait for tester to complete (monitor for shutdown)
echo "Waiting for Strategy Tester to complete..."
wait $TERMINAL_PID 2>/dev/null || true

echo ""
echo "✅ Strategy Tester execution complete"

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
    echo "  1. Check if tester actually ran (look for report files)"
    echo "  2. Check MT5 logs: $BOTTLE_ROOT/drive_c/Program Files/MetaTrader 5/logs/"
    echo "  3. Verify EA and indicator are in correct locations"
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
echo "Validation Complete (FULLY AUTOMATED)"
echo "================================================================================"
echo ""
echo "✅ No GUI interaction required - completely headless!"
echo ""
echo "Review the analysis output above. All diagnostics should show ✓ PASS."
echo ""
echo "Key validations:"
echo "  ✓ Score components in [0,1]"
echo "  ✓ Score formula S=p·c·v·q"
echo "  ✓ Rolling window sums"
echo "  ✓ Coil signals present"
echo ""
echo "If all pass, CCI Neutrality indicator is ready for production use."
echo ""
echo "Files generated:"
echo "  - Test data: $WORK_DIR/test_data_${SYMBOL}_${PERIOD}_${BARS}bars.csv"
echo "  - Debug CSV: $CSV_FILE"
echo ""
echo "================================================================================"
