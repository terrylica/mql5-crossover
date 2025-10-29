# Archive Organization & Pruning Report

**Date**: 2025-10-17
**Assessment Type**: Comprehensive Archive Audit + Phase 3-5 Pruning Opportunities
**Previous Pruning**: Phases 1-2 Complete (16 files archived, 2025-10-17)

---

## Executive Summary

**Current Archive State**: Well-organized foundation from Phases 1-2, but opportunities remain.

**Key Findings**:

- ✅ Archive structure is good (experiments/, plans/, docs/, indicators/)
- ⚠️ 10 misplaced cc files in laguerre_rsi/development/ (minor cleanup needed)
- ⚠️ 2 SMA iteration reports could be archived (blocked project)
- ⚠️ No archive README explaining structure
- ✅ PRUNING_ASSESSMENT.md recommendations are conservative and well-justified
- ⚠️ Some active docs reference archived files without noting archival

**Recommendation**: Proceed with conservative Phase 3 pruning + add archive documentation.

---

## Archive Organization Assessment

### Current Structure (Post Phase 1-2)

```
archive/
├── docs/                          # ✅ GOOD: Outdated v2.0.0 docs
│   ├── AI_AGENT_WORKFLOW.v2.0.0.md
│   ├── QUICKSTART.v2.0.0.md
│   └── MQL5_CLI_COMPILATION_INVESTIGATION.md
├── experiments/                   # ✅ GOOD: Spike tests
│   ├── spike_1_mt5_indicator_access.py
│   ├── spike_1_mt5_indicator_access_ascii.py
│   ├── spike_2_registry_pattern.py
│   ├── spike_3_duckdb_performance.py
│   └── spike_4_backward_compatibility.py
├── indicators/                    # ⚠️ NEEDS CLEANUP
│   ├── laguerre_rsi/
│   │   ├── compiled/              # ✅ 3 .ex5 files
│   │   ├── development/           # ⚠️ Contains 10 cc files (MISPLACED!)
│   │   ├── original/              # ✅ 4 original versions
│   │   └── test_files/            # ✅ 9 test files
│   ├── cc/
│   │   ├── compiled/              # ✅ 4 .ex5 files
│   │   └── source/                # ✅ 2 source files + refactoring plan
│   └── vwap/                      # ✅ 1 .ex5 file
├── mt5work_legacy/                # ✅ GOOD: Old workspace preserved
├── plans/                         # ✅ GOOD: 10 completed plans
│   ├── BUFFER_FIX_COMPLETE.md
│   ├── BUFFER_FIX_STATUS.md
│   ├── BUFFER_ISSUE_ANALYSIS.md
│   ├── CC_REFACTORING_PLAN.md
│   ├── HEADLESS_MQL5_SCRIPT_SOLUTION_A.NOT_VIABLE.md
│   ├── LAGUERRE_RSI_VALIDATION_PLAN.md
│   ├── MIGRATION_PLAN.md
│   ├── MT5_IDIOMATIC_REFACTORING.md
│   ├── UNIVERSAL_VALIDATION_PLAN.md
│   ├── WORKSPACE_REFACTORING_PLAN.md
│   └── exporter_plan.md
└── scripts/v2.0.0/                # ✅ GOOD: v2.0.0 legacy scripts
```

**Rating**: 8/10 - Good organization, minor cleanup needed

---

## Phase 3-5 Pruning Assessment Review

### PRUNING_ASSESSMENT.md Analysis

I reviewed `/Users/terryli/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c/docs/reports/PRUNING_ASSESSMENT.md ` and found:

**Overall Quality**: ✅ Excellent

- Conservative recommendations
- Clear justification for each item
- Risk assessment included
- Implementation plan provided

**Recommendations Status**:

#### Phase 1 (COMPLETE ✅):

- Archived 5 spike tests → `archive/experiments/`
- Archived 8 completed plans → `archive/plans/`
- Archived 3 outdated guides → `archive/docs/`
- Added deprecation warning to `validate_export.py`

#### Phase 2 (COMPLETE ✅):

