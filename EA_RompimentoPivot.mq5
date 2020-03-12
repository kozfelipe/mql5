//+------------------------------------------------------------------+
//|                                           EA_RompimentoPivot.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

MqlTick                       tick;
MqlRates                      rates[];
MqlDateTime                   date;
CTrade                        trade;

double                        rsi_buffer[], atr_buffer[], bb_upper_buffer[], bb_lower_buffer[];
int                           rsi_handler, atr_handler, bb_handler, signal_timer = 0;

input string                  secao0 = "############################"; //### Definições Básicas ###
input ulong                   magic_number = 1; // magic number
input ulong                   deviation = 50; // desvio
input ENUM_ORDER_TYPE_FILLING filling = ORDER_FILLING_RETURN; // preenchimento
input int                     fixo_tp = 20; // TP fixo
input int                     fixo_sl = 5; // SL fixo

input string                  secao1 = "############################"; //### Horário de Operação ###
enum                          ENUM_DATE {ENABLED, DISABLED};
input ENUM_DATE               datetime_mode = DISABLED; // ativar horário personalizado
input int                     datetime_start_hour = 10; // hora de inicio de abertura de posições
input int                     datetime_start_min = 30; // minuto de inicio de abertura de posições
input int                     datetime_stop_hour = 16; // hora de encerramento de abertura de posições
input int                     datetime_stop_min = 45; // minuto de encerramento de abertura de posições
input int                     datetime_close_hour = 17; // hora de inicio de fechamento de posições
input int                     datetime_close_min = 20; // minuto de inicio de fechamento de posições

input string                  secao2 = "############################"; //### Indicadores ###
input int                     rsi_period = 14; // RSI - período
input ENUM_APPLIED_PRICE      rsi_price = PRICE_CLOSE; // RSI - tipo de preço
input double                  rsi_level_min = 30; // RSI - banda mínima
input double                  rsi_level_max = 70; // RSI - banda máxima

input int                     atr_period = 14; // ATR - período
input double                  atr_fator_opening; // ATR - fator de abertura
input double                  atr_fator_tp; // ATR - fator TP
input double                  atr_fator_sl; // ATR - fator SL

input int                     bb_period = 21; // Bolinger - período
input ENUM_APPLIED_PRICE      bb_price = PRICE_CLOSE; // Bolinger - tipo de preço
input int                     bb_shift = 0; // Bolinger - deslocamento
input double                  bb_deviation = 2; // Bolinger - desvios padrão

input string                  secao3 = "############################"; //### Trailing Stop ###
enum                          ENUM_TS {USER_DEFINED, FIXED, NONE};
input ENUM_TS                 ts_mode = NONE; // TS - modo
input int                     ts_steps = 2; // TS - barras
input int                     ts_period = 6; // TS - período

