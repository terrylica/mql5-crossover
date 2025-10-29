//+------------------------------------------------------------------+
//|                                        CCINeutralityCSVExport.mqh |
//|                    CSV Export Module for CCI Neutrality Indicators |
//+------------------------------------------------------------------+
#property copyright   "Terry Li"
#property link        "https://github.com/terrylica/mql5-crossover"
#property version     "1.00"
#property description "Modular CSV export for CCI Neutrality indicators"

//+------------------------------------------------------------------+
//| CSV Export Module Class                                          |
//+------------------------------------------------------------------+
class CCINeutralityCSVExport
  {
private:
   int               m_file_handle;
   string            m_filename;
   bool              m_is_enabled;

public:
                     CCINeutralityCSVExport();
                    ~CCINeutralityCSVExport();

   bool              Init(string symbol, int period, bool enable_export);
   void              Deinit();

   bool              WriteHeader(int cci_period, int window_size);
   bool              WriteRow(int bar_index,
                              datetime bar_time,
                              double cci_value,
                              double score,
                              double p, double mu, double sd, double e,
                              double c, double v, double q,
                              int color_index);

   bool              IsEnabled() const { return m_is_enabled; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CCINeutralityCSVExport::CCINeutralityCSVExport()
  {
   m_file_handle = INVALID_HANDLE;
   m_filename = "";
   m_is_enabled = false;
  }

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CCINeutralityCSVExport::~CCINeutralityCSVExport()
  {
   Deinit();
  }

//+------------------------------------------------------------------+
//| Initialize CSV export                                             |
//+------------------------------------------------------------------+
bool CCINeutralityCSVExport::Init(string symbol, int period, bool enable_export)
  {
   m_is_enabled = enable_export;

   if(!m_is_enabled)
      return true;

   // Generate filename with timestamp
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   m_filename = StringFormat("cci_neutrality_%s_PERIOD_%s_%04d.%02d.%02d.csv",
                             symbol,
                             EnumToString((ENUM_TIMEFRAMES)period),
                             dt.year, dt.mon, dt.day);

   // Open file for writing
   m_file_handle = FileOpen(m_filename,
                            FILE_WRITE | FILE_CSV | FILE_ANSI,
                            ';');

   if(m_file_handle == INVALID_HANDLE)
     {
      PrintFormat("ERROR: Failed to create CSV file '%s', error %d",
                  m_filename, GetLastError());
      m_is_enabled = false;
      return false;
     }

   PrintFormat("CSV export enabled: %s", m_filename);
   return true;
  }

//+------------------------------------------------------------------+
//| Cleanup CSV export                                                |
//+------------------------------------------------------------------+
void CCINeutralityCSVExport::Deinit()
  {
   if(m_file_handle != INVALID_HANDLE)
     {
      FileClose(m_file_handle);
      m_file_handle = INVALID_HANDLE;

      if(m_is_enabled)
         PrintFormat("CSV export completed: %s", m_filename);
     }

   m_is_enabled = false;
  }

//+------------------------------------------------------------------+
//| Write CSV header                                                  |
//+------------------------------------------------------------------+
bool CCINeutralityCSVExport::WriteHeader(int cci_period, int window_size)
  {
   if(!m_is_enabled || m_file_handle == INVALID_HANDLE)
      return false;

   // Write metadata as comments
   FileWrite(m_file_handle, "# CCI Neutrality Score Export");
   FileWrite(m_file_handle, "# CCI Period: " + IntegerToString(cci_period));
   FileWrite(m_file_handle, "# Window Size: " + IntegerToString(window_size));
   FileWrite(m_file_handle, "# Generated: " + TimeToString(TimeCurrent()));
   FileWrite(m_file_handle, "");

   // Write column headers
   FileWrite(m_file_handle,
             "time",
             "bar",
             "cci",
             "score",
             "p",
             "mu",
             "sd",
             "e",
             "c",
             "v",
             "q",
             "color");

   return true;
  }

//+------------------------------------------------------------------+
//| Write data row to CSV                                             |
//+------------------------------------------------------------------+
bool CCINeutralityCSVExport::WriteRow(int bar_index,
                                       datetime bar_time,
                                       double cci_value,
                                       double score,
                                       double p, double mu, double sd, double e,
                                       double c, double v, double q,
                                       int color_index)
  {
   if(!m_is_enabled || m_file_handle == INVALID_HANDLE)
      return false;

   // Map color index to descriptive string
   string color_name;
   switch(color_index)
     {
      case 0:  color_name = "Red";    break;
      case 1:  color_name = "Yellow"; break;
      case 2:  color_name = "Green";  break;
      default: color_name = "Unknown"; break;
     }

   FileWrite(m_file_handle,
             TimeToString(bar_time),
             bar_index,
             DoubleToString(cci_value, 2),
             DoubleToString(score, 6),
             DoubleToString(p, 6),
             DoubleToString(mu, 2),
             DoubleToString(sd, 2),
             DoubleToString(e, 6),
             DoubleToString(c, 6),
             DoubleToString(v, 6),
             DoubleToString(q, 6),
             color_name);

   return true;
  }
//+------------------------------------------------------------------+
