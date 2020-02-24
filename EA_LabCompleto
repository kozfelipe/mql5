#include <Trade\Trade.mqh>
CTrade trade;

input int                     ma_periodo = 20;//Período da Média
input int                     ma_desloc = 0;//Deslocamento da Média
input ENUM_MA_METHOD          ma_metodo = MODE_SMA;//Método Média Móvel
input ENUM_APPLIED_PRICE      ma_preco = PRICE_CLOSE;//Preço para Média
input ulong                   magicNum = 123456;//Magic Number
input ulong                   desvPts = 50;//Desvio em Pontos
input ENUM_ORDER_TYPE_FILLING preenchimento = ORDER_FILLING_RETURN;//Preenchimento da Ordem

input double                  lote = 5.0;//Volume
input double                  stopLoss = 5;//Stop Loss
input double                  takeProfit = 20;//Take Profit
input double                  gatilhoBE = 2;//Gatilho BreakEven
input double                  gatilhoTS = 6;//Gatilho TrailingStop
input double                  stepTS = 2;//Step TrailingStop

input int                     horaInicioAbertura = 10;//Hora de Inicio de Abertura de Posições
input int                     minutoInicioAbertura = 30;//Minuto de Inicio de Abertura de Pisoções
input int                     horaFimAbertura = 16;//Hora de Encerramento de Abertura de Posições
input int                     minutoFimAbertura = 45;//Minuto de Encerramento de Abertura de Posições
input int                     horaInicioFechamento = 17;//Hora de Inicio de Fechamento de Posições
input int                     minutoInicioFechamento = 20;//Minuto de Inicio de Fechamento de Posições

double                        PRC;//Preço normalizado
double                        STL;//StopLoss normalizado
double                        TKP;//TakeProfit normalizado

double                        smaArray[];
int                           smaHandle;

bool                          posAberta;
bool                          ordPendente;
bool                          beAtivo;

MqlTick                       ultimoTick;
MqlRates                      rates[];
MqlDateTime                   horaAtual;

int OnInit()
  {
      smaHandle = iMA(_Symbol, _Period, ma_periodo, ma_desloc, ma_metodo, ma_preco);
      if(smaHandle==INVALID_HANDLE)
         {
            Print("Erro ao criar média móvel - erro", GetLastError());
            return(INIT_FAILED);
         }
      ArraySetAsSeries(smaArray, true);
      ArraySetAsSeries(rates, true);     
      
      trade.SetTypeFilling(preenchimento);
      trade.SetDeviationInPoints(desvPts);
      trade.SetExpertMagicNumber(magicNum);
      
      if(horaInicioAbertura > horaFimAbertura || horaFimAbertura > horaInicioFechamento)
         {  
            Alert("Inconsistência de Horários de Negociação!");
            return(INIT_FAILED);
         }
      if(horaInicioAbertura == horaFimAbertura && minutoInicioAbertura >= minutoFimAbertura)
         {
            Alert("Inconsistência de Horários de Negociação!");
            return(INIT_FAILED);
         }
      if(horaFimAbertura == horaInicioFechamento && minutoFimAbertura >= minutoInicioFechamento)
         {
            Alert("Inconsistência de Horários de Negociação!");
            return(INIT_FAILED);
         }
      
      return(INIT_SUCCEEDED);
  }
