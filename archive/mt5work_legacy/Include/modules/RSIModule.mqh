
#ifndef __RSI_MODULE_MQH__
#define __RSI_MODULE_MQH__

#include "..\\DataExportCore.mqh"

bool RSIModule_Load(const string symbol,
                    const ENUM_TIMEFRAMES timeframe,
                    const int bars,
                    const int period,
                    IndicatorColumn &column,
                    string &errorMessage)
  {
   column.header=StringFormat("RSI_%d",period);
   column.digits=2;
   ArrayResize(column.values,bars);
   ArraySetAsSeries(column.values,true);

   int handle=iRSI(symbol,timeframe,period,PRICE_CLOSE);
   if(handle==INVALID_HANDLE)
     {
      errorMessage="RSI handle creation failed";
      return(false);
     }
   int copied=CopyBuffer(handle,0,0,bars,column.values);
   IndicatorRelease(handle);
   if(copied!=bars)
     {
      errorMessage=StringFormat("RSI CopyBuffer expected %d bars, received %d",bars,copied);
      return(false);
     }
   return(true);
  }

#endif // __RSI_MODULE_MQH__
