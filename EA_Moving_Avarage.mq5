//+------------------------------------------------------------------+
//|                                            EA_Moving_Avarage.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

CTrade                     trade;
double                     ma_buffer[];
int                        ma_handler;
input int                  ma_period = 21;
input ENUM_MA_METHOD       ma_method = MODE_SMA;
input ENUM_APPLIED_PRICE   ma_price = PRICE_CLOSE;
input double               lot = 5;

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
                   ma_method,          // smoothing type
                   ma_price            // type of price or handle
                );

   ArraySetAsSeries(ma_buffer, true);

   if(ma_handler==INVALID_HANDLE)
     {
      Print("Falha ao carregar manipulador do indicador. (confira o input de período)");
      return(INIT_FAILED);
     }

   if(!ChartIndicatorAdd(ChartID(), (int)ChartGetInteger(0,CHART_WINDOWS_TOTAL), ma_handler))
      Alert("Falha ao carregar gráfico do indicador: erro ", GetLastError());

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
   bool     buy_close = false, sell_close = false, close = false;

   if(!SymbolInfoTick(_Symbol, tick))
     {
      Alert("Erro ao carregar tick:", GetLastError());
      return;
     }

   if(!CopyBuffer(ma_handler, 0, 0, 3, ma_buffer))
     {
      Alert("Falha no preenchimento do buffer");
      return;
     }

   for(int i=0; i<PositionsTotal(); i++)
      if(PositionGetSymbol(i) == _Symbol) // close position
        {
         close = true;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            buy_close = true;
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
            sell_close = true;
        }

   if(tick.last > ma_buffer[0] && !close)
     {
      simple_trade(
         buy,
         lot,
         tick.ask,
         tick.ask - 5,
         tick.ask + 5,
         "compra"
      );
     }
   if(tick.last < ma_buffer[0] && !close)
     {
      simple_trade(
         sell,
         lot,
         tick.bid,
         tick.bid + 5,
         tick.bid - 5,
         "venda"
      );
     }

   Comment("ASK: ", tick.ask, "\nBID:", tick.bid, "\nLAST:", tick.last);

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Simple Trade                                                     |
//+------------------------------------------------------------------+
enum trade_mode {buy, sell};
void simple_trade(trade_mode mode, double volume, double price, double _sl, double _tp, string comment)
  {
   switch(mode)
     {
      case buy:
         if(trade.Buy(volume, _Symbol, price, _sl, _tp, comment))
            Print("Ordem de Compra: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         break;
      case sell:
         if(trade.Sell(volume, _Symbol, price, _sl, _tp, comment))
            Print("Ordem de Venda: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         break;
     }

  }
//+------------------------------------------------------------------+