void OnTick()
  {               
      if(!SymbolInfoTick(Symbol(),ultimoTick))
         {
            Alert("Erro ao obter informações de Preços: ", GetLastError());
            return;
         }
         
      if(CopyRates(_Symbol, _Period, 0, 3, rates)<0)
         {
            Alert("Erro ao obter as informações de MqlRates: ", GetLastError());
            return;
         }
      
      if(CopyBuffer(smaHandle, 0, 0, 3, smaArray)<0)
         {
            Alert("Erro ao copiar dados da média móvel: ", GetLastError());
            return;
         }
         
      posAberta = false;
      for(int i = PositionsTotal()-1; i>=0; i--)
         {
            string symbol = PositionGetSymbol(i);
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            if(symbol == _Symbol && magic == magicNum)
               {  
                  posAberta = true;
                  break;
               }
         }
         
      ordPendente = false;
      for(int i = OrdersTotal()-1; i>=0; i--)
         {
            ulong ticket = OrderGetTicket(i);
            string symbol = OrderGetString(ORDER_SYMBOL);
            ulong magic = OrderGetInteger(ORDER_MAGIC);
            if(symbol == _Symbol && magic == magicNum)
               {
                  ordPendente = true;
                  break;
               }
         }
      
      if(!posAberta)
         {
            beAtivo = false;
         }
         
      if(posAberta && !beAtivo)
         {
            BreakEven(ultimoTick.last);
         }
         
      if(posAberta && beAtivo)
         {
            TrailingStop(ultimoTick.last);
         }
      
      if(HoraFechamento())
         {
            Comment("Horário de Fechamento de Posições!");
            FechaPosicao();
         }
      else if(HoraNegociacao())
         {
            Comment("Dentro do Horário de Negociação!");
         }
      else
         {
            Comment("Fora do Horário de Negociação!");
         }
            
      if(ultimoTick.last>smaArray[0] && rates[1].close>rates[1].open && !posAberta && !ordPendente && HoraNegociacao())
         {
            PRC = NormalizeDouble(ultimoTick.ask, _Digits);
            STL = NormalizeDouble(PRC - stopLoss, _Digits);
            TKP = NormalizeDouble(PRC + takeProfit, _Digits);
            if(trade.Buy(lote, _Symbol, PRC, STL, TKP, ""))
               {
                  Print("Ordem de Compra - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
               }
            else
               {
                  Print("Ordem de Compra - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
               }
         }
      else if(ultimoTick.last<smaArray[0] && rates[1].close<rates[1].open && !posAberta && !ordPendente && HoraNegociacao())
         {
            PRC = NormalizeDouble(ultimoTick.bid, _Digits);
            STL = NormalizeDouble(PRC + stopLoss, _Digits);
            TKP = NormalizeDouble(PRC - takeProfit, _Digits);
            if(trade.Sell(lote, _Symbol, PRC, STL, TKP, ""))
               {
                  Print("Ordem de Venda - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
               }
            else
               {
                  Print("Ordem de Venda - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
               }
         }   
  }
//---
//---
bool HoraFechamento()
   {
      TimeToStruct(TimeCurrent(), horaAtual);
      if(horaAtual.hour >= horaInicioFechamento)
         {
            if(horaAtual.hour == horaInicioFechamento)
               {
                  if(horaAtual.min >= minutoInicioFechamento)
                     {
                        return true;
                     }
                  else
                     {
                        return false;
                     }
               }
            return true;
         }
      return false;
   }
//---
//---
bool HoraNegociacao()
   {
      TimeToStruct(TimeCurrent(), horaAtual);
      if(horaAtual.hour >= horaInicioAbertura && horaAtual.hour <= horaFimAbertura)
         {
            if(horaAtual.hour == horaInicioAbertura)
               {
                  if(horaAtual.min >= minutoInicioAbertura)
                     {
                        return true;
                     }
                  else
                     {
                        return false;
                     }
               }
            if(horaAtual.hour == horaFimAbertura)
               {
                  if(horaAtual.min <= minutoFimAbertura)
                     {
                        return true;
                     }
                  else
                     {
                        return false;
                     }
               }
            return true;
         }
      return false;
   }
//---
//---
void FechaPosicao()
   {
      for(int i = PositionsTotal()-1; i>=0; i--)
         {
            string symbol = PositionGetSymbol(i);
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            if(symbol == _Symbol && magic == magicNum)
               {
                  ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
                  if(trade.PositionClose(PositionTicket, desvPts))
                     {
                        Print("Posição Fechada - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                     }
                  else
                     {
                        Print("Posição Fechada - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                     }
               }
         }
   }
//---
//---
void TrailingStop(double preco)
   {
      for(int i = PositionsTotal()-1; i>=0; i--)
         {
            string symbol = PositionGetSymbol(i);
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            if(symbol == _Symbol && magic==magicNum)
               {
                  ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
                  double StopLossCorrente = PositionGetDouble(POSITION_SL);
                  double TakeProfitCorrente = PositionGetDouble(POSITION_TP);
                  if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                     {
                        if(preco >= (StopLossCorrente + gatilhoTS) )
                           {
                              double novoSL = NormalizeDouble(StopLossCorrente + stepTS, _Digits);
                              if(trade.PositionModify(PositionTicket, novoSL, TakeProfitCorrente))
                                 {
                                    Print("TrailingStop - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                 }
                              else
                                 {
                                    Print("TrailingStop - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                 }
                           }
                     }
                  else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                     {
                        if(preco <= (StopLossCorrente - gatilhoTS) )
                           {
                              double novoSL = NormalizeDouble(StopLossCorrente - stepTS, _Digits);
                              if(trade.PositionModify(PositionTicket, novoSL, TakeProfitCorrente))
                                 {
                                    Print("TrailingStop - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                 }
                              else
                                 {
                                    Print("TrailingStop - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                 }
                           }
                     }
               }
         }
   }
//---
//---

void BreakEven(double preco)
   {
      for(int i = PositionsTotal()-1; i>=0; i--)
         {
            string symbol = PositionGetSymbol(i);
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            if(symbol == _Symbol && magic == magicNum)
               {
                  ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
                  double PrecoEntrada = PositionGetDouble(POSITION_PRICE_OPEN);
                  double TakeProfitCorrente = PositionGetDouble(POSITION_TP);
                  if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                     {
                        if( preco >= (PrecoEntrada + gatilhoBE) )
                           {
                              if(trade.PositionModify(PositionTicket, PrecoEntrada, TakeProfitCorrente))
                                 {
                                    Print("BreakEven - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                    beAtivo = true;
                                 }
                              else
                                 {
                                    Print("BreakEven - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                 }
                           }                           
                     }
                  else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                     {
                        if( preco <= (PrecoEntrada - gatilhoBE) )
                           {
                              if(trade.PositionModify(PositionTicket, PrecoEntrada, TakeProfitCorrente))
                                 {
                                    Print("BreakEven - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                    beAtivo = true;
                                 }
                              else
                                 {
                                    Print("BreakEven - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                 }
                           }
                     }
               }
         }
   }
