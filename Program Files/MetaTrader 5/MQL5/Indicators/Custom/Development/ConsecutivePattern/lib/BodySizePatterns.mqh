//+------------------------------------------------------------------+
//|                                        BodySizePatterns.mqh      |
//|                                                        Terry Li |
//|        Body size pattern detection (expansion/contraction)       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Set contraction signal based on pattern direction                |
//| Requires: Global buffers and input parameters from parent        |
//+------------------------------------------------------------------+
void SetContractionSignal(int bar, bool isBullish, int rates_total)
{
   if(isBullish)
   {
      // Update consecutive counter
      if(bar < rates_total - 1 && BufferSignalBar[bar+1] != 0 && BufferColorIndex[bar+1] == CLR_BULLISH)
         BufferConsecutiveBullish[bar] = BufferConsecutiveBullish[bar+1] + 1;
      else
         BufferConsecutiveBullish[bar] = 1;

      // Mark this bar as a signal bar
      BufferSignalBar[bar] = 1;

      // Set the color index for this bar if showing colored bars
      if(InpShowColorBars)
         BufferColorIndex[bar] = CLR_BULLISH;
   }
   else
   {
      // Update consecutive counter
      if(bar < rates_total - 1 && BufferSignalBar[bar+1] != 0 && BufferColorIndex[bar+1] == CLR_BEARISH)
         BufferConsecutiveBearish[bar] = BufferConsecutiveBearish[bar+1] + 1;
      else
         BufferConsecutiveBearish[bar] = 1;

      // Mark this bar as a signal bar
      BufferSignalBar[bar] = 1;

      // Set the color index for this bar if showing colored bars
      if(InpShowColorBars)
         BufferColorIndex[bar] = CLR_BEARISH;
   }
}

//+------------------------------------------------------------------+
//| Set expansion signal based on pattern direction                  |
//| Requires: Global buffers and input parameters from parent        |
//+------------------------------------------------------------------+
void SetExpansionSignal(int bar, bool isBullish, const double &high[], const double &low[], const datetime &time[], int rates_total)
{
   if(isBullish)
   {
      // Update consecutive counter (check for 0.0, not EMPTY_VALUE)
      if(bar < rates_total - 1 && BufferExpBullishSignal[bar+1] != 0.0)
         BufferExpConsecutiveBullish[bar] = BufferExpConsecutiveBullish[bar+1] + 1;
      else
         BufferExpConsecutiveBullish[bar] = 1;

      // Calculate dot size based on consecutive count
      int dotSize = InpArrowSize + (int)MathMin(BufferExpConsecutiveBullish[bar] - 1, InpMaxDotSize - InpArrowSize);

      // Offset in price: InpDotOffsetPips pips above high
      double offset = InpDotOffsetPips * PipSize();  // Universal pip conversion
      double linePrice = high[bar] + offset;

      // Set the arrow size and position (always set, the PLOT_EMPTY_VALUE handles "no draw")
      if(InpShowDots)
      {
         PlotIndexSetInteger(2, PLOT_LINE_WIDTH, dotSize);
         BufferExpBullishSignal[bar] = linePrice;
      }

      // Create extending line from this signal
      CreateExpansionLine(bar, true, linePrice, time[bar]);
   }
   else
   {
      // Update consecutive counter (check for 0.0, not EMPTY_VALUE)
      if(bar < rates_total - 1 && BufferExpBearishSignal[bar+1] != 0.0)
         BufferExpConsecutiveBearish[bar] = BufferExpConsecutiveBearish[bar+1] + 1;
      else
         BufferExpConsecutiveBearish[bar] = 1;

      // Calculate dot size based on consecutive count
      int dotSize = InpArrowSize + (int)MathMin(BufferExpConsecutiveBearish[bar] - 1, InpMaxDotSize - InpArrowSize);

      // Offset in price: InpDotOffsetPips pips below low
      double offset = InpDotOffsetPips * PipSize();  // Universal pip conversion
      double linePrice = low[bar] - offset;

      // Set the arrow size and position (always set, the PLOT_EMPTY_VALUE handles "no draw")
      if(InpShowDots)
      {
         PlotIndexSetInteger(1, PLOT_LINE_WIDTH, dotSize);
         BufferExpBearishSignal[bar] = linePrice;
      }

      // Create extending line from this signal
      CreateExpansionLine(bar, false, linePrice, time[bar]);
   }
}
//+------------------------------------------------------------------+
