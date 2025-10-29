#!/usr/bin/env python3
"""
CCI Neutrality Debug Analyzer

Examines CSV output from CCI_Neutrality_Debug.mq5 to verify:
1. CCI values are sensible
2. Statistical calculations (p, mu, sd, e) are correct
3. Score components (c, v, q) are in [0,1] range
4. Composite score S = p·c·v·q is accurate
5. Coil/expansion logic triggers appropriately
6. Rolling window sums are consistent
"""

import pandas as pd
import numpy as np
from pathlib import Path


def analyze_cci_debug(csv_path):
    """Analyze CCI debug CSV output."""

    print(f"\n{'='*80}")
    print(f"CCI Neutrality Debug Analysis")
    print(f"{'='*80}")
    print(f"File: {csv_path}")

    # Read CSV
    df = pd.read_csv(csv_path, sep=';', parse_dates=['time'])

    print(f"\nDataset: {len(df)} bars")
    print(f"Period: {df['time'].iloc[0]} to {df['time'].iloc[-1]}")

    # 1. CCI Value Range
    print(f"\n{'─'*80}")
    print("1. CCI Value Analysis")
    print(f"{'─'*80}")
    print(f"   Range: [{df['cci'].min():.2f}, {df['cci'].max():.2f}]")
    print(f"   Mean: {df['cci'].mean():.2f}")
    print(f"   Std Dev: {df['cci'].std():.2f}")

    pct_in_channel = (df['in_channel'] == 1).sum() / len(df) * 100
    print(f"   In-channel [-100,100]: {pct_in_channel:.1f}%")

    # 2. Statistical Components
    print(f"\n{'─'*80}")
    print("2. Statistical Components")
    print(f"{'─'*80}")

    print(f"   p (in-channel ratio):")
    print(f"      Range: [{df['p'].min():.4f}, {df['p'].max():.4f}]")
    print(f"      Mean: {df['p'].mean():.4f}")

    print(f"   mu (mean CCI):")
    print(f"      Range: [{df['mu'].min():.2f}, {df['mu'].max():.2f}]")
    print(f"      Mean: {df['mu'].mean():.2f}")

    print(f"   sd (std dev CCI):")
    print(f"      Range: [{df['sd'].min():.2f}, {df['sd'].max():.2f}]")
    print(f"      Mean: {df['sd'].mean():.2f}")

    print(f"   e (breach magnitude ratio):")
    print(f"      Range: [{df['e'].min():.4f}, {df['e'].max():.4f}]")
    print(f"      Mean: {df['e'].mean():.4f}")

    # 3. Score Components Validation
    print(f"\n{'─'*80}")
    print("3. Score Components Validation (should be [0,1])")
    print(f"{'─'*80}")

    for comp in ['c', 'v', 'q']:
        min_val = df[comp].min()
        max_val = df[comp].max()
        status = "✓" if 0 <= min_val <= max_val <= 1 else "✗"
        print(f"   {comp}: [{min_val:.4f}, {max_val:.4f}] {status}")

    # 4. Composite Score Verification
    print(f"\n{'─'*80}")
    print("4. Composite Score Verification")
    print(f"{'─'*80}")

    df['score_calculated'] = df['p'] * df['c'] * df['v'] * df['q']
    df['score_error'] = np.abs(df['score'] - df['score_calculated'])

    max_error = df['score_error'].max()
    print(f"   Score range: [{df['score'].min():.4f}, {df['score'].max():.4f}]")
    print(f"   Formula verification (S = p·c·v·q):")
    print(f"      Max error: {max_error:.6f} {'✓' if max_error < 1e-6 else '✗'}")

    if max_error >= 1e-6:
        worst_idx = df['score_error'].idxmax()
        print(f"      Worst case at bar {df.loc[worst_idx, 'bar']}:")
        print(f"         Recorded: {df.loc[worst_idx, 'score']:.6f}")
        print(f"         Calculated: {df.loc[worst_idx, 'score_calculated']:.6f}")

    # 5. Signal Analysis
    print(f"\n{'─'*80}")
    print("5. Signal Analysis")
    print(f"{'─'*80}")

    coil_count = (df['coil'] == 1).sum()
    expansion_count = (df['expansion'] == 1).sum()

    print(f"   Coil signals: {coil_count} ({coil_count/len(df)*100:.2f}%)")
    print(f"   Expansion signals: {expansion_count} ({expansion_count/len(df)*100:.2f}%)")

    if coil_count > 0:
        coil_bars = df[df['coil'] == 1]
        print(f"\n   Coil signal stats:")
        print(f"      Avg streak: {coil_bars['streak'].mean():.1f}")
        print(f"      Avg score: {coil_bars['score'].mean():.4f}")
        print(f"      Avg p: {coil_bars['p'].mean():.4f}")
        print(f"      Avg |mu|: {np.abs(coil_bars['mu']).mean():.2f}")
        print(f"      Avg sd: {coil_bars['sd'].mean():.2f}")

        # Show first few coil signals
        print(f"\n   First 5 coil signals:")
        print(f"   {'Bar':<8} {'Time':<20} {'CCI':<10} {'Score':<10} {'Streak':<8}")
        for idx, row in coil_bars.head(5).iterrows():
            print(f"   {row['bar']:<8} {str(row['time']):<20} {row['cci']:<10.2f} "
                  f"{row['score']:<10.4f} {row['streak']:<8}")

    # 6. Rolling Window Sum Consistency
    print(f"\n{'─'*80}")
    print("6. Rolling Window Sum Verification (spot check)")
    print(f"{'─'*80}")

    # Check a few random bars
    window_size = 30  # From InpWindow default
    check_indices = np.random.choice(df.index[window_size:], min(5, len(df)-window_size), replace=False)

    max_sum_error = 0
    for idx in check_indices:
        bar_num = df.loc[idx, 'bar']

        # Manually calculate sums for window ending at idx
        window_start = max(0, idx - window_size + 1)
        window_data = df.loc[window_start:idx]

        manual_sum_b = (window_data['in_channel'] == 1).sum()
        manual_sum_cci = window_data['cci'].sum()
        manual_sum_cci2 = (window_data['cci'] ** 2).sum()

        recorded_sum_b = df.loc[idx, 'sum_b']
        recorded_sum_cci = df.loc[idx, 'sum_cci']
        recorded_sum_cci2 = df.loc[idx, 'sum_cci2']

        error_b = abs(manual_sum_b - recorded_sum_b)
        error_cci = abs(manual_sum_cci - recorded_sum_cci)
        error_cci2 = abs(manual_sum_cci2 - recorded_sum_cci2)

        max_sum_error = max(max_sum_error, error_b, error_cci, error_cci2)

    print(f"   Max rolling sum error: {max_sum_error:.6f} {'✓' if max_sum_error < 1e-3 else '✗'}")

    # 7. Threshold Compliance Check
    print(f"\n{'─'*80}")
    print("7. Coil Threshold Compliance Check")
    print(f"{'─'*80}")

    if coil_count > 0:
        coil_bars = df[df['coil'] == 1]

        # All coils should meet these thresholds
        streak_ok = (coil_bars['streak'] >= 5).all()
        p_ok = (coil_bars['p'] >= 0.80).all()
        mu_ok = (np.abs(coil_bars['mu']) <= 20.0).all()
        sd_ok = (coil_bars['sd'] <= 30.0).all()
        score_ok = (coil_bars['score'] >= 0.80).all()

        print(f"   Streak >= 5: {'✓' if streak_ok else '✗'}")
        print(f"   p >= 0.80: {'✓' if p_ok else '✗'}")
        print(f"   |mu| <= 20.0: {'✓' if mu_ok else '✗'}")
        print(f"   sd <= 30.0: {'✓' if sd_ok else '✗'}")
        print(f"   score >= 0.80: {'✓' if score_ok else '✗'}")

        all_ok = streak_ok and p_ok and mu_ok and sd_ok and score_ok
        print(f"\n   Overall compliance: {'✓ PASS' if all_ok else '✗ FAIL'}")
    else:
        print("   No coil signals to check")

    # 8. Summary
    print(f"\n{'='*80}")
    print("Summary")
    print(f"{'='*80}")

    checks = {
        "Score components in [0,1]": all(0 <= df[c].min() <= df[c].max() <= 1 for c in ['c', 'v', 'q']),
        "Score formula S=p·c·v·q": max_error < 1e-6,
        "Rolling window sums": max_sum_error < 1e-3,
        "Coil signals present": coil_count > 0,
    }

    for check, passed in checks.items():
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"   {check:<40} {status}")

    print(f"\n{'='*80}\n")

    return df


