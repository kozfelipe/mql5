//+------------------------------------------------------------------+
//|                                           EA_RompimentoPivot.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

input int                     rsi_period = 14, atr_period = 14, bb_period = 21, bb_shift = 0, ticks_de_entrada, fixo_tp, fixo_sl, qtd_candles_seguidos, corpo_percent, duracao_sinal;
input ENUM_APPLIED_PRICE      rsi_price = PRICE_CLOSE, bb_price = PRICE_CLOSE;
input double                  rsi_level_min = 30, rsi_level_max = 70, bb_deviation = 2, atr_fator_opening, atr_fator_tp, atr_fator_sl;
input ulong                   magic = 123;

double                        rsi_buffer[], atr_buffer[], bb_upper_buffer[], bb_lower_buffer[];
int                           rsi_handler, atr_handler, bb_handler, signal_timer = 0;

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
      Print("Falha ao carregar manipulador do indicador. (confira os inputs)");
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

   bool signal_buy = false, signal_sell = false, position_open = false;

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

   if((signal_buy || signal_sell) && signal_timer == 0) // inicia duração do sinal
      signal_timer = TimeCurrent();

   if((signal_buy || signal_sell) && signal_timer > 0 && (TimeCurrent() - signal_timer) >= duracao_sinal) // caso o sinal se mantenha no tempo de duração
     {

      double _price, _sl, _tp;
      bool   buy_open = false, sell_open = false;

      for(int i=0; i<PositionsTotal(); i++) // status da posição
         if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magic)
           {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               buy_open = true;
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
               sell_open = true;
            break;
           }

      if(signal_buy && !buy_open)
        {
         _price = NormalizeDouble(rates[0].high + atr_fator_opening * atr_buffer[0] + (ticks_de_entrada * tick.ask) / 100000, _Digits);
         _tp =    NormalizeDouble(rates[0].high + atr_fator_tp * atr_buffer[0] + (fixo_tp * tick.ask) / 100000, _Digits);
         _sl =    NormalizeDouble(rates[0].low - atr_fator_tp * atr_buffer[0] - (fixo_sl * tick.ask) / 100000, _Digits);
         if(trade.Buy(NULL, _Symbol, _price, _sl, _tp, "rompimento de pivot verde"))
            Print("Ordem de Compra: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
        }
      if(signal_sell && !sell_open)
        {
         _price = NormalizeDouble(rates[0].low - atr_fator_opening * atr_buffer[0] - (ticks_de_entrada * tick.bid) / 100000, _Digits);
         _tp =    NormalizeDouble(rates[0].high - atr_fator_tp * atr_buffer[0] - (fixo_tp * tick.bid) / 100000, _Digits);
         _sl =    NormalizeDouble(rates[0].high + atr_fator_tp * atr_buffer[0] + (fixo_sl * tick.bid) / 100000, _Digits);
         if(trade.Sell(NULL, _Symbol, _price, _sl, _tp, "rompimento de pivot vermelho"))
            Print("Ordem de Venda: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
        }
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
