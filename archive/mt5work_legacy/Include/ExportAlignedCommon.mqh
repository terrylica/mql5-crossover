#ifndef __EXPORT_ALIGNED_COMMON_MQH__
#define __EXPORT_ALIGNED_COMMON_MQH__

#include "DataExportCore.mqh"
#include "modules/RSIModule.mqh"

bool RunExportAligned(const string symbol,
                      const ENUM_TIMEFRAMES timeframe,
                      const int requestedBars,
                      const bool includeRSI,
                      const int rsiPeriod,
                      const string explicitFilename)
  {
   string trimmedSymbol=symbol;
   StringTrimLeft(trimmedSymbol);
   StringTrimRight(trimmedSymbol);
   if(StringLen(trimmedSymbol)==0)
     {
      Print("Symbol input is empty");
      return(false);
     }
   if(!SymbolSelect(trimmedSymbol,true))
     {
      PrintFormat("SymbolSelect failed for %s (error %d)",trimmedSymbol,GetLastError());
      return(false);
     }

   BarSeries series;
   if(!LoadRates(trimmedSymbol,timeframe,requestedBars,series))
     {
      Print("LoadRates failed");
      return(false);
     }
   if(series.count<=0)
     {
      Print("No bars returned");
      return(false);
     }

   IndicatorColumn columns[];
   int columnCount=0;

   if(includeRSI)
     {
      IndicatorColumn rsiColumn;
      string rsiError="";
      if(!RSIModule_Load(trimmedSymbol,timeframe,series.count,rsiPeriod,rsiColumn,rsiError))
        {
         PrintFormat("RSI module failed: %s",rsiError);
         return(false);
        }
      ArrayResize(columns,columnCount+1);
      columns[columnCount]=rsiColumn;
      columnCount++;
     }

   string filename=explicitFilename;
   if(StringLen(filename)==0)
      filename=StringFormat("Export_%s_%s.csv",trimmedSymbol,EnumToString(timeframe));

   int handle;
   if(!OpenCsv(filename,handle))
     {
      PrintFormat("Failed to open output file %s (error %d)",filename,GetLastError());
      return(false);
     }

   string baseHeaders[8]={"time","open","high","low","close","tick_volume","spread","real_volume"};
   IndicatorColumn columnCopy[]=columns; // pass by reference as required
   WriteCsvHeader(handle,baseHeaders,columnCopy,columnCount);
   if(!WriteCsvRows(handle,series,columnCopy,columnCount))
     {
      FileClose(handle);
      Print("Failed to write CSV rows");
      return(false);
     }
   FileClose(handle);
   PrintFormat("Export complete: %d bars for %s %s -> %s",series.count,trimmedSymbol,EnumToString(timeframe),filename);
   return(true);
  }

#endif // __EXPORT_ALIGNED_COMMON_MQH__
