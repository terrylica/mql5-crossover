
#ifndef __DATAEXPORTCORE_MQH__
#define __DATAEXPORTCORE_MQH__

#include <Arrays\ArrayObj.mqh>

struct BarSeries
  {
   MqlRates      data[];
   int           count;
  };

struct IndicatorColumn
  {
   string        header;
   double        values[];
   int           digits;
  };

// Load up to requestedBars (or TERMINAL_MAXBARS if requestedBars <= 0)
bool LoadRates(const string symbol,
               const ENUM_TIMEFRAMES timeframe,
               const int requestedBars,
               BarSeries &series)
  {
   int maxBars=(int)TerminalInfoInteger(TERMINAL_MAXBARS);
   int limit=requestedBars>0 ? MathMin(requestedBars,maxBars) : maxBars;
   if(limit<=0)
      return(false);
   ArraySetAsSeries(series.data,true);
   int copied=CopyRates(symbol,timeframe,0,limit,series.data);
   if(copied<=0)
      return(false);
   series.count=copied;
   return(true);
  }

bool OpenCsv(const string filename,
             int &handle)
  {
   handle=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI);
   if(handle==INVALID_HANDLE)
      return(false);
   return(true);
  }

void WriteCsvHeader(const int handle,
                    string &baseHeaders[],
                    IndicatorColumn &columns[],
                    const int columnCount)
  {
   int baseCount=ArraySize(baseHeaders);
   string headerRow="";
   for(int i=0;i<baseCount;i++)
     {
      if(i>0)
         headerRow+=",";
      headerRow+=baseHeaders[i];
     }
   for(int j=0;j<columnCount;j++)
     {
      headerRow+=",";
      headerRow+=columns[j].header;
     }
   FileWrite(handle,headerRow);
  }

bool WriteCsvRows(const int handle,
                  const BarSeries &series,
                  IndicatorColumn &columns[],
                  const int columnCount)
  {
   ArraySetAsSeries(series.data,true);
   for(int c=0;c<columnCount;c++)
      ArraySetAsSeries(columns[c].values,true);
   for(int i=series.count-1;i>=0;--i)
     {
      MqlRates bar=series.data[i];
      string row=TimeToString(bar.time,TIME_DATE|TIME_MINUTES);
      row+=","+DoubleToString(bar.open,_Digits);
      row+=","+DoubleToString(bar.high,_Digits);
      row+=","+DoubleToString(bar.low,_Digits);
      row+=","+DoubleToString(bar.close,_Digits);
      row+=","+(string)bar.tick_volume;
      row+=","+(string)bar.spread;
      row+=","+(string)bar.real_volume;
      for(int j=0;j<columnCount;j++)
        {
         row+=",";
         if(columns[j].digits>=0)
            row+=DoubleToString(columns[j].values[i],columns[j].digits);
         else
            row+=DoubleToString(columns[j].values[i],-1);
        }
      FileWrite(handle,row);
     }
   return(true);
  }

#endif // __DATAEXPORTCORE_MQH__
