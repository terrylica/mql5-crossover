//+------------------------------------------------------------------+
//|                                          CCINeutralityTester.mq5 |
//|                     Wrapper EA for Strategy Tester automation    |
//|                                                                  |
//| Purpose: Enable headless testing of CCI_Neutrality_Debug via    |
//| command line Strategy Tester execution                          |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property link        "https://github.com/terrylica/mql5-crossover"
#property version     "1.00"
#property description "Wrapper EA to test CCI_Neutrality_Debug indicator"
#property description "For automated Strategy Tester execution"

// Declare indicator for tester (per mql5.com documentation)
#property tester_indicator "::Indicators\\Custom\\Development\\CCINeutrality\\CCI_Neutrality_Debug.ex5"

//--- Input parameters (match indicator defaults)
input int    InpCCILength     = 20;      // CCI period
input int    InpWindow        = 30;      // Window W for statistics
input int    InpMinStreak     = 5;       // Min in-channel streak
input double InpMinInChannel  = 0.80;    // Min fraction inside [-100,100]
input double InpMaxMean       = 20.0;    // Max |mean CCI|
input double InpMaxStdev      = 30.0;    // Max stdev of CCI
input double InpMinScore      = 0.80;    // Score threshold (tau)
input double InpC0            = 50.0;    // Centering constant C0
input double InpC1            = 50.0;    // Dispersion constant C1
input double InpC2            = 100.0;   // Breach magnitude constant C2
input bool   InpEnableCSV     = true;    // Enable CSV output
input int    InpFlushInterval = 100;     // Flush every N bars

//--- Indicator handle
int g_indicator_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Create indicator handle using iCustom
   g_indicator_handle = iCustom(
      _Symbol,
      _Period,
      "::Indicators\\Custom\\Development\\CCINeutrality\\CCI_Neutrality_Debug.ex5",
      InpCCILength,
      InpWindow,
      InpMinStreak,
      InpMinInChannel,
      InpMaxMean,
      InpMaxStdev,
      InpMinScore,
      InpC0,
      InpC1,
      InpC2,
      InpEnableCSV,
      InpFlushInterval
   );

   if(g_indicator_handle == INVALID_HANDLE)
     {
      PrintFormat("ERROR: Failed to create indicator handle, error %d", GetLastError());
      return INIT_FAILED;
     }

   PrintFormat("CCINeutralityTester initialized successfully");
   PrintFormat("Symbol: %s, Period: %s", _Symbol, EnumToString(_Period));
   PrintFormat("Indicator handle: %d", g_indicator_handle);

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Release indicator handle
   if(g_indicator_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_indicator_handle);
      g_indicator_handle = INVALID_HANDLE;
     }

   PrintFormat("CCINeutralityTester deinitialized, reason: %d", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- We don't need to do anything here
//--- The indicator calculates automatically via iCustom() call
//--- This function just ensures the EA runs in Strategy Tester

//--- Optional: Copy indicator buffer to verify it's calculating
   static bool first_tick = true;
   if(first_tick)
     {
      double buffer[];
      ArraySetAsSeries(buffer, true);

      int copied = CopyBuffer(g_indicator_handle, 0, 0, 1, buffer);
      if(copied > 0)
        {
         PrintFormat("Indicator is calculating - first CCI value: %.2f", buffer[0]);
        }

      first_tick = false;
     }
  }

//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//--- Return dummy value (not used for indicator testing)
//--- Main purpose is CSV output from indicator
   return 0.0;
  }
//+------------------------------------------------------------------+
