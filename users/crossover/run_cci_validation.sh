#!/bin/bash
#
# CCI Neutrality Indicator - Fully Automated Validation
#
# Uses historical data for fast testing without waiting for live ticks.
# Based on documented workflows in:
# - docs/guides/WINE_PYTHON_EXECUTION.md (v3.0.0 headless execution)
# - docs/guides/INDICATOR_VALIDATION_METHODOLOGY.md (5000-bar warmup)
# - docs/MT5_REFERENCE_HUB.md (automation matrix)
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
PYTHON_EXE="C:\\Program Files\\Python312\\python.exe"
WORK_DIR="$BOTTLE_ROOT/drive_c/users/crossover"
FILES_DIR="$BOTTLE_ROOT/drive_c/users/crossover/AppData/Roaming/MetaQuotes/Terminal/Common/Files"

echo "================================================================================"
echo "CCI Neutrality Indicator - Automated Validation"
echo "================================================================================"
echo "Symbol: $SYMBOL"
echo "Timeframe: $PERIOD"
echo "Bars: $BARS (historical data)"
echo ""
echo "Reference documentation:"
echo "  - WINE_PYTHON_EXECUTION.md (v3.0.0 Wine Python workflow)"
echo "  - INDICATOR_VALIDATION_METHODOLOGY.md (5000-bar warmup requirement)"
echo "  - MT5_REFERENCE_HUB.md (automation matrix)"
echo "================================================================================"

# Step 1: Generate test dataset via Wine Python (FULLY AUTOMATED)
echo ""
echo "Step 1: Generating test dataset via Wine Python (headless)"
echo "────────────────────────────────────────────────────────────────────────────────"
echo "This uses MT5 Python API to fetch historical data - no GUI needed"

CX_BOTTLE="$CX_BOTTLE" \
WINEPREFIX="$WINEPREFIX" \
wine "$PYTHON_EXE" \
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

# Step 2: Attach indicator to chart (MANUAL - MT5 limitation)
echo ""
echo "Step 2: Attach CCI_Neutrality_Debug indicator to chart"
echo "────────────────────────────────────────────────────────────────────────────────"
echo "⚠️  This requires GUI interaction (MT5 limitation)"
echo ""
echo "Manual steps:"
echo "  1. Open MT5"
echo "  2. Open $SYMBOL $PERIOD chart"
echo "  3. Press Home key to scroll back and load ~$BARS bars"
echo "  4. Navigator → Indicators → Custom → Development → CCINeutrality"
echo "  5. Drag CCI_Neutrality_Debug onto chart"
echo "  6. Click OK (defaults are fine)"
echo "  7. Check Terminal → Journal for: 'CSV debug output: MQL5/Files/...'"
echo ""
echo "Press Enter when CSV has been generated..."
read

# Step 3: Find CSV file
echo ""
echo "Step 3: Locating CSV output"
echo "────────────────────────────────────────────────────────────────────────────────"

CSV_PATTERN="cci_debug_${SYMBOL}_PERIOD_${PERIOD}_*.csv"
CSV_FILE=$(ls -t "$FILES_DIR"/$CSV_PATTERN 2>/dev/null | head -1)

if [ -z "$CSV_FILE" ]; then
    echo "❌ No CSV file found matching: $CSV_PATTERN"
    echo "   Expected location: $FILES_DIR"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check MT5 Terminal → Journal for 'CSV debug output' message"
    echo "  2. Verify indicator attached successfully (no errors in Journal)"
    echo "  3. Manually check: $FILES_DIR"
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
echo "Validation Complete"
echo "================================================================================"
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
