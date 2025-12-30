"""
Pattern Validator

Validates MQL5 indicator patterns based on lessons learned from
the Data-First Debugging Protocol applied to cc indicator v1.20-v1.23.

Key Validations:
1. Signal ratio sanity check (not >10% of bars)
2. Overlapping pattern detection
3. EMPTY_VALUE handling
4. Timeseries indexing consistency
"""

from dataclasses import dataclass
from enum import Enum
from .log_parser import MT5LogParser, LogEntry, SignalSummary


class ValidationSeverity(Enum):
    """Severity levels for validation results."""
    PASS = "pass"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"


@dataclass
class ValidationResult:
    """Result of a single validation check."""
    name: str
    severity: ValidationSeverity
    message: str
    details: dict | None = None


class PatternValidator:
    """
    Validate MQL5 indicator debug output for common bugs.

    Based on lessons learned from cc indicator debugging:
    - Overlapping patterns cause excessive signals
    - High signal ratios indicate logic bugs
    - EMPTY_VALUE constants in debug output indicate calculation issues

    Usage:
        validator = PatternValidator()
        results = validator.validate_all(log_entries, "cc")
        for result in results:
            print(f"[{result.severity.value}] {result.name}: {result.message}")
    """

    # Threshold for signal ratio warning (learned from cc v1.22 debug: 3.75% was suspicious)
    SIGNAL_RATIO_WARNING = 0.05  # 5%
    SIGNAL_RATIO_ERROR = 0.10   # 10%

    # EMPTY_VALUE in MQL5 is DBL_MAX
    EMPTY_VALUE = 1.7976931348623157e+308  # DBL_MAX

    def __init__(self, parser: MT5LogParser | None = None):
        """
        Initialize validator with optional parser.

        Args:
            parser: MT5LogParser instance. Creates new one if not provided.
        """
        self.parser = parser or MT5LogParser()

    def validate_all(self, entries: list[LogEntry], indicator_name: str) -> list[ValidationResult]:
        """
        Run all validation checks on log entries.

        Args:
            entries: List of log entries.
            indicator_name: Indicator name to validate.

        Returns:
            List of ValidationResult objects.
        """
        results = []

        # 1. Check signal ratio
        results.append(self.validate_signal_ratio(entries, indicator_name))

        # 2. Check for overlapping patterns
        results.append(self.validate_no_overlapping(entries, indicator_name))

        # 3. Check for EMPTY_VALUE in debug output
        results.append(self.validate_no_empty_values(entries, indicator_name))

        # 4. Check for error messages
        results.append(self.validate_no_errors(entries, indicator_name))

        return results

    def validate_signal_ratio(self, entries: list[LogEntry], indicator_name: str) -> ValidationResult:
        """
        Validate that signal ratio is within expected bounds.

        From cc v1.22 debugging: 3445/91844 = 3.75% signals indicated overlapping bug.
        After fix (v1.23), ratio should be much lower.
        """
        summary = self.parser.extract_signal_summary(entries, indicator_name)

        if summary is None:
            return ValidationResult(
                name="signal_ratio",
                severity=ValidationSeverity.WARNING,
                message="No signal summary found in logs. Add DEBUG logging to track signals.",
                details={"hint": "Add: Print('DEBUG: Total signals: ', count, ' out of ', total, ' bars');"}
            )

        ratio = summary.signal_ratio

        if ratio >= self.SIGNAL_RATIO_ERROR:
            return ValidationResult(
                name="signal_ratio",
                severity=ValidationSeverity.ERROR,
                message=f"Signal ratio {ratio:.2%} exceeds {self.SIGNAL_RATIO_ERROR:.0%} threshold",
                details={
                    "total_signals": summary.total_signals,
                    "total_bars": summary.total_bars,
                    "ratio": ratio,
                    "hint": "Check for overlapping pattern detection or overly sensitive filters"
                }
            )

        if ratio >= self.SIGNAL_RATIO_WARNING:
            return ValidationResult(
                name="signal_ratio",
                severity=ValidationSeverity.WARNING,
                message=f"Signal ratio {ratio:.2%} is high (>{self.SIGNAL_RATIO_WARNING:.0%})",
                details={
                    "total_signals": summary.total_signals,
                    "total_bars": summary.total_bars,
                    "ratio": ratio
                }
            )

        return ValidationResult(
            name="signal_ratio",
            severity=ValidationSeverity.PASS,
            message=f"Signal ratio {ratio:.2%} is within expected bounds",
            details={
                "total_signals": summary.total_signals,
                "total_bars": summary.total_bars,
                "ratio": ratio
            }
        )

    def validate_no_overlapping(self, entries: list[LogEntry], indicator_name: str) -> ValidationResult:
        """
        Validate no overlapping pattern signals exist.

        This was the root cause of cc v1.20 bug: consecutive bars both
        triggered signals because they were part of the same expansion sequence.
        """
        is_valid, message = self.parser.validate_no_overlapping_patterns(entries, indicator_name)

        if is_valid:
            return ValidationResult(
                name="overlapping_patterns",
                severity=ValidationSeverity.PASS,
                message=message
            )

        # Extract consecutive pairs for details
        signals = self.parser.extract_debug_signals(entries, indicator_name)
        consecutive = self.parser._find_consecutive_signals(signals)

        return ValidationResult(
            name="overlapping_patterns",
            severity=ValidationSeverity.CRITICAL,
            message="Overlapping pattern detection bug found",
            details={
                "consecutive_pairs": consecutive[:10],  # First 10
                "total_pairs": len(consecutive),
                "fix_hint": (
                    "Only signal at END of pattern sequence. "
                    "Check if pattern extends one bar earlier; if so, skip current bar."
                )
            }
        )

    def validate_no_empty_values(self, entries: list[LogEntry], indicator_name: str) -> ValidationResult:
        """
        Check for EMPTY_VALUE constants in debug output.

        EMPTY_VALUE (1.797693e+308) in debug output indicates:
        - Indicator didn't calculate for those bars
        - Buffer not properly initialized
        - Timeseries indexing issues
        """
        empty_count = 0
        empty_examples = []

        for entry in entries:
            if indicator_name.lower() not in entry.source.lower():
                continue

            # Check for EMPTY_VALUE in various formats
            if "1.79769" in entry.message or "EMPTY_VALUE" in entry.message:
                empty_count += 1
                if len(empty_examples) < 3:
                    empty_examples.append(entry.message[:100])

        if empty_count == 0:
            return ValidationResult(
                name="empty_values",
                severity=ValidationSeverity.PASS,
                message="No EMPTY_VALUE detected in debug output"
            )

        return ValidationResult(
            name="empty_values",
            severity=ValidationSeverity.ERROR,
            message=f"Found {empty_count} EMPTY_VALUE occurrences in debug output",
            details={
                "count": empty_count,
                "examples": empty_examples,
                "fix_hint": (
                    "Check: 1) Buffer initialization, 2) Timeseries indexing, "
                    "3) Calculation start bar, 4) Array bounds"
                )
            }
        )

    def validate_no_errors(self, entries: list[LogEntry], indicator_name: str) -> ValidationResult:
        """
        Check for error messages in log entries.
        """
        errors = []

        for entry in entries:
            if indicator_name.lower() not in entry.source.lower():
                continue

            if entry.log_type == "error":
                errors.append(entry.message[:100])

        if not errors:
            return ValidationResult(
                name="error_messages",
                severity=ValidationSeverity.PASS,
                message="No error messages found"
            )

        return ValidationResult(
            name="error_messages",
            severity=ValidationSeverity.ERROR,
            message=f"Found {len(errors)} error messages",
            details={
                "errors": errors[:5]  # First 5
            }
        )

    def generate_report(self, results: list[ValidationResult]) -> str:
        """
        Generate a human-readable validation report.

        Args:
            results: List of validation results.

        Returns:
            Formatted report string.
        """
        lines = [
            "=" * 70,
            "MQL5 Pattern Validation Report",
            "=" * 70,
            ""
        ]

        # Summary
        severity_counts = {s: 0 for s in ValidationSeverity}
        for result in results:
            severity_counts[result.severity] += 1

        lines.append("Summary:")
        lines.append(f"  PASS:     {severity_counts[ValidationSeverity.PASS]}")
        lines.append(f"  WARNING:  {severity_counts[ValidationSeverity.WARNING]}")
        lines.append(f"  ERROR:    {severity_counts[ValidationSeverity.ERROR]}")
        lines.append(f"  CRITICAL: {severity_counts[ValidationSeverity.CRITICAL]}")
        lines.append("")

        # Details
        lines.append("Details:")
        lines.append("-" * 70)

        for result in results:
            status_icon = {
                ValidationSeverity.PASS: "[OK]",
                ValidationSeverity.WARNING: "[WARN]",
                ValidationSeverity.ERROR: "[ERR]",
                ValidationSeverity.CRITICAL: "[CRIT]"
            }[result.severity]

            lines.append(f"{status_icon} {result.name}")
            lines.append(f"    {result.message}")

            if result.details:
                for key, value in result.details.items():
                    if isinstance(value, list) and len(value) > 3:
                        lines.append(f"    {key}: [{len(value)} items]")
                    else:
                        lines.append(f"    {key}: {value}")

            lines.append("")

        lines.append("=" * 70)

        # Overall status
        if severity_counts[ValidationSeverity.CRITICAL] > 0:
            lines.append("STATUS: CRITICAL - Immediate fixes required")
        elif severity_counts[ValidationSeverity.ERROR] > 0:
            lines.append("STATUS: FAILED - Errors found")
        elif severity_counts[ValidationSeverity.WARNING] > 0:
            lines.append("STATUS: WARNING - Review recommended")
        else:
            lines.append("STATUS: PASSED - All checks passed")

        return "\n".join(lines)
