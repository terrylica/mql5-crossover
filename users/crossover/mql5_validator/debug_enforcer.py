"""
Debug Enforcer

Analyzes MQL5 source code to ensure it follows the debugging patterns
required for effective validation. Enforces the canonical debug flow
learned from cc indicator v1.20-v1.23 debugging session.

Required Debug Patterns:
1. Signal count logging in pattern detection
2. Body size/value logging for pattern analysis
3. Direction logging (BULL/BEAR)
4. Summary logging at end of OnCalculate
"""

import re
from pathlib import Path
from dataclasses import dataclass
from enum import Enum


class EnforcementLevel(Enum):
    """Enforcement levels for debug requirements."""
    REQUIRED = "required"
    RECOMMENDED = "recommended"
    OPTIONAL = "optional"


@dataclass
class DebugPattern:
    """A debug pattern requirement."""
    name: str
    pattern: re.Pattern
    level: EnforcementLevel
    description: str
    example: str


@dataclass
class EnforcementResult:
    """Result of enforcement check."""
    pattern_name: str
    found: bool
    level: EnforcementLevel
    message: str
    line_number: int | None = None
    suggestion: str | None = None


class DebugEnforcer:
    """
    Enforce debug patterns in MQL5 source code.

    Based on the canonical debug flow from cc indicator debugging:
    1. Count signals during detection
    2. Log body sizes for pattern analysis
    3. Log signal direction
    4. Print summary at end

    Usage:
        enforcer = DebugEnforcer()
        results = enforcer.analyze_file("/path/to/indicator.mq5")
        report = enforcer.generate_report(results)
        print(report)
    """

    # Canonical debug patterns that should be present
    PATTERNS = [
        DebugPattern(
            name="signal_counter",
            pattern=re.compile(r'(signalCount|signal_count|SignalCount)\s*(\+\+|=\s*\d+|\+=)', re.IGNORECASE),
            level=EnforcementLevel.REQUIRED,
            description="Counter variable for tracking number of signals",
            example="int signalCount = 0;\n// then in loop:\nsignalCount++;"
        ),
        DebugPattern(
            name="debug_body_sizes",
            pattern=re.compile(r'Print\s*\([^)]*(?:bodies|body.*size|BodySize)', re.IGNORECASE),
            level=EnforcementLevel.REQUIRED,
            description="Debug output logging body sizes for pattern analysis",
            example='Print("DEBUG bar ", i, ": bodies=[", DoubleToString(bodySizes[i], 5), "]");'
        ),
        DebugPattern(
            name="debug_direction",
            pattern=re.compile(r'Print\s*\([^)]*(?:BULL|BEAR|bullish|bearish)', re.IGNORECASE),
            level=EnforcementLevel.REQUIRED,
            description="Debug output logging signal direction",
            example='Print("DEBUG: ", isPatternBullish ? "BULL" : "BEAR");'
        ),
        DebugPattern(
            name="total_signals_summary",
            pattern=re.compile(r'Print\s*\([^)]*[Tt]otal.*signal', re.IGNORECASE),
            level=EnforcementLevel.REQUIRED,
            description="Summary logging of total signals at end of calculation",
            example='Print("DEBUG: Total expansion signals: ", signalCount, " out of ", rates_total, " bars");'
        ),
        DebugPattern(
            name="debug_limited",
            pattern=re.compile(r'if\s*\(\s*(?:debugCount|debug_count)\s*<\s*\d+', re.IGNORECASE),
            level=EnforcementLevel.RECOMMENDED,
            description="Limit debug output to first N signals to avoid log spam",
            example='if(debugCount < 10) { Print("DEBUG..."); debugCount++; }'
        ),
        DebugPattern(
            name="overlapping_check",
            pattern=re.compile(r'(?:extends|overlapping|previous|extends.*earlier)', re.IGNORECASE),
            level=EnforcementLevel.RECOMMENDED,
            description="Logic to check for overlapping pattern sequences",
            example='bool extendsEarlier = (BufferBodySizes[i-1] > BufferBodySizes[i]);'
        ),
        DebugPattern(
            name="prev_calculated_check",
            pattern=re.compile(r'if\s*\(\s*prev_calculated\s*==\s*0\s*\)', re.IGNORECASE),
            level=EnforcementLevel.RECOMMENDED,
            description="Conditional debug output only on first calculation",
            example='if(prev_calculated == 0) Print("DEBUG: ...");'
        ),
    ]

    def __init__(self):
        """Initialize enforcer."""
        pass

    def analyze_file(self, file_path: Path | str) -> list[EnforcementResult]:
        """
        Analyze MQL5 file for debug patterns.

        Args:
            file_path: Path to .mq5 or .mqh file.

        Returns:
            List of EnforcementResult objects.
        """
        file_path = Path(file_path)

        if not file_path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")

        # Read file content
        content = file_path.read_text(encoding='utf-8', errors='replace')
        lines = content.splitlines()

        results = []

        for pattern in self.PATTERNS:
            result = self._check_pattern(pattern, content, lines)
            results.append(result)

        return results

    def _check_pattern(self, pattern: DebugPattern, content: str, lines: list[str]) -> EnforcementResult:
        """Check if a pattern is present in the content."""
        match = pattern.pattern.search(content)

        if match:
            # Find line number
            pos = match.start()
            line_number = content[:pos].count('\n') + 1

            return EnforcementResult(
                pattern_name=pattern.name,
                found=True,
                level=pattern.level,
                message=f"Found: {pattern.description}",
                line_number=line_number
            )

        return EnforcementResult(
            pattern_name=pattern.name,
            found=False,
            level=pattern.level,
            message=f"Missing: {pattern.description}",
            suggestion=pattern.example
        )

    def analyze_directory(self, dir_path: Path | str, pattern: str = "*.mq5") -> dict[str, list[EnforcementResult]]:
        """
        Analyze all MQL5 files in a directory.

        Args:
            dir_path: Directory to scan.
            pattern: Glob pattern for files.

        Returns:
            Dictionary mapping file paths to their results.
        """
        dir_path = Path(dir_path)
        results = {}

        for file_path in dir_path.rglob(pattern):
            results[str(file_path)] = self.analyze_file(file_path)

        return results

    def generate_report(self, results: list[EnforcementResult], file_name: str = "") -> str:
        """
        Generate enforcement report.

        Args:
            results: List of enforcement results.
            file_name: Optional file name for header.

        Returns:
            Formatted report string.
        """
        lines = [
            "=" * 70,
            f"MQL5 Debug Pattern Enforcement Report",
            f"File: {file_name}" if file_name else "",
            "=" * 70,
            ""
        ]

        # Summary
        required_missing = sum(
            1 for r in results
            if not r.found and r.level == EnforcementLevel.REQUIRED
        )
        recommended_missing = sum(
            1 for r in results
            if not r.found and r.level == EnforcementLevel.RECOMMENDED
        )

        lines.append("Summary:")
        lines.append(f"  Required patterns missing:    {required_missing}")
        lines.append(f"  Recommended patterns missing: {recommended_missing}")
        lines.append("")

        # Required patterns
        lines.append("Required Patterns:")
        lines.append("-" * 70)
        for result in results:
            if result.level != EnforcementLevel.REQUIRED:
                continue

            status = "[OK]" if result.found else "[MISSING]"
            lines.append(f"{status} {result.pattern_name}")
            lines.append(f"    {result.message}")
            if result.line_number:
                lines.append(f"    Line: {result.line_number}")
            if result.suggestion:
                lines.append(f"    Add: {result.suggestion}")
            lines.append("")

        # Recommended patterns
        lines.append("Recommended Patterns:")
        lines.append("-" * 70)
        for result in results:
            if result.level != EnforcementLevel.RECOMMENDED:
                continue

            status = "[OK]" if result.found else "[MISSING]"
            lines.append(f"{status} {result.pattern_name}")
            lines.append(f"    {result.message}")
            if result.suggestion and not result.found:
                lines.append(f"    Add: {result.suggestion}")
            lines.append("")

        lines.append("=" * 70)

        # Overall status
        if required_missing > 0:
            lines.append("STATUS: FAILED - Missing required debug patterns")
            lines.append("")
            lines.append("The Data-First Debugging Protocol requires these patterns for effective")
            lines.append("validation. Add the missing patterns before running validation.")
        elif recommended_missing > 0:
            lines.append("STATUS: WARNING - Missing recommended patterns")
        else:
            lines.append("STATUS: PASSED - All debug patterns present")

        return "\n".join(lines)

    def generate_debug_template(self, indicator_name: str) -> str:
        """
        Generate debug code template for a new indicator.

        Args:
            indicator_name: Name of the indicator.

        Returns:
            MQL5 code template with debug patterns.
        """
        return f'''//+------------------------------------------------------------------+
//| Debug Template for {indicator_name}
//| Generated by MQL5 Validator Framework
//+------------------------------------------------------------------+

// === Debug variables (add at global scope) ===
int debugCount = 0;
int signalCount = 0;

// === In OnCalculate, at start of detection loop ===
/*
int debugCount = 0;
int signalCount = 0;

for(int i = 1; i < rates_total - InpConsecutiveCount; i++)
{{
   // ... pattern detection logic ...

   // DEBUG: Log first 10 signals (limit to avoid log spam)
   if(debugCount < 10 && prev_calculated == 0)
   {{
      Print("DEBUG {indicator_name} bar ", i, ": bodies=[",
            DoubleToString(BufferBodySizes[i], 5), ", ",
            DoubleToString(BufferBodySizes[i+1], 5), ", ",
            DoubleToString(BufferBodySizes[i+2], 5), "] ",
            isPatternBullish ? "BULL" : "BEAR");
      debugCount++;
   }}
   signalCount++;

   // ... signal setting logic ...
}}

// DEBUG: Summary at end of OnCalculate
if(prev_calculated == 0)
   Print("DEBUG: Total {indicator_name} signals: ", signalCount, " out of ", rates_total, " bars");
*/

// === Overlapping pattern prevention (for expansion/contraction patterns) ===
/*
// Only signal at END of pattern sequence
if(i > 0)
{{
   bool prevBarSameDirection = true;
   if(InpSameDirection)
   {{
      bool isPrevBarBullish = close[i-1] > open[i-1];
      prevBarSameDirection = (isPrevBarBullish == isPatternBullish);
   }}

   // Check if pattern extends one bar earlier
   bool extendsEarlier = prevBarSameDirection &&
                         (BufferBodySizes[i-1] > BufferBodySizes[i]);

   if(extendsEarlier)
      continue; // Skip - this is part of a longer sequence
}}
*/
'''
