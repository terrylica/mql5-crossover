//+------------------------------------------------------------------+
//|                                                    CsvLogger.mqh |
//|                             CSV Logging Utility for Indicators   |
//|                                                                  |
//| Usage:                                                           |
//|   CsvLogger log;                                                 |
//|   log.Open("myfile.csv");                                        |
//|   log.Header("time;price;value");                                |
//|   log.Row(StringFormat("%s;%.5f;%.2f", ...));                   |
//|   log.Close();                                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| CSV Logger Class                                                 |
//| Writes diagnostic data to CSV files in Common Files directory   |
//+------------------------------------------------------------------+
class CsvLogger
  {
private:
   int               m_handle;
   string            m_path;
   bool              m_header_written;

public:
                     CsvLogger(void);
                    ~CsvLogger(void);

   bool              Open(const string filename);
   void              Header(const string columns);
   void              Row(const string data);
   void              Flush(void);
   void              Close(void);

   bool              IsOpen(void) const { return m_handle != INVALID_HANDLE; }
   string            GetPath(void) const { return m_path; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CsvLogger::CsvLogger(void) : m_handle(INVALID_HANDLE),
                             m_header_written(false)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CsvLogger::~CsvLogger(void)
  {
   Close();
  }

//+------------------------------------------------------------------+
//| Open CSV file for writing                                       |
//| Uses FILE_COMMON for persistence across terminal sessions       |
//| Returns: true if successful, false otherwise                    |
//+------------------------------------------------------------------+
bool CsvLogger::Open(const string filename)
  {
   if(m_handle != INVALID_HANDLE)
      Close();

   m_path = filename;

   // Open with FILE_COMMON so files persist in Terminal\Common\Files
   // FILE_CSV ensures proper CSV formatting
   // FILE_SHARE_READ allows external tools to read while open
   m_handle = FileOpen(m_path,
                       FILE_WRITE | FILE_CSV | FILE_SHARE_READ | FILE_COMMON,
                       ';',
                       CP_UTF8);

   if(m_handle == INVALID_HANDLE)
     {
      int error = GetLastError();
      PrintFormat("CsvLogger: Failed to open file '%s', error %d", m_path, error);
      return false;
     }

   PrintFormat("CsvLogger: Opened '%s' in %s",
               m_path,
               TerminalInfoString(TERMINAL_COMMONDATA_PATH));
   m_header_written = false;
   return true;
  }

//+------------------------------------------------------------------+
//| Write CSV header row                                            |
//| Only writes once per file                                       |
//+------------------------------------------------------------------+
void CsvLogger::Header(const string columns)
  {
   if(m_handle == INVALID_HANDLE || m_header_written)
      return;

   FileWrite(m_handle, columns);
   m_header_written = true;
   FileFlush(m_handle);
  }

//+------------------------------------------------------------------+
//| Write data row to CSV                                           |
//+------------------------------------------------------------------+
void CsvLogger::Row(const string data)
  {
   if(m_handle == INVALID_HANDLE)
      return;

   FileWrite(m_handle, data);
  }

//+------------------------------------------------------------------+
//| Flush buffer to disk                                            |
//| Call periodically for large datasets                            |
//+------------------------------------------------------------------+
void CsvLogger::Flush(void)
  {
   if(m_handle != INVALID_HANDLE)
      FileFlush(m_handle);
  }

//+------------------------------------------------------------------+
//| Close CSV file                                                  |
//+------------------------------------------------------------------+
void CsvLogger::Close(void)
  {
   if(m_handle != INVALID_HANDLE)
     {
      FileClose(m_handle);
      PrintFormat("CsvLogger: Closed '%s'", m_path);
      m_handle = INVALID_HANDLE;
      m_header_written = false;
     }
  }
//+------------------------------------------------------------------+
