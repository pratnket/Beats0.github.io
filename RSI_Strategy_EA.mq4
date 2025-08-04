//+------------------------------------------------------------------+
//|                                              RSI_Strategy_EA.mq4 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- 輸入參數
input group "=== RSI 設定 ==="
input int RSI_Period = 14;              // RSI週期
input ENUM_APPLIED_PRICE RSI_Price = PRICE_CLOSE; // RSI應用價格
input double RSI_Overbought = 70.0;     // RSI超買水平
input double RSI_Oversold = 30.0;       // RSI超賣水平

input group "=== 交易設定 ==="
input double LotSize = 0.1;             // 交易手數
input bool UseAutoLot = false;          // 使用自動手數
input double RiskPercent = 2.0;         // 風險百分比(當UseAutoLot=true時)
input int StopLoss = 50;                // 止損點數
input int TakeProfit = 100;             // 止盈點數
input bool UseTrailingStop = true;      // 使用移動止損
input int TrailingStop = 30;            // 移動止損點數
input int TrailingStep = 10;            // 移動止損步長

input group "=== 時間設定 ==="
input bool UseTimeFilter = false;       // 使用時間過濾
input int StartHour = 8;                // 開始交易時間(小時)
input int EndHour = 18;                 // 結束交易時間(小時)

input group "=== 其他設定 ==="
input int Magic = 12345;                // 魔術數字
input int Slippage = 3;                 // 滑點
input int MaxTrades = 1;                // 最大同時交易數
input string EA_Comment = "RSI Strategy"; // EA註釋

//--- 全局變量
int buy_ticket = 0;
int sell_ticket = 0;
datetime lastBarTime = 0;
double currentRSI = 0;
double previousRSI = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("RSI策略EA已啟動");
   Print("RSI週期: ", RSI_Period);
   Print("超買水平: ", RSI_Overbought);
   Print("超賣水平: ", RSI_Oversold);
   Print("交易手數: ", LotSize);
   
   // 檢查參數有效性
   if(RSI_Overbought <= RSI_Oversold)
   {
      Alert("錯誤：RSI超買水平必須大於超賣水平！");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(LotSize <= 0)
   {
      Alert("錯誤：交易手數必須大於0！");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("RSI策略EA已停止，原因代碼: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 檢查是否是新K線
   if(lastBarTime != Time[0])
   {
      lastBarTime = Time[0];
      
      // 更新RSI值
      currentRSI = iRSI(Symbol(), 0, RSI_Period, RSI_Price, 0);
      previousRSI = iRSI(Symbol(), 0, RSI_Period, RSI_Price, 1);
      
      // 檢查時間過濾
      if(!IsTimeToTrade())
         return;
      
      // 執行交易邏輯
      CheckTradingSignals();
   }
   
   // 處理移動止損
   if(UseTrailingStop)
   {
      HandleTrailingStop();
   }
   
   // 顯示信息
   DisplayInfo();
}

//+------------------------------------------------------------------+
//| 檢查交易信號                                                    |
//+------------------------------------------------------------------+
void CheckTradingSignals()
{
   int openTrades = CountOpenTrades();
   
   // 如果已達到最大交易數，不開新倉
   if(openTrades >= MaxTrades)
      return;
   
   // 買入信號：RSI從超賣區域向上突破
   if(previousRSI <= RSI_Oversold && currentRSI > RSI_Oversold)
   {
      // 關閉可能的賣出倉位
      CloseAllSellPositions();
      
      // 開啟買入倉位
      OpenBuyPosition();
      Print("RSI買入信號：RSI從 ", DoubleToStr(previousRSI, 2), " 上升到 ", DoubleToStr(currentRSI, 2));
   }
   
   // 賣出信號：RSI從超買區域向下突破
   if(previousRSI >= RSI_Overbought && currentRSI < RSI_Overbought)
   {
      // 關閉可能的買入倉位
      CloseAllBuyPositions();
      
      // 開啟賣出倉位
      OpenSellPosition();
      Print("RSI賣出信號：RSI從 ", DoubleToStr(previousRSI, 2), " 下降到 ", DoubleToStr(currentRSI, 2));
   }
}

//+------------------------------------------------------------------+
//| 計算手數                                                        |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   if(!UseAutoLot)
      return LotSize;
   
   double balance = AccountBalance();
   double riskAmount = balance * RiskPercent / 100.0;
   double pointValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double lots = riskAmount / (StopLoss * pointValue);
   
   // 規範化手數
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   
   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);
   lots = NormalizeDouble(lots / lotStep, 0) * lotStep;
   
   return lots;
}

