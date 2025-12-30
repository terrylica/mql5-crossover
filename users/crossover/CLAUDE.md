# Python Workspace Context

**Purpose**: Python utilities for MT5 data export, validation, and indicator development.

**Navigation**: [Root CLAUDE.md](../../CLAUDE.md) | [docs/](../../docs/)

---

## Environment Requirements

```bash
# Wine Python environment (inside CrossOver bottle)
# Python 3.12+ with:
# - MetaTrader5 5.0.5328
# - NumPy 1.26.4 (NOT 2.x - compatibility issues)

# Critical environment variables for Wine execution
CX_BOTTLE="MetaTrader 5"  # Mandatory for CrossOver wine wrapper
WINEPREFIX="$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5"
```

---

## Core Scripts

| Script | Version | Purpose |
|--------|---------|---------|
| `export_aligned.py` | v3.0.0 | Wine Python data export (headless, production) |
| `validate_indicator.py` | v1.0.0 | Universal indicator validation (≥0.999 correlation) |
| `generate_export_config.py` | v4.0.0 | Config file generator for GUI exports |
| `test_mt5_connection.py` | - | MT5 connection diagnostics |
| `test_xauusd_info.py` | - | Symbol information testing |

### Deprecated

| Script | Replacement |
|--------|-------------|
| `validate_export.py` | Use `validate_indicator.py` instead |

---

## Python Indicators

| Module | Version | Correlation |
|--------|---------|-------------|
| `indicators/laguerre_rsi.py` | v1.0.0 | 1.000000 (validated) |
| `indicators/__init__.py` | - | Package initialization |

---

## Quick Commands

### Export Data (v3.0.0 Headless)

```bash
CX_BOTTLE="MetaTrader 5" \
WINEPREFIX="$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5" \
wine "C:\\Program Files\\Python312\\python.exe" \
  "C:\\users\\crossover\\export_aligned.py" \
  --symbol EURUSD --period M1 --bars 5000
```

### Validate Indicator

```bash
python validate_indicator.py \
  --csv /path/to/Export_EURUSD_PERIOD_M1.csv \
  --indicator laguerre_rsi \
  --threshold 0.999
```

### Generate Config (v4.0.0)

```bash
python generate_export_config.py \
  --symbol EURUSD \
  --timeframe M1 \
  --bars 1000 \
  --output ../Program\ Files/MetaTrader\ 5/MQL5/Files/export_config.txt
```

---

## Output Locations

| Type | Path |
|------|------|
| CSV Exports | `exports/` (local to this directory) |
| Config Files | `../Program Files/MetaTrader 5/MQL5/Files/` |
| Example Configs | `../Program Files/MetaTrader 5/MQL5/Files/configs/` |

---

## Validation Methodology

**Critical Requirements**:

1. **5000-bar warmup**: Python implementations need identical historical context as MQL5
2. **ATR expanding window**: MQL5 uses `sum/period` for first N bars (not pandas rolling)
3. **RSI formula**: Use `alpha=1/period` (not `span=period`)
4. **Column normalization**: Handle MT5 column naming variations

**Reference**: [../../docs/guides/INDICATOR_VALIDATION_METHODOLOGY.md](../../docs/guides/INDICATOR_VALIDATION_METHODOLOGY.md)

---

## Path Navigation (macOS ↔ Wine)

| Context | Path Style |
|---------|------------|
| macOS native | `~/Library/.../drive_c/users/crossover/` |
| Wine Python | `C:\users\crossover\` |
| CSV copy | macOS native paths |

**Reference**: [../../docs/guides/WINE_PYTHON_EXECUTION.md](../../docs/guides/WINE_PYTHON_EXECUTION.md)
