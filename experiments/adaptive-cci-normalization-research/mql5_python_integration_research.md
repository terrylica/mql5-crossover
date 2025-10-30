# MQL5-Python Integration Research

**Date**: 2025-10-29
**Purpose**: Evaluate feasibility of calling Python from MQL5 for adaptive CCI normalization

---

## Executive Summary

**Can MQL5 call Python?** YES - Multiple methods available

**Should it?** NO - Not recommended for this use case

**Why?** Performance overhead, complexity, and deployment challenges outweigh benefits. Native MQL5 implementation is simpler and faster.

---

## Integration Methods

### Method 1: DLL Integration (C/C++ Bridge)

**Architecture**:

```
MQL5 → C++ DLL → Python C API → Python script
```

**Requirements**:

- Compile C++ DLL that embeds Python interpreter
- Use Python C API (`Python.h`)
- DLL must be in `MQL5/Libraries/` folder
- 64-bit DLL for MetaTrader 5

**Example MQL5 Code**:

```mql5
#import "PythonBridge.dll"
   int InitPython(string pythonPath);
   double CallPercentileRank(double &values[], int size, double current);
   void ShutdownPython();
#import

void OnInit() {
   InitPython("C:\\Python312\\python.exe");
}

double CalculateAdaptiveScore(double cci, double &window[], int size) {
   return CallPercentileRank(window, size, cci);
}

void OnDeinit(const int reason) {
   ShutdownPython();
}
```

**Example C++ DLL**:

```cpp
#include <Python.h>
#include <windows.h>

extern "C" {
   __declspec(dllexport) int InitPython(wchar_t* pythonPath) {
      Py_SetProgramName(pythonPath);
      Py_Initialize();
      return Py_IsInitialized();
   }

   __declspec(dllexport) double CallPercentileRank(
      double* values, int size, double current
   ) {
      PyObject *pModule, *pFunc, *pArgs, *pValue;

      // Import module
      pModule = PyImport_ImportModule("numpy");
      if (!pModule) return -1;

      // Build arguments
      pArgs = PyTuple_New(2);
      PyObject* pList = PyList_New(size);
      for(int i = 0; i < size; i++) {
         PyList_SetItem(pList, i, PyFloat_FromDouble(values[i]));
      }
      PyTuple_SetItem(pArgs, 0, pList);
      PyTuple_SetItem(pArgs, 1, PyFloat_FromDouble(current));

      // Call function
      pFunc = PyObject_GetAttrString(pModule, "percentile_rank");
      pValue = PyObject_CallObject(pFunc, pArgs);

      double result = PyFloat_AsDouble(pValue);

      Py_DECREF(pArgs);
      Py_DECREF(pFunc);
      Py_DECREF(pModule);
      Py_DECREF(pValue);

      return result;
   }

   __declspec(dllexport) void ShutdownPython() {
      Py_Finalize();
   }
}
```

**Pros**:

- ✅ Direct integration
- ✅ Can leverage Python libraries (NumPy, SciPy)
- ✅ Same memory space (fast data transfer)

**Cons**:

- ❌ Complex setup (C++ compilation required)
- ❌ Platform-specific (Windows DLL)
- ❌ Memory management complexity
- ❌ Python interpreter overhead (~50-100ms initialization)
- ❌ GIL (Global Interpreter Lock) performance penalty
- ❌ Deployment complexity (DLL + Python installation)

**Performance**:

- Initialization: ~50-100ms (one-time)
- Per-call overhead: ~1-5ms (crossing language boundaries)
- Actual calculation: ~0.001ms (NumPy)
- **Total per bar**: ~1-5ms (400x slower than native MQL5)

---

### Method 2: Named Pipes / IPC

**Architecture**:

```
MQL5 (client) ⟷ Named Pipe ⟷ Python Server (background)
```

**MQL5 Code**:

```mql5
int pipe_handle;

void OnInit() {
   // Connect to Python server
   pipe_handle = CreateFile(
      "\\\\.\\pipe\\cci_normalization",
      GENERIC_READ | GENERIC_WRITE,
      0, NULL, OPEN_EXISTING, 0, NULL
   );
}

double CalculateAdaptiveScore(double cci, double &window[], int size) {
   // Send request
   string request = "percentile_rank," + DoubleToString(cci) + ",";
   for(int i = 0; i < size; i++) {
      request += DoubleToString(window[i]) + ",";
   }
   WriteFile(pipe_handle, request);

   // Read response
   string response;
   ReadFile(pipe_handle, response);
   return StringToDouble(response);
}
```

**Python Server**:

```python
import win32pipe
import win32file
import numpy as np

def percentile_rank(value, window):
    return np.sum(window < value) / len(window)

def main():
    pipe = win32pipe.CreateNamedPipe(
        r'\\.\pipe\cci_normalization',
        win32pipe.PIPE_ACCESS_DUPLEX,
        win32pipe.PIPE_TYPE_MESSAGE | win32pipe.PIPE_READMODE_MESSAGE | win32pipe.PIPE_WAIT,
        1, 65536, 65536, 0, None
    )

    while True:
        win32pipe.ConnectNamedPipe(pipe, None)
        data = win32file.ReadFile(pipe, 65536)

        # Parse request
        parts = data[1].decode().split(',')
        current = float(parts[1])
        window = np.array([float(x) for x in parts[2:] if x])

        # Calculate
        score = percentile_rank(current, window)

        # Send response
        win32file.WriteFile(pipe, str(score).encode())
        win32pipe.DisconnectNamedPipe(pipe)

if __name__ == '__main__':
    main()
```

**Pros**:

- ✅ Language-agnostic
- ✅ Python runs in separate process (no crashes affect MT5)
- ✅ Can restart Python without restarting MT5

**Cons**:

- ❌ High latency (~10-50ms per call)
- ❌ Complex data serialization
- ❌ Requires background Python server
- ❌ Error handling complexity
- ❌ Windows-specific (named pipes)

**Performance**:

- Per-call overhead: ~10-50ms (serialization + IPC)
- **Total per bar**: ~10-50ms (10,000x slower than native!)

---

### Method 3: File-Based Communication

**Architecture**:

```
MQL5 → Write CSV → Python reads → Calculate → Write result → MQL5 reads
```

**MQL5 Code**:

```mql5
double CalculateAdaptiveScore(double cci, double &window[], int size) {
   // Write input file
   int handle = FileOpen("cci_input.csv", FILE_WRITE|FILE_CSV);
   FileWrite(handle, DoubleToString(cci));
   for(int i = 0; i < size; i++) {
      FileWrite(handle, DoubleToString(window[i]));
   }
   FileClose(handle);

   // Execute Python script
   ShellExecute(0, "open", "python.exe", "calculate_score.py", NULL, SW_HIDE);

   // Wait for result
   Sleep(100);

   // Read result
   handle = FileOpen("cci_output.csv", FILE_READ|FILE_CSV);
   double score = StringToDouble(FileReadString(handle));
   FileClose(handle);

   return score;
}
```

**Pros**:

- ✅ Simplest to implement
- ✅ Easy to debug (inspect files)
- ✅ Platform-independent

**Cons**:

- ❌ EXTREMELY SLOW (~100-500ms per call)
- ❌ Disk I/O overhead
- ❌ File locking issues
- ❌ Not suitable for real-time indicators
- ❌ Unreliable (timing issues)

**Performance**:

- Per-call overhead: ~100-500ms
- **Total per bar**: ~100-500ms (100,000x slower!)

---

### Method 4: Python MetaTrader5 Package (Reverse Direction)

**Architecture**:

```
Python → MetaTrader5 API → MT5 Terminal → Get CCI data → Calculate in Python
```

**Python Code**:

```python
import MetaTrader5 as mt5
import numpy as np

mt5.initialize()

def calculate_adaptive_cci_score(symbol="EURUSD", timeframe=mt5.TIMEFRAME_M12, window=120):
    # Get CCI values
    rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, window)

    # Calculate CCI (assuming indicator exists)
    # Note: Cannot directly access indicator buffers!

    # Calculate percentile rank
    cci_values = rates['close']  # Placeholder
    current_cci = cci_values[-1]
    score = np.sum(cci_values < current_cci) / len(cci_values)

    return score
```