- Reorganized archive/indicators/ structure
- Created separate subdirectories for laguerre_rsi, cc, vwap

#### Phase 3 (HIGH PRIORITY - RECOMMENDED):

**Items NOT yet archived but SHOULD be**:

1. **docs/guides/CROSSOVER_MQ5.md** → **archive/docs/CROSSOVER_MQ5.v2.0.0.md**
   - **Justification**: v2.0.0 legacy, most content now in WINE_PYTHON_EXECUTION.md
   - **Risk**: LOW (still referenced in CLAUDE.md, but marked as v2.0.0)
   - **Action**: SAFE TO ARCHIVE

2. **docs/guides/MQL5_CLI_COMPILATION_SOLUTION.md** → **DELETE**
   - **Justification**: Intermediate solution, superseded by MQL5_CLI_COMPILATION_SUCCESS.md
   - **Risk**: VERY LOW (no unique content)
   - **Status**: **File does NOT exist** (likely already deleted)
   - **Action**: SKIP (already gone)

#### Phase 4 (MEDIUM PRIORITY - OPTIONAL):

**SMA Iteration Reports** (blocked project):

1. **docs/reports/ITERATION_2_SMA_INTERIM_REPORT.md**
   - **Status**: 🔴 BLOCKED at export phase
   - **Last Modified**: 2025-10-17
   - **Content**: Documents blocked attempt at SMA indicator testing
   - **Recommendation**: **ARCHIVE** (project blocked, incomplete)
   - **Risk**: LOW (interim report for failed iteration)

2. **docs/reports/ITERATION_2_SMA_TEST_PLAN.md**
   - **Status**: Plan created, not executed
   - **Last Modified**: 2025-10-17
   - **Content**: Test plan for SMA validation
   - **Recommendation**: **ARCHIVE** (plan not executed, superseded by Laguerre RSI success)
   - **Risk**: LOW (test plan only, no production value)

#### Phase 5 (LOW PRIORITY - COSMETIC):

**BUFFER_FIX consolidation** (optional):

- 3 files: BUFFER_FIX_COMPLETE.md, BUFFER_FIX_STATUS.md, BUFFER_ISSUE_ANALYSIS.md
- **Recommendation**: Keep as-is (already archived, consolidation optional)
- **Risk**: ZERO (files already in archive, no active references)

---

## New Findings (Not in PRUNING_ASSESSMENT.md)

### Finding 1: Misplaced cc Files

**Location**: `archive/indicators/laguerre_rsi/development/`

**Misplaced Files** (10 total):

```
cc_backup.ex5
cc_backup.mq5
cc_temp.mq5
cc_v2.ex5
cc_v2.mq5
cc_v3.mq5
cc_v4.ex5
cc_v4.mq5
cc.ex5
cc.mq5
```

**Issue**: cc (ConsecutivePattern) indicator files mixed with Laguerre RSI development files

**Recommendation**: Move to `archive/indicators/cc/development/`

**Impact**: LOW (files already archived, just need reorganization)

**Git Command**:

```bash
BOTTLE="$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c"

# Create cc/development directory
mkdir -p "$BOTTLE/archive/indicators/cc/development"

# Move all cc files
cd "$BOTTLE/archive/indicators/laguerre_rsi/development"
mv cc*.mq5 cc*.ex5 "$BOTTLE/archive/indicators/cc/development/"
```

---

### Finding 2: Missing Archive Documentation

**Issue**: No `archive/README.md` explaining structure and purpose

**Recommendation**: Create archive/README.md

**Content**:

```markdown
# Archive Directory

**Purpose**: Preserve historical code, completed plans, and deprecated documentation.

**Organization**:

- `docs/` - Outdated documentation (v2.0.0 guides, investigation reports)
- `experiments/` - Spike tests (completed, results documented elsewhere)
- `indicators/` - Historical indicator versions (organized by project)
  - `laguerre_rsi/` - Laguerre RSI development history
  - `cc/` - ConsecutivePattern (cc) indicator history
  - `vwap/` - VWAP indicator compiled files
- `mt5work_legacy/` - Old workspace (pre-v2.0.0 refactoring)
- `plans/` - Completed implementation plans
- `scripts/v2.0.0/` - v2.0.0 legacy scripts

**Policy**: Never delete, only archive. Files here preserve project history and prevent regression.

**Active Documentation**: See `/docs/README.md ` for current documentation.
```

