#!/usr/bin/env python3
"""
Automated CCI Neutrality Indicator Testing

Uses MT5 Strategy Tester for fast historical backtesting instead of waiting
for live data. Generates CSV output and runs validation automatically.

Based on:
- docs/guides/INDICATOR_VALIDATION_METHODOLOGY.md (5000-bar warmup)
- docs/MT5_REFERENCE_HUB.md (automation matrix)
- Program Files/.../CCINeutrality/README.md (Strategy Tester workflow)
"""

import subprocess
import time
from pathlib import Path
from datetime import datetime
import sys

# Paths
BOTTLE_ROOT = Path.home() / "Library/Application Support/CrossOver/Bottles/MetaTrader 5"
CROSSOVER_BIN = Path.home() / "Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin"
TERMINAL_EXE = "C:\\Program Files\\MetaTrader 5\\terminal64.exe"
FILES_DIR = BOTTLE_ROOT / "drive_c/users/crossover/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
INDICATOR_PATH = "C:\\Program Files\\MetaTrader 5\\MQL5\\Indicators\\Custom\\Development\\CCINeutrality\\CCI_Neutrality_Debug.ex5"

# Test configuration
TEST_CONFIG = {
    "symbol": "EURUSD",
    "timeframe": "M12",  # 12-minute (faster than M1, more data than M15)
    "bars": 5000,        # Per INDICATOR_VALIDATION_METHODOLOGY.md
    "start_date": "2024.01.01",
    "end_date": "2025.10.28",
}


def print_header(text):
    """Print section header."""
    print(f"\n{'='*80}")
    print(f"{text}")
    print(f"{'='*80}")


def print_step(num, text):
    """Print step."""
    print(f"\n{num}. {text}")
    print(f"{'─'*80}")


def check_prerequisites():
    """Verify all required files exist."""
    print_step(1, "Checking prerequisites")

    checks = {
        "CrossOver bin": CROSSOVER_BIN / "wine",
        "Terminal exe": BOTTLE_ROOT / "drive_c/Program Files/MetaTrader 5/terminal64.exe",
        "Debug indicator": BOTTLE_ROOT / "drive_c/Program Files/MetaTrader 5/MQL5/Indicators/Custom/Development/CCINeutrality/CCI_Neutrality_Debug.ex5",
        "Analyzer script": Path("analyze_cci_debug.py"),
    }

    all_ok = True
    for name, path in checks.items():
        exists = path.exists()
        status = "✓" if exists else "✗"
        print(f"   {status} {name}: {path}")
        if not exists:
            all_ok = False

    if not all_ok:
        print("\n❌ Prerequisites missing!")
        return False

    print("\n✅ All prerequisites found")
    return True


def create_tester_config():
    """Create MT5 tester configuration file."""
    print_step(2, "Creating Strategy Tester configuration")

    # MT5 tester config location
    config_dir = BOTTLE_ROOT / "drive_c/users/crossover/Config"
    config_dir.mkdir(exist_ok=True)

    config_path = config_dir / "tester_cci_debug.ini"

    # Strategy Tester configuration
    # See: docs/guides/SCRIPT_PARAMETER_PASSING_RESEARCH.md for startup.ini syntax
    config_content = f"""[Tester]
Expert=
Symbol={TEST_CONFIG['symbol']}
Period={TEST_CONFIG['timeframe']}
Model=0
ExecutionMode=0
Optimization=0
FromDate={TEST_CONFIG['start_date']}
ToDate={TEST_CONFIG['end_date']}
ForwardMode=0
Visual=0

[Indicator]
Name={INDICATOR_PATH}
DrawBars=0
"""

    config_path.write_text(config_content, encoding='utf-8')
    print(f"   Config written to: {config_path}")
    print(f"   Symbol: {TEST_CONFIG['symbol']}")
    print(f"   Timeframe: {TEST_CONFIG['timeframe']}")
    print(f"   Date range: {TEST_CONFIG['start_date']} to {TEST_CONFIG['end_date']}")

    return config_path


