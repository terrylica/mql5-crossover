# Documentation Hub Context

**Purpose**: Central reference for all project documentation - guides, reports, plans, and templates.

**Navigation**: [Root CLAUDE.md](../CLAUDE.md) | [MT5 Reference Hub](MT5_REFERENCE_HUB.md) | [README](README.md)

---

## Directory Structure

| Directory | Purpose | Count |
|-----------|---------|-------|
| [guides/](guides/) | Step-by-step workflows and technical references | 18 files |
| [reports/](reports/) | Validation results, assessments, status reports | 16 files |
| [plans/](plans/) | Implementation plans and blocking issues | 7 files |
| [templates/](templates/) | Reusable checklists and templates | 1 file |
| [archive/](archive/) | Deprecated docs and historical research | 8 files |

---

## Single Source of Truth

| Topic | Authoritative Document |
|-------|------------------------|
| **WORKFLOWS** | |
| MQL5→Python Migration Workflow | [guides/MQL5_TO_PYTHON_MIGRATION_GUIDE.md](guides/MQL5_TO_PYTHON_MIGRATION_GUIDE.md) |
| Lessons Learned (8 gotchas) | [guides/LESSONS_LEARNED_PLAYBOOK.md](guides/LESSONS_LEARNED_PLAYBOOK.md) |
| Indicator Migration Checklist | [templates/INDICATOR_MIGRATION_CHECKLIST.md](templates/INDICATOR_MIGRATION_CHECKLIST.md) |
| Wine Python Execution (v3.0.0) | [guides/WINE_PYTHON_EXECUTION.md](guides/WINE_PYTHON_EXECUTION.md) |
| File-Based Config (v4.0.0) | [guides/V4_FILE_BASED_CONFIG_WORKFLOW.md](guides/V4_FILE_BASED_CONFIG_WORKFLOW.md) |
| Headless Execution Evolution | [plans/HEADLESS_EXECUTION_PLAN.md](plans/HEADLESS_EXECUTION_PLAN.md) |
| **PATHS & INFRASTRUCTURE** | |
| MT5 Paths, Directory Structure | [guides/MT5_FILE_LOCATIONS.md](guides/MT5_FILE_LOCATIONS.md) |
| X: Drive Mapping, Git Integration | [guides/BOTTLE_TRACKING.md](guides/BOTTLE_TRACKING.md) |
| **ENCODING** | |
| UTF-8/UTF-16LE Detection | [guides/MQL5_ENCODING_SOLUTIONS.md](guides/MQL5_ENCODING_SOLUTIONS.md) |
| **COMPILATION** | |
| X: Drive CLI Compilation | `../.claude/skills/mql5-x-compile` + `../tools/compile_mql5.sh` |
| CLI Compilation Guide | [guides/MQL5_CLI_COMPILATION_SUCCESS.md](guides/MQL5_CLI_COMPILATION_SUCCESS.md) |
| /inc Parameter Behavior | [guides/EXTERNAL_RESEARCH_BREAKTHROUGHS.md](guides/EXTERNAL_RESEARCH_BREAKTHROUGHS.md) |
| **WINE ENVIRONMENT** | |
| CrossOver Setup, Wine Builds | [guides/CROSSOVER_MQ5.md](guides/CROSSOVER_MQ5.md) |
| **CONFIGURATION** | |
| startup.ini Syntax | [guides/SCRIPT_PARAMETER_PASSING_RESEARCH.md](guides/SCRIPT_PARAMETER_PASSING_RESEARCH.md) |
| .set File Format | [guides/MQL5_PRESET_FILES_RESEARCH.md](guides/MQL5_PRESET_FILES_RESEARCH.md) |
| **VALIDATION** | |
| Production Methodology | [guides/INDICATOR_VALIDATION_METHODOLOGY.md](guides/INDICATOR_VALIDATION_METHODOLOGY.md) |
| Laguerre RSI Success | [reports/LAGUERRE_RSI_VALIDATION_SUCCESS.md](reports/LAGUERRE_RSI_VALIDATION_SUCCESS.md) |
| Validation Failures Case | [guides/PYTHON_INDICATOR_VALIDATION_FAILURES.md](guides/PYTHON_INDICATOR_VALIDATION_FAILURES.md) |
| SLO Metrics | [reports/VALIDATION_STATUS.md](reports/VALIDATION_STATUS.md) |
| **CASE STUDIES** | |
| Laguerre RSI Algorithm | [guides/LAGUERRE_RSI_ANALYSIS.md](guides/LAGUERRE_RSI_ANALYSIS.md) |
| Laguerre RSI Temporal Audit | [guides/LAGUERRE_RSI_TEMPORAL_AUDIT.md](guides/LAGUERRE_RSI_TEMPORAL_AUDIT.md) |
| Laguerre RSI Bug Journey | [archive/LAGUERRE_RSI_BUG_JOURNEY.md](archive/LAGUERRE_RSI_BUG_JOURNEY.md) |
| **RESEARCH** | |
| External Research Findings | [guides/EXTERNAL_RESEARCH_BREAKTHROUGHS.md](guides/EXTERNAL_RESEARCH_BREAKTHROUGHS.md) |
| Script Parameters (30+ sources) | [guides/SCRIPT_PARAMETER_PASSING_RESEARCH.md](guides/SCRIPT_PARAMETER_PASSING_RESEARCH.md) |
| .set Preset Files | [guides/MQL5_PRESET_FILES_RESEARCH.md](guides/MQL5_PRESET_FILES_RESEARCH.md) |
| **STATUS** | |
| Documentation Readiness | [reports/DOCUMENTATION_READINESS_ASSESSMENT.md](reports/DOCUMENTATION_READINESS_ASSESSMENT.md) |
| Pruning Assessment | [reports/PRUNING_ASSESSMENT.md](reports/PRUNING_ASSESSMENT.md) |
| Technical Debt | [reports/TECHNICAL_DEBT_REPORT.md](reports/TECHNICAL_DEBT_REPORT.md) |
| Legacy Code Assessment | [reports/LEGACY_CODE_ASSESSMENT.md](reports/LEGACY_CODE_ASSESSMENT.md) |
| Historical Context (2022-2025) | [archive/historical.txt](archive/historical.txt) |

