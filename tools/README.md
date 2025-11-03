# MQL5 Compilation Tools

## ⚠️ CRITICAL: Always Use X: Drive for CLI Compilation

**DO NOT** compile using full paths with spaces like `C:/Program Files/MetaTrader 5/MQL5/...`
Wine/CrossOver has a known bug where these paths cause **silent compilation failures** (reports success but doesn't create .ex5 files).

**ALWAYS USE X: DRIVE** instead: `X:\Indicators\Custom\...`

## Quick Start

### Option 1: Helper Script (Recommended)

```bash
cd /Users/terryli/Library/Application\ Support/CrossOver/Bottles/MetaTrader\ 5/drive_c

# Compile any MQL5 file (path relative to MQL5 folder)
./tools/compile_mql5.sh "Indicators/Custom/Development/CCINeutrality/CCI_Neutrality_Adaptive.mq5"

# The script automatically:
# - Converts path to X: drive format
# - Verifies X: drive mapping exists
# - Compiles using proper Wine/CrossOver flags
# - Reports success/failure
```

### Option 2: Direct Command

```bash
CX="$HOME/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
"$CX" --bottle "MetaTrader 5" \
  --cx-app "C:/Program Files/MetaTrader 5/MetaEditor64.exe" \
  /log \
  /compile:"X:\\Indicators\\Custom\\Development\\CCINeutrality\\CCI_Neutrality_Adaptive.mq5" \
  /inc:"X:"
```

**Key points:**
- Use `X:\` prefix (not `C:\Program Files\...`)
- Escape backslashes: `X:\\Indicators\\...`
- Use `/inc:"X:"` for include directory
- Compilation takes ~1 second

## X: Drive Mapping

The X: drive is a symlink that maps to the MQL5 folder, eliminating path spaces:

```
X:\Indicators\Custom\file.mq5  →  MQL5/Indicators/Custom/file.mq5
X:\Scripts\file.mq5            →  MQL5/Scripts/file.mq5
X:\Include\file.mqh            →  MQL5/Include/file.mqh
```

**Verify X: drive exists:**
```bash
ls -la "$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5/dosdevices/" | grep "x:"
```

**If not found, create it:**
```bash
cd "$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5/dosdevices"
ln -s "../drive_c/Program Files/MetaTrader 5/MQL5" "x:"
```

## Scripts in This Directory

### `compile_mql5.sh`

**Purpose:** Compile MQL5 indicators/scripts via CLI using X: drive

**Usage:**
```bash
./tools/compile_mql5.sh <relative_path_from_MQL5>
```

**Examples:**
```bash
# Compile CCI Neutrality indicator
./tools/compile_mql5.sh "Indicators/Custom/Development/CCINeutrality/CCI_Neutrality_Adaptive.mq5"

# Compile export script
./tools/compile_mql5.sh "Scripts/DataExport/ExportAligned.mq5"

# Compile consecutive pattern indicator
./tools/compile_mql5.sh "Indicators/Custom/Development/ConsecutivePattern/cc.mq5"
```

**Features:**
- Auto-converts Unix paths to Windows X: drive format
- Verifies X: drive mapping exists (creates if missing)
- Validates source file exists before compilation
- Shows compilation log on failure
- Reports .ex5 file size and timestamp on success

## Troubleshooting

### Issue: "❌ Compilation failed: .ex5 not created"

**Check compilation log:**
```bash
# View the log for your file
cat "Program Files/MetaTrader 5/MQL5/Indicators/Custom/Development/CCINeutrality/CCI_Neutrality_Adaptive.log"
```

Common causes:
- Syntax errors in MQL5 code
- Missing `#include` dependencies
- Invalid function calls

### Issue: "X: drive mapping not found"

**Solution:** Run the script anyway - it will auto-create the mapping:
```bash
./tools/compile_mql5.sh "Indicators/Custom/MyIndicator.mq5"
# Output: ⚠️  X: drive mapping not found, creating...
#         ✅ X: drive created
```

### Issue: Silent failure (no error, no .ex5)

**Cause:** You're using direct paths with spaces (wrong method)

**Solution:** Use X: drive method:
```bash
# ❌ WRONG - Silent failure
/compile:"C:/Program Files/MetaTrader 5/MQL5/Indicators/Custom/file.mq5"

# ✅ CORRECT - Works reliably
/compile:"X:\\Indicators\\Custom\\file.mq5" /inc:"X:"
```

## Documentation References

- **Skill documentation:** `.claude/skills/mql5-x-compile/README.md`
- **CLAUDE.md:** See "Key Commands" section (line 329-342)
- **Single Source of Truth:** CLAUDE.md table (line 227)
- **CHANGELOG.md:** See v4.24 Technical Details (line 85-90)

## Why X: Drive?

| Method | Path | Result |
|--------|------|--------|
| ❌ Direct path | `C:/Program Files/.../file.mq5` | Silent failure (Wine bug) |
| ✅ X: drive | `X:\Indicators\Custom\file.mq5` | Success (~1s) |
| ⚠️ Temp file workaround | `C:/TempCompile.mq5` | Works but hacky |
| ⚠️ GUI compilation | Open MetaEditor, press F7 | Works but not automatable |

**Always use X: drive for CLI compilation!**
