#property script_show_inputs
#property strict

#include <DataExport/DataExportCore.mqh>
#include <DataExport/modules/RSIModule.mqh>

input string          InpSymbol             = "EURUSD";
input ENUM_TIMEFRAMES InpTimeframe          = PERIOD_M1;
input int             InpBars               = 5000;
input bool            InpUseRSI             = true;
input int             InpRSIPeriod          = 14;

void OnStart()
  {
   string symbol=InpSymbol;
   if(!SymbolSelect(symbol,true))
     {
      PrintFormat("SymbolSelect failed for %s",symbol);
      return;
     }

   BarSeries series;
   if(!LoadRates(symbol,InpTimeframe,InpBars,series))
     {
      Print("LoadRates failed");
      return;
     }

   IndicatorColumn columns[];
   int columnCount=0;

   if(InpUseRSI)
     {
      IndicatorColumn rsiColumn;
      string rsiError="";
      if(!RSIModule_Load(symbol,InpTimeframe,series.count,InpRSIPeriod,rsiColumn,rsiError))
        {
         PrintFormat("RSI module failed: %s",rsiError);
         return;
        }
      ArrayResize(columns,columnCount+1);
      columns[columnCount]=rsiColumn;
      columnCount++;
     }

   string filename="Export_Test.csv";
   int handle;
   if(!OpenCsv(filename,handle))
     {
      PrintFormat("Failed to open output file %s",filename);
      return;
     }

   string baseHeaders[8]={"time","open","high","low","close","tick_volume","spread","real_volume"};
   WriteCsvHeader(handle,baseHeaders,columns,columnCount);
   WriteCsvRows(handle,series,columns,columnCount);
   FileClose(handle);
   PrintFormat("Export complete: %d bars for %s",series.count,symbol);
  }