---

## Implementation Plans

| Plan | Status | Description |
|------|--------|-------------|
| [adaptive-cci-normalization.yaml](plans/adaptive-cci-normalization.yaml) | Research Complete | Adaptive percentile-based normalization (v1.0.0) |
| [HEADLESS_EXECUTION_PLAN.md](plans/HEADLESS_EXECUTION_PLAN.md) | v3.0.0 + v4.0.0 COMPLETE | Python API + File-based config |
| [cci-neutrality-indicator.yaml](plans/cci-neutrality-indicator.yaml) | Blocked | v1.3.2, calculation errors |
| [cci-rising-pattern-marker.yaml](plans/cci-rising-pattern-marker.yaml) | Pending | CCI Rising pattern marker |

### Blocking Issues

- [MT5_AUTOMATION_BLOCKING_ISSUE_v1.3.0.md](plans/MT5_AUTOMATION_BLOCKING_ISSUE_v1.3.0.md)
- [STRATEGY_TESTER_BLOCKING_ISSUE.md](plans/STRATEGY_TESTER_BLOCKING_ISSUE.md)
- [WORKFLOW_EVOLUTION_FRAMEWORK.md](plans/WORKFLOW_EVOLUTION_FRAMEWORK.md)

---

## Quick Links

- **Start here**: [MQL5_TO_PYTHON_MIGRATION_GUIDE.md](guides/MQL5_TO_PYTHON_MIGRATION_GUIDE.md)
- **Critical gotchas**: [LESSONS_LEARNED_PLAYBOOK.md](guides/LESSONS_LEARNED_PLAYBOOK.md)
- **Current status**: [VALIDATION_STATUS.md](reports/VALIDATION_STATUS.md)
