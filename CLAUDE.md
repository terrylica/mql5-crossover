# mql5-crossover Project Memory

**Architecture**: Link Farm + Hub-and-Spoke with Progressive Disclosure

---

## Quick Start

**First Time?** Start with these 3 documents:

1. [MQL5_TO_PYTHON_MIGRATION_GUIDE.md](docs/guides/MQL5_TO_PYTHON_MIGRATION_GUIDE.md) - 7-phase workflow (2-4 hours)
2. [LESSONS_LEARNED_PLAYBOOK.md](docs/guides/LESSONS_LEARNED_PLAYBOOK.md) - 8 critical gotchas
3. [INDICATOR_MIGRATION_CHECKLIST.md](docs/templates/INDICATOR_MIGRATION_CHECKLIST.md) - Copy-paste checklist

**Export Data?**
- Headless: [WINE_PYTHON_EXECUTION.md](docs/guides/WINE_PYTHON_EXECUTION.md) (v3.0.0)
- GUI: [V4_FILE_BASED_CONFIG_WORKFLOW.md](docs/guides/V4_FILE_BASED_CONFIG_WORKFLOW.md) (v4.0.0)

---

## Navigation

| Location | Content |
|----------|---------|
| [docs/](docs/CLAUDE.md) | Documentation hub, SSOT table, plans, reports |
| [docs/guides/](docs/guides/CLAUDE.md) | Step-by-step workflows (18 files) |
| [docs/reports/](docs/reports/CLAUDE.md) | Validation results, assessments (16 files) |
| [docs/archive/](docs/archive/CLAUDE.md) | Legacy knowledge, dead ends (8 files) |
| [users/crossover/](users/crossover/CLAUDE.md) | Python workspace utilities |
| [MQL5/](Program%20Files/MetaTrader%205/MQL5/CLAUDE.md) | MQL5 source and compilation |
| [MQL5/Indicators/Custom/](Program%20Files/MetaTrader%205/MQL5/Indicators/Custom/CLAUDE.md) | Indicator organization |

**Task Navigator**: [docs/MT5_REFERENCE_HUB.md](docs/MT5_REFERENCE_HUB.md) - Decision trees, automation matrix

---

## Environment Variables

```bash
# Add to ~/.zshrc
CROSSOVER_BOTTLE="$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5"
export MQL5_ROOT="$CROSSOVER_BOTTLE/drive_c"
alias m5='cd "$MQL5_ROOT"'
```

**Paths**:
- `MQL5_ROOT` = Project root (git, navigation)
- `CROSSOVER_BOTTLE` = Bottle root (Wine)

---

## Project Status

| Metric | Value |
|--------|-------|
| **Version** | 4.0.0 |
| **Headless** | v3.0.0 Python API (production) |
| **GUI Export** | v4.0.0 file-based config |
| **Latest Validation** | Laguerre RSI - 1.000000 correlation |

**SLOs**: Availability 100%, Correctness 100%, Observability 100%, Maintainability 100%

---

## Workflow Matrix

| Task | Approach | Reference |
|------|----------|-----------|
| Automated headless | v3.0.0 Python API | [WINE_PYTHON_EXECUTION.md](docs/guides/WINE_PYTHON_EXECUTION.md) |
| Manual GUI exports | v4.0.0 file config | [V4_FILE_BASED_CONFIG_WORKFLOW.md](docs/guides/V4_FILE_BASED_CONFIG_WORKFLOW.md) |
| Custom indicators | GUI mode only | Python API can't access buffers |
| Compilation | X: drive CLI | [MQL5/CLAUDE.md](Program%20Files/MetaTrader%205/MQL5/CLAUDE.md), `/mql5-x-compile` |
| Validation | ≥0.999 correlation | [INDICATOR_VALIDATION_METHODOLOGY.md](docs/guides/INDICATOR_VALIDATION_METHODOLOGY.md) |

---

## Quick Reference

**Compile MQL5**:
```bash
./tools/compile_mql5.sh "Indicators/Custom/Development/MyIndicator.mq5"
# Or use: /mql5-x-compile
```

**Export Data (v3.0.0)**:
```bash
cd "$MQL5_ROOT/users/crossover"
CX_BOTTLE="MetaTrader 5" wine "C:\\Program Files\\Python312\\python.exe" \
  "C:\\users\\crossover\\export_aligned.py" --symbol EURUSD --period M1 --bars 5000
```

**Validate**:
```bash
cd "$MQL5_ROOT/users/crossover"
python validate_indicator.py --csv exports/Export.csv --indicator laguerre_rsi --threshold 0.999
```

---

## Key Discoveries (2025-10-17)

- **v4.0.0 File-Based Config**: Config reader working, GUI mode
- **v2.1.0 startup.ini**: NOT VIABLE (named sections unsupported)
- **/inc parameter**: OVERRIDES default paths (omit unless external includes)
- **Python API limitation**: Cannot access indicator buffers
- **Path spaces**: Use X: drive or copy to C:/ root

---

## Research Context

- **Historical findings**: [docs/archive/historical.txt](docs/archive/historical.txt) (2022-2025)
- **Dead ends**: [docs/archive/CLAUDE.md](docs/archive/CLAUDE.md)
- **Full SSOT table**: [docs/CLAUDE.md](docs/CLAUDE.md)

---

**Tip**: Child directories have their own CLAUDE.md files. Claude pulls them in on demand when working in those directories.
