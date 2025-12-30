"""
MQL5 Validator Framework

A Python-based validator that enforces debugging patterns learned from
the Data-First Debugging Protocol. Catches MQL5 indicator errors early
through structured log analysis and pattern validation.

Version: 1.0.0
Created: 2025-12-30

Core Components:
- LogParser: Parse MT5 UTF-16LE logs
- PatternValidator: Validate debug output patterns
- DebugEnforcer: Ensure MQL5 code has required debug statements
"""

from .log_parser import MT5LogParser
from .pattern_validator import PatternValidator
from .debug_enforcer import DebugEnforcer

__version__ = "1.0.0"
__all__ = ["MT5LogParser", "PatternValidator", "DebugEnforcer"]
