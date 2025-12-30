# Guides Context

**Purpose**: Step-by-step workflows and technical references for MQL5→Python development.

**Navigation**: [docs/CLAUDE.md](../CLAUDE.md) | [Root CLAUDE.md](../../CLAUDE.md)

---

## Master Workflow (Start Here)

| Guide | Description |
|-------|-------------|
| [MQL5_TO_PYTHON_MIGRATION_GUIDE.md](MQL5_TO_PYTHON_MIGRATION_GUIDE.md) | Complete 7-phase workflow (2-4 hours per indicator) |
| [LESSONS_LEARNED_PLAYBOOK.md](LESSONS_LEARNED_PLAYBOOK.md) | 8 critical gotchas from 185+ hours of debugging |

---

## By Task

### Exporting Data

| Guide | Version | Mode |
|-------|---------|------|
| [WINE_PYTHON_EXECUTION.md](WINE_PYTHON_EXECUTION.md) | v3.0.0 | Headless (production) |
| [V4_FILE_BASED_CONFIG_WORKFLOW.md](V4_FILE_BASED_CONFIG_WORKFLOW.md) | v4.0.0 | GUI with config files |

### Compilation

| Guide | Content |
|-------|---------|
| [MQL5_CLI_COMPILATION_SUCCESS.md](MQL5_CLI_COMPILATION_SUCCESS.md) | CLI via CrossOver --cx-app (~1s compile) |
| [BOTTLE_TRACKING.md](BOTTLE_TRACKING.md) | X: drive mapping for path spaces |
| [MQL5_ENCODING_SOLUTIONS.md](MQL5_ENCODING_SOLUTIONS.md) | UTF-8/UTF-16LE encoding |

### Validation

| Guide | Content |
|-------|---------|
| [INDICATOR_VALIDATION_METHODOLOGY.md](INDICATOR_VALIDATION_METHODOLOGY.md) | 5000-bar warmup, ≥0.999 correlation |
| [PYTHON_INDICATOR_VALIDATION_FAILURES.md](PYTHON_INDICATOR_VALIDATION_FAILURES.md) | NaN traps, warmup, pandas pitfalls |
| [LAGUERRE_RSI_TEMPORAL_AUDIT.md](LAGUERRE_RSI_TEMPORAL_AUDIT.md) | No look-ahead bias verification |

### File Paths

| Guide | Content |
|-------|---------|
| [MT5_FILE_LOCATIONS.md](MT5_FILE_LOCATIONS.md) | Complete MT5 file paths |
| [CROSSOVER_MQ5.md](CROSSOVER_MQ5.md) | MT5/CrossOver technical reference |

---

## Case Studies

| Guide | Hours | Key Lessons |
|-------|-------|-------------|
| [LAGUERRE_RSI_ANALYSIS.md](LAGUERRE_RSI_ANALYSIS.md) | - | Algorithm breakdown, Python translation |
| [../archive/LAGUERRE_RSI_BUG_JOURNEY.md](../archive/LAGUERRE_RSI_BUG_JOURNEY.md) | 14 | 3 bugs: price smoothing, array indexing, shared state |

---

## Research References

| Guide | Sources | Content |
|-------|---------|---------|
| [EXTERNAL_RESEARCH_BREAKTHROUGHS.md](EXTERNAL_RESEARCH_BREAKTHROUGHS.md) | External AI | /inc trap, script automation, Python API limits |
| [SCRIPT_PARAMETER_PASSING_RESEARCH.md](SCRIPT_PARAMETER_PASSING_RESEARCH.md) | 30+ | startup.ini, .set files, known bugs |
| [MQL5_PRESET_FILES_RESEARCH.md](MQL5_PRESET_FILES_RESEARCH.md) | - | .set encoding, location, #property |

---

## File Count: 18 guides

All guides are battle-tested with empirical validation. See individual files for version history and validation status.