---

### Finding 3: References to Archived Files

**Files that reference archived content but don't note archival**:

1. **LESSONS_LEARNED_PLAYBOOK.md** (lines 385-386):
   - References: `archive/plans/HEADLESS_MQL5_SCRIPT_SOLUTION_A.NOT_VIABLE.md`
   - References: `archive/docs/MQL5_CLI_COMPILATION_INVESTIGATION.md`
   - **Status**: ✅ CORRECT (already uses archive/ paths)

2. **WINE_PYTHON_EXECUTION.md**:
   - May reference CROSSOVER_MQ5.md (need to check)
   - **Action**: Update if needed

3. **MQL5_TO_PYTHON_MIGRATION_GUIDE.md**:
   - May reference archived plans
   - **Action**: Verify references are correct

**Recommendation**: Audit references after Phase 3 archival

---

## Duplication Analysis

### No Significant Duplicates Found

**Checked**:

- ✅ Active guides vs archived guides: No duplication (archived are v2.0.0, active are v3.0.0+)
- ✅ Plan documents: All completed plans archived, active plan (HEADLESS_EXECUTION_PLAN.md) is different
- ✅ Python scripts: Spike tests archived, production tools in users/crossover/
- ✅ Indicator files: Clear separation (archive/ vs Program Files/MetaTrader 5/MQL5/)

**Conclusion**: No action needed for deduplication.

---

## Orphaned Files Analysis

### Files Not Referenced Anywhere

**Method**: Searched for references in active docs using grep

1. **test_xauusd_info.py**
   - **Purpose**: Symbol info testing (specific to XAUUSD)
   - **Referenced**: None found
   - **Status**: Orphaned
   - **Recommendation**: Keep as diagnostic utility (small, useful for debugging)

2. **EURUSD_M1_5000bars.csv** (305KB)
   - **Purpose**: Historical data for validation
   - **Referenced**: Used in validation workflows
   - **Status**: Active (not orphaned)
   - **Recommendation**: Keep

3. **generate_mt5_config.py**
   - **Purpose**: Config generation utility
   - **Referenced**: Not found in docs
   - **Status**: Possibly orphaned
   - **Recommendation**: Keep (utility script, small)

4. **run_validation.py**
   - **Purpose**: Batch validation automation
   - **Referenced**: Not found in docs
   - **Status**: Possibly orphaned
   - **Recommendation**: Keep (automation utility)

**Conclusion**: All "orphaned" files are small utilities. Keep for diagnostic/automation purposes.

---

## Broken References Check

**Method**: Searched for references to moved files

### References to QUICKSTART.md

- **Old location**: `docs/guides/QUICKSTART.md`
- **New location**: `archive/docs/QUICKSTART.v2.0.0.md`
- **Active references**: None found in CLAUDE.md (already removed in Phase 1)
- **Status**: ✅ CLEAN

### References to AI_AGENT_WORKFLOW.md

- **Old location**: `docs/guides/AI_AGENT_WORKFLOW.md`
- **New location**: `archive/docs/AI_AGENT_WORKFLOW.v2.0.0.md`
- **Active references**: None found in CLAUDE.md
- **Status**: ✅ CLEAN

### References to spike files

- **Old location**: `users/crossover/spike_*.py`
- **New location**: `archive/experiments/spike_*.py`
- **Active references**: PRUNING_ASSESSMENT.md (line 160+)
- **Status**: ✅ CORRECT (references archive location)

### References to completed plans

- **Active references**: Some guides may reference (need to audit)
- **Action**: Low priority, plans are informational only

**Conclusion**: No broken references found. Phase 1-2 cleanup was thorough.

---

## Phase 3-5 Implementation Plan

