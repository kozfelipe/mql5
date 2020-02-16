//+------------------------------------------------------------------+
//|                                               EA_Crossing_MA.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://youtu.be/gY_PHfAOMlY"
#property version   "1.00"

#include <Trade\Trade.mqh>

CTrade         trade;
double         ma_long_buffer[], ma_short_buffer[];
int            ma_long_handler, ma_short_handler;
input int      ma_long_period = 50, ma_short_period = 10;
input double   lot = 0.1;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Print("Início...");

   ma_long_handler = iMA(
                        _Symbol,            // symbol name
                        _Period,            // period
                        ma_long_period,     // averaging period
                        0,                  // horizontal shift
                        MODE_SMA,           // smoothing type
                        PRICE_CLOSE         // type of price or handle
                     );

   ma_short_handler = iMA(
                         _Symbol,            // symbol name
                         _Period,            // period
                         ma_short_period,    // averaging period
                         0,                  // horizontal shift
                         MODE_SMA,           // smoothing type
                         PRICE_CLOSE         // type of price or handle
                      );

   if(ma_long_handler==INVALID_HANDLE || ma_short_handler==INVALID_HANDLE)
     {
      Print("Falha ao carregar manipulador do indicador. (confira o input de período)");
      return(INIT_FAILED);
     }

   if(!ChartIndicatorAdd(ChartID(), (int)ChartGetInteger(0,CHART_WINDOWS_TOTAL), ma_long_handler) ||
      !ChartIndicatorAdd(ChartID(), (int)ChartGetInteger(0,CHART_WINDOWS_TOTAL), ma_short_handler))
      Alert("Falha ao carregar gráfico do indicador: erro ", GetLastError());

   ArraySetAsSeries(ma_long_buffer, true);
   ArraySetAsSeries(ma_short_buffer, true);

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   IndicatorRelease(ma_long_handler);
   IndicatorRelease(ma_short_handler);

   ArrayFree(ma_long_buffer);
   ArrayFree(ma_short_buffer);

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
   bool     buy_closed = false, sell_closed = false;

   if(!SymbolInfoTick(_Symbol, tick))
     {
      Alert("Erro ao carregar tick:", GetLastError());
      return;
     }

   if(!CopyBuffer(ma_long_handler, 0, 0, 3, ma_long_buffer) ||
      !CopyBuffer(ma_short_handler, 0, 0, 3, ma_short_buffer))
     {
      Print("Falha no preenchimento do buffer");
      return;
     }

   for(int i=0; i<PositionsTotal(); i++)
      if(PositionGetSymbol(i) == _Symbol) // closed position
        {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            buy_closed = true;
         else
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
               sell_closed = true;
        }

   if(ma_long_buffer[1] < ma_short_buffer[1] && ma_long_buffer[2] > ma_short_buffer[2])
     {
      if(sell_closed)
        {
         buy(lot*2, 0, 0, 0, "virada de mão");
         return;
        }
      if(buy_closed)
         return;
      buy(lot, 0, 0, 0, "compra a mercado");
     }
   if(ma_long_buffer[1] > ma_short_buffer[1] && ma_long_buffer[2] < ma_short_buffer[2])
     {
      if(buy_closed)
        {
         sell(lot*2, 0, 0, 0, "virada de mão");
         return;
        }
      if(sell_closed)
         return;
      sell(lot, 0, 0, 0, "venda a mercado");
     }

   Comment("ASK: ", tick.ask, "\nBID:", tick.bid, "\nLAST:", tick.last);

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Buy Order                                                        |
//+------------------------------------------------------------------+
void buy(double volume, double price, double _sl, double _tp, string comment)
  {
   Print("Compra");
   trade.Buy(volume, _Symbol, price, _sl, _tp, comment);
  }

//+------------------------------------------------------------------+
//| Sell Order                                                       |
//+------------------------------------------------------------------+
void sell(double volume, double price, double _sl, double _tp, string comment)
  {
   Print("Venda");
   trade.Sell(volume, _Symbol, price, _sl, _tp, comment);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
