//+------------------------------------------------------------------+
//|  BingShen SR Resonance Mobile v2.5N-Pro (GBPUSD)              |
//|  Features: Pattern Recognition + Breakout Alerts + Dual Filter |
//|  Added: Range Sorting, Stop Loss, Scoring System, Cooldown     |
//+------------------------------------------------------------------+
#property strict

// Input Parameters
extern bool EnableTimeFilter = true;
extern int StartHour_UTC = 2;
extern int EndHour_UTC = 14;

extern int CooldownSeconds = 600;
extern int MinRangeWidthPoints = 300;

extern bool EnableD1TrendFilter = true;
extern bool EnableSMA300Filter = true;
extern int MinScoreThreshold = 80;

// Global Variables
datetime LastNotificationTime = 0;
double LastNotificationPrice = 0;

string MainPattern = "";
double OperationHigh, OperationLow, SuggestedStopLoss, CurrentPrice;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   if (Symbol() != "GBPUSD") {
      Alert("This version is for GBPUSD only");
      return(INIT_FAILED);
   }
   Print("BingShen SR v2.5N-Pro initialized for GBPUSD");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   if (!IsTimeAllowed() || !IsRangeWidthSufficient()) return;

   // Use more precise price handling
   CurrentPrice = NormalizeDouble(Bid, Digits);
   int direction = DetermineDirectionAndPattern();

   if (direction == 0 || !IsTrendDirectionConsistent(direction)) return;
   if (TimeCurrent() - LastNotificationTime < CooldownSeconds) return;
   
   // Price movement check: at least 1 point movement required
   double minPriceMove = (Digits == 5) ? Point : Point * 10;
   if (MathAbs(CurrentPrice - LastNotificationPrice) < minPriceMove) return;

   double controlPoint = (direction > 0) ? OperationHigh : OperationLow;
   if ((direction > 0 && CurrentPrice > controlPoint) || (direction < 0 && CurrentPrice < controlPoint)) {
      int score = CalculateScore(direction);
      if (score >= MinScoreThreshold) {
         SendTradeNotification(direction, controlPoint, score);
         LastNotificationTime = TimeCurrent();
         LastNotificationPrice = CurrentPrice;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if current time is within allowed trading hours           |
//+------------------------------------------------------------------+
bool IsTimeAllowed() {
   if (!EnableTimeFilter) return true;
   int nowHour = TimeHour(TimeCurrent());
   return (nowHour >= StartHour_UTC && nowHour <= EndHour_UTC);
}

//+------------------------------------------------------------------+
//| Check if price range is sufficient for trading                  |
//+------------------------------------------------------------------+
bool IsRangeWidthSufficient() {
   double high = iHigh(NULL, 0, iHighest(NULL, 0, MODE_HIGH, 20, 1));
   double low = iLow(NULL, 0, iLowest(NULL, 0, MODE_LOW, 20, 1));
   
   // Adjust minimum width requirement based on broker precision
   double minWidth = (Digits == 5) ? Point * MinRangeWidthPoints : Point * MinRangeWidthPoints * 10;
   return ((high - low) >= minWidth);
}

//+------------------------------------------------------------------+
//| Check if trend direction is consistent with filters             |
//+------------------------------------------------------------------+
bool IsTrendDirectionConsistent(int direction) {
   if (!EnableSMA300Filter) return true;
   double sma = iMA(NULL, 0, 300, 0, MODE_SMA, PRICE_CLOSE, 1);
   if (direction > 0 && CurrentPrice > sma) return true;
   if (direction < 0 && CurrentPrice < sma) return true;
   return false;
}

//+------------------------------------------------------------------+
//| Determine trading direction and pattern type                    |
//+------------------------------------------------------------------+
int DetermineDirectionAndPattern() {
   // Get more candlestick data for better accuracy
   double h1 = iHigh(NULL, 0, 5);
   double l1 = iLow(NULL, 0, 4);
   double h2 = iHigh(NULL, 0, 3);
   double l2 = iLow(NULL, 0, 2);
   double h3 = iHigh(NULL, 0, 1);
   double l3 = iLow(NULL, 0, 1);

   // Calculate appropriate stop loss distance (adjusted for broker precision)
   double stopDistance = (Digits == 5) ? 100 * Point : 10 * Point;  // 10 pips

   // N Pattern (Bullish)
   if (h2 > h1 && l2 > l1 && h3 > h2) {
      MainPattern = "N Pattern";
      OperationHigh = NormalizeDouble(h2, Digits);
      OperationLow = NormalizeDouble(l2, Digits);
      SuggestedStopLoss = NormalizeDouble(l2 - stopDistance, Digits);
      return 1;
   }
   
   // Inverted N Pattern (Bearish)
   if (l2 < l1 && h2 < h1 && l3 < l2) {
      MainPattern = "Inverted N Pattern";
      OperationHigh = NormalizeDouble(h2, Digits);
      OperationLow = NormalizeDouble(l2, Digits);
      SuggestedStopLoss = NormalizeDouble(h2 + stopDistance, Digits);
      return -1;
   }
   
   // W Pattern (Double Bottom)
   if (l1 > l2 && l2 < l3 && h3 < h1) {
      MainPattern = "W Pattern";
      OperationHigh = NormalizeDouble(h1, Digits);
      OperationLow = NormalizeDouble(l2, Digits);
      SuggestedStopLoss = NormalizeDouble(l2 - stopDistance, Digits);
      return 1;
   }
   
   // M Pattern (Double Top)
   if (h1 < h2 && h2 > h3 && l3 > l1) {
      MainPattern = "M Pattern";
      OperationHigh = NormalizeDouble(h2, Digits);
      OperationLow = NormalizeDouble(l1, Digits);
      SuggestedStopLoss = NormalizeDouble(h2 + stopDistance, Digits);
      return -1;
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate trading signal score                                  |
//+------------------------------------------------------------------+
int CalculateScore(int direction) {
   int score = 0;
   
   // Pattern scoring
   if (MainPattern == "N Pattern" || MainPattern == "Inverted N Pattern") score += 40;
   if (MainPattern == "W Pattern" || MainPattern == "M Pattern") score += 30;

   // Price range scoring (adjusted for broker precision)
   double range = OperationHigh - OperationLow;
   double pointValue = (Digits == 5) ? Point : Point * 10;
   
   if (range > pointValue * 40) score += 20;      // 40 pips
   else if (range > pointValue * 30) score += 15; // 30 pips
   else if (range > pointValue * 20) score += 10; // 20 pips

   // D1 trend filter scoring
   if (EnableD1TrendFilter) {
      int tf = PERIOD_D1;
      double d1sma = iMA(NULL, tf, 200, 0, MODE_SMA, PRICE_CLOSE, 1);
      double d1price = iClose(NULL, tf, 1);
      if ((direction > 0 && d1price > d1sma) || (direction < 0 && d1price < d1sma)) score += 20;
   }
   
   // Additional scoring: Price momentum
   double momentum = iMomentum(NULL, 0, 14, PRICE_CLOSE, 1);
   if ((direction > 0 && momentum > 100) || (direction < 0 && momentum < 100)) score += 10;
   
   return score;
}

//+------------------------------------------------------------------+
//| Send trading notification                                       |
//+------------------------------------------------------------------+
void SendTradeNotification(int direction, double controlPoint, int score) {
   string dir = (direction > 0) ? "🟢 BUY Signal Activated!" : "🔴 SELL Signal Activated!";
   string tone = (score >= 100) ? "Strong recommendation to enter immediately" : "Please carefully evaluate entry opportunity";
   
   // Ensure correct price display precision (GBPUSD usually 5 decimals)
   int precision = (Digits == 5) ? 5 : 4;  // Auto-detect broker precision
   
   string msg = StringConcatenate(
      "【BingShen SR v2.5N-Pro GBPUSD】\n",
      dir, "\n",
      "Pattern: ", MainPattern, "\n",
      "Score: ", IntegerToString(score), " / 100\n",
      "Operation Range: ", DoubleToString(OperationLow, precision), " ~ ", DoubleToString(OperationHigh, precision), "\n",
      "Suggested Stop Loss: ", DoubleToString(SuggestedStopLoss, precision), "\n",
      "Current Price: ", DoubleToString(CurrentPrice, precision), " (Bid:", DoubleToString(Bid, precision), " Ask:", DoubleToString(Ask, precision), ")\n",
      "Symbol: GBPUSD\n",
      "Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), "\n",
      tone
   );
   
   Print(msg);
   SendNotification(msg);
}