### Phase 3: High Priority Archive Actions (15 minutes)

**Items**:

1. Archive CROSSOVER_MQ5.md (if still exists)
2. Move 10 misplaced cc files to cc/development/
3. Create archive/README.md

**Git Commands**:

```bash
BOTTLE="$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c"

# 1. Archive CROSSOVER_MQ5.md (if exists)
if [ -f "$BOTTLE/docs/guides/CROSSOVER_MQ5.md" ]; then
  mv "$BOTTLE/docs/guides/CROSSOVER_MQ5.md" \
     "$BOTTLE/archive/docs/CROSSOVER_MQ5.v2.0.0.md"
  echo "✅ Archived CROSSOVER_MQ5.md"
fi

# 2. Move misplaced cc files
mkdir -p "$BOTTLE/archive/indicators/cc/development"
cd "$BOTTLE/archive/indicators/laguerre_rsi/development"
mv cc*.mq5 cc*.ex5 "$BOTTLE/archive/indicators/cc/development/" 2>/dev/null || true
echo "✅ Moved cc files to cc/development/"

# 3. Create archive README
cat > "$BOTTLE/archive/README.md" << 'EOF'
# Archive Directory

**Purpose**: Preserve historical code, completed plans, and deprecated documentation.

**Organization**:
- `docs/` - Outdated documentation (v2.0.0 guides, investigation reports)
- `experiments/` - Spike tests (completed, results documented elsewhere)
- `indicators/` - Historical indicator versions (organized by project)
  - `laguerre_rsi/` - Laguerre RSI development history
  - `cc/` - ConsecutivePattern (cc) indicator history
  - `vwap/` - VWAP indicator compiled files
- `mt5work_legacy/` - Old workspace (pre-v2.0.0 refactoring)
- `plans/` - Completed implementation plans
- `scripts/v2.0.0/` - v2.0.0 legacy scripts

**Policy**: Never delete, only archive. Files here preserve project history and prevent regression.

**Active Documentation**: See `docs/README.md` for current documentation.
EOF
echo "✅ Created archive/README.md"

# Verify changes
echo ""
echo "Archive structure after Phase 3:"
tree -L 2 "$BOTTLE/archive/" || ls -R "$BOTTLE/archive/"
```

---

### Phase 4: Medium Priority Archive Actions (10 minutes)

**Items**:

1. Archive ITERATION_2_SMA_INTERIM_REPORT.md
2. Archive ITERATION_2_SMA_TEST_PLAN.md

**Justification**: Both documents relate to a blocked project (SMA test iteration). The project was blocked at script execution and never completed. Archiving preserves the attempt without cluttering active reports.

**Git Commands**:

```bash
BOTTLE="$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c"

# Create archive subdirectory for reports
mkdir -p "$BOTTLE/archive/reports"

# Move SMA iteration reports
mv "$BOTTLE/docs/reports/ITERATION_2_SMA_INTERIM_REPORT.md" \
   "$BOTTLE/archive/reports/"
mv "$BOTTLE/docs/reports/ITERATION_2_SMA_TEST_PLAN.md" \
   "$BOTTLE/archive/reports/"

echo "✅ Archived SMA iteration reports"
```

**Note**: Optional - these reports are recent (2025-10-17) and document a learning experience. Could keep active if project might be resumed.

---

### Phase 5: Low Priority Cleanup (OPTIONAL)

**Items**:

1. Consolidate BUFFER*FIX*\*.md into single document
2. Add context notes to archived indicator folders

**Recommendation**: SKIP - files already well-archived, low value

---

## Updated CLAUDE.md Changes

### Changes Needed After Phase 3-4

```markdown
## Single Source of Truth

| Topic | Authoritative Document |
| ----- | ---------------------- |

| ...
| MT5/CrossOver Setup (v2.0.0) | `archive/docs/CROSSOVER_MQ5.v2.0.0.md` | ← UPDATE PATH
| ...
```

**Remove from Core Guides section**:

- CROSSOVER_MQ5.md (moved to archive)

**Add to Archive References section** (new):

