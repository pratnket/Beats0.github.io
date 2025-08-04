//+------------------------------------------------------------------+
//|                                            Grid_Trading_EA.mq4 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- 輸入參數
input group "=== 網格設定 ==="
input double GridStep = 20.0;           // 網格間距(點數)
input int MaxGridLevels = 10;           // 最大網格層數
input double LotSize = 0.1;             // 基礎手數
input double LotMultiplier = 1.5;      // 手數倍數
input double GridStart = 0;             // 網格起始價格(0=當前價格)

input group "=== 風險管理 ==="
input double MaxDrawdownPercent = 20.0; // 最大回撤百分比
input double TakeProfitPips = 30.0;     // 止盈點數
input bool UseBreakEven = true;         // 使用保本
input double BreakEvenPips = 20.0;      // 保本點數
input double MaxLossPerDay = 100.0;     // 每日最大虧損

input group "=== 交易時間 ==="
input bool UseTimeFilter = false;       // 使用時間過濾
input int StartHour = 0;                // 開始時間
input int EndHour = 23;                 // 結束時間
input bool TradeSunday = false;         // 週日交易
input bool TradeMonday = true;          // 週一交易
input bool TradeTuesday = true;         // 週二交易
input bool TradeWednesday = true;       // 週三交易
input bool TradeThursday = true;        // 週四交易
input bool TradeFriday = true;          // 週五交易
input bool TradeSaturday = false;       // 週六交易

input group "=== 其他設定 ==="
input int Magic = 12345;                // 魔術數字
input int Slippage = 3;                 // 滑點
input string EA_Comment = "Grid Trading"; // EA註釋

//--- 全局變量
struct GridLevel
{
   double price;
   int ticket;
   double lots;
   bool active;
};

GridLevel buyLevels[50];
GridLevel sellLevels[50];
int buyLevelCount = 0;
int sellLevelCount = 0;
double startPrice = 0;
double dailyStartBalance = 0;
bool dailyLossReached = false;
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("網格交易EA已啟動");
   
   // 初始化起始價格
   if(GridStart == 0)
      startPrice = (Ask + Bid) / 2;
   else
      startPrice = GridStart;
   
   // 初始化每日餘額
   dailyStartBalance = AccountBalance();
   
   // 初始化網格
   InitializeGrid();
   
   Print("網格起始價格: ", DoubleToStr(startPrice, Digits));
   Print("網格間距: ", GridStep, " 點");
   Print("最大網格層數: ", MaxGridLevels);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("網格交易EA已停止");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 檢查每日重置
   CheckDailyReset();
   
   // 檢查最大回撤
   if(CheckMaxDrawdown())
   {
      CloseAllPositions();
      return;
   }
   
   // 檢查交易時間
   if(!IsTimeToTrade())
      return;
   
   // 檢查每日虧損限制
   if(dailyLossReached)
      return;
   
   // 檢查網格
   if(lastBarTime != Time[0])
   {
      lastBarTime = Time[0];
      CheckGridLevels();
   }
   
   // 處理保本
   if(UseBreakEven)
      HandleBreakEven();
   
   // 顯示信息
   DisplayInfo();
}

//+------------------------------------------------------------------+
//| 初始化網格                                                      |
//+------------------------------------------------------------------+
void InitializeGrid()
{
   // 清空網格
   ArrayInitialize(buyLevels, 0);
   ArrayInitialize(sellLevels, 0);
   buyLevelCount = 0;
   sellLevelCount = 0;
   
   // 設置買入網格
   for(int i = 0; i < MaxGridLevels; i++)
   {
      buyLevels[i].price = startPrice - (i + 1) * GridStep * Point;
      buyLevels[i].lots = LotSize * MathPow(LotMultiplier, i);
      buyLevels[i].active = true;
      buyLevels[i].ticket = 0;
      buyLevelCount++;
   }
   
   // 設置賣出網格
   for(int i = 0; i < MaxGridLevels; i++)
   {
      sellLevels[i].price = startPrice + (i + 1) * GridStep * Point;
      sellLevels[i].lots = LotSize * MathPow(LotMultiplier, i);
      sellLevels[i].active = true;
      sellLevels[i].ticket = 0;
      sellLevelCount++;
   }
}

