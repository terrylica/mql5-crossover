#!/usr/bin/env python3
"""
Generate CCI Test Dataset via Wine Python

Fully automated historical data fetch using MT5 Python API.
No GUI interaction needed - runs completely headless.

Based on:
- docs/guides/WINE_PYTHON_EXECUTION.md (v3.0.0 workflow)
- docs/guides/INDICATOR_VALIDATION_METHODOLOGY.md (5000-bar requirement)

Usage:
    CX_BOTTLE="MetaTrader 5" \\
    WINEPREFIX="$HOME/Library/Application Support/CrossOver/Bottles/MetaTrader 5" \\
    wine "C:\\Program Files\\Python312\\python.exe" \\
      "C:\\users\\crossover\\generate_test_data.py" \\
      --symbol EURUSD --period M12 --bars 5000
"""

import sys
import argparse
from datetime import datetime


def main():
    parser = argparse.ArgumentParser(description='Generate CCI test dataset')
    parser.add_argument('--symbol', default='EURUSD', help='Symbol (default: EURUSD)')
    parser.add_argument('--period', default='M12', help='Timeframe (default: M12)')
    parser.add_argument('--bars', type=int, default=5000, help='Number of bars (default: 5000)')
    args = parser.parse_args()

    try:
        import MetaTrader5 as mt5
        import pandas as pd
        import numpy as np
    except ImportError as e:
        print(f"ERROR: Missing dependency: {e}")
        print("Required: MetaTrader5, pandas, numpy")
        sys.exit(1)

    # Initialize MT5
    if not mt5.initialize():
        print(f"ERROR: MT5 initialization failed, error: {mt5.last_error()}")
        sys.exit(1)

    print(f"MT5 version: {mt5.version()}")
    print(f"MT5 terminal info: {mt5.terminal_info()}")

    # Map period string to MT5 constant
    period_map = {
        'M1': mt5.TIMEFRAME_M1,
        'M2': mt5.TIMEFRAME_M2,
        'M3': mt5.TIMEFRAME_M3,
        'M4': mt5.TIMEFRAME_M4,
        'M5': mt5.TIMEFRAME_M5,
        'M6': mt5.TIMEFRAME_M6,
        'M10': mt5.TIMEFRAME_M10,
        'M12': mt5.TIMEFRAME_M12,
        'M15': mt5.TIMEFRAME_M15,
        'M20': mt5.TIMEFRAME_M20,
        'M30': mt5.TIMEFRAME_M30,
        'H1': mt5.TIMEFRAME_H1,
        'H2': mt5.TIMEFRAME_H2,
        'H3': mt5.TIMEFRAME_H3,
        'H4': mt5.TIMEFRAME_H4,
        'H6': mt5.TIMEFRAME_H6,
        'H8': mt5.TIMEFRAME_H8,
        'H12': mt5.TIMEFRAME_H12,
        'D1': mt5.TIMEFRAME_D1,
        'W1': mt5.TIMEFRAME_W1,
        'MN1': mt5.TIMEFRAME_MN1,
    }

    if args.period not in period_map:
        print(f"ERROR: Invalid period '{args.period}'")
        print(f"Valid periods: {', '.join(period_map.keys())}")
        mt5.shutdown()
        sys.exit(1)

    timeframe = period_map[args.period]

    # Select symbol
    if not mt5.symbol_select(args.symbol, True):
        print(f"ERROR: Failed to select symbol {args.symbol}, error: {mt5.last_error()}")
        mt5.shutdown()
        sys.exit(1)

    print(f"\nFetching {args.bars} bars of {args.symbol} {args.period}...")

    # Fetch rates
    rates = mt5.copy_rates_from_pos(args.symbol, timeframe, 0, args.bars)

    if rates is None or len(rates) == 0:
        print(f"ERROR: Failed to fetch rates, error: {mt5.last_error()}")
        mt5.shutdown()
        sys.exit(1)

    # Convert to DataFrame
    df = pd.DataFrame(rates)
    df['time'] = pd.to_datetime(df['time'], unit='s')

    print(f"Fetched {len(df)} bars")
    print(f"Date range: {df['time'].iloc[0]} to {df['time'].iloc[-1]}")

    # Now calculate CCI manually to generate reference data
    print("\nCalculating CCI reference values...")

    # CCI parameters (match indicator defaults)
    cci_period = 20

    # Calculate typical price
    df['tp'] = (df['high'] + df['low'] + df['close']) / 3

    # Calculate SMA of typical price
    df['sma_tp'] = df['tp'].rolling(window=cci_period).mean()

    # Calculate mean absolute deviation
    def mad(x):
        """Mean Absolute Deviation."""
        if len(x) < 2:
            return 0.0
        mean = x.mean()
        return np.abs(x - mean).mean()

    df['mad_tp'] = df['tp'].rolling(window=cci_period).apply(mad, raw=False)

    # Calculate CCI
    df['cci'] = (df['tp'] - df['sma_tp']) / (0.015 * df['mad_tp'])

    # Handle division by zero
    df['cci'] = df['cci'].replace([np.inf, -np.inf], np.nan)

    # Count valid CCI values
    valid_cci = df['cci'].notna().sum()
    print(f"Valid CCI values: {valid_cci} / {len(df)}")

    # Save to CSV
    output_path = f"C:\\users\\crossover\\test_data_{args.symbol}_{args.period}_{args.bars}bars.csv"
    df[['time', 'open', 'high', 'low', 'close', 'tick_volume', 'spread', 'real_volume', 'cci']].to_csv(
        output_path, index=False
    )

    print(f"\nTest data saved to: {output_path}")
    print(f"Columns: time, OHLC, volumes, CCI reference")
    print(f"\nStatistics:")
    print(f"  CCI range: [{df['cci'].min():.2f}, {df['cci'].max():.2f}]")
    print(f"  CCI mean: {df['cci'].mean():.2f}")
    print(f"  CCI std: {df['cci'].std():.2f}")

    in_channel = ((df['cci'].abs() <= 100) & df['cci'].notna()).sum()
    pct_in_channel = in_channel / valid_cci * 100 if valid_cci > 0 else 0
    print(f"  In-channel [-100,100]: {pct_in_channel:.1f}%")

    mt5.shutdown()
    print("\nDone!")


if __name__ == "__main__":
    main()
