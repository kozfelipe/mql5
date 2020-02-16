//+------------------------------------------------------------------+
//|                                            EA_Moving_Avarage.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

CTrade         trade;
double         ma_buffer[], close_buffer[], sl, tp;
int            ma_handler, factor = 10;
input int      ma_period = 21;
input double   stoploss = 30, takeprofit = 100, lot = 0.1;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Print("Início...");
   
   ma_handler = iMA(
                   _Symbol,            // symbol name
                   _Period,            // period
                   ma_period,          // averaging period
                   0,                  // horizontal shift
                   MODE_SMA,           // smoothing type
                   PRICE_CLOSE         // type of price or handle
                );
                
   ArraySetAsSeries(ma_buffer, true);
   ArraySetAsSeries(close_buffer,true); 
                
   if(ma_handler==INVALID_HANDLE)
     {
      Print("Falha ao carregar manipulador do indicador. (confira o input de período)");
      return(INIT_FAILED);
     }
     
   if(!ChartIndicatorAdd(ChartID(), (int)ChartGetInteger(0,CHART_WINDOWS_TOTAL), ma_handler))
      Alert("Falha ao carregar gráfico do indicador: erro ", GetLastError());
      
   sl = stoploss;
   tp = takeprofit;
   
   if(_Digits == 5 || _Digits == 3)
     {
      sl = sl * factor;
      tp = tp * factor;
     }

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   IndicatorRelease(ma_handler);
   ArrayFree(ma_buffer);
   ArrayFree(close_buffer);  

   switch(reason)
     {
      case 0:
         Alert("ATENÇÃO: Motivo de remoção: O Expert Advisor terminou sua operação chamando a função ExpertRemove().");
         break;
      case 1:
         Alert("ATENÇÃO: Motivo de remoção: O robo foi excluído do gráfico.");
         break;
      case 2:
         Alert("ATENÇÃO: Motivo de remoção: O robo foi recompilado.");
         break;
      case 3:
         Alert("ATENÇÃO: Motivo de remoção: O período do símbolo ou gráfico foi alterado.");;
         break;
      case 4:
         Alert("ATENÇÃO: Motivo de remoção: O gráfico foi encerrado.");
         break;
      case 5:
         Alert("ATENÇÃO: Motivo de remoção: Os parâmetros de entrada foram alterados pelo usuário.");
         break;
      case 6:
         Alert("ATENÇÃO: Motivo de remoção: Outra conta foi ativada ou o servidor de negociação foi reconectado devido a alterações nas configurações de conta.");
         break;
      case 7:
         Alert("ATENÇÃO: Motivo de remoção: Um novo modelo foi aplicado.");
         break;
      case 8:
         Alert("ATENÇÃO: Motivo de remoção: O manipulador OnInit() retornou um valor diferente de zero.");
         break;
      case 9:
         Alert("ATENÇÃO: Motivo de remoção: Terminal foi fechado.");
         break;
     }
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   MqlTick  tick;
   bool     buy_open = false, sell_open = false;

   if(!SymbolInfoTick(_Symbol, tick))
     {
      Alert("Erro ao carregar tick:", GetLastError());
      return;
     }

   if(!CopyBuffer(ma_handler, 0, 0, 3, ma_buffer) || !CopyClose(_Symbol, _Period, 1, 2, close_buffer))
     {
      Print("Falha no preenchimento do buffer");
      return;
     }

   for(int i=0;i<PositionsTotal();i++)
      if(PositionGetSymbol(i) == _Symbol) // open position
        {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            buy_open = true;
         else
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
               sell_open = true;
        }

   if(ma_buffer[1] > close_buffer[1] && ma_buffer[0] < close_buffer[0])
     {
      if(sell_open)
         trade.PositionClose(_Symbol);
      if(buy_open)
         return;
      buy(
         lot,
         NormalizeDouble(tick.bid, _Digits),
         NormalizeDouble(tick.bid - sl * _Point, _Digits),
         NormalizeDouble(tick.bid + tp * _Point, _Digits)
      );
     }
    if(ma_buffer[1] < close_buffer[1] && ma_buffer[0] > close_buffer[0])
     {
      if(buy_open)
         trade.PositionClose(_Symbol);
      if(sell_open)
         return;
      sell(
         lot,
         NormalizeDouble(tick.bid, _Digits),
         NormalizeDouble(tick.bid + sl * _Point, _Digits),
         NormalizeDouble(tick.bid - tp * _Point, _Digits)
      );
     }

   Comment("ASK: ", tick.ask, "\nBID:", tick.bid, "\nLAST:", tick.last);

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Buy Order                                                        |
//+------------------------------------------------------------------+
void buy(double volume, double price, double _sl, double _tp)
  {
   Print("Compra");
   trade.Buy(volume, _Symbol, price, _sl, _tp, "compra");
  }

//+------------------------------------------------------------------+
//| Sell Order                                                       |
//+------------------------------------------------------------------+
void sell(double volume, double price, double _sl, double _tp)
  {
   Print("Venda");
   trade.Sell(volume, _Symbol, price, _sl, _tp, "venda");
  }
//+------------------------------------------------------------------+
