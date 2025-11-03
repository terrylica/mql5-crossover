//+------------------------------------------------------------------+
//| Test_PatternDetector.mq5                                         |
//| Unit test script for PatternDetector.mqh library                 |
//| Version: 1.0.0                                                   |
//+------------------------------------------------------------------+
#property copyright "2025"
#property version   "1.00"
#property script_show_inputs

#include "../Indicators/Custom/Development/CCINeutrality/lib/PatternDetector.mqh"

//+------------------------------------------------------------------+
//| Test case result tracking                                        |
//+------------------------------------------------------------------+
int g_tests_passed = 0;
int g_tests_failed = 0;

//+------------------------------------------------------------------+
//| Assert helper function                                           |
//+------------------------------------------------------------------+
void AssertTrue(string test_name, bool condition)
  {
   if(condition)
     {
      g_tests_passed++;
      Print("✅ PASS: ", test_name);
     }
   else
     {
      g_tests_failed++;
      Print("❌ FAIL: ", test_name);
     }
  }

void AssertFalse(string test_name, bool condition)
  {
   AssertTrue(test_name, !condition);
  }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== PatternDetector Unit Tests ===");
   Print("");

//--- Test 1: Rising pattern (all bars increasing)
   double rising[] = {0.1, 0.2, 0.3, 0.4};
   ArraySetAsSeries(rising, true);
   AssertTrue("Test 1: Rising pattern detected (0.1<0.2<0.3<0.4)",
              DetectRisingPattern(rising, 3));

//--- Test 2: Flat pattern (all bars equal)
   double flat[] = {0.5, 0.5, 0.5, 0.5};
   ArraySetAsSeries(flat, true);
   AssertFalse("Test 2: Flat pattern not detected (0.5=0.5=0.5=0.5)",
               DetectRisingPattern(flat, 3));

//--- Test 3: Falling pattern (all bars decreasing)
   double falling[] = {0.4, 0.3, 0.2, 0.1};
   ArraySetAsSeries(falling, true);
   AssertFalse("Test 3: Falling pattern not detected (0.4>0.3>0.2>0.1)",
               DetectRisingPattern(falling, 3));

//--- Test 4: Mixed pattern (not consistently rising)
   double mixed[] = {0.1, 0.3, 0.2, 0.4};
   ArraySetAsSeries(mixed, true);
   AssertFalse("Test 4: Mixed pattern not detected (0.1<0.3>0.2<0.4)",
               DetectRisingPattern(mixed, 3));

//--- Test 5: Boundary - index too small (index < 3)
   AssertFalse("Test 5: Index=2 returns false (needs index>=3)",
               DetectRisingPattern(rising, 2));

//--- Test 6: Boundary - empty array
   double empty[];
   AssertFalse("Test 6: Empty array returns false",
               DetectRisingPattern(empty, 3));

//--- Test 7: Edge case - very small differences (precision)
   double precision[] = {0.100000, 0.100001, 0.100002, 0.100003};
   ArraySetAsSeries(precision, true);
   AssertTrue("Test 7: Precision test (tiny increments)",
              DetectRisingPattern(precision, 3));

//--- Test 8: Edge case - large values
   double large[] = {1000.0, 2000.0, 3000.0, 4000.0};
   ArraySetAsSeries(large, true);
   AssertTrue("Test 8: Large values (1000<2000<3000<4000)",
              DetectRisingPattern(large, 3));

//--- Test 9: GetDetectionDetails - verify struct contents
   DetectionDetails details = GetDetectionDetails(rising, 3);
   AssertTrue("Test 9a: Details val[i-3] = 0.1",
              MathAbs(details.val_i_minus_3 - 0.1) < 0.0001);
   AssertTrue("Test 9b: Details val[i] = 0.4",
              MathAbs(details.val_i - 0.4) < 0.0001);
   AssertTrue("Test 9c: Details check1 = true",
              details.check1);
   AssertTrue("Test 9d: Details pattern_detected = true",
              details.pattern_detected);

//--- Test 10: GetDetectionDetails - flat pattern checks
   DetectionDetails flat_details = GetDetectionDetails(flat, 3);
   AssertFalse("Test 10a: Flat pattern check1 = false",
               flat_details.check1);
   AssertFalse("Test 10b: Flat pattern check2 = false",
               flat_details.check2);
   AssertFalse("Test 10c: Flat pattern pattern_detected = false",
               flat_details.pattern_detected);

//--- Test 11: Real-world data simulation
   double real_world[] = {0.123456, 0.345678, 0.567890, 0.789012};
   ArraySetAsSeries(real_world, true);
   AssertTrue("Test 11: Real-world data pattern",
              DetectRisingPattern(real_world, 3));

//--- Test 12: Partial rise (only 3 of 4 bars rising)
   double partial[] = {0.5, 0.4, 0.5, 0.6};  // i-3=0.5, i-2=0.4 (FAILS check1)
   ArraySetAsSeries(partial, true);
   AssertFalse("Test 12: Partial rise not detected (first check fails)",
               DetectRisingPattern(partial, 3));

//--- Print summary
   Print("");
   Print("=== Test Summary ===");
   Print("Tests Passed: ", g_tests_passed);
   Print("Tests Failed: ", g_tests_failed);
   Print("Total Tests: ", g_tests_passed + g_tests_failed);

   if(g_tests_failed == 0)
      Print("✅ ALL TESTS PASSED!");
   else
      Print("❌ SOME TESTS FAILED - Review logic");
  }
//+------------------------------------------------------------------+