//+------------------------------------------------------------------+
//| 檢查網格層級                                                    |
//+------------------------------------------------------------------+
void CheckGridLevels()
{
   double currentPrice = (Ask + Bid) / 2;
   
   // 檢查買入網格
   for(int i = 0; i < buyLevelCount; i++)
   {
      if(buyLevels[i].active && buyLevels[i].ticket == 0)
      {
         if(currentPrice <= buyLevels[i].price)
         {
            OpenGridOrder(OP_BUY, i, true);
         }
      }
   }
   
   // 檢查賣出網格
   for(int i = 0; i < sellLevelCount; i++)
   {
      if(sellLevels[i].active && sellLevels[i].ticket == 0)
      {
         if(currentPrice >= sellLevels[i].price)
         {
            OpenGridOrder(OP_SELL, i, false);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 開啟網格訂單                                                    |
//+------------------------------------------------------------------+
void OpenGridOrder(int orderType, int levelIndex, bool isBuyGrid)
{
   double price, sl = 0, tp = 0;
   double lots;
   color orderColor;
   string comment;
   
   if(isBuyGrid)
   {
      price = Ask;
      lots = buyLevels[levelIndex].lots;
      if(TakeProfitPips > 0)
         tp = price + TakeProfitPips * Point;
      orderColor = clrGreen;
      comment = EA_Comment + " Buy Grid " + IntegerToString(levelIndex);
   }
   else
   {
      price = Bid;
      lots = sellLevels[levelIndex].lots;
      if(TakeProfitPips > 0)
         tp = price - TakeProfitPips * Point;
      orderColor = clrRed;
      comment = EA_Comment + " Sell Grid " + IntegerToString(levelIndex);
   }
   
   // 規範化手數
   lots = NormalizeLots(lots);
   
   int ticket = OrderSend(Symbol(), orderType, lots, price, Slippage, sl, tp, comment, Magic, 0, orderColor);
   
   if(ticket > 0)
   {
      if(isBuyGrid)
      {
         buyLevels[levelIndex].ticket = ticket;
         Print("買入網格訂單已開啟，層級: ", levelIndex, "，價格: ", DoubleToStr(price, Digits), "，手數: ", lots);
      }
      else
      {
         sellLevels[levelIndex].ticket = ticket;
         Print("賣出網格訂單已開啟，層級: ", levelIndex, "，價格: ", DoubleToStr(price, Digits), "，手數: ", lots);
      }
   }
   else
   {
      Print("網格訂單失敗，錯誤代碼: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| 規範化手數                                                      |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   
   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);
   lots = NormalizeDouble(lots / lotStep, 0) * lotStep;
   
   return lots;
}

//+------------------------------------------------------------------+
//| 檢查最大回撤                                                    |
//+------------------------------------------------------------------+
bool CheckMaxDrawdown()
{
   double balance = AccountBalance();
   double equity = AccountEquity();
   double drawdown = (balance - equity) / balance * 100;
   
   if(drawdown >= MaxDrawdownPercent)
   {
      Alert("已達到最大回撤限制：", DoubleToStr(drawdown, 2), "%");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 檢查每日重置                                                    |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   static int lastDay = -1;
   int currentDay = Day();
   
   if(lastDay != currentDay)
   {
      lastDay = currentDay;
      dailyStartBalance = AccountBalance();
      dailyLossReached = false;
      Print("每日重置完成，新的一天開始");
   }
   
   // 檢查每日虧損
   double dailyPL = AccountBalance() - dailyStartBalance;
   if(dailyPL <= -MaxLossPerDay)
   {
      if(!dailyLossReached)
      {
         dailyLossReached = true;
         Alert("已達到每日最大虧損限制：", DoubleToStr(-dailyPL, 2));
      }
   }
}

//+------------------------------------------------------------------+
//| 處理保本                                                        |
//+------------------------------------------------------------------+
void HandleBreakEven()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
         {
            double openPrice = OrderOpenPrice();
            double currentSL = OrderStopLoss();
            
            if(OrderType() == OP_BUY)
            {
               if(Bid >= openPrice + BreakEvenPips * Point && (currentSL < openPrice || currentSL == 0))
               {
                  bool result = OrderModify(OrderTicket(), openPrice, openPrice, OrderTakeProfit(), 0, clrBlue);
                  if(result)
                     Print("買入訂單保本設置完成，票據號: ", OrderTicket());
               }
            }
            else if(OrderType() == OP_SELL)
            {
               if(Ask <= openPrice - BreakEvenPips * Point && (currentSL > openPrice || currentSL == 0))
               {
                  bool result = OrderModify(OrderTicket(), openPrice, openPrice, OrderTakeProfit(), 0, clrBlue);
                  if(result)
                     Print("賣出訂單保本設置完成，票據號: ", OrderTicket());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 關閉所有倉位                                                    |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
         {
            if(OrderType() == OP_BUY)
            {
               OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrBlue);
            }
            else if(OrderType() == OP_SELL)
            {
               OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrBlue);
            }
         }
      }
   }
   
   // 重置網格票據號
   for(int i = 0; i < buyLevelCount; i++)
      buyLevels[i].ticket = 0;
   
   for(int i = 0; i < sellLevelCount; i++)
      sellLevels[i].ticket = 0;
}

//+------------------------------------------------------------------+
//| 檢查是否在交易時間內                                            |
//+------------------------------------------------------------------+
bool IsTimeToTrade()
{
   if(!UseTimeFilter)
      return true;
   
   int currentHour = Hour();
   int dayOfWeek = DayOfWeek();
   
   // 檢查時間
   if(currentHour < StartHour || currentHour > EndHour)
      return false;
   
   // 檢查星期
   switch(dayOfWeek)
   {
      case 0: return TradeSunday;
      case 1: return TradeMonday;
      case 2: return TradeTuesday;
      case 3: return TradeWednesday;
      case 4: return TradeThursday;
      case 5: return TradeFriday;
      case 6: return TradeSaturday;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| 計算總盈虧                                                      |
//+------------------------------------------------------------------+
double CalculateTotalProfit()
{
   double totalProfit = 0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
         {
            totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
//| 顯示信息                                                        |
//+------------------------------------------------------------------+
void DisplayInfo()
{
   int totalOrders = 0;
   double totalProfit = CalculateTotalProfit();
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
            totalOrders++;
      }
   }
   
   double dailyPL = AccountBalance() - dailyStartBalance;
   double currentPrice = (Ask + Bid) / 2;
   
   string info = StringConcatenate(
      "\n=== 網格交易EA ===",
      "\n當前價格: ", DoubleToStr(currentPrice, Digits),
      "\n網格起始: ", DoubleToStr(startPrice, Digits),
      "\n開倉數量: ", totalOrders,
      "\n總浮動盈虧: ", DoubleToStr(totalProfit, 2),
      "\n今日盈虧: ", DoubleToStr(dailyPL, 2),
      "\n賬戶餘額: ", DoubleToStr(AccountBalance(), 2),
      "\n賬戶淨值: ", DoubleToStr(AccountEquity(), 2),
      "\n每日限制: ", (dailyLossReached ? "已達到" : "正常")
   );
   
   Comment(info);
}