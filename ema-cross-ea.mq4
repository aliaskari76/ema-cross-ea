//+------------------------------------------------------------------+
//|                                                 ema-cross-ea.mq4 |
//|                                                       Ali Askari |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property strict

#define MACROSS_MAGIC_NUM 20130715
#define MACROSS_OPEN_BUY_SIGNAL 1
#define MACROSS_OPEN_SELL_SIGNAL -1
#define MACROSS_NO_SIGNAL 0

//--- input parameters
// extern keyword defines parameters that can be set by the user in the
// "Expert properties" dialog.
extern int       ShortMaPeriod = 13;
extern int       LongMaPeriod  = 21;

// These are in fractional pips, which are 0.1 of a pip.
extern int       StopLoss      = 180;
extern int       TakeProfit    = 250;
extern int TrailingOffsetPoints = 100;
extern double risk_percent = 2;
extern double max_lot_size = 1;
extern double InitialLotSize = 0.1;    // Starting position size
extern double Ratio = 2.0;              // Ratio of winning trades to losing trades
extern int Slippage = 3;                // Slippage in pips
extern string Comment = "Fixed Ratio";  // Comment for new orders


//+------------------------------------------------------------------+
//| Get moving average values for the most recent price points.                                                    |
//+------------------------------------------------------------------+
void MaRecentValues(double& ma[], int maPeriod, int numValues = 3)
  {
// i is the index of the price array to calculate the MA value for.
// e.g. i=0 is the current price, i=1 is the previous bar's price.
   for(int i=0; i < numValues; i++)
     {
      ma[i] = iMA(NULL,0,maPeriod,0,MODE_EMA,PRICE_CLOSE,i);
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalcLotSize()
  {
   double balance = AccountBalance();
   double equity = AccountEquity();
   double free_margin = AccountFreeMargin();
   double real_profit = equity - balance;

   double lot_size = NormalizeDouble(balance * risk_percent / 100 / (100 * MarketInfo(Symbol(), MODE_TICKVALUE)), 2);
   if(lot_size > max_lot_size)
      lot_size = max_lot_size;

   if(real_profit < 0)
      lot_size = InitialLotSize;


   printf("lot size is = "+ lot_size);
   return(lot_size);
  }


// Trailing Stop
void TrailingStop(int TrailingOffsetPoints)
  {

// Iterate over all the trades beginning from the last one to prevent reindexing
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {

      // Select trade by its position and check Magic Number
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderMagicNumber() == MACROSS_MAGIC_NUM)
        {

         // Adjust the stoploss if the offset is exceeded
         if((OrderType() == OP_BUY) && (NormPrice(Bid - OrderStopLoss()) > NormPrice(TrailingOffsetPoints * Point))&& (OrderProfit()>5))
           {

            if(!OrderModify(OrderTicket(), OrderOpenPrice(), NormPrice(Bid - TrailingOffsetPoints * Point), OrderTakeProfit(), OrderExpiration(), clrNONE))
              {
               Alert("Cannot modify the SL due to: ", GetLastError());
              }

           }
         else
            if((OrderType() == OP_SELL) && (NormPrice(OrderStopLoss() - Ask) > NormPrice(TrailingOffsetPoints * Point))&&(OrderProfit()>5))
              {

               if(!OrderModify(OrderTicket(), OrderOpenPrice(), NormPrice(Ask + TrailingOffsetPoints * Point), OrderTakeProfit(), OrderExpiration(), clrNONE))
                 {
                  Alert("Cannot modify the SL due to: ", GetLastError());
                 }
              }
        }
     }
  }

// Normalize the Price value
double NormPrice(double Price)
  {
   return NormalizeDouble(Price, Digits);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OpenSignal()
  {
   int signal = MACROSS_NO_SIGNAL;

// Execute only on the first tick of a new bar, to avoid repeatedly
// opening orders when an open condition is satisfied.
   if(Volume[0] > 1)
      return(0);

//---- get Moving Average values

   double shortMa[3];
   MaRecentValues(shortMa, ShortMaPeriod, 3);

   double longMa[3];
   MaRecentValues(longMa, LongMaPeriod, 3);

//---- buy conditions
   if(shortMa[2] < longMa[2]
      && shortMa[1] > longMa[1])
     {
      signal = MACROSS_OPEN_BUY_SIGNAL;
     }

//---- sell conditions
   if(shortMa[2] > longMa[2]
      && shortMa[1] < longMa[1])
     {
      signal = MACROSS_OPEN_SELL_SIGNAL;
     }
   return(signal);
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }

//+------------------------------------------------------------------+
int start()
  {
   double Lotsize = CalcLotSize();
   int signal = OpenSignal();
// Set slippage to a large enough number to avoid error 138 - quote
// outdated.
   int slippage = 30;
   if(signal == MACROSS_OPEN_BUY_SIGNAL)
     {
      Print("Buy signal");
      if(!OrderSend(Symbol(),OP_BUY,Lotsize,Bid,slippage,
                    Bid-StopLoss*Point, // Stop loss price.
                    Bid+TakeProfit*Point, // Take profit price.
                    NULL,MACROSS_MAGIC_NUM,0,Green))
        {
         Print("OrderSend failed with error ", GetLastError());
        }
     }
   else
      if(signal == MACROSS_OPEN_SELL_SIGNAL)
        {
         Print("Sell signal");
         if(!OrderSend(Symbol(),OP_SELL,Lotsize,Ask,slippage,
                       Ask+StopLoss*Point,  // Stop loss price.
                       Ask-TakeProfit*Point, // Take profit price.
                       NULL,MACROSS_MAGIC_NUM,0,Red))
           {
            Print("OrderSend failed with error ", GetLastError());
           }
        }
   return(0);
  }
//+------------------------------------------------------------------+