def run_strategy_tester():
    """Run MT5 Strategy Tester in headless mode."""
    print_step(3, "Running Strategy Tester (historical backtest)")

    print(f"   This will:")
    print(f"   - Load {TEST_CONFIG['bars']} bars of historical {TEST_CONFIG['symbol']} {TEST_CONFIG['timeframe']} data")
    print(f"   - Run CCI_Neutrality_Debug indicator")
    print(f"   - Generate CSV output")
    print(f"   - Should take 10-30 seconds (much faster than live data)")

    # Note: Strategy Tester automation via CLI is complex in MT5
    # For now, provide manual instructions
    # Future: Investigate MetaApi or FIX API for full automation

    print("\n   ⚠️  Strategy Tester requires GUI interaction (limitation of MT5)")
    print("\n   Manual steps:")
    print("   1. Open MT5")
    print("   2. View → Strategy Tester (Ctrl+R)")
    print("   3. Settings:")
    print(f"      - Symbol: {TEST_CONFIG['symbol']}")
    print(f"      - Period: {TEST_CONFIG['timeframe']}")
    print(f"      - Date: {TEST_CONFIG['start_date']} to {TEST_CONFIG['end_date']}")
    print("   4. Indicator → Select 'CCI_Neutrality_Debug'")
    print("   5. Click 'Start'")
    print("   6. Wait for completion (CSV written to MQL5/Files/)")

    print("\n   Alternative (faster): Attach indicator directly to chart")
    print(f"   - Open {TEST_CONFIG['symbol']} {TEST_CONFIG['timeframe']} chart")
    print("   - Scroll back to load ~5000 bars")
    print("   - Attach CCI_Neutrality_Debug indicator")
    print("   - CSV written immediately")

    return True


def wait_for_csv():
    """Wait for CSV file to be generated."""
    print_step(4, "Waiting for CSV output")

    pattern = f"cci_debug_{TEST_CONFIG['symbol']}_PERIOD_{TEST_CONFIG['timeframe']}_*.csv"

    print(f"   Watching for: {pattern}")
    print(f"   Location: {FILES_DIR}")
    print("\n   Press Ctrl+C when indicator completes and CSV is written...")

    try:
        while True:
            csv_files = list(FILES_DIR.glob(pattern))
            if csv_files:
                latest = max(csv_files, key=lambda p: p.stat().st_mtime)
                age_seconds = time.time() - latest.stat().st_mtime

                if age_seconds < 60:  # Generated in last minute
                    print(f"\n   ✅ Found: {latest.name}")
                    print(f"      Size: {latest.stat().st_size:,} bytes")
                    print(f"      Age: {age_seconds:.0f} seconds")
                    return latest

            time.sleep(2)

    except KeyboardInterrupt:
        print("\n\n   Checking for CSV files...")
        csv_files = list(FILES_DIR.glob(pattern))
        if csv_files:
            latest = max(csv_files, key=lambda p: p.stat().st_mtime)
            print(f"   Using most recent: {latest.name}")
            return latest
        else:
            print(f"   ❌ No CSV files found matching {pattern}")
            return None


def run_analysis(csv_path):
    """Run Python analysis on CSV."""
    print_step(5, "Running automated analysis")

    if not csv_path or not csv_path.exists():
        print("   ❌ CSV file not found, skipping analysis")
        return False

    print(f"   Analyzing: {csv_path.name}")

    try:
        result = subprocess.run(
            ["python3", "analyze_cci_debug.py"],
            cwd=Path.cwd(),
            capture_output=False,
            timeout=60
        )

        if result.returncode == 0:
            print("\n   ✅ Analysis completed successfully")
            return True
        else:
            print(f"\n   ❌ Analysis failed with exit code {result.returncode}")
            return False

    except subprocess.TimeoutExpired:
        print("\n   ❌ Analysis timed out (>60 seconds)")
        return False
    except Exception as e:
        print(f"\n   ❌ Analysis error: {e}")
        return False


def main():
    """Main test workflow."""
    print_header("CCI Neutrality Automated Testing")
    print(f"Strategy: Use historical data (faster than live)")
    print(f"Reference: docs/guides/INDICATOR_VALIDATION_METHODOLOGY.md")

    # Check prerequisites
    if not check_prerequisites():
        sys.exit(1)

    # Create config (for reference, not used in GUI workflow)
    config_path = create_tester_config()

    # Run Strategy Tester (manual for now)
    run_strategy_tester()

    # Wait for CSV
    csv_path = wait_for_csv()

    if not csv_path:
        print_header("Test FAILED - No CSV generated")
        sys.exit(1)

    # Run analysis
    success = run_analysis(csv_path)

    # Summary
    print_header("Test Summary")
    if success:
        print("✅ CCI Neutrality indicator test PASSED")
        print("\nNext steps:")
        print("1. Review analysis output above")
        print("2. Verify all diagnostics show ✓ PASS")
        print("3. If all pass, indicator is ready for production")
    else:
        print("❌ CCI Neutrality indicator test FAILED")
        print("\nTroubleshooting:")
        print("1. Check CSV file exists and has data")
        print("2. Review error messages above")
        print("3. Manually run: python3 analyze_cci_debug.py")

    print(f"\n{'='*80}\n")


if __name__ == "__main__":
    main()
