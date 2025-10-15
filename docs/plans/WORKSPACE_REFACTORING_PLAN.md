# MT5 CrossOver Workspace - Structural Analysis & Refactoring Plan

**Date**: 2025-10-15
**Commit**: c741b25 (Laguerre RSI cleanup)
**Purpose**: Deep dive analysis for structural refactoring

---

## 📊 Current Structure Overview

### Top-Level Directories

```
/Users/terryli/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c/
├── .claude/                    # Claude Code local settings
├── .git/                       # Git repository (2 commits)
├── archive/                    # Archived development files (1MB)
├── docs/                       # Documentation (from mql5-crossover)
├── mt5work/                    # MQL5 staging/working area
├── python/                     # Validation utilities (mostly empty)
├── scripts/                    # Legacy v2.0.0 scripts
├── users/crossover/            # ACTIVE: Wine Python scripts + indicators
├── Program Files/MetaTrader 5/ # MT5 installation
└── Program Files/Python312/    # Wine Python 3.12 (gitignored)
```

---

## 🔍 Directory Analysis

### 1. `users/crossover/` ✅ ACTIVE WORKSPACE

**Size**: 592MB (mostly Windows user data in AppData/)

**Essential Files**:
```
users/crossover/
├── export_aligned.py              # Wine Python export script (v3.0.0)
├── test_mt5_connection.py         # MT5 API test
├── test_xauusd_info.py            # Symbol info test
├── indicators/
│   ├── __init__.py
│   └── laguerre_rsi.py            # Python indicator implementation
└── exports/                       # CSV outputs (gitignored)
```

**Status**: ✅ **This is the PRIMARY working directory**

**Issues**: None - well organized

---

### 2. `python/` ⚠️ NEARLY EMPTY

**Contents**:
```
python/
├── .gitkeep
└── validate_export.py             # CSV validator
```

**Issues**:
- ❌ Only has 1 file (validate_export.py)
- ❌ Python indicators are in `users/crossover/indicators/` instead
- ❌ Creates expectation of Python workspace but doesn't deliver

**Refactoring Options**:
1. **CONSOLIDATE**: Move `validate_export.py` → `users/crossover/`
2. **ELIMINATE**: Delete `python/` directory entirely
3. **EXPAND**: Move all Python code from `users/crossover/` → `python/`

**Recommendation**: Option 1 (CONSOLIDATE) - Keep everything in `users/crossover/`

---

### 3. `scripts/` ⚠️ LEGACY v2.0.0

**Contents**:
```
scripts/
├── .gitkeep
├── mq5run                         # v2.0.0 startup.ini wrapper
└── setup-bottle-mapping           # X: drive mapping utility
```

**Issues**:
- ⚠️ `mq5run` is v2.0.0 legacy (startup.ini approach - DEPRECATED)
- ⚠️ Not needed for v3.0.0 Wine Python workflow

**Status Check**: From project memory:
> v2.0.0 (startup.ini) - LEGACY ⚠️
> **Limitation**: requires manual GUI initialization per symbol/timeframe
> **Recommendation**: Migrate to v3.0.0 for production use

