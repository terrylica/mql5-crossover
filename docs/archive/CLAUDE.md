# Archive Context

**Purpose**: Historical research, deprecated approaches, and legacy documentation preserved for reference.

**Navigation**: [docs/CLAUDE.md](../CLAUDE.md) | [Root CLAUDE.md](../../CLAUDE.md)

**Policy**: No deletion - all historical context preserved for future reference.

---

## Why This Matters

This archive contains **185+ hours of debugging knowledge**. Before exploring new approaches:

1. Check if it's a known dead end
2. Review lessons learned
3. Understand why previous approaches failed

---

## Known Dead Ends (Do NOT Retry)

| Approach | Status | Why |
|----------|--------|-----|
| startup.ini parameter passing (v2.1.0) | NOT VIABLE | Named sections `[ScriptName]` not supported |
| ScriptParameters directive | FAILED | Blocks execution with silent failure |
| startup.ini for new symbols | CONDITIONAL | Requires GUI initialization first |

**Reference**: [HEADLESS_EXECUTION_PLAN.v2.0.0.archived.md](HEADLESS_EXECUTION_PLAN.v2.0.0.archived.md)

---

## Bug Documentation

| File | Hours | Bugs Fixed |
|------|-------|------------|
| [LAGUERRE_RSI_BUG_JOURNEY.md](LAGUERRE_RSI_BUG_JOURNEY.md) | 14 | Price smoothing, array indexing, shared state |
| [LAGUERRE_RSI_SHARED_STATE_BUG.archived.md](LAGUERRE_RSI_SHARED_STATE_BUG.archived.md) | - | Multi-instance state corruption |
| [LAGUERRE_RSI_ARRAY_INDEXING_BUG.archived.md](LAGUERRE_RSI_ARRAY_INDEXING_BUG.archived.md) | - | Off-by-one errors in buffer access |
| [LAGUERRE_RSI_BUG_FIX_SUMMARY.archived.md](LAGUERRE_RSI_BUG_FIX_SUMMARY.archived.md) | - | Overview of all fixes |
| [LAGUERRE_RSI_BUG_REPORT.archived.md](LAGUERRE_RSI_BUG_REPORT.archived.md) | - | Original bug report |

---

## Historical Research

| File | Lines | Content |
|------|-------|---------|
| [historical.txt](historical.txt) | 5,073 | 2022-2025 community research findings |

**Key Findings in historical.txt**:
- MT5 automation limitations across platforms
- CrossOver-specific behaviors vs native Windows
- Community workarounds and their limitations

---

## Success Records

| File | Correlation | Content |
|------|-------------|---------|
| [SUCCESS_REPORT.v2.0.0.md](SUCCESS_REPORT.v2.0.0.md) | 0.999902 | Historical v2.0.0 validation (manual execution) |

---

## How to Use This Archive

**When debugging a new issue**:
1. Search `historical.txt` for keywords
2. Check bug journey documents for similar patterns
3. Review dead ends before trying new approaches

**When migrating a new indicator**:
1. Read [LAGUERRE_RSI_BUG_JOURNEY.md](LAGUERRE_RSI_BUG_JOURNEY.md) for common pitfalls
2. Apply lessons to your indicator
3. Use validation methodology from [../reports/LAGUERRE_RSI_VALIDATION_SUCCESS.md](../reports/LAGUERRE_RSI_VALIDATION_SUCCESS.md)

---

## File Count: 8 archived files + 5,073 lines of research

Preserved knowledge prevents re-exploration of failed approaches (estimated 50+ hours saved per new contributor).
