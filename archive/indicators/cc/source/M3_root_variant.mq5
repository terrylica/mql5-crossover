//+------------------------------------------------------------------+
//|                                                           M3.mq5 |
//|                                    Copyright 2024, Eon Labs Ltd. |
//|                                          https://www.eonlabs.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Eon Labs Ltd."
#property link      "https://www.eonlabs.com"
#property version   "1.00"
#property indicator_chart_window
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---
   
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                             Custom 3-Minute Bars |
//|                                      Script to plot 3-min OHLC   |
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_color1 Blue
#property indicator_color2 Red
#property indicator_color3 Green
#property indicator_color4 Yellow

input int MinutesPerBar = 3;  // Number of minutes per bar
double OpenBuffer[], HighBuffer[], LowBuffer[], CloseBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    SetIndexBuffer(0, OpenBuffer);
    SetIndexBuffer(1, HighBuffer);
    SetIndexBuffer(2, LowBuffer);
    SetIndexBuffer(3, CloseBuffer);

    IndicatorSetString(INDICATOR_SHORTNAME, "Custom 3-Minute OHLC");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[]) {

    int limit = rates_total - prev_calculated;
    int barIndex = 0;

    for (int i = limit; i >= 0; i--) {
        datetime currentTime = time[i];
        
        // Define start of a 3-minute bar
        if (currentTime % (MinutesPerBar * 60) == 0) {
            // Store Open, High, Low, Close for the custom bar
            double openPrice = open[i];
            double highPrice = open[i];
            double lowPrice = open[i];
            double closePrice = open[i];
            
            for (int j = i; j < i + MinutesPerBar && j < rates_total; j++) {
                highPrice = MathMax(highPrice, high[j]);
                lowPrice = MathMin(lowPrice, low[j]);
                closePrice = close[j];
            }
            
            OpenBuffer[barIndex] = openPrice;
            HighBuffer[barIndex] = highPrice;
            LowBuffer[barIndex] = lowPrice;
            CloseBuffer[barIndex] = closePrice;

            barIndex++;
        }
    }
    return(rates_total);
}