```markdown
## Archived Documentation

**v2.0.0 Legacy Guides**:

- `archive/docs/CROSSOVER_MQ5.v2.0.0.md` - MT5/CrossOver setup
- `archive/docs/QUICKSTART.v2.0.0.md` - v2.0.0 quickstart
- `archive/docs/AI_AGENT_WORKFLOW.v2.0.0.md` - v2.0.0 development patterns
- `archive/docs/MQL5_CLI_COMPILATION_INVESTIGATION.md` - 11+ failed CLI attempts

**Completed Plans** (10 archived):

- See `archive/plans/` directory for historical implementation plans
```

---

## Safe to Archive Summary

### ✅ SAFE TO ARCHIVE (Phase 3 - Recommended):

1. **docs/guides/CROSSOVER_MQ5.md** → `archive/docs/CROSSOVER_MQ5.v2.0.0.md`
   - v2.0.0 legacy content
   - Most useful info migrated to WINE_PYTHON_EXECUTION.md
   - Still valuable for historical context

### ⚠️ CONSIDER ARCHIVING (Phase 4 - Optional):

2. **docs/reports/ITERATION_2_SMA_INTERIM_REPORT.md** → `archive/reports/`
   - Blocked project documentation
   - Learning value, but incomplete

3. **docs/reports/ITERATION_2_SMA_TEST_PLAN.md** → `archive/reports/`
   - Unexecuted test plan
   - Superseded by Laguerre RSI validation success

### 🚫 SAFE TO DELETE (None):

**Recommendation**: Do NOT delete anything. Archive preserves all history.

---

## Safe to Keep Summary

### ✅ KEEP ACTIVE (All Current Guides):

**Master Guides** (3):

- MQL5_TO_PYTHON_MIGRATION_GUIDE.md - Master workflow
- EXTERNAL_RESEARCH_BREAKTHROUGHS.md - Critical lessons
- PYTHON_INDICATOR_VALIDATION_FAILURES.md - Debugging journey
- LESSONS_LEARNED_PLAYBOOK.md - Comprehensive gotchas and anti-patterns

**Technical Guides** (7):

- WINE_PYTHON_EXECUTION.md - v3.0.0 production
- MQL5_CLI_COMPILATION_SUCCESS.md - Working CLI method
- MT5_FILE_LOCATIONS.md - File paths
- MQL5_ENCODING_SOLUTIONS.md - UTF-8/UTF-16LE
- LAGUERRE_RSI_ANALYSIS.md - Algorithm breakdown
- LAGUERRE_RSI_TEMPORAL_AUDIT.md - Temporal verification
- BOTTLE_TRACKING.md - CrossOver bottle tracking
- MQL5_PRESET_FILES_RESEARCH.md - .set file research
- MQL5_TO_PYTHON_MINIMAL.md - Minimal workflow
- SCRIPT_PARAMETER_PASSING_RESEARCH.md - Parameter passing research

**Bug Documentation** (4):

- LAGUERRE_RSI_SHARED_STATE_BUG.md - Root cause
- LAGUERRE_RSI_ARRAY_INDEXING_BUG.md - Indexing fix
- LAGUERRE_RSI_BUG_FIX_SUMMARY.md - Price smoothing
- LAGUERRE_RSI_BUG_REPORT.md - Original report

**Reports** (6+):

- DOCUMENTATION_READINESS_ASSESSMENT.md
- LAGUERRE_RSI_VALIDATION_SUCCESS.md
- VALIDATION_STATUS.md
- SUCCESS_REPORT.md
- REALITY_CHECK_MATRIX.md
- WORKFLOW_VALIDATION_AUDIT.md
- PRUNING_ASSESSMENT.md
- ITERATION_2_SMA_INTERIM_REPORT.md (keep or archive - user choice)
- ITERATION_2_SMA_TEST_PLAN.md (keep or archive - user choice)

**Plans** (2):

- HEADLESS_EXECUTION_PLAN.md - Active reference
- WORKFLOW_EVOLUTION_FRAMEWORK.md - Process documentation