def main():
    """Find and analyze most recent CCI debug CSV."""

    files_dir = Path("/Users/terryli/Library/Application Support/CrossOver/Bottles/"
                    "MetaTrader 5/drive_c/users/crossover/AppData/Roaming/MetaQuotes/"
                    "Terminal/Common/Files")

    # Find most recent cci_debug CSV
    csv_files = list(files_dir.glob("cci_debug_*.csv"))

    if not csv_files:
        print("ERROR: No cci_debug_*.csv files found")
        print(f"Expected location: {files_dir}")
        print("\nSteps to generate CSV:")
        print("1. Open MT5")
        print("2. Attach CCI_Neutrality_Debug indicator to a chart")
        print("3. Wait for it to calculate (check Journal for 'CSV debug output' message)")
        print("4. CSV will be written to MQL5/Files/")
        return

    # Use most recent file
    latest_csv = max(csv_files, key=lambda p: p.stat().st_mtime)

    print(f"\nFound {len(csv_files)} CSV file(s)")
    print(f"Using most recent: {latest_csv.name}")

    df = analyze_cci_debug(latest_csv)

    # Optionally export summary
    summary_path = latest_csv.parent / f"{latest_csv.stem}_summary.txt"
    print(f"Summary available at: {summary_path}")


if __name__ == "__main__":
    main()