//+------------------------------------------------------------------+
//| 開啟買入倉位                                                    |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double lots = CalculateLotSize();
   double sl = 0, tp = 0;
   
   if(StopLoss > 0)
      sl = Ask - StopLoss * Point;
   
   if(TakeProfit > 0)
      tp = Ask + TakeProfit * Point;
   
   buy_ticket = OrderSend(Symbol(), OP_BUY, lots, Ask, Slippage, sl, tp, EA_Comment + " Buy", Magic, 0, clrGreen);
   
   if(buy_ticket > 0)
   {
      Print("買入訂單已開啟，票據號: ", buy_ticket, "，手數: ", lots, "，RSI: ", DoubleToStr(currentRSI, 2));
   }
   else
   {
      Print("買入訂單失敗，錯誤代碼: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| 開啟賣出倉位                                                    |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
   double lots = CalculateLotSize();
   double sl = 0, tp = 0;
   
   if(StopLoss > 0)
      sl = Bid + StopLoss * Point;
   
   if(TakeProfit > 0)
      tp = Bid - TakeProfit * Point;
   
   sell_ticket = OrderSend(Symbol(), OP_SELL, lots, Bid, Slippage, sl, tp, EA_Comment + " Sell", Magic, 0, clrRed);
   
   if(sell_ticket > 0)
   {
      Print("賣出訂單已開啟，票據號: ", sell_ticket, "，手數: ", lots, "，RSI: ", DoubleToStr(currentRSI, 2));
   }
   else
   {
      Print("賣出訂單失敗，錯誤代碼: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| 關閉所有買入倉位                                                |
//+------------------------------------------------------------------+
void CloseAllBuyPositions()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic && OrderType() == OP_BUY)
         {
            bool result = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrBlue);
            if(result)
               Print("買入倉位已關閉，票據號: ", OrderTicket(), "，盈虧: ", DoubleToStr(OrderProfit(), 2));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 關閉所有賣出倉位                                                |
//+------------------------------------------------------------------+
void CloseAllSellPositions()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic && OrderType() == OP_SELL)
         {
            bool result = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrBlue);
            if(result)
               Print("賣出倉位已關閉，票據號: ", OrderTicket(), "，盈虧: ", DoubleToStr(OrderProfit(), 2));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 計算當前開倉數量                                                |
//+------------------------------------------------------------------+
int CountOpenTrades()
{
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| 處理移動止損                                                    |
//+------------------------------------------------------------------+
void HandleTrailingStop()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
         {
            if(OrderType() == OP_BUY)
            {
               double newSL = Bid - TrailingStop * Point;
               if(newSL > OrderStopLoss() + TrailingStep * Point)
               {
                  bool result = OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrBlue);
                  if(result)
                     Print("買入倉位移動止損已更新，新止損: ", DoubleToStr(newSL, Digits));
               }
            }
            else if(OrderType() == OP_SELL)
            {
               double newSL = Ask + TrailingStop * Point;
               if(newSL < OrderStopLoss() - TrailingStep * Point || OrderStopLoss() == 0)
               {
                  bool result = OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrBlue);
                  if(result)
                     Print("賣出倉位移動止損已更新，新止損: ", DoubleToStr(newSL, Digits));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 檢查是否在交易時間內                                            |
//+------------------------------------------------------------------+
bool IsTimeToTrade()
{
   if(!UseTimeFilter)
      return true;
   
   int currentHour = Hour();
   
   if(StartHour <= EndHour)
   {
      return (currentHour >= StartHour && currentHour < EndHour);
   }
   else
   {
      return (currentHour >= StartHour || currentHour < EndHour);
   }
}

//+------------------------------------------------------------------+
//| 顯示信息                                                        |
//+------------------------------------------------------------------+
void DisplayInfo()
{
   string info = StringConcatenate(
      "\n=== RSI策略EA ===",
      "\n當前RSI: ", DoubleToStr(currentRSI, 2),
      "\n開倉數量: ", CountOpenTrades(),
      "\n賬戶餘額: ", DoubleToStr(AccountBalance(), 2),
      "\n賬戶淨值: ", DoubleToStr(AccountEquity(), 2),
      "\n浮動盈虧: ", DoubleToStr(AccountProfit(), 2)
   );
   
   Comment(info);
}