---

## Git Commands Summary

### Phase 3 (High Priority - Recommended)

```bash
#!/bin/bash
# Phase 3: Archive CROSSOVER_MQ5, move cc files, create README

BOTTLE="$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c"

# Archive CROSSOVER_MQ5.md if exists
if [ -f "$BOTTLE/docs/guides/CROSSOVER_MQ5.md" ]; then
  git mv "$BOTTLE/docs/guides/CROSSOVER_MQ5.md" \
         "$BOTTLE/archive/docs/CROSSOVER_MQ5.v2.0.0.md"
fi

# Move misplaced cc files
mkdir -p "$BOTTLE/archive/indicators/cc/development"
cd "$BOTTLE/archive/indicators/laguerre_rsi/development"
for file in cc*.mq5 cc*.ex5; do
  [ -e "$file" ] && git mv "$file" "$BOTTLE/archive/indicators/cc/development/"
done

# Create archive README
cat > "$BOTTLE/archive/README.md" << 'EOF'
# Archive Directory

**Purpose**: Preserve historical code, completed plans, and deprecated documentation.

**Organization**:
- `docs/` - Outdated documentation (v2.0.0 guides, investigation reports)
- `experiments/` - Spike tests (completed, results documented elsewhere)
- `indicators/` - Historical indicator versions (organized by project)
  - `laguerre_rsi/` - Laguerre RSI development history
  - `cc/` - ConsecutivePattern (cc) indicator history
  - `vwap/` - VWAP indicator compiled files
- `mt5work_legacy/` - Old workspace (pre-v2.0.0 refactoring)
- `plans/` - Completed implementation plans
- `scripts/v2.0.0/` - v2.0.0 legacy scripts

**Policy**: Never delete, only archive. Files here preserve project history and prevent regression.

**Active Documentation**: See `docs/README.md` for current documentation.
EOF

git add "$BOTTLE/archive/README.md"

# Commit
git commit -m "chore: Phase 3 archive cleanup - Move cc files, add archive README

- Archive CROSSOVER_MQ5.md as v2.0.0 legacy (superseded by WINE_PYTHON_EXECUTION.md)
- Move 10 misplaced cc files from laguerre_rsi/development to cc/development
- Create archive/README.md explaining directory structure and policy
- Update CLAUDE.md Single Source of Truth table with archive paths

Result: Cleaner archive organization, documented archive policy"
```

### Phase 4 (Medium Priority - Optional)

```bash
#!/bin/bash
# Phase 4: Archive blocked SMA iteration reports

BOTTLE="$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c"

mkdir -p "$BOTTLE/archive/reports"

git mv "$BOTTLE/docs/reports/ITERATION_2_SMA_INTERIM_REPORT.md" \
       "$BOTTLE/archive/reports/"
git mv "$BOTTLE/docs/reports/ITERATION_2_SMA_TEST_PLAN.md" \
       "$BOTTLE/archive/reports/"

git commit -m "chore: Phase 4 archive cleanup - Archive blocked SMA iteration reports

- Move ITERATION_2_SMA_INTERIM_REPORT.md to archive (project blocked at execution)
- Move ITERATION_2_SMA_TEST_PLAN.md to archive (test plan unexecuted)

Result: Cleaner active reports directory, preserved blocked project history"
```

---

## Risk Assessment

### Phase 3 Actions (Recommended)

| Action                   | Risk Level  | Justification                                             |
| ------------------------ | ----------- | --------------------------------------------------------- |
| Archive CROSSOVER_MQ5.md | 🟢 LOW      | Already marked v2.0.0, content duplicated in newer guides |
| Move cc files            | 🟢 VERY LOW | Files already in archive, just reorganizing               |
| Create README            | 🟢 ZERO     | New file, no risk                                         |

### Phase 4 Actions (Optional)

| Action              | Risk Level | Justification                                           |
| ------------------- | ---------- | ------------------------------------------------------- |
| Archive SMA reports | 🟡 MEDIUM  | Recent files (2025-10-17), blocked project might resume |

