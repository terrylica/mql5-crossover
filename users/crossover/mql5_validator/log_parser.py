"""
MT5 Log Parser

Parses MetaTrader 5 log files (UTF-16LE encoded) and extracts
structured debug information from Print() statements.

Learned from debugging cc indicator v1.20-v1.23:
- Debug logs reveal overlapping pattern issues
- Signal counts expose logic bugs
- Body size sequences show pattern detection flow
"""

import re
from pathlib import Path
from datetime import datetime, date
from dataclasses import dataclass
from typing import Generator


@dataclass
class LogEntry:
    """Structured log entry from MT5"""
    timestamp: datetime
    source: str
    message: str
    log_type: str = "info"  # info, debug, error, warning


@dataclass
class DebugSignal:
    """Parsed debug signal from indicator Print() output"""
    bar_index: int
    body_sizes: list[float]
    direction: str  # "BULL" or "BEAR"
    raw_message: str


@dataclass
class SignalSummary:
    """Summary statistics from debug log"""
    total_signals: int
    total_bars: int
    signal_ratio: float
    consecutive_signals: list[tuple[int, int]]  # (bar_index, next_bar_index)


class MT5LogParser:
    """
    Parse MT5 log files and extract structured debug information.

    Usage:
        parser = MT5LogParser()
        entries = parser.parse_log("/path/to/20251230.log")
        signals = parser.extract_debug_signals(entries, "cc")
        summary = parser.summarize_signals(signals)
    """

    # Pattern for standard MT5 log entry
    # Format: "HH\tMM\tSS.mmm\tsource\tmessage"
    LOG_PATTERN = re.compile(
        r'^(\d{1,2})\t(\d{2})\t(\d{2}\.\d{3})\t([^\t]+)\t(.*)$'
    )

    # Pattern for cc indicator debug output
    # Format: "DEBUG Expansion bar X: bodies=[A, B, C] BULL/BEAR"
    DEBUG_EXPANSION_PATTERN = re.compile(
        r'DEBUG Expansion bar (\d+): bodies=\[([^\]]+)\] (BULL|BEAR)'
    )

    # Pattern for total signal count
    # Format: "DEBUG: Total expansion signals: X out of Y bars"
    TOTAL_SIGNALS_PATTERN = re.compile(
        r'DEBUG: Total expansion signals: (\d+) out of (\d+) bars'
    )

    def __init__(self, log_dir: Path | str | None = None):
        """
        Initialize parser with optional log directory.

        Args:
            log_dir: Path to MT5 Logs directory. Defaults to standard location.
        """
        if log_dir is None:
            # Default MT5 log location
            self.log_dir = Path.home() / "Library" / "Application Support" / \
                "CrossOver" / "Bottles" / "MetaTrader 5" / "drive_c" / \
                "Program Files" / "MetaTrader 5" / "MQL5" / "Logs"
        else:
            self.log_dir = Path(log_dir)

    def get_log_path(self, log_date: date | None = None) -> Path:
        """
        Get log file path for a specific date.

        Args:
            log_date: Date to get log for. Defaults to today.

        Returns:
            Path to log file.
        """
        if log_date is None:
            log_date = date.today()

        filename = log_date.strftime("%Y%m%d.log")
        return self.log_dir / filename

    def parse_log(self, log_path: Path | str | None = None) -> list[LogEntry]:
        """
        Parse MT5 log file into structured entries.

        Args:
            log_path: Path to log file. Defaults to today's log.

        Returns:
            List of LogEntry objects.
        """
        if log_path is None:
            log_path = self.get_log_path()
        else:
            log_path = Path(log_path)

        if not log_path.exists():
            raise FileNotFoundError(f"Log file not found: {log_path}")

        entries = []

        # MT5 logs are UTF-16LE encoded
        content = log_path.read_text(encoding='utf-16-le')

        for line in content.splitlines():
            entry = self._parse_line(line)
            if entry:
                entries.append(entry)

        return entries

    def _parse_line(self, line: str) -> LogEntry | None:
        """Parse a single log line into LogEntry."""
        match = self.LOG_PATTERN.match(line)
        if not match:
            return None

        hour, minute, second_ms, source, message = match.groups()

        # Parse timestamp (date not in log, use today)
        second, ms = second_ms.split('.')
        timestamp = datetime.now().replace(
            hour=int(hour),
            minute=int(minute),
            second=int(second),
            microsecond=int(ms) * 1000
        )

        # Detect log type from message
        log_type = "info"
        msg_lower = message.lower()
        if "error" in msg_lower or "failed" in msg_lower:
            log_type = "error"
        elif "warning" in msg_lower or "warn" in msg_lower:
            log_type = "warning"
        elif "debug" in msg_lower:
            log_type = "debug"

        return LogEntry(
            timestamp=timestamp,
            source=source,
            message=message,
            log_type=log_type
        )

    def filter_by_indicator(self, entries: list[LogEntry], indicator_name: str) -> list[LogEntry]:
        """
        Filter log entries by indicator name.

        Args:
            entries: List of log entries.
            indicator_name: Indicator name to filter by (case-insensitive).

        Returns:
            Filtered list of entries.
        """
        indicator_lower = indicator_name.lower()
        return [e for e in entries if indicator_lower in e.source.lower()]

    def extract_debug_signals(self, entries: list[LogEntry], indicator_name: str) -> list[DebugSignal]:
        """
        Extract debug signals from log entries.

        This parses the debug output format used in cc indicator v1.22+:
        "DEBUG Expansion bar X: bodies=[A, B, C] BULL/BEAR"

        Args:
            entries: List of log entries.
            indicator_name: Indicator name to filter.

        Returns:
            List of DebugSignal objects.
        """
        signals = []

        for entry in entries:
            if indicator_name.lower() not in entry.source.lower():
                continue

            match = self.DEBUG_EXPANSION_PATTERN.search(entry.message)
            if match:
                bar_index = int(match.group(1))
                body_sizes_str = match.group(2)
                direction = match.group(3)

                # Parse body sizes
                body_sizes = [
                    float(s.strip())
                    for s in body_sizes_str.split(',')
                ]

                signals.append(DebugSignal(
                    bar_index=bar_index,
                    body_sizes=body_sizes,
                    direction=direction,
                    raw_message=entry.message
                ))

        return signals

    def extract_signal_summary(self, entries: list[LogEntry], indicator_name: str) -> SignalSummary | None:
        """
        Extract signal summary from log entries.

        Parses: "DEBUG: Total expansion signals: X out of Y bars"

        Args:
            entries: List of log entries.
            indicator_name: Indicator name to filter.

        Returns:
            SignalSummary if found, None otherwise.
        """
        for entry in entries:
            if indicator_name.lower() not in entry.source.lower():
                continue

            match = self.TOTAL_SIGNALS_PATTERN.search(entry.message)
            if match:
                total_signals = int(match.group(1))
                total_bars = int(match.group(2))

                # Find consecutive signals
                signals = self.extract_debug_signals(entries, indicator_name)
                consecutive = self._find_consecutive_signals(signals)

                return SignalSummary(
                    total_signals=total_signals,
                    total_bars=total_bars,
                    signal_ratio=total_signals / total_bars if total_bars > 0 else 0,
                    consecutive_signals=consecutive
                )

        return None

    def _find_consecutive_signals(self, signals: list[DebugSignal]) -> list[tuple[int, int]]:
        """
        Find consecutive signal pairs (indicates overlapping pattern bug).

        This was the key insight from debugging cc v1.22 - bars 4 and 5
        both had signals because of overlapping pattern detection.
        """
        consecutive = []

        # Sort by bar index
        sorted_signals = sorted(signals, key=lambda s: s.bar_index)

        for i in range(len(sorted_signals) - 1):
            current = sorted_signals[i]
            next_signal = sorted_signals[i + 1]

            if next_signal.bar_index == current.bar_index + 1:
                consecutive.append((current.bar_index, next_signal.bar_index))

        return consecutive

    def validate_no_overlapping_patterns(self, entries: list[LogEntry], indicator_name: str) -> tuple[bool, str]:
        """
        Validate that there are no overlapping pattern signals.

        Overlapping patterns indicate a bug where consecutive bars both
        trigger signals because they're part of the same expansion sequence.

        Args:
            entries: List of log entries.
            indicator_name: Indicator name to validate.

        Returns:
            Tuple of (is_valid, message).
        """
        signals = self.extract_debug_signals(entries, indicator_name)
        consecutive = self._find_consecutive_signals(signals)

        if not consecutive:
            return True, f"No overlapping patterns detected ({len(signals)} signals)"

        return False, (
            f"OVERLAPPING PATTERN BUG DETECTED!\n"
            f"Found {len(consecutive)} consecutive signal pairs:\n"
            f"First 5: {consecutive[:5]}\n"
            f"This indicates signals are not filtering to end-of-sequence only."
        )
