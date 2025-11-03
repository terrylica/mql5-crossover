//+------------------------------------------------------------------+
//| ArrowManager.mqh                                                 |
//| Arrow object lifecycle management (create/delete/cleanup)        |
//| Version: 1.0.0                                                   |
//+------------------------------------------------------------------+
#property copyright "2025"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Arrow configuration constants                                    |
//+------------------------------------------------------------------+
#define ARROW_CODE_BULLET 108         // Bullet/large dot (platform-independent)
#define ARROW_DEFAULT_COLOR clrYellow // Yellow for visibility
#define ARROW_DEFAULT_WIDTH 1         // Line width
#define ARROW_Y_POSITION 1.1          // Fixed Y position (above 0-1 histogram)

//+------------------------------------------------------------------+
//| Create arrow object at specified time                            |
//| Returns: true if created successfully, false otherwise           |
//| Parameters:                                                       |
//|   - chart_id: Chart identifier (0 = current)                     |
//|   - window_num: Window number (0=main chart, 1+=subwindow)       |
//|   - time: Time to place arrow                                    |
//|   - y_pos: Y coordinate (default 1.1)                            |
//|   - arrow_code: Arrow code (default 108 = bullet)                |
//|   - color: Arrow color (default yellow)                          |
//|   - width: Arrow width (default 1)                               |
//+------------------------------------------------------------------+
bool CreateArrow(long chart_id,
                 int window_num,
                 datetime time,
                 double y_pos = ARROW_Y_POSITION,
                 int arrow_code = ARROW_CODE_BULLET,
                 color arrow_color = ARROW_DEFAULT_COLOR,
                 int width = ARROW_DEFAULT_WIDTH)
  {
   // Generate unique object name based on time
   string obj_name = "RisingArrow_" + TimeToString(time, TIME_DATE | TIME_SECONDS);

   // Check if object already exists
   if(ObjectFind(chart_id, obj_name) >= 0)
     {
      // Already exists, no need to create
      return true;
     }

   // Create arrow object
   if(!ObjectCreate(chart_id, obj_name, OBJ_ARROW, window_num, time, y_pos))
     {
      Print("ERROR: ArrowManager: Failed to create arrow at ", TimeToString(time),
            ", error: ", GetLastError());
      return false;
     }

   // Set arrow properties
   ObjectSetInteger(chart_id, obj_name, OBJPROP_ARROWCODE, arrow_code);
   ObjectSetInteger(chart_id, obj_name, OBJPROP_COLOR, arrow_color);
   ObjectSetInteger(chart_id, obj_name, OBJPROP_WIDTH, width);
   ObjectSetInteger(chart_id, obj_name, OBJPROP_BACK, false);  // Foreground

   return true;
  }

//+------------------------------------------------------------------+
//| Delete arrow object at specified time                            |
//| Returns: true if deleted, false if not found                     |
//+------------------------------------------------------------------+
bool DeleteArrow(long chart_id, datetime time)
  {
   string obj_name = "RisingArrow_" + TimeToString(time, TIME_DATE | TIME_SECONDS);

   if(ObjectFind(chart_id, obj_name) < 0)
      return false;  // Not found

   return ObjectDelete(chart_id, obj_name);
  }

//+------------------------------------------------------------------+
//| Delete ALL arrow objects with prefix "RisingArrow_"              |
//| Returns: Number of arrows deleted                                |
//| Use case: Cleanup on indicator initialization or removal         |
//+------------------------------------------------------------------+
int DeleteAllArrows(long chart_id)
  {
   int deleted = 0;
   int total = ObjectsTotal(chart_id, -1, OBJ_ARROW);

   // Iterate backwards (safe for deletion during iteration)
   for(int i = total - 1; i >= 0; i--)
     {
      string obj_name = ObjectName(chart_id, i, -1, OBJ_ARROW);

      // Check if it's our arrow (starts with "RisingArrow_")
      if(StringFind(obj_name, "RisingArrow_") == 0)
        {
         if(ObjectDelete(chart_id, obj_name))
            deleted++;
        }
     }

   if(deleted > 0)
      Print("ArrowManager: Deleted ", deleted, " arrow objects");

   return deleted;
  }

//+------------------------------------------------------------------+
//| Delete test marker objects                                       |
//| Returns: Number of test markers deleted                          |
//| Use case: Phase 2 cleanup (hard-coded test arrows)               |
//+------------------------------------------------------------------+
int DeleteTestMarkers(long chart_id)
  {
   int deleted = 0;
   int total = ObjectsTotal(chart_id, -1, OBJ_ARROW);

   for(int i = total - 1; i >= 0; i--)
     {
      string obj_name = ObjectName(chart_id, i, -1, OBJ_ARROW);

      // Check if it's a test marker (starts with "TESTMARKER_")
      if(StringFind(obj_name, "TESTMARKER_") == 0)
        {
         if(ObjectDelete(chart_id, obj_name))
            deleted++;
        }
     }

   if(deleted > 0)
      Print("ArrowManager: Deleted ", deleted, " test marker objects");

   return deleted;
  }

//+------------------------------------------------------------------+
//| Count arrow objects on chart                                     |
//| Returns: Number of RisingArrow_* objects found                   |
//+------------------------------------------------------------------+
int CountArrows(long chart_id)
  {
   int count = 0;
   int total = ObjectsTotal(chart_id, -1, OBJ_ARROW);

   for(int i = 0; i < total; i++)
     {
      string obj_name = ObjectName(chart_id, i, -1, OBJ_ARROW);
      if(StringFind(obj_name, "RisingArrow_") == 0)
         count++;
     }

   return count;
  }
//+------------------------------------------------------------------+
