#property copyright "Test"
#property indicator_chart_window

#include <PatternRecognizers/PatternHelpers.mqh>

int OnInit() { return(INIT_SUCCEEDED); }
int OnCalculate(const int rates_total, const int prev_calculated, const double &close[]) { return(rates_total); }
