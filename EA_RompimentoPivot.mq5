//+------------------------------------------------------------------+
//|                                           EA_RompimentoPivot.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

input int                     rsi_period = 14, atr_period = 14, bb_period = 14, ticks_de_entrada, fixo_tp, fixo_sl, qtd_candles_seguidos;
input ENUM_APPLIED_PRICE      rsi_price = PRICE_CLOSE, bb_price = PRICE_CLOSE;
input double                  rsi_level_min = 30, rsi_level_max = 70, bb_deviation = 2;

double                        rsi_buffer[], atr_buffer[], bb_upper_buffer[], bb_lower_buffer[];
int                           rsi_handler, atr_handler, bb_handler;

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
                   0,             // band shift
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

   if(!SymbolInfoTick(_Symbol, tick)) // atualiza tick
     {
      Alert("Erro ao carregar tick: ", GetLastError());
      return;
     }

   if(!CopyBuffer(rsi_handler, 0, 0, 3, rsi_buffer) ||
      !CopyBuffer(rsi_handler, 0, 0, 3, rsi_buffer) ||
      !CopyBuffer(bb_handler, 1, 0, 3, bb_upper_buffer) ||
      !CopyBuffer(bb_handler, 2, 0, 3, bb_lower_buffer)) // atualiza indicadores
     {
      Alert("Falha no preenchimento do buffer ", GetLastError());
      return;
     }

  }
//+------------------------------------------------------------------+