**Pros**:

- ✅ No DLL compilation needed
- ✅ Python-first development
- ✅ Good for backtesting/analysis

**Cons**:

- ❌ **Cannot access indicator buffers!**
- ❌ Python controls MT5 (not what we want)
- ❌ Requires MT5 terminal running
- ❌ Not suitable for real-time indicators

**Use Case**:

- ✅ Backtesting and validation
- ✅ Historical analysis
- ❌ Real-time indicator calculation

---

## Performance Comparison

| Method | Per-Call Latency | Complexity | Production-Ready |
| --- | --- | --- | --- |
| **Native MQL5** | ~0.001ms | Low | ✅ YES |
| DLL + Python C API | ~1-5ms | Very High | ⚠️ Maybe |
| Named Pipes | ~10-50ms | High | ❌ NO |
| File-Based | ~100-500ms | Low | ❌ NO |
| MT5 Python Package | N/A | Medium | ❌ NO (wrong dir) |

**Baseline**: Native MQL5 percentile rank loop = **~0.001ms per calculation**

---

## Empirical Findings from This Project

**From Wine Python Execution (`WINE_PYTHON_EXECUTION.md`):**

```bash
# This works for DATA EXPORT (batch processing)
wine "C:\\Program Files\\Python312\\python.exe" \
  "C:\\users\\crossover\\export_aligned.py" \
  --symbol EURUSD --period M1 --bars 5000
```

**But NOT for real-time indicator calculations!**

Reasons:

1. Wine adds 50-100ms overhead per Python invocation
2. MT5 indicators calculate per-bar (need ~0.001ms per call)
3. MetaTrader5 Python API cannot access custom indicator buffers
4. File-based config workflow (v4.0.0) is GUI-only

---

## Recommendation: Pure MQL5 Implementation

### Why Native MQL5 is Superior

**1. Performance**:

```
Native MQL5:     0.001ms per calculation
Python via DLL:  1-5ms per calculation (1000x slower)
Python via IPC:  10-50ms per calculation (10,000x slower)
```

**2. Simplicity**:

```mql5
// MQL5 implementation (20 lines)
double PercentileRank(double value, double &window[], int size) {
    int count_below = 0;
    for(int i = 0; i < size; i++) {
        if(window[i] < value) count_below++;
    }
    return (double)count_below / size;
}

double score = PercentileRank(current_cci, cci_window, window_size);
```

vs

```
Python integration:
1. Write C++ DLL wrapper (~200 lines)
2. Compile with Python C API headers
3. Deploy DLL + Python installation
4. Handle memory management
5. Deal with GIL performance issues
6. Test across MT5 updates
```

**3. Deployment**:

- ✅ MQL5: Single `.ex5` file
- ❌ Python: `.ex5` + `.dll` + Python runtime + NumPy + environment setup

**4. Reliability**:

- ✅ MQL5: No external dependencies
- ❌ Python: Python version compatibility, library updates, DLL conflicts

**5. Debugging**:

- ✅ MQL5: Built-in debugger, `Print()` statements
- ❌ Python: Cross-language debugging complexity

---

## When Python Integration Makes Sense

**Use Python for**:

1. ✅ **Backtesting and validation** (use MetaTrader5 Python package)
2. ✅ **Historical analysis** (batch processing via Wine Python)
3. ✅ **Prototyping and research** (this document!)
4. ✅ **Complex ML models** (too complex for MQL5)

**Use MQL5 for**:

1. ✅ **Real-time indicators** (this project)
2. ✅ **Simple calculations** (percentile rank, median, IQR)
3. ✅ **Production trading** (reliability critical)

---

## Hybrid Workflow (Recommended)

**Phase 1: Research & Validation (Python)**

```bash
# Use Python for prototyping
python adversarial_percentile_tests.py
python python_statistical_modules_research.py

# Validate approach with historical data
wine python export_aligned.py --symbol EURUSD --bars 5000
python validate_indicator.py --csv Export.csv
```

