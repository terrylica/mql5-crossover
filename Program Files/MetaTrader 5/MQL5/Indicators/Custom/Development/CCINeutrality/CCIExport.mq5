//+------------------------------------------------------------------+
//|                                            CCI_Export_Script.mq5 |
//|                      Script to trigger CCI_Neutrality_Debug CSV  |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property version     "1.00"
#property description "Script to trigger CCI Neutrality Debug indicator CSV export via iCustom()"
#property script_show_inputs
#property strict

//--- Input parameters
input string InpSymbol = "EURUSD";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M12;
input int InpBars = 5000;

// CCI_Neutrality_Debug parameters (must match indicator defaults)
input int    InpCCILength     = 20;
input int    InpWindow        = 30;
input int    InpMinStreak     = 5;
input double InpMinInChannel  = 0.80;
input double InpMaxMean       = 20.0;
input double InpMaxStdev      = 30.0;
input double InpMinScore      = 0.80;
input double InpC0            = 50.0;
input double InpC1            = 50.0;
input double InpC2            = 100.0;
input bool   InpEnableCSV     = true;
input int    InpFlushInterval = 100;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   PrintFormat("=== CCI Export Script v1.0.0 ===");
   PrintFormat("Symbol: %s", InpSymbol);
   PrintFormat("Timeframe: %s", EnumToString(InpTimeframe));
   PrintFormat("Bars: %d", InpBars);
   PrintFormat("CSV Export: %s", InpEnableCSV ? "ENABLED" : "DISABLED");

   // Step 1: Select symbol
   if(!SymbolSelect(InpSymbol, true))
     {
      PrintFormat("ERROR: SymbolSelect failed for %s (error %d)", InpSymbol, GetLastError());
      return;
     }

   PrintFormat("✓ Symbol selected: %s", InpSymbol);

   // Step 2: Wait for history download (max 5 seconds)
   datetime from = TimeCurrent() - PeriodSeconds(InpTimeframe) * 1000;
   int attempts = 0;
   int maxAttempts = 50;  // 50 * 100ms = 5 seconds

   while(attempts < maxAttempts)
     {
      datetime time[];
      int copied = CopyTime(InpSymbol, InpTimeframe, 0, 1, time);
      if(copied > 0)
         break;

      Sleep(100);
      attempts++;
     }

   if(attempts >= maxAttempts)
     {
      PrintFormat("ERROR: History download timeout for %s %s after %d ms",
                  InpSymbol, EnumToString(InpTimeframe), maxAttempts * 100);
      return;
     }

   PrintFormat("✓ History available for %s %s (waited %d ms)",
               InpSymbol, EnumToString(InpTimeframe), attempts * 100);

   // Step 3: Create indicator handle via iCustom()
   // The indicator will:
   // - Execute OnInit() → open CSV file and write header
   // - Execute OnCalculate() for each bar → write data rows
   // - Execute OnDeinit() when handle is released → close CSV file

   PrintFormat("Creating CCI_Neutrality_Debug indicator handle...");

   int handle = iCustom(InpSymbol, InpTimeframe,
                        "Custom\\Development\\CCINeutrality\\CCI_Neutrality_Debug",
                        InpCCILength, InpWindow, InpMinStreak, InpMinInChannel,
                        InpMaxMean, InpMaxStdev, InpMinScore,
                        InpC0, InpC1, InpC2,
                        InpEnableCSV, InpFlushInterval);

   if(handle == INVALID_HANDLE)
     {
      PrintFormat("ERROR: Failed to create indicator handle, error %d", GetLastError());
      return;
     }

   PrintFormat("✓ Indicator handle created: %d", handle);

   // Step 4: Wait for indicator to calculate all bars
   // BarsCalculated() returns number of bars calculated by indicator
   PrintFormat("Waiting for indicator to calculate %d bars...", InpBars);

   int calculated = 0;
   attempts = 0;
   maxAttempts = 100;  // 100 * 100ms = 10 seconds

   while(attempts < maxAttempts)
     {
      calculated = BarsCalculated(handle);

      if(calculated >= InpBars || calculated < 0)
         break;

      Sleep(100);
      attempts++;

      if(attempts % 10 == 0)  // Progress update every second
         PrintFormat("  Progress: %d / %d bars calculated", calculated, InpBars);
     }

   if(calculated < 0)
     {
      PrintFormat("ERROR: BarsCalculated returned error: %d", GetLastError());
      IndicatorRelease(handle);
      return;
     }

   if(calculated < InpBars)
     {
      PrintFormat("WARNING: Timeout - only %d / %d bars calculated after %d ms",
                  calculated, InpBars, maxAttempts * 100);
     }
   else
     {
      PrintFormat("✓ Indicator calculated %d bars", calculated);
     }

   // Step 5: Copy buffer to force final calculation
   // This ensures OnCalculate() has been called for all bars
   double buffer[];
   ArraySetAsSeries(buffer, true);

   int copied = CopyBuffer(handle, 0, 0, InpBars, buffer);

   if(copied <= 0)
     {
      PrintFormat("ERROR: CopyBuffer failed, error %d", GetLastError());
      IndicatorRelease(handle);
      return;
     }

   PrintFormat("✓ Copied %d indicator values from buffer", copied);
   PrintFormat("  First value: %.2f", buffer[0]);
   PrintFormat("  Last value: %.2f", buffer[copied - 1]);

   // Step 6: Release indicator handle
   // This triggers OnDeinit() which closes the CSV file
   PrintFormat("Releasing indicator handle (triggers CSV file close)...");

   if(!IndicatorRelease(handle))
     {
      PrintFormat("WARNING: IndicatorRelease failed, error %d", GetLastError());
     }
   else
     {
      PrintFormat("✓ Indicator released successfully");
     }

   // Give indicator time to flush and close file
   Sleep(500);

   PrintFormat("=== CCI Export Script Complete ===");
   PrintFormat("Check MQL5/Files/ for CSV output:");
   PrintFormat("  cci_debug_%s_%s_*.csv", InpSymbol, EnumToString(InpTimeframe));
  }
//+------------------------------------------------------------------+
