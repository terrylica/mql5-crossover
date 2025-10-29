#!/usr/bin/env python3
"""
CCI Neutrality Score - Comprehensive Distribution Analysis

Analyzes 200k+ bars of data to identify:
1. Component distributions (p, c, v, q)
2. Bottleneck components (limiting factors)
3. Percentiles and modes
4. Optimal normalization constants
5. Formula recommendations
"""

import pandas as pd
import numpy as np
from pathlib import Path
from scipy import stats

# Load CSV
csv_path = Path("/Users/terryli/Library/Application Support/CrossOver/Bottles/MetaTrader 5/drive_c/Program Files/MetaTrader 5/MQL5/Files/cci_debug_EURUSD_PERIOD_M12_2025.10.29.csv")

print("=== CCI Neutrality Score Distribution Analysis ===\n")
print(f"Loading data from: {csv_path.name}")
print(f"File size: {csv_path.stat().st_size / 1e6:.1f} MB\n")

df = pd.read_csv(csv_path, sep=';')
print(f"Total bars: {len(df):,}")
print(f"Date range: {df['time'].iloc[0]} to {df['time'].iloc[-1]}")
print(f"Data columns: {', '.join(df.columns)}\n")

# Filter out warmup bars (first 50 bars where score might be invalid)
df_valid = df[df['bar'] >= 50].copy()
print(f"Valid bars (after warmup): {len(df_valid):,}\n")

# Extract components
components = {
    'p': df_valid['p'],      # Fraction in channel
    'c': df_valid['c'],      # Centering (1 - |mean|/C0)
    'v': df_valid['v'],      # Dispersion (1 - stdev/C1)
    'q': df_valid['q'],      # Breach magnitude (1 - excess/C2)
    'score': df_valid['score']  # Final multiplicative score
}

# Also calculate theoretical scores
df_valid['score_additive'] = 0.25 * (df_valid['p'] + df_valid['c'] + df_valid['v'] + df_valid['q'])
df_valid['score_geometric'] = (df_valid['p'] * df_valid['c'] * df_valid['v'] * df_valid['q']) ** 0.25
df_valid['score_power'] = (df_valid['p'] * df_valid['c'] * df_valid['v'] * df_valid['q']) ** 0.5

print("=" * 80)
print("COMPONENT DISTRIBUTION STATISTICS")
print("=" * 80)

for name, data in components.items():
    print(f"\n{name.upper()} Component:")
    print(f"  Mean:   {data.mean():.6f}")
    print(f"  Median: {data.median():.6f}")
    print(f"  Std:    {data.std():.6f}")
    print(f"  Min:    {data.min():.6f}")
    print(f"  Max:    {data.max():.6f}")
    print(f"  Percentiles:")
    for pct in [1, 5, 10, 25, 50, 75, 90, 95, 99]:
        print(f"    P{pct:2d}: {data.quantile(pct/100):.6f}")

    # Mode detection (rounded to 3 decimals for binning)
    data_rounded = (data * 1000).round() / 1000
    mode_val = data_rounded.mode().iloc[0] if len(data_rounded.mode()) > 0 else np.nan
    mode_count = (data_rounded == mode_val).sum()
    mode_pct = mode_count / len(data) * 100
    print(f"  Mode: {mode_val:.6f} ({mode_count:,} occurrences, {mode_pct:.1f}%)")

    # Zero counts (critical for multiplicative formula)
    zero_count = (data == 0.0).sum()
    near_zero_count = (data < 0.001).sum()
    print(f"  Zeros: {zero_count:,} ({zero_count/len(data)*100:.2f}%)")
    print(f"  Near-zero (<0.001): {near_zero_count:,} ({near_zero_count/len(data)*100:.2f}%)")

print("\n" + "=" * 80)
print("BOTTLENECK ANALYSIS (Which component limits the score?)")
print("=" * 80)

# For each bar, find the minimum component (bottleneck)
component_matrix = df_valid[['p', 'c', 'v', 'q']].values
bottleneck_idx = np.argmin(component_matrix, axis=1)
bottleneck_names = ['p', 'c', 'v', 'q']

print("\nBottleneck frequency (which component is lowest most often):")
for i, name in enumerate(bottleneck_names):
    count = (bottleneck_idx == i).sum()
    pct = count / len(df_valid) * 100
    print(f"  {name}: {count:,} bars ({pct:.1f}%)")

# Average bottleneck value
print("\nAverage value when each component is the bottleneck:")
for i, name in enumerate(bottleneck_names):
    mask = bottleneck_idx == i
    if mask.sum() > 0:
        avg_val = df_valid[name][mask].mean()
        print(f"  {name}: {avg_val:.6f}")