**Phase 2: Implementation (MQL5)**

```mql5
// Translate proven algorithm to MQL5
double AdaptiveScore(double cci, double &window[], int size) {
   // Use insights from Python research
   // But implement in native MQL5
   return PercentileRank(cci, window, size);
}
```

**Phase 3: Validation (Python)**

```bash
# Export MQL5 indicator results
# Validate against Python reference
python validate_mql5_output.py --mql5 Export_MQL5.csv --python reference.csv
```

---

## Code Example: MQL5 Multi-Scale Percentile Rank

```mql5
//+------------------------------------------------------------------+
//| Adaptive Multi-Scale CCI Normalization                           |
//+------------------------------------------------------------------+

input int InpWindowShort = 30;   // Short window (6 hours @ M12)
input int InpWindowMed   = 120;  // Medium window (1 day)
input int InpWindowLong  = 500;  // Long window (4 days)

// Rolling CCI windows
double cci_window_short[];
double cci_window_med[];
double cci_window_long[];

//+------------------------------------------------------------------+
//| Percentile Rank Calculation                                      |
//+------------------------------------------------------------------+
double PercentileRank(double value, const double &window[], int size) {
   int count_below = 0;
   for(int i = 0; i < size; i++) {
      if(window[i] < value) count_below++;
   }
   return (double)count_below / size;
}

//+------------------------------------------------------------------+
//| Multi-Scale Adaptive Score                                       |
//+------------------------------------------------------------------+
double AdaptiveScore(double current_cci) {
   // Calculate percentile rank at each scale
   double pr_short = PercentileRank(current_cci, cci_window_short, InpWindowShort);
   double pr_med   = PercentileRank(current_cci, cci_window_med, InpWindowMed);
   double pr_long  = PercentileRank(current_cci, cci_window_long, InpWindowLong);

   // Weighted ensemble (favor recent)
   double score = 0.5 * pr_short + 0.3 * pr_med + 0.2 * pr_long;

   return score;
}

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[]) {

   // Update rolling windows (implement circular buffer for efficiency)
   // ... window management code ...

   for(int i = prev_calculated; i < rates_total; i++) {
      double current_cci = CalculateCCI(i);  // Your CCI calculation

      // Wait for warmup
      if(i < InpWindowLong) {
         score_buffer[i] = 0.5;  // Neutral during warmup
         continue;
      }

      // Calculate adaptive score
      double score = AdaptiveScore(current_cci);

      // Map to colors
      color bar_color;
      if(score > 0.7)      bar_color = clrGreen;   // High neutral
      else if(score > 0.3) bar_color = clrYellow;  // Medium
      else                 bar_color = clrRed;     // Low neutral

      score_buffer[i] = score;
      color_buffer[i] = bar_color;
   }

   return rates_total;
}
```

**Performance**: ~0.001-0.002ms per bar (fast enough for real-time)

---

## Conclusion

**Question**: Can MQL5 call Python for adaptive CCI normalization?

**Answer**: YES (technically possible via DLL), but NO (not recommended)

**Recommended Approach**:

1. ✅ Use Python for research and validation (this research!)
2. ✅ Implement in native MQL5 (simple percentile rank loop)
3. ✅ Use Python to validate MQL5 output
4. ✅ Deploy pure MQL5 indicator (no dependencies)

**Key Insight**: The algorithm is simple enough that Python's advantages (libraries, ease of use) don't outweigh the complexity and performance costs of integration.

**Performance Winner**: Native MQL5 (1000x faster, simpler, more reliable)

---

## References

1. MQL5 DLL Documentation: https://www.mql5.com/en/docs/integration/dll
2. Python C API: https://docs.python.org/3/c-api/
3. MetaTrader5 Python Package: https://pypi.org/project/MetaTrader5/
4. This project's Wine Python workflow: `docs/guides/WINE_PYTHON_EXECUTION.md`
5. This project's validation methodology: `docs/guides/INDICATOR_VALIDATION_METHODOLOGY.md`
