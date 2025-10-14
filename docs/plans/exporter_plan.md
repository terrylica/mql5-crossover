# Exporter Framework Plan

## Goal
Create a reusable MetaTrader 5 exporter that produces CSV files containing aligned price data and indicator outputs for AI-driven Python replication workflows.

## Architectural Outline
- `DataExportCore.mqh`: Shared utilities for retrieving price series (`CopyRates`), writing CSV headers/rows, and managing indicator modules.
- Indicator modules: Individual MQL5 includes that expose initialization and per-bar value retrieval for specific indicators (built-in or custom).
- Export script (`ExportAligned.mq5`): Orchestrates the export by staging symbol/timeframe inputs, invoking core functions, compiling indicator outputs, and writing CSV.
- CLI helper (`mq5export`): Shell function to stage script, generate MT5 config, run `terminal64.exe /config`, and copy resulting CSV to repository.
- Logs/history: Append structured metadata (timestamp, symbol, timeframe, bars exported) to `exports/history.json`.

## Task Status
- [x] `DataExportCore.mqh` provides rate loading (bounded by `TERMINAL_MAXBARS`), bar series struct, and CSV writer producing UTF-8 rows.
- [x] `modules/RSIModule.mqh` implements the first indicator adapter (built-in RSI). Additional modules should follow the same interface.
- [x] `ExportAligned.mq5` compiles the core + RSI column and writes aligned CSV output.
- [~] `mq5export` helper stages sources, compiles via `mq5c`, deploys the `.ex5`, builds an MT5 config, and launches `terminal64.exe /config`. CSV copy/history append succeed when the script produces output; automated MT startup still needs verification that the script runs headlessly (current command exits with an error if the CSV is absent).
- [x] Documentation refresh (CROSSOVER_MQ5.md updated; SLOs listed below).

## SLOs
- Availability: `mq5c` must return zero on compilation success; `mq5export` must exit non-zero if the export artefact is missing (no silent fallback). CLI tooling logs failures to stderr.
- Correctness: Exported CSV rows include identical timestamps for price and indicator columns. Indicator adapters are required to copy exactly the requested number of bars; any mismatch aborts execution.
- Observability: Each export run must emit `Print` summaries inside MetaTrader and append a JSON line to `exports/history.jsonl` capturing timestamp, symbol, timeframe, bar count, and filename. CLI helpers print the staging/log locations.
- Maintainability: Indicator modules are isolated includes adhering to the `IndicatorColumn` contract; adding a new module requires only a new include and registration inside the script (no modifications to the core writer).
