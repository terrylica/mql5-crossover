//+------------------------------------------------------------------+
//|                                             PatternHelpers.mqh   |
//|                                                        Terry Li |
//|                         Common helper functions for patterns     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get pip size for current symbol (universal: forex, JPY, metals)  |
//| Works with 5-digit, 4-digit, 3-digit, and 2-digit brokers        |
//+------------------------------------------------------------------+
double PipSize()
{
   // Universal formula: pip = 1 / 10^(digits-1)
   // 5-digit EURUSD: 1/10^4 = 0.0001 (1 pip)
   // 3-digit USDJPY: 1/10^2 = 0.01   (1 pip)
   // 2-digit XAUUSD: 1/10^1 = 0.1    (1 pip)
   return 1.0 / MathPow(10, _Digits - 1);
}

//+------------------------------------------------------------------+
//| Check if all bars in the pattern have the same direction         |
//+------------------------------------------------------------------+
bool CheckSameDirection(const double &open[], const double &close[], int startBar, int count, bool isBullish)
{
   for(int j = 1; j < count; j++)
   {
      bool isCurrentBarBullish = close[startBar + j] > open[startBar + j];
      if(isCurrentBarBullish != isBullish)
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check if we have consecutive contractions in body size           |
//+------------------------------------------------------------------+
bool CheckConsecutiveContractions(const double &bodySizes[], int startBar, int count)
{
   for(int j = 0; j < count - 1; j++)
   {
      // For a contraction, current bar should have smaller body than previous
      if(bodySizes[startBar + j] >= bodySizes[startBar + j + 1])
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check if we have consecutive expansions in body size             |
//+------------------------------------------------------------------+
bool CheckConsecutiveExpansions(const double &bodySizes[], int startBar, int count)
{
   for(int j = 0; j < count - 1; j++)
   {
      // For an expansion, current bar should have larger body than previous
      if(bodySizes[startBar + j] <= bodySizes[startBar + j + 1])
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check if all bars in pattern meet minimum body size requirement  |
//+------------------------------------------------------------------+
bool CheckMinimumBodySize(const double &bodySizes[], int startBar, int count, double minBodySize)
{
   // If minBodySize is 0 or negative, skip this check
   if(minBodySize <= 0)
      return true;

   for(int j = 0; j < count; j++)
   {
      if(bodySizes[startBar + j] < minBodySize)
         return false;
   }
   return true;
}
//+------------------------------------------------------------------+
