#!/bin/bash
#
# MQL5 CLI Compilation Helper for Wine/CrossOver
#
# Usage: ./compile_mql5.sh <source.mq5> [target_directory]
#
# Workaround for Wine/CrossOver issue: Long paths with spaces cause silent
# CLI compilation failures. This script:
# 1. Copies source to simple path (C:/TempCompile.mq5)
# 2. Compiles from simple path
# 3. Copies .ex5 back to target location
#
# Example:
#   ./compile_mql5.sh \
#     "Program Files/MetaTrader 5/MQL5/Indicators/Custom/MyIndicator.mq5" \
#     "Program Files/MetaTrader 5/MQL5/Indicators/Custom"
#

set -euo pipefail

# Configuration
BOTTLE_PATH="$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5"
CX="$HOME/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
BOTTLE="MetaTrader 5"
ME="C:/Program Files/MetaTrader 5/MetaEditor64.exe"
INC="C:/Program Files/MetaTrader 5/MQL5"

# Temp paths (simple, no spaces)
TEMP_SOURCE="$BOTTLE_PATH/drive_c/TempCompile.mq5"
TEMP_EX5="$BOTTLE_PATH/drive_c/TempCompile.ex5"

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <source.mq5> [target_directory]"
    echo ""
    echo "Example:"
    echo "  $0 'Program Files/MetaTrader 5/MQL5/Indicators/Custom/MyIndicator.mq5'"
    echo "  $0 'MyIndicator.mq5' 'Program Files/MetaTrader 5/MQL5/Indicators/Custom'"
    exit 1
fi

SOURCE_PATH="$1"
TARGET_DIR="${2:-}"

# If source path is relative, prepend bottle drive_c
if [[ "$SOURCE_PATH" != /* ]]; then
    SOURCE_PATH="$BOTTLE_PATH/drive_c/$SOURCE_PATH"
fi

# If no target directory specified, use source directory
if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR=$(dirname "$SOURCE_PATH")
else
    # If target is relative, prepend bottle drive_c
    if [[ "$TARGET_DIR" != /* ]]; then
        TARGET_DIR="$BOTTLE_PATH/drive_c/$TARGET_DIR"
    fi
fi

# Extract filename without extension
BASENAME=$(basename "$SOURCE_PATH" .mq5)

echo "=== MQL5 CLI Compilation Helper ==="
echo "Source: $SOURCE_PATH"
echo "Target: $TARGET_DIR/${BASENAME}.ex5"
echo ""

# Step 1: Copy to simple path
echo "[1/4] Copying source to temp location..."
cp "$SOURCE_PATH" "$TEMP_SOURCE"

# Step 2: Compile
echo "[2/4] Compiling..."
"$CX" --bottle "$BOTTLE" --cx-app "$ME" \
    /log \
    /compile:"C:/TempCompile.mq5" \
    /inc:"$INC"

sleep 1

# Step 3: Check if compilation succeeded
if [ ! -f "$TEMP_EX5" ]; then
    echo "❌ Compilation failed: .ex5 not created"
    echo ""
    echo "Check compilation log:"
    LOG_PATH=$(find "$BOTTLE_PATH/drive_c/Program Files/MetaTrader 5/MQL5" -name "TempCompile.log" 2>/dev/null | head -1)
    if [ -n "$LOG_PATH" ]; then
        tail -20 "$LOG_PATH"
    fi
    rm -f "$TEMP_SOURCE"
    exit 1
fi

echo "[3/4] Compilation successful!"
ls -lh "$TEMP_EX5"

# Step 4: Copy to target
echo "[4/4] Copying .ex5 to target location..."
mkdir -p "$TARGET_DIR"
cp "$TEMP_EX5" "$TARGET_DIR/${BASENAME}.ex5"

# Cleanup
rm -f "$TEMP_SOURCE" "$TEMP_EX5"

echo ""
echo "✅ Done!"
echo "Output: $TARGET_DIR/${BASENAME}.ex5"
ls -lh "$TARGET_DIR/${BASENAME}.ex5"
