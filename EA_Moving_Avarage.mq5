//+------------------------------------------------------------------+
//|                                            EA_Moving_Avarage.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://github.com/guilhermetabordaribas/MQL5"
#property version   "1.00"

#include <Trade\Trade.mqh>

input double                  lot = 5, stoploss = 5, takeprofit = 5;
input int                     ma_period = 21;
input ENUM_MA_METHOD          ma_method = MODE_SMA;
input ENUM_APPLIED_PRICE      ma_price = PRICE_CLOSE;
input ulong                   magic = 123, deviation = 50;
input ENUM_ORDER_TYPE_FILLING filling = ORDER_FILLING_RETURN;
double                        ma_buffer[], trade_price, trade_sl, trade_tp;
int                           ma_handler;
enum                          trade_mode {buy, sell};
MqlTick                       tick;
MqlRates                      rates[];
CTrade                        trade;

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

   if(ma_handler==INVALID_HANDLE)
     {
      Print("Falha ao carregar manipulador do indicador. (confira o input de período)");
      return(INIT_FAILED);
     }

   if(!ChartIndicatorAdd(ChartID(), (int)ChartGetInteger(0,CHART_WINDOWS_TOTAL), ma_handler))
      Alert("Falha ao carregar gráfico do indicador: erro ", GetLastError());

   trade.SetExpertMagicNumber(magic);
   trade.SetTypeFilling(filling);
   trade.SetDeviationInPoints(deviation);

   ArraySetAsSeries(ma_buffer, true);
   ArraySetAsSeries(rates, true);

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
   ArrayFree(rates);

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
   bool buy_open = false, sell_open = false, position_open = false, order_pending = false;

   for(int i=0; i<PositionsTotal(); i++) // status da posição
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magic)
        {
         position_open = true;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            buy_open = true;
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
            sell_open = true;
         break;
        }

   for(int i=0; i<OrdersTotal(); i++) // ordem pendente
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == magic)
        {
         order_pending = true;
         break;
        }

   if(!CopyBuffer(ma_handler, 0, 0, 3, ma_buffer)) // atualiza indicador
     {
      Alert("Falha no preenchimento do buffer");
      return;
     }

   if(!SymbolInfoTick(_Symbol, tick)) // atualiza tick
     {
      Alert("Erro ao carregar tick: ", GetLastError());
      return;
     }

   if(CopyRates(_Symbol, _Period, 0, 3, rates) < 0) // atualiza rates
     {
      Alert("Falha na dedução das taxas: ", GetLastError());
      return;
     }

   if(tick.last > ma_buffer[0] && // acima da MA
      rates[1].close > rates[1].open && // candle anterior de alta
      !position_open && // posição fechada
      !order_pending) // sem ordem pendente
     {
      trade_price = NormalizeDouble(tick.ask, _Digits);
      trade_sl = NormalizeDouble(trade_price - stoploss, _Digits);
      trade_tp = NormalizeDouble(trade_price + takeprofit, _Digits);
      simple_trade(
         buy,
         lot,
         trade_price,
         trade_sl,
         trade_tp,
         "compra"
      );
     }
   if(tick.last < ma_buffer[0] && // abaixo da MA
      rates[1].close < rates[1].open && // candle anterior de baixa
      !position_open && // posição fechada
      !order_pending) // sem ordem pendente
     {
      trade_price = NormalizeDouble(tick.bid, _Digits);
      trade_sl = NormalizeDouble(trade_price + stoploss, _Digits);
      trade_tp = NormalizeDouble(trade_price - takeprofit, _Digits);
      simple_trade(
         sell,
         lot,
         trade_price,
         trade_sl,
         trade_tp,
         "venda"
      );
     }

   Comment("ASK: ", tick.ask, "\nBID:", tick.bid, "\nLAST:", tick.last);

  }

//+------------------------------------------------------------------+
//| Simple Trade                                                     |
//+------------------------------------------------------------------+
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
      default:
         Print("Modo Desconhecido");
         break;
     }
  }
//+------------------------------------------------------------------+