input string                  secao4 = "############################"; //### Estratégia ###
input int                     ticks_de_entrada; // ticks de entrada
input int                     qtd_candles_seguidos; // candles seguidos
input int                     corpo_percent; // percentual tamanho do candle
input int                     duracao_sinal; // segundos de duração do sinal

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Print("Início...");

   rsi_handler = iRSI(
                    _Symbol,            // symbol name
                    _Period,            // period
                    rsi_period,         // averaging period
                    rsi_price           // type of price or handle
                 );

   atr_handler = iATR(
                    _Symbol,            // symbol name
                    _Period,            // period
                    rsi_period          // averaging period
                 );

   bb_handler = iBands(
                   _Symbol,       // symbol name
                   _Period,       // period
                   bb_period,     // averaging period
                   bb_shift,      // band shift
                   bb_deviation,  // deviation
                   bb_price       // type of price or handle
                );

   if(rsi_handler == INVALID_HANDLE || atr_handler == INVALID_HANDLE || bb_handler == INVALID_HANDLE)
     {
      Alert("Falha ao carregar manipulador do indicador. (confira os inputs)");
      return(INIT_FAILED);
     }

   ChartIndicatorAdd(ChartID(), (int)ChartGetInteger(0,CHART_WINDOWS_TOTAL), rsi_handler);
   ChartIndicatorAdd(ChartID(), (int)ChartGetInteger(0,CHART_WINDOWS_TOTAL), atr_handler);
   ChartIndicatorAdd(ChartID(), (int)ChartGetInteger(0,CHART_WINDOWS_TOTAL), bb_handler);

   ArraySetAsSeries(rsi_buffer, true);
   ArraySetAsSeries(atr_buffer, true);
   ArraySetAsSeries(bb_upper_buffer, true);
   ArraySetAsSeries(bb_lower_buffer, true);
   ArraySetAsSeries(rates, true);

   trade.SetExpertMagicNumber(magic_number);
   trade.SetDeviationInPoints(deviation);
   trade.SetTypeFilling(filling);

   if(datetime_start_hour > datetime_stop_hour || datetime_stop_hour > datetime_close_hour)
     {
      Alert("Inconsistência de Horários de Negociação!");
      return(INIT_FAILED);
     }
   if(datetime_start_hour == datetime_stop_hour && datetime_start_min >= datetime_stop_min)
     {
      Alert("Inconsistência de Horários de Negociação!");
      return(INIT_FAILED);
     }
   if(datetime_stop_hour == datetime_close_hour && datetime_stop_min >= datetime_close_min)
     {
      Alert("Inconsistência de Horários de Negociação!");
      return(INIT_FAILED);
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
   IndicatorRelease(rsi_handler);
   IndicatorRelease(atr_handler);
   IndicatorRelease(bb_handler);
   ArrayFree(rsi_buffer);
   ArrayFree(atr_buffer);
   ArrayFree(bb_upper_buffer);
   ArrayFree(bb_lower_buffer);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

   if(!is_new_candle(_Period) && signal_timer == 0) // tick a cada novo candle caso não haja sinal ativo
      return;

   bool signal_buy = false, signal_sell = false, buy_open = false, sell_open = false, order_pending = false;

   if(!SymbolInfoTick(_Symbol, tick)) // atualiza tick
     {
      Alert("Erro ao carregar tick: ", GetLastError());
      return;
     }

   TimeToStruct(TimeCurrent(), date);
   Comment("ASK: ", tick.ask, "\nBID:", tick.bid, "\nLAST:", tick.last, "\n", date.hour, ":", date.min);

   if(CopyRates(_Symbol, _Period, 0, 3, rates) < 0) // atualiza rates
     {
      Alert("Falha na dedução das taxas: ", GetLastError());
      return;
     }

   if(!CopyBuffer(rsi_handler, 0, 0, 3, rsi_buffer) ||
      !CopyBuffer(atr_handler, 0, 0, 3, atr_buffer) ||
      !CopyBuffer(bb_handler, 1, 0, 3, bb_upper_buffer) ||
      !CopyBuffer(bb_handler, 2, 0, 3, bb_lower_buffer)) // atualiza indicadores
     {
      Alert("Falha no preenchimento do buffer ", GetLastError());
      return;
     }

   if(rates[0].low < rates[1].low && rates[0].close > rates[1].close)   // pivot verde
     {
      signal_buy = true;
      for(int i = 0; i < qtd_candles_seguidos; i++)
        {
         if(rates[1+i].open < rates[1+i].close) // candles anteriores devem ser vermelhos
           {
            signal_buy = false;
            break;
           }
         if(i == 0 && (rsi_buffer[1+i] > rsi_level_max || rsi_buffer[1+i] < rsi_level_min)) // primeiro candle vermelho fora da faixa RSI
           {
            signal_buy = false;
            break;
           }
         if(i == (int)(qtd_candles_seguidos - 1) && rates[1+i].close > bb_lower_buffer[1+i]) // ultimo candle vermelho dentro da banda inferior
           {
            signal_buy = false;
            break;
           }
        }
      if((fabs(rates[0].close - rates[0].open)/fabs(rates[0].high - rates[0].low)*100) < corpo_percent) // corpo fora do percentual
         signal_buy = false;
     }

   if(rates[0].high > rates[1].high && rates[0].close > rates[1].close)   // pivot vermelho
     {
      signal_sell = true;
      for(int i = 0; i < qtd_candles_seguidos; i++)
        {
         if(rates[1+i].open < rates[1+i].close) // candles anteriores devem ser verdes
           {
            signal_sell = false;
            break;
           }
         if(i == 0 && (rsi_buffer[1+i] > rsi_level_max || rsi_buffer[1+i] < rsi_level_min)) // primeiro candle verde fora da faixa RSI
           {
            signal_sell = false;
            break;
           }
         if(i == (int)(qtd_candles_seguidos - 1) && rates[1+i].open < bb_upper_buffer[1+i]) // ultimo candle verde dentro da banda superior
           {
            signal_sell = false;
            break;
           }
         if((fabs(rates[0].close - rates[0].open)/fabs(rates[0].high - rates[0].low)*100) < corpo_percent) // corpo fora do percentual
            signal_sell = false;
        }
     }

   for(int i=0; i<PositionsTotal(); i++) // status da posição
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magic_number)
        {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            buy_open = true;
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
            sell_open = true;
         break;
        }

   for(int i=0; i<OrdersTotal(); i++) // ordem pendente
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == magic_number)
        {
         order_pending = true;
         break;
        }

   if(buy_open || sell_open || order_pending) // posição aberta
     {
      trailing_stop(tick.last);
      return;
     }

   if((signal_buy || signal_sell) && signal_timer == 0) // inicia duração do sinal
     {
      signal_timer = TimeCurrent();
      return;
     }

   if(datetime_mode == ENABLED && horafechamento())
      fechaposicao();

   if((signal_buy || signal_sell) && signal_timer > 0 && (TimeCurrent() - signal_timer) >= duracao_sinal && horanegociacao()) // caso o sinal se mantenha no tempo de duração sem posição aberta
     {

      double _price, _sl, _tp;

      if(signal_buy)
        {
         _price = NormalizeDouble(rates[0].high + atr_fator_opening * atr_buffer[0] + (ticks_de_entrada * tick.ask) / 100000, _Digits);
         _tp =    NormalizeDouble(rates[0].high + atr_fator_tp * atr_buffer[0] + (fixo_tp * tick.ask) / 100000, _Digits);
         _sl =    NormalizeDouble(rates[0].low - atr_fator_tp * atr_buffer[0] - (fixo_sl * tick.ask) / 100000, _Digits);
         if(trade.Buy(NULL, _Symbol, _price, _sl, _tp, "rompimento de pivot verde"))
            Print("Ordem de Compra: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
        }
      if(signal_sell)
        {
         _price = NormalizeDouble(rates[0].low - atr_fator_opening * atr_buffer[0] - (ticks_de_entrada * tick.bid) / 100000, _Digits);
         _tp =    NormalizeDouble(rates[0].high - atr_fator_tp * atr_buffer[0] - (fixo_tp * tick.bid) / 100000, _Digits);
         _sl =    NormalizeDouble(rates[0].high + atr_fator_tp * atr_buffer[0] + (fixo_sl * tick.bid) / 100000, _Digits);
         if(trade.Sell(NULL, _Symbol, _price, _sl, _tp, "rompimento de pivot vermelho"))
            Print("Ordem de Venda: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
        }

      signal_timer = 0;

     }

  }

//+------------------------------------------------------------------+
//| Return whether is new candle                                     |
//+------------------------------------------------------------------+
bool is_new_candle(const datetime barTime)
  {
   static datetime barTimeLast = 0;
   bool            result      = barTime != barTimeLast;
   barTimeLast = barTime;
   return result;
  }

//+------------------------------------------------------------------+
//| Trailing Stop                                                    |
//+------------------------------------------------------------------+
void trailing_stop(double preco)
  {
   for(int i=0; i<PositionsTotal(); i++)
     {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magic_number)
        {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         double sl_current = PositionGetDouble(POSITION_SL);
         double tp_current = PositionGetDouble(POSITION_TP);
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && preco >= (sl_current + ts_period))
           {
            double sl_new = NormalizeDouble(sl_current + ts_steps, _Digits);
            if(trade.PositionModify(ticket, sl_new, tp_current))
               Print("TrailingStop - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
            else
               Print("TrailingStop - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
           }
         else
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && preco <= (sl_current - ts_period))
              {
               double sl_new = NormalizeDouble(sl_current - ts_steps, _Digits);
               if(trade.PositionModify(ticket, sl_new, tp_current))
                  Print("TrailingStop - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
               else
                  Print("TrailingStop - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
              }
        }
     }
  }

//+------------------------------------------------------------------+
//| Closing Time                                                     |
//+------------------------------------------------------------------+
bool horafechamento()
  {
   TimeToStruct(TimeCurrent(), date);
   if(date.hour >= datetime_close_hour)
     {
      if(date.hour == datetime_close_hour)
         if(date.min >= datetime_close_min)
            return true;
         else
            return false;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Operation Time                                                   |
//+------------------------------------------------------------------+
bool horanegociacao()
  {
   if(datetime_mode == DISABLED)
      return true;
   TimeToStruct(TimeCurrent(), date);
   if(date.hour >= datetime_start_hour && date.hour <= datetime_stop_hour)
     {
      if(date.hour == datetime_start_hour)
         if(date.min >= datetime_start_min)
            return true;
         else
            return false;
      if(date.hour == datetime_stop_hour)
         if(date.min <= datetime_stop_min)
            return true;
         else
            return false;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Close Positions                                                  |
//+------------------------------------------------------------------+
void fechaposicao()
  {
   for(int i=0; i<PositionsTotal(); i++)
     {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magic_number)
        {
         if(trade.PositionClose(PositionGetInteger(POSITION_TICKET), deviation))
            Print("Posição Fechada - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
         else
            Print("Posição Fechada - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
        }
     }
  }
//+------------------------------------------------------------------+
