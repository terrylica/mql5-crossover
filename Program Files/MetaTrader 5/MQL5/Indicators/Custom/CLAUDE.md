# Custom Indicators Context

**Purpose**: Project-based indicator organization and development patterns.

**Navigation**: [MQL5/CLAUDE.md](../../CLAUDE.md) | [Root CLAUDE.md](../../../../../CLAUDE.md)

---

## Folder Structure

| Folder | Purpose | MT5 Navigator Path |
|--------|---------|-------------------|
| `ProductionIndicators/` | Production-ready indicators | Indicators → Custom → ProductionIndicators |
| `PythonInterop/` | Python export workflow indicators | Indicators → Custom → PythonInterop |
| `Libraries/` | Shared library files (.mqh) | Indicators → Custom → Libraries |
| `Development/` | Active development projects | Indicators → Custom → Development |

---

## Design Principles

1. **Functional Separation**: Production vs Python vs Libraries vs Development
2. **Project Self-Containment**: Local dependencies in project folders
3. **Scalability**: Add new project folders as needed
4. **MT5 Navigator Visibility**: Organized hierarchy visible in MT5

---

## Development Project Example

```
Development/
└── ConsecutivePattern/           # cc indicator project
    ├── cc.mq5                    # Main version
    ├── cc_backup.mq5             # Standalone fallback
    └── lib/                      # Local project libraries
        └── CCIPatternLib.mqh     # Project-specific include
```

**Pattern**: Keep project dependencies local to avoid cross-project conflicts.

---

## Adding New Indicators

1. **Development**: Create folder in `Development/` with project name
2. **Testing**: Validate using Python comparison (≥0.999 correlation)
3. **Production**: Move to `ProductionIndicators/` when validated
4. **Python Export**: If exporting data, add to `PythonInterop/`

---

## Compilation

```bash
# From project root
./tools/compile_mql5.sh "Indicators/Custom/Development/MyProject/MyIndicator.mq5"

# Or use skill
/mql5-x-compile
```

**Reference**: [../../CLAUDE.md](../../CLAUDE.md) for compilation details

---

## Current Inventory

### ProductionIndicators/
- 6 production-ready indicators (renamed with descriptive names)

### PythonInterop/
- 6 Python export workflow indicators

### Development/
- ConsecutivePattern (cc indicator)
- CCINeutrality (CCI Neutrality Adaptive)

---

## Archived Indicators

Historical versions are preserved in `../../../../../archive/indicators/`:

| Subfolder | Content |
|-----------|---------|
| `laguerre_rsi/` | Laguerre RSI development history |
| `cc/` | Consecutive Pattern versions |
| `vwap/` | VWAP indicator |

**Reference**: [../../../../../docs/archive/CLAUDE.md](../../../../../docs/archive/CLAUDE.md)
