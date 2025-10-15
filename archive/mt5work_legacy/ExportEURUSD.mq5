#property script_show_inputs

input string      InpSymbol    = "EURUSD";
input ENUM_TIMEFRAMES InpTF    = PERIOD_M1;
input int         InpBars      = 5000;

void OnStart()
  {
   if(!SymbolSelect(InpSymbol,true))
     {
      PrintFormat("SymbolSelect failed for %s (error %d)",InpSymbol,GetLastError());
      return;
     }
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int copied=CopyRates(InpSymbol,InpTF,0,InpBars,rates);
   if(copied<=0)
     {
      PrintFormat("CopyRates failed (%d)",GetLastError());
      return;
     }
   string tf=EnumToString(InpTF);
   string filename=StringFormat("Export_%s_%s.csv",InpSymbol,tf);
   int handle=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("FileOpen failed (%d)",GetLastError());
      return;
     }
   FileWrite(handle,"time","open","high","low","close","tick_volume","spread","real_volume");
   for(int i=copied-1;i>=0;--i)
     {
      MqlRates row=rates[i];
      FileWrite(handle,
                TimeToString(row.time,TIME_DATE|TIME_MINUTES),
                DoubleToString(row.open,_Digits),
                DoubleToString(row.high,_Digits),
                DoubleToString(row.low,_Digits),
                DoubleToString(row.close,_Digits),
                row.tick_volume,
                row.spread,
                row.real_volume);
     }
   FileClose(handle);
   PrintFormat("Exported %d bars for %s %s to %s",copied,InpSymbol,tf,filename);
  }
