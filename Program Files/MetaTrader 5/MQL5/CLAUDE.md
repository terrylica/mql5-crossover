# MQL5 Development Context

**Purpose**: MQL5 source code organization, compilation, and development patterns.

**Navigation**: [Root CLAUDE.md](../../../CLAUDE.md) | [docs/](../../../docs/)

---

## Directory Structure

```
MQL5/
├── Scripts/DataExport/           # Export scripts
│   ├── ExportAligned.mq5 + .ex5  # Main export script (v4.0.0)
│   └── ExportEURUSD.mq5          # Legacy EURUSD exporter
├── Include/DataExport/           # Custom include libraries
│   ├── DataExportCore.mqh        # Core export functionality
│   ├── ExportAlignedCommon.mqh   # Common utilities
│   └── modules/
│       └── RSIModule.mqh         # RSI calculation module
├── Indicators/Custom/            # Project-based organization
│   ├── ProductionIndicators/     # Production-ready
│   ├── PythonInterop/            # Python export workflow
│   ├── Libraries/                # Shared .mqh files
│   └── Development/              # Active development
├── Files/                        # Config and output files
│   ├── export_config.txt         # Active v4.0.0 config
│   └── configs/                  # Example configs
├── Presets/                      # Indicator presets (.set files)
└── Logs/                         # MQL5 runtime logs
```

---

## Compilation (X: Drive Method)

**Critical**: Always use X: drive to avoid path space issues.

```bash
# X: drive = MQL5/ root
# X:\Indicators\... = MQL5/Indicators/...

CX="$HOME/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
"$CX" --bottle "MetaTrader 5" \
  --cx-app "C:/Program Files/MetaTrader 5/MetaEditor64.exe" \
  /log \
  /compile:"X:\\Indicators\\Custom\\Development\\MyIndicator.mq5" \
  /inc:"X:"
```

**Helper Script**: `../../../tools/compile_mql5.sh`

**Skill**: `/mql5-x-compile` (auto-converts paths)

**Reference**: [../../../docs/guides/MQL5_CLI_COMPILATION_SUCCESS.md](../../../docs/guides/MQL5_CLI_COMPILATION_SUCCESS.md)

---

## Key Compilation Notes

| Issue | Solution |
|-------|----------|
| Path has spaces | Use X: drive or copy to C:/ root |
| Exit 0 but no .ex5 | Path problem, check log |
| **Exit 1 but .ex5 exists** | **Success!** Wine returns exit 1 even on success - always verify .ex5 file |
| /inc behavior | OVERRIDES default paths (omit unless needed) |
| CrossOver path | `~/Applications/` NOT `/Applications/` |

**Critical**: Exit code is unreliable. Always verify compilation by checking:
1. `.ex5` file exists and has recent timestamp
2. Per-file `.log` shows "0 errors, 0 warnings"

---

## Encoding

Both UTF-8 and UTF-16LE compile successfully. Prefer UTF-8 for easier editing and git diffs.

**Reference**: [../../../docs/guides/MQL5_ENCODING_SOLUTIONS.md](../../../docs/guides/MQL5_ENCODING_SOLUTIONS.md)

---

## File Types

| Extension | Purpose |
|-----------|---------|
| `.mq5` | MQL5 source code |
| `.ex5` | Compiled executable |
| `.mqh` | Header/include file |
| `.set` | Preset file (UTF-16LE BOM) |

---

## Logs Location

| Log | Path | Encoding |
|-----|------|----------|
| **Per-file compile log** | Same dir as `.mq5` (e.g., `Fvg.log`) | UTF-16LE |
| MetaEditor global | `../../../Program Files/MetaTrader 5/logs/metaeditor.log` | UTF-16LE |
| MQL5 Runtime | `Logs/` (this directory) | UTF-8 |
| Expert Advisors | `../../../Program Files/MetaTrader 5/logs/` | varies |

**Preferred**: Use the per-file `.log` next to your `.mq5` - it's always created and contains the exact compilation result.

```bash
# Read per-file compilation log (UTF-16LE encoded)
cat "/path/to/YourIndicator.log"
# Or with proper decoding:
iconv -f UTF-16LE -t UTF-8 "/path/to/YourIndicator.log"
```

**Skill**: `/mt5-log-reader` (validates compilation and execution)

---

## Quick Links

- [Indicators/Custom/CLAUDE.md](Indicators/Custom/CLAUDE.md) - Indicator organization
- [../../../docs/guides/MT5_FILE_LOCATIONS.md](../../../docs/guides/MT5_FILE_LOCATIONS.md) - Complete path reference
- [../../../docs/guides/BOTTLE_TRACKING.md](../../../docs/guides/BOTTLE_TRACKING.md) - X: drive mapping
