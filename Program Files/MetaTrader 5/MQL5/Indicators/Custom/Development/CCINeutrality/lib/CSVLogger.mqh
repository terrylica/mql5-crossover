//+------------------------------------------------------------------+
//| CSVLogger.mqh                                                    |
//| CSV audit trail logging for pattern detection                   |
//| Version: 1.0.0                                                   |
//+------------------------------------------------------------------+
#property copyright "2025"
#property version   "1.00"
#property strict

#include "PatternDetector.mqh"  // For DetectionDetails struct

//+------------------------------------------------------------------+
//| CSV Logger class                                                 |
//| Manages file handle and logging operations                       |
//+------------------------------------------------------------------+
class CSVLogger
  {
private:
   int               m_file_handle;
   string            m_filename;
   bool              m_header_written;

public:
                     CSVLogger();
                    ~CSVLogger();

   bool              Open(string filename);
   void              Close();
   bool              IsOpen();

   bool              WriteHeader();
   bool              WriteDetectionRow(int bar_index,
                                       datetime time,
                                       const DetectionDetails &details,
                                       bool marker_placed,
                                       double arrow_value);
  };

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSVLogger::CSVLogger()
  {
   m_file_handle = INVALID_HANDLE;
   m_filename = "";
   m_header_written = false;
  }

//+------------------------------------------------------------------+
//| Destructor - ensures file is closed                              |
//+------------------------------------------------------------------+
CSVLogger::~CSVLogger()
  {
   Close();
  }

//+------------------------------------------------------------------+
//| Open CSV file for writing                                        |
//| Returns: true if opened successfully                             |
//+------------------------------------------------------------------+
bool CSVLogger::Open(string filename)
  {
   // Close existing file if open
   Close();

   m_filename = filename;

   // Open file for writing (create or overwrite)
   m_file_handle = FileOpen(m_filename,
                            FILE_WRITE | FILE_CSV | FILE_ANSI,
                            ",");

   if(m_file_handle == INVALID_HANDLE)
     {
      Print("ERROR: CSVLogger: Failed to open ", m_filename,
            ", error: ", GetLastError());
      return false;
     }

   Print("CSVLogger: Opened file ", m_filename);
   m_header_written = false;

   return true;
  }

//+------------------------------------------------------------------+
//| Close CSV file                                                   |
//+------------------------------------------------------------------+
void CSVLogger::Close()
  {
   if(m_file_handle != INVALID_HANDLE)
     {
      FileClose(m_file_handle);
      Print("CSVLogger: Closed file ", m_filename);
      m_file_handle = INVALID_HANDLE;
      m_header_written = false;
     }
  }

//+------------------------------------------------------------------+
//| Check if file is open                                            |
//+------------------------------------------------------------------+
bool CSVLogger::IsOpen()
  {
   return (m_file_handle != INVALID_HANDLE);
  }

//+------------------------------------------------------------------+
//| Write CSV header row                                             |
//+------------------------------------------------------------------+
bool CSVLogger::WriteHeader()
  {
   if(m_file_handle == INVALID_HANDLE)
      return false;

   if(m_header_written)
      return true;  // Already written

   // Write header
   FileWrite(m_file_handle,
             "BarIndex",
             "Time",
             "Val[i-3]",
             "Val[i-2]",
             "Val[i-1]",
             "Val[i]",
             "Check1(i-3<i-2)",
             "Check2(i-2<i-1)",
             "Check3(i-1<i)",
             "MarkerPlaced",
             "ArrowValue");

   FileFlush(m_file_handle);
   m_header_written = true;

   return true;
  }

//+------------------------------------------------------------------+
//| Write detection data row                                         |
//+------------------------------------------------------------------+
bool CSVLogger::WriteDetectionRow(int bar_index,
                                  datetime time,
                                  const DetectionDetails &details,
                                  bool marker_placed,
                                  double arrow_value)
  {
   if(m_file_handle == INVALID_HANDLE)
      return false;

   // Ensure header is written
   if(!m_header_written)
      WriteHeader();

   // Format arrow value (EMPTY_VALUE shows as "EMPTY")
   string arrow_str = (arrow_value == EMPTY_VALUE) ? "EMPTY" :
                      DoubleToString(arrow_value, 1);

   // Write data row
   FileWrite(m_file_handle,
             IntegerToString(bar_index),
             TimeToString(time, TIME_DATE | TIME_SECONDS),
             DoubleToString(details.val_i_minus_3, 6),
             DoubleToString(details.val_i_minus_2, 6),
             DoubleToString(details.val_i_minus_1, 6),
             DoubleToString(details.val_i, 6),
             BoolToString(details.check1),
             BoolToString(details.check2),
             BoolToString(details.check3),
             marker_placed ? "YES" : "NO",
             arrow_str);

   FileFlush(m_file_handle);  // Immediate write for examination

   return true;
  }
//+------------------------------------------------------------------+
