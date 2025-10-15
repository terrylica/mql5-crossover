# MT5 Idiomatic Directory Structure - Refactoring Plan

**Date**: 2025-10-15
**Context**: User wants MQL5 development following MT5's traditional hierarchy, visible in Navigator window
**Research**: MetaTrader 5 official documentation and best practices

---

## 🎯 Core Principle: Everything Must Be Visible in Navigator

**MetaTrader 5 Navigator Window** displays files from:
- `/MQL5/Experts/` - Expert Advisors
- `/MQL5/Indicators/` - Indicators  
- `/MQL5/Scripts/` - Scripts
- `/MQL5/Include/` - Include files (libraries)
- `/MQL5/Services/` - Services
- `/MQL5/Files/` - Data files

**Critical Issue**: Files in `mt5work/` or `users/crossover/` are NOT visible in MT5 Navigator!

---

## 📚 MT5 Official Directory Structure (From MetaQuotes Documentation)

### Standard Hierarchy

```
/MQL5/
├── Experts/           # Trading robots (Expert Advisors)
├── Indicators/        # Technical indicators
│   ├── Custom/        # User custom indicators
│   ├── Examples/      # MT5 example indicators
│   ├── Market/        # Downloaded from Market
│   └── Free Indicators/
├── Scripts/           # One-time execution scripts
│   ├── Examples/      # MT5 example scripts
│   └── UnitTests/     # Test scripts
├── Include/           # Include files (.mqh)
│   ├── Arrays/        # Standard library
│   ├── Controls/      # UI controls
│   ├── Indicators/    # Indicator helpers
│   └── [Custom]/      # YOUR custom includes
├── Files/             # Data files (read/write)
├── Libraries/         # DLL libraries
├── Services/          # Background services
└── Shared Projects/   # MQL5 Storage projects
```

### Best Practice for Project Organization

**From MT5 Documentation**:
> "If you develop a trading robot, create a separate folder for it in the Experts directory. 
> For indicators – in the Indicators directory, for scripts – in Scripts, etc."

**Example**:
```
/MQL5/Scripts/MyDataExporter/
├── Main.mq5
├── Config.mq5
└── Utils.mqh
```

---

## 🔍 Current Workspace Analysis

### Problem 1: Source Files in Wrong Location

