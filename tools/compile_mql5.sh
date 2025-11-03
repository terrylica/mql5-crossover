#!/bin/bash
#
# MQL5 CLI Compilation Helper for Wine/CrossOver
#
# Usage: ./compile_mql5.sh <relative_path_from_MQL5>
#
# Uses X: drive mapping to avoid "Program Files" path spaces.
# X: drive maps to MQL5 folder: X:\Indicators\... = MQL5/Indicators/...
#
# Examples:
#   ./compile_mql5.sh "Indicators/Custom/MyIndicator.mq5"
#   ./compile_mql5.sh "Scripts/DataExport/ExportAligned.mq5"
#   ./compile_mql5.sh "Indicators/Custom/Development/CCINeutrality/CCI_Neutrality_Adaptive.mq5"
#

set -euo pipefail

# Configuration
BOTTLE_PATH="$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5"
CX="$HOME/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
BOTTLE="MetaTrader 5"
ME="C:/Program Files/MetaTrader 5/MetaEditor64.exe"

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <relative_path_from_MQL5>"
    echo ""
    echo "Path should be relative to MQL5 folder (no MQL5/ prefix needed):"
    echo "  $0 'Indicators/Custom/MyIndicator.mq5'"
    echo "  $0 'Scripts/DataExport/ExportAligned.mq5'"
    exit 1
fi

RELATIVE_PATH="$1"

# Strip leading MQL5/ if present
RELATIVE_PATH="${RELATIVE_PATH#MQL5/}"
RELATIVE_PATH="${RELATIVE_PATH#Program Files/MetaTrader 5/MQL5/}"

# Convert forward slashes to backslashes for Windows path
X_DRIVE_PATH="X:\\${RELATIVE_PATH//\//\\}"

# Full filesystem path for verification
FULL_PATH="$BOTTLE_PATH/drive_c/Program Files/MetaTrader 5/MQL5/$RELATIVE_PATH"
BASENAME=$(basename "$RELATIVE_PATH" .mq5)
TARGET_DIR=$(dirname "$FULL_PATH")
EX5_PATH="$TARGET_DIR/${BASENAME}.ex5"

echo "=== MQL5 CLI Compilation Helper (X: Drive) ==="
echo "Source: $RELATIVE_PATH"
echo "X: path: $X_DRIVE_PATH"
echo "Output: $EX5_PATH"
echo ""

# Verify source exists
if [ ! -f "$FULL_PATH" ]; then
    echo "❌ Source file not found: $FULL_PATH"
    exit 1
fi

# Verify X: drive mapping exists
if [ ! -L "$BOTTLE_PATH/dosdevices/x:" ]; then
    echo "⚠️  X: drive mapping not found, creating..."
    cd "$BOTTLE_PATH/dosdevices"
    ln -s "../drive_c/Program Files/MetaTrader 5/MQL5" "x:"
    echo "✅ X: drive created"
fi

# Compile using X: drive path
echo "[1/2] Compiling..."
"$CX" --bottle "$BOTTLE" --cx-app "$ME" /log /compile:"$X_DRIVE_PATH" /inc:"X:" || true

sleep 2

# Check if compilation succeeded
if [ ! -f "$EX5_PATH" ]; then
    echo "❌ Compilation failed: .ex5 not created"
    echo ""
    echo "Check compilation log:"
    LOG_FILE="$TARGET_DIR/${BASENAME}.log"
    if [ -f "$LOG_FILE" ]; then
        echo "Log: $LOG_FILE"
        tail -20 "$LOG_FILE" 2>/dev/null || echo "(Unable to read log file)"
    else
        echo "No log file found at: $LOG_FILE"
    fi
    exit 1
fi

echo "[2/2] Compilation successful!"
echo ""
echo "✅ Done!"
ls -lh "$EX5_PATH"
