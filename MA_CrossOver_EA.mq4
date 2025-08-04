//+------------------------------------------------------------------+
//|                                           MA_CrossOver_EA.mq4 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- 輸入參數
input int FastMA_Period = 20;           // 快速移動平均線週期
input int SlowMA_Period = 50;           // 慢速移動平均線週期
input ENUM_MA_METHOD MA_Method = MODE_SMA; // 移動平均線方法
input ENUM_APPLIED_PRICE Applied_Price = PRICE_CLOSE; // 應用價格
input double LotSize = 0.1;             // 交易手數
input int StopLoss = 50;                // 止損點數
input int TakeProfit = 100;             // 止盈點數
input int Magic = 12345;                // 魔術數字
input int Slippage = 3;                 // 滑點

//--- 全局變量
int ticket = 0;
bool buy_opened = false;
bool sell_opened = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("MA交叉策略EA已啟動");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("MA交叉策略EA已停止");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 計算移動平均線
   double fastMA_current = iMA(Symbol(), 0, FastMA_Period, 0, MA_Method, Applied_Price, 0);
   double fastMA_previous = iMA(Symbol(), 0, FastMA_Period, 0, MA_Method, Applied_Price, 1);
   double slowMA_current = iMA(Symbol(), 0, SlowMA_Period, 0, MA_Method, Applied_Price, 0);
   double slowMA_previous = iMA(Symbol(), 0, SlowMA_Period, 0, MA_Method, Applied_Price, 1);
   
   // 檢查是否有未平倉位
   CheckOpenPositions();
   
   // 買入信號：快線從下方穿越慢線
   if(fastMA_previous <= slowMA_previous && fastMA_current > slowMA_current && !buy_opened)
   {
      if(sell_opened)
         CloseAllSellPositions();
      
      OpenBuyPosition();
   }
   
   // 賣出信號：快線從上方穿越慢線
   if(fastMA_previous >= slowMA_previous && fastMA_current < slowMA_current && !sell_opened)
   {
      if(buy_opened)
         CloseAllBuyPositions();
      
      OpenSellPosition();
   }
}

//+------------------------------------------------------------------+
//| 檢查當前未平倉位                                                |
//+------------------------------------------------------------------+
void CheckOpenPositions()
{
   buy_opened = false;
   sell_opened = false;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
         {
            if(OrderType() == OP_BUY)
               buy_opened = true;
            if(OrderType() == OP_SELL)
               sell_opened = true;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 開啟買入倉位                                                    |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double sl = 0, tp = 0;
   
   if(StopLoss > 0)
      sl = Ask - StopLoss * Point;
   
   if(TakeProfit > 0)
      tp = Ask + TakeProfit * Point;
   
   ticket = OrderSend(Symbol(), OP_BUY, LotSize, Ask, Slippage, sl, tp, "MA交叉買入", Magic, 0, clrGreen);
   
   if(ticket > 0)
   {
      Print("買入訂單已開啟，票據號: ", ticket);
      buy_opened = true;
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
   double sl = 0, tp = 0;
   
   if(StopLoss > 0)
      sl = Bid + StopLoss * Point;
   
   if(TakeProfit > 0)
      tp = Bid - TakeProfit * Point;
   
   ticket = OrderSend(Symbol(), OP_SELL, LotSize, Bid, Slippage, sl, tp, "MA交叉賣出", Magic, 0, clrRed);
   
   if(ticket > 0)
   {
      Print("賣出訂單已開啟，票據號: ", ticket);
      sell_opened = true;
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
               Print("買入倉位已關閉，票據號: ", OrderTicket());
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
               Print("賣出倉位已關閉，票據號: ", OrderTicket());
         }
      }
   }
}