print("\n" + "=" * 80)
print("SCORE DISTRIBUTION COMPARISON")
print("=" * 80)

score_variants = {
    'Current (Multiplicative)': df_valid['score'],
    'Additive (0.25×sum)': df_valid['score_additive'],
    'Geometric Mean (4th root)': df_valid['score_geometric'],
    'Power Transform (sqrt)': df_valid['score_power']
}

for variant_name, scores in score_variants.items():
    print(f"\n{variant_name}:")
    print(f"  Mean:   {scores.mean():.6f}")
    print(f"  Median: {scores.median():.6f}")
    print(f"  P95:    {scores.quantile(0.95):.6f}")
    print(f"  P99:    {scores.quantile(0.99):.6f}")
    print(f"  Above 0.03 (Yellow): {(scores >= 0.03).sum():,} ({(scores >= 0.03).sum()/len(scores)*100:.1f}%)")
    print(f"  Above 0.06 (Green):  {(scores >= 0.06).sum():,} ({(scores >= 0.06).sum()/len(scores)*100:.1f}%)")

print("\n" + "=" * 80)
print("OPTIMAL NORMALIZATION CONSTANTS")
print("=" * 80)

# Current constants
C0_current = 50.0  # for centering
C1_current = 50.0  # for dispersion

# Calculate actual mean and stdev distributions
abs_mean = df_valid['mu'].abs()
stdev = df_valid['sd']

print("\n|mean| distribution (for C0 optimization):")
print(f"  Current C0: {C0_current}")
print(f"  Median |mean|: {abs_mean.median():.2f}")
print(f"  P75 |mean|:    {abs_mean.quantile(0.75):.2f}")
print(f"  P90 |mean|:    {abs_mean.quantile(0.90):.2f}")
print(f"  P95 |mean|:    {abs_mean.quantile(0.95):.2f}")
print(f"  Recommendation: C0 = {abs_mean.quantile(0.75):.0f}-{abs_mean.quantile(0.90):.0f}")

print("\nstdev distribution (for C1 optimization):")
print(f"  Current C1: {C1_current}")
print(f"  Median stdev: {stdev.median():.2f}")
print(f"  P75 stdev:    {stdev.quantile(0.75):.2f}")
print(f"  P90 stdev:    {stdev.quantile(0.90):.2f}")
print(f"  P95 stdev:    {stdev.quantile(0.95):.2f}")
print(f"  Recommendation: C1 = {stdev.quantile(0.75):.0f}-{stdev.quantile(0.90):.0f}")

print("\n" + "=" * 80)
print("RECOMMENDATIONS")
print("=" * 80)

print("""
Based on 200k+ bars of analysis:

1. BOTTLENECK IDENTIFICATION:
   - Check which component (p/c/v/q) is most often the limiting factor
   - Target that component for relaxation first

2. FORMULA ALTERNATIVES (ranked by spike frequency increase):

   a) ADDITIVE (Best for high spike frequency):
      score = 0.25×(p + c + v + q)
      Pros: Compensatory, one weak component doesn't kill score
      Cons: Less strict definition of "neutrality"

   b) GEOMETRIC MEAN (Balanced):
      score = (p × c × v × q)^0.25
      Pros: Still multiplicative but less harsh
      Cons: Still somewhat strict

   c) RELAXED CONSTANTS (Easiest to test):
      Increase C0, C1, C2 by 50-100%
      Pros: Simple parameter change
      Cons: Less dramatic improvement

3. NORMALIZATION STRATEGY:
   - Use P75-P90 as target range (not P50)
   - This creates "achievable stretch goals" rather than "impossible standards"

4. ADAPTIVE PERCENTILE APPROACH:
   - Top 20% → Green
   - Middle 40% → Yellow
   - Bottom 40% → Red
   - Guarantees consistent spike frequency regardless of market regime
""")

print("\nAnalysis complete. Data saved to: distribution_analysis.txt")

# Save detailed report
with open('distribution_analysis.txt', 'w') as f:
    f.write("CCI Neutrality Score - Distribution Analysis Report\n")
    f.write("=" * 80 + "\n\n")

    for name, data in components.items():
        f.write(f"{name.upper()} Component:\n")
        f.write(f"  Mean: {data.mean():.6f}, Median: {data.median():.6f}\n")
        f.write(f"  Percentiles: " + ", ".join([f"P{p}={data.quantile(p/100):.6f}" for p in [5,25,50,75,95]]) + "\n\n")

    f.write("\nBottleneck Analysis:\n")
    for i, name in enumerate(bottleneck_names):
        count = (bottleneck_idx == i).sum()
        pct = count / len(df_valid) * 100
        f.write(f"  {name}: {pct:.1f}% of bars\n")

print("\nDone!")
