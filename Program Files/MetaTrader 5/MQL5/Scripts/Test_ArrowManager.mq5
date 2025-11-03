//+------------------------------------------------------------------+
//| Test_ArrowManager.mq5                                            |
//| Unit test script for ArrowManager.mqh library                    |
//| Version: 1.0.0                                                   |
//+------------------------------------------------------------------+
#property copyright "2025"
#property version   "1.00"
#property script_show_inputs

#include "../Indicators/Custom/Development/CCINeutrality/lib/ArrowManager.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== ArrowManager Unit Tests ===");
   Print("");

//--- Test 1: Cleanup all existing arrows
   Print("Test 1: Initial cleanup");
   int initial_count = DeleteAllArrows(0);
   Print("  Deleted ", initial_count, " existing arrows");

//--- Test 2: Create single arrow
   Print("");
   Print("Test 2: Create arrow at current time");
   datetime test_time = TimeCurrent();
   bool created = CreateArrow(0, 0, test_time);  // chart_id=0, window_num=0 (main chart)
   Print("  Created: ", created ? "YES" : "NO");

//--- Test 3: Count arrows
   Print("");
   Print("Test 3: Count arrows on chart");
   int count = CountArrows(0);
   Print("  Count: ", count, " (expected 1)");

//--- Test 4: Create duplicate (should handle gracefully)
   Print("");
   Print("Test 4: Create duplicate arrow (same time)");
   bool duplicate = CreateArrow(0, 0, test_time);
   Print("  Created duplicate: ", duplicate ? "YES (OK, already exists)" : "NO");
   count = CountArrows(0);
   Print("  Count: ", count, " (expected 1, not 2)");

//--- Test 5: Create multiple arrows
   Print("");
   Print("Test 5: Create 3 additional arrows");
   datetime time1 = test_time + 60;   // +1 minute
   datetime time2 = test_time + 120;  // +2 minutes
   datetime time3 = test_time + 180;  // +3 minutes

   CreateArrow(0, 0, time1);
   CreateArrow(0, 0, time2);
   CreateArrow(0, 0, time3);

   count = CountArrows(0);
   Print("  Count: ", count, " (expected 4)");

//--- Test 6: Delete specific arrow
   Print("");
   Print("Test 6: Delete arrow at time2");
   bool deleted = DeleteArrow(0, time2);
   Print("  Deleted: ", deleted ? "YES" : "NO");
   count = CountArrows(0);
   Print("  Count: ", count, " (expected 3)");

//--- Test 7: Delete non-existent arrow
   Print("");
   Print("Test 7: Delete non-existent arrow");
   datetime fake_time = test_time + 999;
   bool deleted_fake = DeleteArrow(0, fake_time);
   Print("  Deleted: ", deleted_fake ? "YES" : "NO (expected NO)");

//--- Test 8: Create test marker
   Print("");
   Print("Test 8: Create test marker (different prefix)");
   string test_marker = "TESTMARKER_" + TimeToString(test_time, TIME_DATE | TIME_SECONDS);
   ObjectCreate(0, test_marker, OBJ_ARROW, 0, test_time, 2.0);
   ObjectSetInteger(0, test_marker, OBJPROP_ARROWCODE, 108);
   ObjectSetInteger(0, test_marker, OBJPROP_COLOR, clrRed);
   Print("  Created test marker: ", test_marker);

//--- Test 9: Count arrows (should not include test marker)
   Print("");
   Print("Test 9: Count arrows (excluding test marker)");
   count = CountArrows(0);
   Print("  Count: ", count, " (expected 3, test marker not counted)");

//--- Test 10: Delete all arrows
   Print("");
   Print("Test 10: Delete all RisingArrow_* objects");
   int deleted_count = DeleteAllArrows(0);
   Print("  Deleted: ", deleted_count, " arrows");
   count = CountArrows(0);
   Print("  Count: ", count, " (expected 0)");

//--- Test 11: Delete test markers
   Print("");
   Print("Test 11: Delete test markers");
   int deleted_markers = DeleteTestMarkers(0);
   Print("  Deleted: ", deleted_markers, " test markers");

//--- Test 12: Verify all clean
   Print("");
   Print("Test 12: Verify chart is clean");
   count = CountArrows(0);
   Print("  Arrow count: ", count, " (expected 0)");

   int total_objects = ObjectsTotal(0, -1, OBJ_ARROW);
   Print("  Total arrow objects: ", total_objects, " (expected 0)");

//--- Final message
   Print("");
   Print("=== ArrowManager Tests Complete ===");
   Print("Check chart visually: should have NO arrows remaining");

   ChartRedraw(0);
  }
//+------------------------------------------------------------------+
