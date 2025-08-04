//+------------------------------------------------------------------+
//|                                                BingShen_SR_Basic.mq4 |
//|                                  BingShen SR v2.5N-Pro GBPUSD Basic |
//|                                                                      |
//+------------------------------------------------------------------+
#property copyright "BingShen SR"
#property link      ""
#property version   "2.50"
#property strict

// Input Parameters
input bool EnableTimeFilter = true;
input int StartHour_UTC = 2;
input int EndHour_UTC = 14;
input int CooldownSeconds = 600;
input int MinRangeWidthPoints = 300;
input bool EnableD1TrendFilter = true;
input bool EnableSMA300Filter = true;
input int MinScoreThreshold = 80;

// Global Variables
datetime LastNotificationTime = 0;
double LastNotificationPrice = 0.0;
string MainPattern = "";
double OperationHigh = 0.0;
double OperationLow = 0.0; 
double SuggestedStopLoss = 0.0;
double CurrentPrice = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(Symbol() != "GBPUSD")
   {
      Alert("This EA is for GBPUSD only");
      return(INIT_FAILED);
   }
   
   Print("BingShen SR Basic EA initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("BingShen SR Basic EA removed");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsTimeAllowed()) return;
   if(!IsRangeWidthSufficient()) return;

   CurrentPrice = Bid;
   int direction = DetermineDirection();

   if(direction == 0) return;
   if(!IsTrendConsistent(direction)) return;
   if(TimeCurrent() - LastNotificationTime < CooldownSeconds) return;
   
   double minMove = Point * 5;
   if(MathAbs(CurrentPrice - LastNotificationPrice) < minMove) return;

   double controlPoint = (direction > 0) ? OperationHigh : OperationLow;
   bool signalTriggered = false;
   
   if(direction > 0 && CurrentPrice > controlPoint) signalTriggered = true;
   if(direction < 0 && CurrentPrice < controlPoint) signalTriggered = true;
   
   if(signalTriggered)
   {
      int score = CalculateScore(direction);
      if(score >= MinScoreThreshold)
      {
         SendNotification(direction, score);
         LastNotificationTime = TimeCurrent();
         LastNotificationPrice = CurrentPrice;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if current time is allowed                                |
//+------------------------------------------------------------------+
bool IsTimeAllowed()
{
   if(!EnableTimeFilter) return true;
   
   int currentHour = TimeHour(TimeCurrent());
   return (currentHour >= StartHour_UTC && currentHour <= EndHour_UTC);
}

//+------------------------------------------------------------------+
//| Check if range width is sufficient                              |
//+------------------------------------------------------------------+
bool IsRangeWidthSufficient()
{
   double high = iHigh(NULL, 0, iHighest(NULL, 0, MODE_HIGH, 20, 1));
   double low = iLow(NULL, 0, iLowest(NULL, 0, MODE_LOW, 20, 1));
   
   double minWidth = Point * MinRangeWidthPoints;
   return ((high - low) >= minWidth);
}

//+------------------------------------------------------------------+
//| Check if trend is consistent                                    |
//+------------------------------------------------------------------+
bool IsTrendConsistent(int direction)
{
   if(!EnableSMA300Filter) return true;
   
   double sma300 = iMA(NULL, 0, 300, 0, MODE_SMA, PRICE_CLOSE, 1);
   
   if(direction > 0 && CurrentPrice > sma300) return true;
   if(direction < 0 && CurrentPrice < sma300) return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Determine trading direction                                      |
//+------------------------------------------------------------------+
int DetermineDirection()
{
   double h1 = iHigh(NULL, 0, 5);
   double l1 = iLow(NULL, 0, 5);
   double h2 = iHigh(NULL, 0, 3);
   double l2 = iLow(NULL, 0, 3);
   double h3 = iHigh(NULL, 0, 1);
   double l3 = iLow(NULL, 0, 1);

   double stopDist = Point * 100;

   // N Pattern
   if(h2 > h1 && l2 > l1 && h3 > h2)
   {
      MainPattern = "N Pattern";
      OperationHigh = h2;
      OperationLow = l2;
      SuggestedStopLoss = l2 - stopDist;
      return 1;
   }
   
   // Inverted N Pattern  
   if(l2 < l1 && h2 < h1 && l3 < l2)
   {
      MainPattern = "Inverted N";
      OperationHigh = h2;
      OperationLow = l2;
      SuggestedStopLoss = h2 + stopDist;
      return -1;
   }
   
   // W Pattern
   if(l1 > l2 && l2 < l3 && h3 < h1)
   {
      MainPattern = "W Pattern";
      OperationHigh = h1;
      OperationLow = l2;
      SuggestedStopLoss = l2 - stopDist;
      return 1;
   }
   
   // M Pattern
   if(h1 < h2 && h2 > h3 && l3 > l1)
   {
      MainPattern = "M Pattern";
      OperationHigh = h2;
      OperationLow = l1;
      SuggestedStopLoss = h2 + stopDist;
      return -1;
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate signal score                                           |
//+------------------------------------------------------------------+
int CalculateScore(int direction)
{
   int score = 0;
   
   // Pattern score
   if(MainPattern == "N Pattern" || MainPattern == "Inverted N") score += 40;
   if(MainPattern == "W Pattern" || MainPattern == "M Pattern") score += 30;

   // Range score
   double range = OperationHigh - OperationLow;
   if(range > Point * 400) score += 20;
   else if(range > Point * 300) score += 15;
   else if(range > Point * 200) score += 10;

   // D1 trend score
   if(EnableD1TrendFilter)
   {
      double d1sma = iMA(NULL, PERIOD_D1, 200, 0, MODE_SMA, PRICE_CLOSE, 1);
      double d1close = iClose(NULL, PERIOD_D1, 1);
      
      if(direction > 0 && d1close > d1sma) score += 20;
      if(direction < 0 && d1close < d1sma) score += 20;
   }
   
   return score;
}

//+------------------------------------------------------------------+
//| Send notification                                               |
//+------------------------------------------------------------------+
void SendNotification(int direction, int score)
{
   string signal = "";
   if(direction > 0) signal = "BUY Signal";
   else signal = "SELL Signal";
   
   string message = "BingShen SR GBPUSD " + signal + 
                   " | Pattern: " + MainPattern +
                   " | Score: " + IntegerToString(score) +
                   " | Price: " + DoubleToStr(CurrentPrice, 5) +
                   " | Range: " + DoubleToStr(OperationLow, 5) + "-" + DoubleToStr(OperationHigh, 5) +
                   " | Stop: " + DoubleToStr(SuggestedStopLoss, 5);
   
   Print(message);
   SendNotification(message);
}