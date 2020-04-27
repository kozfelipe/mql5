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
int                           rsi_handler, atr_handler, bb_handler, datetime_start_hour, datetime_start_min, datetime_stop_hour, datetime_stop_min, datetime_close_hour, datetime_close_min;
string                        stringtime_start[], stringtime_stop[], stringtime_close[];
enum                          ENUM_MODE {ENABLED, DISABLED};
enum                          ENUM_PIVOT {RED, GREEN};

struct Pivot
  {
   int                        timer;
   double                     price;
   ENUM_PIVOT                 type;
  } pivot;

input string                  secao1 = "############################"; //### Definições Básicas ###
input ulong                   magic_number = 1; // magic number
input ulong                   deviation = 50; // desvio
input ENUM_ORDER_TYPE_FILLING filling = ORDER_FILLING_RETURN; // preenchimento
input int                     bars_min = 60; // minimo de barras para operar
input int                     fixo_tp = 20; // TP fixo
input int                     fixo_sl = 5; // SL fixo
input double                  lote = 5; // lote

input string                  secao2 = "############################"; //### Horário de Operação ###
input ENUM_MODE               datetime_mode = DISABLED; // ativar horário personalizado
input string                  datetime_start = "09:20"; // inicio de abertura de posições
input string                  datetime_stop = "17:20"; // encerramento de abertura de posições
input string                  datetime_close = "17:40"; // fechamento de posições

input string                  secao3 = "############################"; //### Indicador RSI ###
input int                     rsi_period = 14; // RSI - período
input ENUM_APPLIED_PRICE      rsi_price = PRICE_CLOSE; // RSI - tipo de preço
input double                  rsi_level_min = 30; // RSI - banda mínima
input double                  rsi_level_max = 70; // RSI - banda máxima

input string                  secao4 = "############################"; //### Indicador ATR ###
input int                     atr_period = 14; // ATR - período
input double                  atr_fator_opening = 1; // ATR - fator de abertura
input double                  atr_fator_tp = 1; // ATR - fator TP
input double                  atr_fator_sl = 1; // ATR - fator SL

input string                  secao5 = "############################"; //### Indicador Bandas de Bolinger ###
input int                     bb_period = 21; // Bolinger - período
input ENUM_APPLIED_PRICE      bb_price = PRICE_CLOSE; // Bolinger - tipo de preço
input int                     bb_shift = 0; // Bolinger - deslocamento
input double                  bb_deviation = 2; // Bolinger - desvios padrão

input string                  secao6 = "############################"; //### Trailing Stop ###
enum                          ENUM_TS {USER_DEFINED, FIXED, NONE};
input ENUM_TS                 ts_mode = NONE; // TS - ativar
input double                  ts_steps = 2; // TS - barras
input double                  ts_period = 6; // TS - período