**mt5work/** (NOT visible in Navigator):
```
mt5work/
├── ExportAligned.mq5          ❌ Should be in /MQL5/Scripts/
├── ExportEURUSD.mq5           ❌ Should be in /MQL5/Scripts/
├── Include/
│   ├── DataExportCore.mqh     ❌ Should be in /MQL5/Include/
│   ├── ExportAlignedCommon.mqh ❌ Should be in /MQL5/Include/
│   └── modules/
│       └── RSIModule.mqh      ❌ Should be in /MQL5/Include/
├── auto_export.ini            ❌ v2.0.0 legacy
├── *.log                      ❌ Temp files
└── staging/                   ❌ Not needed
```

**Include Path Problem**:
```mql5
// Current code in mt5work/ExportAligned.mq5:
#include "../Include/DataExportCore.mqh"  ❌ Broken in mt5work/

// Should be (in proper location):
#include <DataExport/DataExportCore.mqh>  ✅ Works from /MQL5/Scripts/
```

### Problem 2: Only Compiled Files in MT5 Directories

**Program Files/MetaTrader 5/MQL5/Scripts/**:
```
Scripts/
├── ExportAligned.ex5    ✅ Compiled file
├── ExportEURUSD.ex5     ✅ Compiled file
└── [NO SOURCE FILES]    ❌ Can't edit in Navigator!
```

### Current Good Structure

**Indicators/** (Already following MT5 conventions):
```
Indicators/
├── Custom/                              ✅ Your main custom indicators
│   ├── cci-woodie.mq5                  ✅ Source + compiled
│   ├── M3.mq5                          ✅ Source + compiled
│   ├── BB_Width.mq5                    ✅ Source + compiled
│   ├── CandlePatterns.mqh              ✅ Helper library
│   ├── PatternHelpers.mqh              ✅ Helper library
│   └── *.ex5                           ✅ Compiled files
└── Customs/                             ✅ Additional custom area
    ├── atr_refactor_for_python.mq5     ✅ Source + compiled
    ├── zigzag_modular.mq5              ✅ Source + compiled
    └── *.ex5                           ✅ Compiled files
```

**This is EXACTLY how it should be!** ✅

---

## 🎯 Target Structure (MT5 Idiomatic)

### Proposed Organization

```
Program Files/MetaTrader 5/MQL5/
│
├── Scripts/
│   ├── DataExport/                    # PROJECT FOLDER (visible in Navigator)
│   │   ├── ExportAligned.mq5          # Main export script
│   │   ├── ExportEURUSD.mq5           # Legacy EURUSD exporter
│   │   └── README.txt                 # Project documentation
│   ├── Examples/                      # MT5 examples (keep)
│   └── UnitTests/                     # MT5 tests (keep)
│
├── Include/
│   ├── DataExport/                    # CUSTOM INCLUDES (organized)
│   │   ├── DataExportCore.mqh
│   │   ├── ExportAlignedCommon.mqh
│   │   └── modules/
│   │       └── RSIModule.mqh
│   ├── Arrays/                        # MT5 standard library (keep)
│   ├── Controls/                      # MT5 standard library (keep)
│   └── [other MT5 standard dirs]/
│
└── Indicators/
    ├── Custom/                        # KEEP AS IS ✅
    │   ├── [all your indicators]
    │   ├── CandlePatterns.mqh
    │   └── PatternHelpers.mqh
    └── Customs/                       # KEEP AS IS ✅
        ├── atr_refactor_for_python.mq5
        └── [other custom indicators]
```

### Include Path Updates

**After refactoring, scripts will use**:
```mql5
#include <DataExport/DataExportCore.mqh>
#include <DataExport/modules/RSIModule.mqh>
```

**Standard angle bracket syntax** (`<...>`) searches in `/MQL5/Include/` directory.

---

## 🛠️ Refactoring Steps

### Phase 1: Create Target Directories

```bash
cd "Program Files/MetaTrader 5/MQL5"

# Create project folder for scripts
mkdir -p Scripts/DataExport

# Create organized include directory
mkdir -p Include/DataExport/modules
```

### Phase 2: Move Script Source Files

```bash
# Copy source files to proper location
cp ../../../mt5work/ExportAligned.mq5 Scripts/DataExport/
cp ../../../mt5work/ExportEURUSD.mq5 Scripts/DataExport/

# Copy include files
cp ../../../mt5work/Include/DataExportCore.mqh Include/DataExport/
cp ../../../mt5work/Include/ExportAlignedCommon.mqh Include/DataExport/
cp ../../../mt5work/Include/modules/RSIModule.mqh Include/DataExport/modules/
```

### Phase 3: Update Include Paths in Source Files

**Edit `Scripts/DataExport/ExportAligned.mq5`**:

```mql5
// BEFORE (mt5work relative paths):
#include "../Include/DataExportCore.mqh"
#include "../Include/modules/RSIModule.mqh"

// AFTER (MT5 standard angle bracket includes):
#include <DataExport/DataExportCore.mqh>
#include <DataExport/modules/RSIModule.mqh>
```

**Edit `Scripts/DataExport/ExportEURUSD.mq5`**:
- Same include path updates

### Phase 4: Verify in MT5 Navigator

1. Open MetaTrader 5
2. Open Navigator window (Ctrl+N)
3. Expand "Scripts" → "DataExport"
4. You should see: `ExportAligned.mq5`, `ExportEURUSD.mq5`
5. Double-click to open in MetaEditor

### Phase 5: Test Compilation

```bash
# CLI compilation (from drive_c/)
CX="~/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
"$CX" --bottle "MetaTrader 5" \
  --cx-app "C:/Program Files/MetaTrader 5/MetaEditor64.exe" \
  /log /compile:"C:/Program Files/MetaTrader 5/MQL5/Scripts/DataExport/ExportAligned.mq5" \
  /inc:"C:/Program Files/MetaTrader 5/MQL5"
```

**Expected**: 0 errors, compilation successful

### Phase 6: Archive Old mt5work/

```bash
cd /Users/terryli/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c

# Archive the old structure
mkdir -p archive/mt5work_legacy
mv mt5work/* archive/mt5work_legacy/

# Keep directory for potential future staging
# (but it will be empty)
```

---

## 📊 Python Workspace (Unchanged)

**users/crossover/** remains the Python workspace:
```
users/crossover/
├── export_aligned.py          # Wine Python v3.0.0 script
├── validate_export.py         # CSV validator (move from python/)
├── test_*.py                  # Test scripts
├── indicators/                # Python indicators
│   └── laguerre_rsi.py
└── exports/                   # CSV outputs
```

**Rationale**: 
- Python code doesn't need to be in MT5 directories
- Wine Python runs from `users/crossover/`
- Keeps Python and MQL5 workspaces cleanly separated

---

## 🎯 Final Structure Overview

### What's Visible in MT5 Navigator

```
Navigator (MetaTrader 5 GUI)
├── Indicators
│   ├── Custom
│   │   └── [All your indicators] ✅
│   └── Customs
│       └── [Additional indicators] ✅
├── Scripts
│   └── DataExport              ✅ NEW PROJECT FOLDER
│       ├── ExportAligned.mq5   ✅ Visible & editable
│       └── ExportEURUSD.mq5    ✅ Visible & editable
└── Experts
    └── [Your EAs if any]
```

### Workspace Separation

```
MT5 Workspace:    /Program Files/MetaTrader 5/MQL5/    (MQL5 development)
Python Workspace: /users/crossover/                    (Python development)
Documentation:    /docs/                               (Project docs)
Archive:          /archive/                            (Legacy code)
```

---

## ✅ Success Criteria

After refactoring:

1. ✅ All MQL5 source files visible in MT5 Navigator
2. ✅ Can double-click `.mq5` files in Navigator to edit
3. ✅ Include paths use standard `<...>` syntax
4. ✅ CLI compilation works without errors
5. ✅ GUI compilation works (F7 in MetaEditor)
6. ✅ Project folders keep related files organized
7. ✅ No files in weird locations (mt5work/, python/, scripts/)
8. ✅ Python workspace cleanly separated in users/crossover/

---

## 🚨 Critical Requirements (User Constraints)

1. **Navigator Visibility**: ALL MQL5 development must be in `/MQL5/` subdirectories
2. **Idiomatic Hierarchy**: Follow MT5's official directory structure
3. **Project Organization**: Use subdirectories like `/Scripts/DataExport/` for projects
4. **Standard Includes**: Use `<...>` syntax, not relative `"../..."`paths
5. **No Weird Directories**: Don't develop in mt5work/, python/, or other non-MT5 locations

---

## 📋 Implementation Checklist

- [ ] Create `Scripts/DataExport/` directory
- [ ] Create `Include/DataExport/modules/` directory
- [ ] Copy `mt5work/*.mq5` → `Scripts/DataExport/`
- [ ] Copy `mt5work/Include/*.mqh` → `Include/DataExport/`
- [ ] Update include paths in `.mq5` files (use `<...>` syntax)
- [ ] Test CLI compilation
- [ ] Test GUI compilation in MetaEditor
- [ ] Verify files visible in Navigator
- [ ] Archive `mt5work/` to `archive/mt5work_legacy/`
- [ ] Consolidate Python workspace (move validate_export.py)
- [ ] Archive legacy scripts (scripts/ → archive/scripts/v2.0.0/)
- [ ] Delete empty directories (python/, scripts/)
- [ ] Update documentation
- [ ] Git commit with descriptive message

---

## 🎓 MT5 Best Practices Applied

1. **Project Folders**: `Scripts/DataExport/` keeps export scripts organized
2. **Standard Includes**: `Include/DataExport/` mirrors script organization
3. **Navigator Visibility**: Everything in `/MQL5/` subdirectories
4. **Standard Syntax**: `#include <DataExport/...>` uses MT5 conventions
5. **Compiled Files**: `.ex5` files auto-generated in same directories
6. **Source Control**: Only track source files (`.mq5`, `.mqh`), ignore `.ex5`

