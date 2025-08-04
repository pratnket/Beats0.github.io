//+------------------------------------------------------------------+
//|  彬神SR共振手機版 v2.5N-Pro（GBPUSD）                            |
//|  功能：型態判讀 + 快速突破通知 + 雙濾網（SMA300 + D1）         |
//|  加入：操作範圍排序修正、建議止損、評分系統、冷卻與時間管控     |
//+------------------------------------------------------------------+
#property strict

extern bool 啟用時間過濾 = true;
extern int 時間起_UTC = 2;
extern int 時間迄_UTC = 14;

extern int 冷卻秒數 = 600;
extern int 最小區間寬度點數 = 300;

extern bool 啟用D1趨勢過濾 = true;
extern bool 啟用SMA300濾網 = true;
extern int 最低評分門檻 = 80;

datetime 上次通知時間 = 0;
double 上次通知價格 = 0;

string 主型態 = "";
double 操作高, 操作低, 建議止損, 現價;

int OnInit() {
   if (Symbol() != "GBPUSD") {
      Alert("此版本僅限 GBPUSD 使用");
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}

void OnTick() {
   if (!時間允許() || !盤整寬度達標()) return;

   // 使用更精確的價格處理
   現價 = NormalizeDouble(Bid, Digits);
   int 方向 = 判斷方向與型態();

   if (方向 == 0 || !趨勢方向一致(方向)) return;
   if (TimeCurrent() - 上次通知時間 < 冷卻秒數) return;
   
   // 價格變動檢查：至少要有1個點的變動
   double minPriceMove = (Digits == 5) ? Point : Point * 10;
   if (MathAbs(現價 - 上次通知價格) < minPriceMove) return;

   double 主控點 = (方向 > 0) ? 操作高 : 操作低;
   if ((方向 > 0 && 現價 > 主控點) || (方向 < 0 && 現價 < 主控點)) {
      int 評分 = 計算評分(方向);
      if (評分 >= 最低評分門檻) {
         發送通知(方向, 主控點, 評分);
         上次通知時間 = TimeCurrent();
         上次通知價格 = 現價;
      }
   }
}

bool 時間允許() {
   if (!啟用時間過濾) return true;
   int nowHour = TimeHour(TimeCurrent());
   return (nowHour >= 時間起_UTC && nowHour <= 時間迄_UTC);
}

bool 盤整寬度達標() {
   double h = iHigh(NULL, 0, iHighest(NULL, 0, MODE_HIGH, 20, 1));
   double l = iLow(NULL, 0, iLowest(NULL, 0, MODE_LOW, 20, 1));
   
   // 根據broker精度調整最小寬度要求
   double minWidth = (Digits == 5) ? Point * 最小區間寬度點數 : Point * 最小區間寬度點數 * 10;
   return ((h - l) >= minWidth);
}

bool 趨勢方向一致(int 方向) {
   if (!啟用SMA300濾網) return true;
   double sma = iMA(NULL, 0, 300, 0, MODE_SMA, PRICE_CLOSE, 1);
   if (方向 > 0 && 現價 > sma) return true;
   if (方向 < 0 && 現價 < sma) return true;
   return false;
}

int 判斷方向與型態() {
   // 取得更多K線數據以提高準確性
   double h1 = iHigh(NULL, 0, 5);
   double l1 = iLow(NULL, 0, 4);
   double h2 = iHigh(NULL, 0, 3);
   double l2 = iLow(NULL, 0, 2);
   double h3 = iHigh(NULL, 0, 1);
   double l3 = iLow(NULL, 0, 1);

   // 計算適當的止損距離（根據broker精度調整）
   double stopDistance = (Digits == 5) ? 100 * Point : 10 * Point;  // 10 pips

   if (h2 > h1 && l2 > l1 && h3 > h2) {
      主型態 = "N 型";
      操作高 = NormalizeDouble(h2, Digits);
      操作低 = NormalizeDouble(l2, Digits);
      建議止損 = NormalizeDouble(l2 - stopDistance, Digits);
      return 1;
   }
   if (l2 < l1 && h2 < h1 && l3 < l2) {
      主型態 = "倒 N 型";
      操作高 = NormalizeDouble(h2, Digits);
      操作低 = NormalizeDouble(l2, Digits);
      建議止損 = NormalizeDouble(h2 + stopDistance, Digits);
      return -1;
   }
   if (l1 > l2 && l2 < l3 && h3 < h1) {
      主型態 = "W 型";
      操作高 = NormalizeDouble(h1, Digits);
      操作低 = NormalizeDouble(l2, Digits);
      建議止損 = NormalizeDouble(l2 - stopDistance, Digits);
      return 1;
   }
   if (h1 < h2 && h2 > h3 && l3 > l1) {
      主型態 = "M 型";
      操作高 = NormalizeDouble(h2, Digits);
      操作低 = NormalizeDouble(l1, Digits);
      建議止損 = NormalizeDouble(h2 + stopDistance, Digits);
      return -1;
   }
   return 0;
}

int 計算評分(int 方向) {
   int s = 0;
   
   // 型態評分
   if (主型態 == "N 型" || 主型態 == "倒 N 型") s += 40;
   if (主型態 == "W 型" || 主型態 == "M 型") s += 30;

   // 價格區間評分（根據broker精度調整）
   double range = 操作高 - 操作低;
   double pointValue = (Digits == 5) ? Point : Point * 10;
   
   if (range > pointValue * 40) s += 20;      // 40 pips
   else if (range > pointValue * 30) s += 15; // 30 pips
   else if (range > pointValue * 20) s += 10; // 20 pips

   // D1趨勢過濾評分
   if (啟用D1趨勢過濾) {
      int tf = PERIOD_D1;
      double d1sma = iMA(NULL, tf, 200, 0, MODE_SMA, PRICE_CLOSE, 1);
      double d1price = iClose(NULL, tf, 1);
      if ((方向 > 0 && d1price > d1sma) || (方向 < 0 && d1price < d1sma)) s += 20;
   }
   
   // 額外評分：價格動能
   double momentum = iMomentum(NULL, 0, 14, PRICE_CLOSE, 1);
   if ((方向 > 0 && momentum > 100) || (方向 < 0 && momentum < 100)) s += 10;
   
   return s;
}

void 發送通知(int 方向, double 主控點, int 評分) {
   string dir = (方向 > 0) ? "🟢 Buy 訊號成立！" : "🔴 Sell 訊號成立！";
   string tone = (評分 >= 100) ? "強力建議立即進場" : "請謹慎評估進場機會";
   
   // 確保價格顯示精度正確 (GBPUSD通常是5位小數)
   int precision = (Digits == 5) ? 5 : 4;  // 自動判斷broker精度
   
   string msg =
      "【彬神SR v2.5N-Pro GBPUSD】\n" +
      dir + "\n" +
      "型態：" + 主型態 + "\n" +
      "評分：" + IntegerToString(評分) + " / 100\n" +
      "操作區間：" + DoubleToString(操作低, precision) + " ~ " + DoubleToString(操作高, precision) + "\n" +
      "建議止損：" + DoubleToString(建議止損, precision) + "\n" +
      "現價：" + DoubleToString(現價, precision) + " (Bid:" + DoubleToString(Bid, precision) + " Ask:" + DoubleToString(Ask, precision) + ")\n" +
      "商品：GBPUSD\n" +
      "時間：" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n" +
      tone;
   Print(msg);
   SendNotification(msg);
}