//+------------------------------------------------------------------+
//|                                                        teste.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

MqlTick                       tick;
MqlRates                      rates[];
CTrade                        trade;

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

   if(CopyRates(_Symbol, _Period, 0, 3, rates) < 0) // atualiza rates
     {
      Alert("Falha na dedução das taxas: ", GetLastError());
      return;
     }

   Comment("...");

   if(rates[0].low < rates[1].low && rates[0].close > rates[1].close) // pivot verde
     {
      ObjectCreate(0, "verde"+TimeCurrent(), OBJ_ARROW, 0, TimeCurrent(), rates[0].low);
      ObjectSetInteger(0, "verde"+TimeCurrent(), OBJPROP_COLOR, clrGreen);
      Comment("Pivot Verde", "\nlow 0 ", rates[0].low, "\nlow 1 ", rates[1].low, "\nclose 0 ", rates[0].close, "\nclose 1 ", rates[1].close);
     }

   if(rates[0].high > rates[1].high && rates[0].close < rates[1].close) // pivot vermelho
     {
      ObjectCreate(0, "vermelho"+TimeCurrent(), OBJ_ARROW, 0, TimeCurrent(), rates[0].high);
      ObjectSetInteger(0, "vermelho"+TimeCurrent(), OBJPROP_COLOR, clrRed);
      Comment("Pivot Vermelho", "\nhigh 0 ", rates[0].high, "\nhigh 1 ", rates[1].high, "\nclose 0 ", rates[0].close, "\nclose 1 ", rates[1].close);
     }

  }
//+------------------------------------------------------------------+