input string                  secao7 = "############################"; //### Estratégia ###
input ENUM_MODE               filter_candles_mode = ENABLED; // Filtro 1 - ativar
input int                     filter_candles_value = 2; // Filtro 1 - candles anteriors
input ENUM_MODE               filter_bb_mode = ENABLED; // Filtro 2 - ativar
input ENUM_MODE               filter_rsi_mode = ENABLED; // Filtro 3 - ativar
input ENUM_MODE               filter_corpo_mode = ENABLED; // Filtro 4 - ativar
input int                     filter_corpo_percent = 10; // Filtro 4 - percentual tamanho do candle
input int                     ticks_de_entrada = 1; // ticks de entrada
input int                     duracao_sinal = 1200; // segundos de duração do sinal

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Print("Início...");

   if(Bars(_Symbol, _Period) < bars_min)
     {
      Alert("Existem menos de ", bars_min, " barras carregadas");
      return(INIT_FAILED);
     }

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

   ChartSetInteger(0, CHART_SHOW_GRID, false);
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

   pivot.timer = 0;

   StringSplit(datetime_start, ':', stringtime_start);
   StringSplit(datetime_stop, ':', stringtime_stop);
   StringSplit(datetime_close, ':', stringtime_close);
   datetime_start_hour = StringToInteger(stringtime_start[0]);
   datetime_start_min = StringToInteger(stringtime_start[1]);
   datetime_stop_hour = StringToInteger(stringtime_stop[0]);
   datetime_stop_min = StringToInteger(stringtime_stop[1]);
   datetime_close_hour = StringToInteger(stringtime_close[0]);
   datetime_close_min = StringToInteger(stringtime_close[1]);

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

   if(datetime_mode == ENABLED && horafechamento())
     {
      fechaposicao();
      return;
     }

   if(!is_new_candle() && pivot.timer == 0) // tick a cada novo candle caso não haja sinal ativo
      return;

   bool signal = false, buy_open = false, sell_open = false, order_pending = false;

   if(!SymbolInfoTick(_Symbol, tick)) // atualiza tick
     {
      Alert("Erro ao carregar tick: ", GetLastError());
      return;
     }

   TimeToStruct(TimeCurrent(), date);
   if(pivot.timer > 0)
      Comment("ASK: ", tick.ask, "\nBID:", tick.bid, "\nLAST:", tick.last, "\n", date.hour, ":", date.min, "\nTempo Sinal: ", ((uint)TimeCurrent() - (uint)pivot.timer)/60, " minutos");

   if(CopyRates(_Symbol, _Period, 0, 10, rates) < 0) // atualiza rates
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

   if((buy_open || sell_open || order_pending) && ts_mode != NONE)   // posição aberta
     {
      trailing_stop(tick.last);
      return;
     }

   if(rates[1].low < rates[2].low && rates[1].close > rates[2].close)   // pivot verde
     {
      signal = true;
      for(int i = 0; i < filter_candles_value; i++)
         if(rates[2+i].open < rates[2+i].close && filter_candles_mode == ENABLED) // candles anteriores devem ser vermelhos
           {
            signal = false;
            break;
           }
      if(rates[2].close > bb_lower_buffer[2] && filter_bb_mode == ENABLED) // ultimo candle vermelho dentro da banda inferior
         signal = false;
      if((rsi_buffer[2] > rsi_level_max || rsi_buffer[2] < rsi_level_min) && filter_rsi_mode == ENABLED) // primeiro candle vermelho fora da faixa RSI
         signal = false;
      if((rates[1].high - rates[1].low != 0) && (fabs(rates[1].close - rates[1].open)/fabs(rates[1].high - rates[1].low)*100) < filter_corpo_percent && filter_corpo_mode == ENABLED)  // corpo fora do percentual
         signal = false;
      if(signal)
        {
         ObjectCreate(0, TimeCurrent()+" Verde", OBJ_ARROW, 0, rates[1].time, rates[1].low - 10);
         ObjectSetInteger(0, TimeCurrent()+" Verde", OBJPROP_COLOR, clrGreen);
         pivot.type = GREEN;
         pivot.price = rates[1].high;
         pivot.timer = iTime(_Symbol, _Period, 1);
         return;
        }
     }

   if(rates[1].high > rates[2].high && rates[1].close < rates[2].close)   // pivot vermelho
     {
      signal = true;
      for(int i = 0; i < filter_candles_value; i++)
         if(rates[2+i].open > rates[2+i].close && filter_candles_mode == ENABLED) // candles anteriores devem ser verdes
           {
            signal = false;
            break;
           }
      if(rates[2].open < bb_upper_buffer[2] && filter_bb_mode == ENABLED) // ultimo candle verde dentro da banda superior
         signal = false;
      if((rsi_buffer[2] > rsi_level_max || rsi_buffer[2] < rsi_level_min) && filter_rsi_mode == ENABLED) // primeiro candle verde fora da faixa RSI
         signal = false;
      if((rates[1].high - rates[1].low != 0) && (fabs(rates[1].close - rates[1].open)/fabs(rates[1].high - rates[1].low)*100) < filter_corpo_percent && filter_corpo_mode == ENABLED)  // corpo fora do percentual
         signal = false;
      if(signal)
        {
         ObjectCreate(0, TimeCurrent()+" Vermelho", OBJ_ARROW, 0, rates[1].time, rates[1].low - 10);
         ObjectSetInteger(0, TimeCurrent()+" Vermelho", OBJPROP_COLOR, clrRed);
         pivot.type = RED;
         pivot.price = rates[1].low;
         pivot.timer = iTime(_Symbol, _Period, 1);
         return;
        }
     }

   if(pivot.timer > 0 && ((uint)TimeCurrent() - pivot.timer) > duracao_sinal)
     {
      Print("Expirado ", ((uint)TimeCurrent() - pivot.timer)/60, " minutos");
      pivot.timer = 0;
     }
   else
      if(pivot.timer > 0 && horanegociacao() && !buy_open && !sell_open && !order_pending)  // verifica rompimento dentro do tempo de duracao do sinal
        {

         double _price, _sl, _tp;

         if(pivot.type == GREEN && tick.ask > pivot.price) // rompimento
           {
            _price = NormalizePrice(NormalizeDouble(rates[0].high + atr_fator_opening * atr_buffer[0] + (ticks_de_entrada * tick.ask) / 100000, _Digits));
            _tp =    NormalizePrice(NormalizeDouble(rates[0].high + atr_fator_tp * atr_buffer[0] + (fixo_tp * tick.ask) / 100000, _Digits));
            _sl =    NormalizePrice(NormalizeDouble(rates[0].low - atr_fator_sl * atr_buffer[0] - (fixo_sl * tick.ask) / 100000, _Digits));
            if(trade.Buy(lote, _Symbol, _price, _sl, _tp, "Rompimento de Pivot Verde"))
              {
               Print("Ordem de Compra: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
               pivot.timer = 0;
               Print("Reiniciando");
               return;
              }
           }
         if(pivot.type == RED && tick.bid < pivot.price) // rompimento
           {
            _price = NormalizePrice(NormalizeDouble(rates[0].low - atr_fator_opening * atr_buffer[0] - (ticks_de_entrada * tick.bid) / 100000, _Digits));
            _tp =    NormalizePrice(NormalizeDouble(rates[0].low - atr_fator_tp * atr_buffer[0] - (fixo_tp * tick.bid) / 100000, _Digits), _Symbol);
            _sl =    NormalizePrice(NormalizeDouble(rates[0].high + atr_fator_sl * atr_buffer[0] + (fixo_sl * tick.bid) / 100000, _Digits), _Symbol);
            if(trade.Sell(lote, _Symbol, _price, _sl, _tp, "=Rompimento de Pivot Vermelho"))
              {
               Print("Ordem de Venda: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
               pivot.timer = 0;
               Print("Reiniciando");
               return;
              }
           }

        }

  }

//+------------------------------------------------------------------+
//| Return whether is new candle                                     |
//+------------------------------------------------------------------+
bool is_new_candle()
  {
   static datetime new_bar;
   if(new_bar != iTime(_Symbol,_Period, 0))
     {
      new_bar = iTime(_Symbol, _Period, 0);
      return true;
     }
   return false;
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
//| Arredonda o preço ao múltiplo do Símbolo                         |
//+------------------------------------------------------------------+
double NormalizePrice(double price, string symbol=NULL, double tick=0)
  {
   static const double _tick = tick ? tick : SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   return round(price / _tick) * _tick;
  }
//+------------------------------------------------------------------+
//| Arredonda o volume                                               |
//+------------------------------------------------------------------+
double NormalizeVolume(double volume)
  {
   static const double min  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   static const double max  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   static const int digits  = (int)-
                              MathLog10(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP));
   if(volume < min)
      volume = min;
   if(volume > max)
      volume = max;
   return NormalizeDouble(volume, digits);
  }
//+------------------------------------------------------------------+
