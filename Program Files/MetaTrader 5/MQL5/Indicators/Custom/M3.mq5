//+------------------------------------------------------------------+
//|                                             Custom 3-Minute Bars |
//|                                      Script to plot 3-min OHLC   |
//+------------------------------------------------------------------+
#property indicator_chart_window      // Ensure it plots on the main chart
#property indicator_buffers 4         // Define 4 buffers for OHLC
#property indicator_color1 Blue       // Color for Open
#property indicator_color2 Red        // Color for High
#property indicator_color3 Green      // Color for Low
#property indicator_color4 Yellow     // Color for Close

input int MinutesPerBar = 3;          // Number of minutes per custom bar
double OpenBuffer[], HighBuffer[], LowBuffer[], CloseBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    // Assign buffers to the indicator
    SetIndexBuffer(0, OpenBuffer);
    SetIndexBuffer(1, HighBuffer);
    SetIndexBuffer(2, LowBuffer);
    SetIndexBuffer(3, CloseBuffer);

    // Set plot styles for each buffer to display as lines on the main chart
    PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_SECTION);
    PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_SECTION);
    PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_SECTION);
    PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_SECTION);

    // Set short name for the indicator
    IndicatorSetString(INDICATOR_SHORTNAME, "Custom 3-Minute OHLC");

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,      // total number of bars
                const int prev_calculated,  // number of bars already processed
                const datetime &time[],     // array of times
                const double &open[],       // array of opens
                const double &high[],       // array of highs
                const double &low[],        // array of lows
                const double &close[],      // array of closes
                const long &tick_volume[],  // array of tick volumes
                const long &volume[],       // array of volumes
                const int &spread[])        // array of spreads
{
    int start = prev_calculated;  // Start from where the last calculation left off

    // Log information to see if rates_total and prev_calculated make sense
    Comment("rates_total: ", rates_total, "\nprev_calculated: ", prev_calculated);

    // Step 1: Aggregation logic for 3-minute bars
    int barIndex = 0; // Initialize the custom 3-minute bar index
    for (int i = start; i < rates_total; i++) {
        datetime currentTime = time[i];

        // Check if the current time is at the start of a 3-minute interval
        if (currentTime % (MinutesPerBar * 60) == 0) {
            // Initialize OHLC for this 3-minute bar
            double openPrice = open[i];
            double highPrice = high[i];
            double lowPrice = low[i];
            double closePrice = close[i];

            // Aggregate data for the next 3 minutes
            for (int j = i; j < i + MinutesPerBar && j < rates_total; j++) {
                highPrice = MathMax(highPrice, high[j]);
                lowPrice = MathMin(lowPrice, low[j]);
                closePrice = close[j]; // Update to the latest close within the interval
            }

            // Store the calculated 3-minute bar data in buffers
            OpenBuffer[barIndex] = openPrice;
            HighBuffer[barIndex] = highPrice;
            LowBuffer[barIndex] = lowPrice;
            CloseBuffer[barIndex] = closePrice;

            // Log the values of each 3-minute bar for verification
            Comment("3-Minute Bar Index: ", barIndex,
                    "\nTime: ", TimeToString(currentTime),
                    "\nOpen: ", DoubleToString(openPrice, 5),
                    "\nHigh: ", DoubleToString(highPrice, 5),
                    "\nLow: ", DoubleToString(lowPrice, 5),
                    "\nClose: ", DoubleToString(closePrice, 5));

            // Increment bar index for the next 3-minute bar
            barIndex++;
        }
    }

    return(rates_total);
}