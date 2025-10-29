# Repository Guidelines

## Project Structure & Module Organization

The root directory hosts active MQL5 indicators and include headers (e.g., `CCI_Neutrality_Debug.mq5`, `CandlePatterns.mqh`) plus latest CSV/log artifacts. Production-ready builds live under `Program Files/MetaTrader 5/MQL5/Indicators/Custom/Development/CCINeutrality`, aligned with MetaTrader’s directory layout. Long-form documentation and research stay in `docs/` (guides, plans, reports), while frozen history is in `archive/`. Use `experiments/` for spike prototypes and keep automation assets inside `users/crossover/` alongside CrossOver configs. Generated exports should land in `exports/` or the MetaQuotes `Common/Files` path referenced below.

## Build, Test, and Development Commands

Compile indicators through MetaEditor inside CrossOver:  
`$HOME/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine "C:\\Program Files\\MetaTrader 5\\metaeditor64.exe" /compile:"C:\\Program Files\\MetaTrader 5\\MQL5\\Indicators\\Custom\\Development\\CCINeutrality\\CCI_Neutrality_Debug.mq5" /log:"C:\\users\\crossover\\metaeditor.log"`.  
For scripted dataset exports rely on `bash users/crossover/run_cci_script_automation.sh EURUSD M12 5000`; it invokes Python, launches `terminal64.exe` with `startup_cci_export.ini`, and writes CSVs into `users/crossover/AppData/Roaming/MetaQuotes/Terminal/Common/Files`. Headless Strategy Tester validation runs via `bash users/crossover/run_cci_validation_headless.sh EURUSD M12 5000`, producing reports in the same `Common/Files` location plus HTML snapshots in `Program Files/MetaTrader 5/`.

## Coding Style & Naming Conventions

Retain the three-space indentation and brace-on-next-line style used in current `.mq5` sources. Name input parameters with the `Inp` prefix, handles with `h` (e.g., `hCCI`), and module-scope state with `g_`. File names stay PascalCase with underscores separating roles (`CCI_Neutrality_Debug.mq5`). Group inputs using `input group` banners and keep comment banners (`//+------------------------------------------------------------------+`) intact to match MetaEditor expectations. Log messages should be uppercase tagged (e.g., `Print("ERROR: ...")`) for quick grepping.

## Testing Guidelines

Prefer the headless workflow above; it wraps the CCINeutralityTester expert and uses `tester_cci_headless.ini`. Document expected datasets and thresholds in `docs/reports` when adding new scenarios. Name auxiliary test scripts `Test*.mq5` and commit accompanying `.set` files into `Program Files/MetaTrader 5/MQL5/Profiles/Tester/`. Verify generated CSVs for schema compatibility before archiving under `exports/`.

## Commit & Pull Request Guidelines

Follow the existing `<type>: <summary>` convention (`feat:`, `docs:`, `fix:`) in present tense and <=72 characters. Reference impacted indicator paths or configs in the body, link tracking issues, and mention any new CSV or HTML evidence. Pull requests should include a short testing section, updated documentation references, and screenshots when UI charts or templates change (see `Program Files/MetaTrader 5/MQL5/Profiles/Charts`). Ensure no Wine-generated binaries are staged.