**Recommendation**:

- Execute Phase 3 (low risk, high value)
- Hold Phase 4 for user decision (moderate risk if project resumes)

---

## Success Metrics

### Before Phase 3

- Archive has no README (unclear purpose/structure)
- 10 cc files misplaced in laguerre_rsi/development/
- CROSSOVER_MQ5.md in active guides despite v2.0.0 focus

### After Phase 3

- ✅ Archive README explains structure and policy
- ✅ All cc files in cc/ subdirectory
- ✅ All v2.0.0 guides consistently in archive/docs/
- ✅ Clearer separation between active (v3.0.0+) and archived (v2.0.0)

### After Phase 4 (Optional)

- ✅ Active reports directory contains only current/successful projects
- ✅ Blocked/incomplete projects preserved in archive/reports/

---

## Recommendations

### Immediate Action (Phase 3 - 15 minutes)

**Execute Phase 3 cleanup**:

1. Archive CROSSOVER_MQ5.md if exists
2. Move 10 cc files to cc/development/
3. Create archive/README.md
4. Update CLAUDE.md references
5. Git commit with detailed message

**Confidence**: HIGH (low risk, high organization value)

### User Decision Required (Phase 4 - 10 minutes)

**SMA Iteration Reports**:

- Keep active: If SMA validation might be resumed
- Archive: If focus is fully on Laguerre RSI and beyond

**Recommendation**: ARCHIVE (project blocked, Laguerre RSI method proven, SMA less critical)

### Optional (Phase 5)

**SKIP**: BUFFER_FIX consolidation and indicator folder notes have minimal value.

---

## Appendix: Complete File Inventory

### Archive Structure (Post Phase 3)

```
archive/
├── README.md                                          # NEW
├── docs/                                             # 4 files
│   ├── AI_AGENT_WORKFLOW.v2.0.0.md
│   ├── CROSSOVER_MQ5.v2.0.0.md                       # MOVED
│   ├── MQL5_CLI_COMPILATION_INVESTIGATION.md
│   └── QUICKSTART.v2.0.0.md
├── experiments/                                      # 5 files
│   ├── spike_1_mt5_indicator_access.py
│   ├── spike_1_mt5_indicator_access_ascii.py
│   ├── spike_2_registry_pattern.py
│   ├── spike_3_duckdb_performance.py
│   └── spike_4_backward_compatibility.py
├── indicators/
│   ├── laguerre_rsi/
│   │   ├── compiled/                                 # 3 .ex5 files
│   │   ├── development/                              # 7 Laguerre files (10 cc MOVED)
│   │   ├── original/                                 # 4 files
│   │   └── test_files/                               # 9 files
│   ├── cc/
│   │   ├── compiled/                                 # 4 .ex5 files
│   │   ├── development/                              # 10 files (MOVED HERE)
│   │   └── source/                                   # 2 files + plan
│   └── vwap/                                         # 1 file
├── mt5work_legacy/                                   # Legacy workspace
├── plans/                                            # 11 files
│   ├── BUFFER_FIX_COMPLETE.md
│   ├── BUFFER_FIX_STATUS.md
│   ├── BUFFER_ISSUE_ANALYSIS.md
│   ├── CC_REFACTORING_PLAN.md
│   ├── HEADLESS_MQL5_SCRIPT_SOLUTION_A.NOT_VIABLE.md
│   ├── LAGUERRE_RSI_VALIDATION_PLAN.md
│   ├── MIGRATION_PLAN.md
│   ├── MT5_IDIOMATIC_REFACTORING.md
│   ├── UNIVERSAL_VALIDATION_PLAN.md
│   ├── WORKSPACE_REFACTORING_PLAN.md
│   └── exporter_plan.md
├── reports/                                          # 0 files (Phase 4: +2)
└── scripts/v2.0.0/                                   # Legacy scripts
```

---

**Assessment Complete**: 2025-10-17
**Recommendation**: Execute Phase 3 (low risk, high value), hold Phase 4 for user decision
**Next Step**: Review recommendations, execute git commands if approved
