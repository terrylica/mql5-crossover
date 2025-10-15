//+------------------------------------------------------------------+
//|                                            test_text_objects.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

// Input parameters for testing
input int test_bars_back = 10;     // How many bars back to place text
input string test_text = "TEST";   // Text to display
input color text_color = clrRed;   // Text color
input int font_size = 12;          // Font size

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Get current chart ID
   long chart_id = ChartID();
   
   // Get current symbol and timeframe
   string symbol = _Symbol;
   ENUM_TIMEFRAMES period = PERIOD_CURRENT;
   
   // Calculate the time and price for text placement
   datetime text_time = iTime(symbol, period, test_bars_back);
   double text_price = iHigh(symbol, period, test_bars_back);
   
   // Create unique object name with timestamp
   string object_name = "TestText_" + IntegerToString(GetTickCount());
   
   Print("Creating text object: ", object_name);
   Print("Time: ", TimeToString(text_time));
   Print("Price: ", DoubleToString(text_price, _Digits));
   
   // Create the text object
   bool result = ObjectCreate(chart_id, object_name, OBJ_TEXT, 0, text_time, text_price);
   
   if(result)
   {
      Print("Text object created successfully");
      
      // Set text content
      ObjectSetString(chart_id, object_name, OBJPROP_TEXT, test_text);
      
      // Set text properties
      ObjectSetInteger(chart_id, object_name, OBJPROP_COLOR, text_color);
      ObjectSetInteger(chart_id, object_name, OBJPROP_FONTSIZE, font_size);
      ObjectSetString(chart_id, object_name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(chart_id, object_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(chart_id, object_name, OBJPROP_BACK, false);
      ObjectSetInteger(chart_id, object_name, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(chart_id, object_name, OBJPROP_SELECTED, false);
      
      Print("Text properties set successfully");
      
      // Force chart redraw
      ChartRedraw(chart_id);
      
      Print("Chart redrawn - you should see the text '", test_text, "' on the chart");
   }
   else
   {
      int error = GetLastError();
      Print("Failed to create text object. Error code: ", error);
      Print("Error description: ", ErrorDescription(error));
   }
   
   // Create a second test object with different positioning
   string object_name2 = "TestText2_" + IntegerToString(GetTickCount() + 1);
   datetime text_time2 = iTime(symbol, period, test_bars_back - 5);
   double text_price2 = iLow(symbol, period, test_bars_back - 5);
   
   Print("Creating second text object: ", object_name2);
   
   bool result2 = ObjectCreate(chart_id, object_name2, OBJ_TEXT, 0, text_time2, text_price2);
   
   if(result2)
   {
      ObjectSetString(chart_id, object_name2, OBJPROP_TEXT, "TEST2");
      ObjectSetInteger(chart_id, object_name2, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(chart_id, object_name2, OBJPROP_FONTSIZE, font_size);
      ObjectSetString(chart_id, object_name2, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(chart_id, object_name2, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      
      ChartRedraw(chart_id);
      Print("Second text object created successfully");
   }
   else
   {
      Print("Failed to create second text object. Error: ", GetLastError());
   }
   
   Print("Test completed. Check your chart for text objects.");
}

//+------------------------------------------------------------------+
//| Get error description                                             |
//+------------------------------------------------------------------+
string ErrorDescription(int error_code)
{
   switch(error_code)
   {
      case 0: return "No error";
      case 4200: return "Object already exists";
      case 4201: return "Unknown object property";
      case 4202: return "Object does not exist";
      case 4203: return "Unknown object type";
      case 4204: return "No object name";
      case 4205: return "Object coordinates error";
      case 4206: return "No specified subwindow";
      default: return "Error code: " + IntegerToString(error_code);
   }
} 