**Refactoring Options**:
1. **ARCHIVE**: Move to `archive/scripts/v2.0.0/`
2. **DELETE**: Remove entirely (v3.0.0 doesn't need these)
3. **KEEP**: Maintain for backwards compatibility

**Recommendation**: Option 1 (ARCHIVE) - Keep for reference but out of main workspace

---

### 4. `mt5work/` ⚠️ STAGING/DUPLICATE AREA

**Contents**:
```
mt5work/
├── auto_export.ini                # 17KB config
├── ExportAligned.mq5              # MQL5 source (2.1KB)
├── ExportEURUSD.mq5               # MQL5 source (1.5KB)
├── ExportEURUSD.ex5               # Compiled (13KB)
├── TestSimple.mq5                 # Test source
├── TestSimple.ex5                 # Compiled
├── *.log, *.log.utf8              # Compilation logs
├── Include/
│   ├── DataExportCore.mqh         # 2.6KB
│   ├── ExportAlignedCommon.mqh    # 2.4KB
│   └── modules/
│       └── RSIModule.mqh
└── staging/
    └── mql5_export/
```

**Issues**:
- ❌ MQL5 source files (.mq5) no longer exist in `Program Files/MetaTrader 5/MQL5/Scripts/`
- ❌ This appears to be the ONLY location with source files
- ⚠️ v3.0.0 uses Wine Python directly - MQL5 scripts may not be needed anymore

**Critical Question**: Are these MQL5 source files still needed?
- If **YES** (need to modify/recompile): Keep and organize properly
- If **NO** (v3.0.0 uses Python only): Archive or delete

**Recommendation**: CLARIFY usage before refactoring

---

### 5. `docs/` ✅ WELL ORGANIZED

**Contents**:
```
docs/
├── README.md                      # Index
├── guides/                        # 16 files, ~200KB
├── plans/                         # 4 files
├── reports/                       # 2 files
└── archive/                       # Historical docs
```

**Status**: ✅ Copied from mql5-crossover repo (Oct 14), well structured

**Issues**: None

---

### 6. `archive/` ✅ PROPER ARCHIVAL

**Contents**:
```
archive/
└── indicators/
    └── laguerre_rsi/
        ├── original/              # 5 files (buggy versions)
        ├── development/           # 17 files (iterations)
        └── test_files/            # 10 files (encoding tests)
```

**Size**: 1MB

**Status**: ✅ Proper archival from cleanup in commit c741b25

**Issues**: None - archives compiled .ex5 files (gitignored)

---

### 7. `.claude/` ✅ LOCAL CONFIG

**Contents**:
```
.claude/
└── settings.local.json            # Permissions config
```

**Status**: ✅ Proper local configuration (not for git commit)

---

## 🎯 Refactoring Recommendations

### Priority 1: Consolidate Python Workspace

**Problem**: Python code split between two locations
- `python/validate_export.py`
- `users/crossover/*.py` + `users/crossover/indicators/`

**Solution**: Move everything to `users/crossover/`

```bash
# Move validator
mv python/validate_export.py users/crossover/

# Update any imports in export_aligned.py if needed

# Delete empty python/ directory
rm -rf python/
```

**Benefits**:
- Single source of truth for Python code
- Matches v3.0.0 architecture (Wine Python in users/crossover/)
- Cleaner workspace structure

---

### Priority 2: Archive Legacy Scripts

**Problem**: v2.0.0 scripts still in active `scripts/` directory

**Solution**: Archive to `archive/scripts/v2.0.0/`

```bash
# Create archive directory
mkdir -p archive/scripts/v2.0.0

# Move legacy scripts
mv scripts/mq5run archive/scripts/v2.0.0/
mv scripts/setup-bottle-mapping archive/scripts/v2.0.0/

# Delete empty scripts/ directory
rm -rf scripts/
```

**Benefits**:
- Removes confusion about which scripts to use
- Preserves history for reference
- Cleaner workspace

---

### Priority 3: Clarify mt5work/ Purpose

**Problem**: MQL5 source files exist only in mt5work/, unclear if still needed

**Questions to Answer**:
1. Are these MQL5 export scripts still used? (v3.0.0 uses Wine Python directly)
2. Should source files be in `Program Files/MetaTrader 5/MQL5/Scripts/`?
3. Is mt5work/ a temporary staging area or permanent workspace?

**Options**:

**Option A**: If MQL5 scripts NOT needed (v3.0.0 Python-only)
```bash
# Archive all MQL5 source files
mv mt5work/ archive/mt5work_legacy/
```

**Option B**: If MQL5 scripts STILL needed (for compilation)
```bash
# Move source files to proper MT5 locations
cp mt5work/ExportAligned.mq5 "Program Files/MetaTrader 5/MQL5/Scripts/"
cp mt5work/Include/*.mqh "Program Files/MetaTrader 5/MQL5/Include/"

# Keep mt5work/ as staging area for development
```

**Recommendation**: Ask user to clarify usage patterns

---

## 📈 Proposed Final Structure

### Option 1: Python-Only Workflow (v3.0.0 Pure)

```
drive_c/
├── .claude/                       # Local settings
├── .git/                          # Git repo
├── docs/                          # Documentation ✅
├── archive/                       # All legacy code
│   ├── indicators/laguerre_rsi/   # Old indicator versions
│   ├── scripts/v2.0.0/            # Legacy mq5run, setup scripts
│   └── mt5work_legacy/            # MQL5 source files (if not needed)
├── users/crossover/               # PRIMARY WORKSPACE ⭐
│   ├── export_aligned.py          # Wine Python export (v3.0.0)
│   ├── validate_export.py         # Moved from python/
│   ├── test_*.py                  # Test scripts
│   ├── indicators/                # Python indicators
│   │   ├── __init__.py
│   │   └── laguerre_rsi.py
│   └── exports/                   # CSV outputs
└── Program Files/MetaTrader 5/    # MT5 installation
    ├── Config/
    │   └── terminal.ini           # Tracked config
    └── MQL5/
        ├── Indicators/
        │   ├── Custom/            # Only compiled .ex5 files
        │   │   ├── *.ex5          # Production indicators
        │   │   ├── CandlePatterns.mqh
        │   │   └── CC_REFACTORING_PLAN.md
        │   └── Customs/           # Additional indicators
        └── Scripts/
            └── *.ex5              # Only compiled scripts
```

**Characteristics**:
- ✅ Single Python workspace in `users/crossover/`
- ✅ No legacy scripts in main workspace
- ✅ MQL5 sources archived (if not needed)
- ✅ Clean separation: docs, archive, active code

---

### Option 2: Hybrid Workflow (Keep MQL5 Development)

```
drive_c/
├── .claude/                       # Local settings
├── .git/                          # Git repo
├── docs/                          # Documentation ✅
├── archive/                       # Legacy versions only
│   ├── indicators/laguerre_rsi/
│   └── scripts/v2.0.0/
├── mt5work/                       # MQL5 DEVELOPMENT WORKSPACE
│   ├── Scripts/                   # Source .mq5 files
│   ├── Include/                   # Include .mqh files
│   └── staging/                   # Temp compilation area
├── users/crossover/               # PYTHON WORKSPACE ⭐
│   ├── export_aligned.py
│   ├── validate_export.py
│   ├── test_*.py
│   ├── indicators/
│   │   └── laguerre_rsi.py
│   └── exports/
└── Program Files/MetaTrader 5/    # MT5 installation (compiled only)
    └── MQL5/
        ├── Indicators/Custom/     # Compiled .ex5 + .mqh
        └── Scripts/               # Compiled .ex5
```

**Characteristics**:
- ✅ Separate workspaces: mt5work/ (MQL5) + users/crossover/ (Python)
- ✅ MQL5 source files preserved for compilation
- ⚠️ More complex structure

---

## 🤔 Questions for User

1. **MQL5 Scripts Usage**: Are you still compiling/editing MQL5 scripts, or is v3.0.0 Wine Python sufficient?
   - If Python-only → Archive mt5work/
   - If still using MQL5 → Keep mt5work/ as development area

2. **Validation Script Location**: Move `python/validate_export.py` → `users/crossover/`?
   - Consolidates all Python code in one place
   - Matches v3.0.0 architecture

3. **Legacy Scripts**: Archive `scripts/mq5run` and `scripts/setup-bottle-mapping`?
   - These are v2.0.0 legacy tools
   - Not needed for v3.0.0 workflow

---

## ✅ Recommended Actions (If Python-Only)

```bash
# 1. Consolidate Python workspace
mv python/validate_export.py users/crossover/
rm -rf python/

# 2. Archive legacy scripts
mkdir -p archive/scripts/v2.0.0
mv scripts/* archive/scripts/v2.0.0/
rm -rf scripts/

# 3. Archive MQL5 development files (if not needed)
mv mt5work/ archive/mt5work_legacy/

# 4. Commit refactoring
git add -A
git commit -m "refactor: Consolidate Python workspace and archive legacy code

- Move validate_export.py to users/crossover/ (single Python workspace)
- Archive v2.0.0 scripts (mq5run, setup-bottle-mapping)
- Archive mt5work/ MQL5 source files (v3.0.0 uses Wine Python)
- Final structure: docs/, archive/, users/crossover/ (active), Program Files/

Rationale: v3.0.0 Wine Python workflow doesn't need MQL5 scripts or v2.0.0 wrappers"
```

---

## 📊 Space Savings

```
Before refactoring: ~600MB tracked
After refactoring:  ~10MB tracked (everything else gitignored)

Breakdown:
- users/crossover/ Python code: ~30KB
- docs/: ~200KB
- archive/: ~1MB (source .mq5 only, .ex5 gitignored)
- Program Files/MetaTrader 5/MQL5/Indicators/Custom/: ~50KB
```

---

## 🎯 Success Criteria

After refactoring:
1. ✅ Single Python workspace in `users/crossover/`
2. ✅ No duplicate files between directories
3. ✅ Legacy code clearly separated in `archive/`
4. ✅ Clean `git status` (no confusion about tracked files)
5. ✅ v3.0.0 CLI workflow still works (Wine Python export)
6. ✅ Documentation remains accessible in `docs/`

