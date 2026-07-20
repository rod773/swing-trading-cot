//+------------------------------------------------------------------+
//|                                                 WILL_Val.mq5 |
//|                                     Based on Larry Williams (1998)|
//|                                              COT Valuation Index  |
//+------------------------------------------------------------------+
#property copyright "Converted from Pine Script"
#property link      ""
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 6
#property indicator_plots   3
#property indicator_shortname "WILL Val"
//--- plot 1: %-Rank colored line
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrBlue, clrMaroon, clrGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
#property indicator_label1  "%-Rank"
//--- plot 2: Overbought fill zone
#property indicator_type2   DRAW_FILLING
#property indicator_color2  clrMaroon, clrMaroon
#property indicator_label2  "Overbought Zone"
//--- plot 3: Oversold fill zone
#property indicator_type3   DRAW_FILLING
#property indicator_color3  clrGreen, clrGreen
#property indicator_label3  "Oversold Zone"

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "COT Valuation Index"
input string             InpGoldTicker    = "XAUUSD";     // Gold Ticker
input int                InpShortMA       = 2;            // Short MA Period
input int                InpLongMA        = 22;           // Long MA Period
input int                InpLookbackYears = 3;            // Lookback Range (years)
input int                InpOBLevel       = 80;           // Overbought Level
input int                InpOSLevel       = 20;           // Oversold Level

//+------------------------------------------------------------------+
//| Buffers                                                          |
//+------------------------------------------------------------------+
double pctBuffer[];        // main line values
double colorBuffer[];      // color index: 0=blue, 1=maroon, 2=green
double obUpperBuffer[];    // overbought fill upper boundary (100)
double obLowerBuffer[];    // overbought fill lower boundary (OB level)
double osUpperBuffer[];    // oversold fill upper boundary (OS level)
double osLowerBuffer[];    // oversold fill lower boundary (0)

//+------------------------------------------------------------------+
//| Handles & globals                                                |
//+------------------------------------------------------------------+
int goldCloseHandle;
int lookbackBars;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpShortMA < 1 || InpLongMA < 2 || InpLookbackYears < 1)
      return(INIT_PARAMETERS_INCORRECT);

   SetIndexBuffer(0, pctBuffer,     INDICATOR_DATA);
   SetIndexBuffer(1, colorBuffer,   INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, obUpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, obLowerBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, osUpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, osLowerBuffer, INDICATOR_DATA);

   PlotIndexSetInteger(1, PLOT_SHOW_DATA, false);
   PlotIndexSetInteger(2, PLOT_SHOW_DATA, false);

   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 50.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, (double)InpOBLevel);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, (double)InpOSLevel);
   IndicatorSetString(INDICATOR_LEVELTEXT, 0, "Midline");
   IndicatorSetString(INDICATOR_LEVELTEXT, 1, "Overbought");
   IndicatorSetString(INDICATOR_LEVELTEXT, 2, "Oversold");
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DOT);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrGray);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 1, STYLE_DASH);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, clrMaroon);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 2, STYLE_DASH);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 2, clrGreen);

   IndicatorSetDouble(INDICATOR_MINIMUM, 0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 100);

   goldCloseHandle = iClose(InpGoldTicker, _Period);
   if(goldCloseHandle == INVALID_HANDLE)
      return(INIT_FAILED);

   lookbackBars = InpLookbackYears * 52;

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(goldCloseHandle != INVALID_HANDLE)
      IndicatorRelease(goldCloseHandle);
}

//+------------------------------------------------------------------+
//| Manual WMA (Linear Weighted Moving Average)                      |
//+------------------------------------------------------------------+
double ComputeWMA(const double &data[], int period, int index)
{
   double sum = 0, wsum = 0;
   for(int k = 0; k < period && (index - k) >= 0; k++)
   {
      double w = (double)(period - k);
      sum += data[index - k] * w;
      wsum += w;
   }
   return (wsum > 0) ? sum / wsum : 0;
}

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < InpLongMA)
      return(0);

   //--- Get gold close data
   double goldClose[];
   int copiedGold = CopyClose(InpGoldTicker, _Period, 0, rates_total, goldClose);
   if(copiedGold < rates_total)
      return(0);

   //--- Compute spread = goldClose - chartClose
   double spreadData[];
   ArrayResize(spreadData, rates_total);
   for(int i = 0; i < rates_total; i++)
      spreadData[i] = goldClose[i] - close[i];

   //--- Pre-compute short and long WMA on spread
   double shortWma[], longWma[];
   ArrayResize(shortWma, rates_total);
   ArrayResize(longWma,  rates_total);
   ArrayInitialize(shortWma, 0);
   ArrayInitialize(longWma,  0);

   for(int i = InpShortMA - 1; i < rates_total; i++)
      shortWma[i] = ComputeWMA(spreadData, InpShortMA, i);

   for(int i = InpLongMA - 1; i < rates_total; i++)
      longWma[i] = ComputeWMA(spreadData, InpLongMA, i);

   //--- Fill zone buffers
   for(int i = 0; i < rates_total; i++)
   {
      obUpperBuffer[i] = 100.0;
      obLowerBuffer[i] = (double)InpOBLevel;
      osUpperBuffer[i] = (double)InpOSLevel;
      osLowerBuffer[i] = 0.0;
   }

   int start = (prev_calculated > 1) ? prev_calculated - 1 : InpLongMA;
   if(start < InpLongMA)
      start = InpLongMA;

   for(int i = start; i < rates_total; i++)
   {
      double diff = shortWma[i] - longWma[i];

      double hi = diff;
      double lo = diff;
      int lookStart = (i - lookbackBars > 0) ? i - lookbackBars : 0;

      for(int j = lookStart; j < i; j++)
      {
         double d = shortWma[j] - longWma[j];
         if(d > hi) hi = d;
         if(d < lo) lo = d;
      }

      double rng = hi - lo;
      double pct = (rng > 0) ? ((diff - lo) / rng) * 100.0 : 50.0;

      pctBuffer[i] = pct;

      if(pct > InpOBLevel)
         colorBuffer[i] = 1;
      else if(pct < InpOSLevel)
         colorBuffer[i] = 2;
      else
         colorBuffer[i] = 0;
   }

   for(int i = 0; i < start; i++)
   {
      pctBuffer[i]   = EMPTY_VALUE;
      colorBuffer[i] = 0;
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
