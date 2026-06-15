//+------------------------------------------------------------------+
//|  Breakout di Sessione · Intraday · Indici
//|  Generato automaticamente da FTMO Strategy App
//|  Tipo strategia: session_breakout
//+------------------------------------------------------------------+
// Breakout di Sessione · Intraday · Indici
//
// Strategia breakout di sessione intraday su Indici (US30, NAS100, GER40),
// calibrata per una challenge FTMO da $100,000 in fase 1. Rischio 1.0% per trade
// (medium), massimo 3 trade/giorno. Obiettivo: raggiungere il target del 10%
// restando entro il -5% giornaliero e -10% complessivo.
//
// Regole di ingresso:
//   1. Definisci il range della sessione asiatica (00:00–07:00 server).
//   2. Attendi l'apertura di Londra/NY per il breakout del range.
//   3. Entra al close di una candela oltre il bordo del range con volume/momentum.
//   4. Filtro: evita breakout contro il trend H4 dominante.
//   5. Stop loss sul lato opposto del range; take profit pari all'ampiezza del range (1:1–1:2).
//+------------------------------------------------------------------+
#property copyright "FTMO Strategy App"
#property version   "1.00"
#property strict

//==================  PARAMETRI  ===================================
input double RiskPercent      = 1.00;   // Rischio % per trade
input double MinRR            = 2.0;      // Risk:Reward minimo (TP = SL * RR)
input double SL_ATR_Mult      = 1.5;        // Stop loss = ATR * questo moltiplicatore
input int    ATR_Period       = 14;         // Periodo ATR
input ENUM_TIMEFRAMES TrendTF = PERIOD_H4;  // Timeframe per il filtro di trend
input int    MaxDailyTrades   = 3;         // Numero massimo di trade al giorno
input double MaxDailyLossPct  = 5.0;       // Stop trading se perdita giornaliera >= (FTMO 5%)
input double MaxOverallLossPct= 10.0;      // Blocco se drawdown totale >= (FTMO 10%)
input double StopDayProfitPct = 3.0;        // Stop trading dopo +% in giornata (lock-in)
input int    StartHour        = 8;          // Ora inizio operativita' (server)
input int    EndHour          = 20;         // Ora fine operativita' (server)
input bool   UseBreakEven     = true;       // Break-even dopo +1R
input int    MagicNumber      = 990201;
input int    Slippage         = 30;
input int    MaxSpreadPoints  = 50;         // Salta ingressi con spread elevato

//==================  STATO  =======================================
#define SIGNAL_NONE 0
#define SIGNAL_BUY  1
#define SIGNAL_SELL 2

datetime g_dayStart      = 0;
double   g_dayStartEquity= 0;
double   g_initialBalance= 0;
int      g_tradesToday   = 0;
datetime g_lastBarTime   = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   g_initialBalance = AccountBalance();
   ResetDay();
   Print("EA avviato | Saldo iniziale: ", g_initialBalance,
         " | Max daily loss: ", DoubleToString(g_initialBalance*MaxDailyLossPct/100,2),
         " | Max overall loss: ", DoubleToString(g_initialBalance*MaxOverallLossPct/100,2));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
void ResetDay()
{
   g_dayStart       = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   g_dayStartEquity = AccountEquity();
   g_tradesToday    = 0;
}

//+------------------------------------------------------------------+
//|  Controllo conformita' FTMO: ritorna true se si puo' tradare      |
//+------------------------------------------------------------------+
bool RiskGuardOK()
{
   // Reset giornaliero
   if(TimeCurrent() >= g_dayStart + 86400) ResetDay();

   double equity = AccountEquity();

   // Max overall loss (rispetto al saldo iniziale)
   double overallLoss = g_initialBalance - equity;
   if(overallLoss >= g_initialBalance * MaxOverallLossPct/100.0)
   {
      static bool warned1=false;
      if(!warned1){ Print("STOP: limite overall loss FTMO raggiunto."); warned1=true; }
      return false;
   }

   // Max daily loss (rispetto all'equity di inizio giornata)
   double dailyLoss = g_dayStartEquity - equity;
   if(dailyLoss >= g_initialBalance * MaxDailyLossPct/100.0)
      return false;

   // Lock-in: stop dopo +X% in giornata
   double dailyProfit = equity - g_dayStartEquity;
   if(dailyProfit >= g_initialBalance * StopDayProfitPct/100.0)
      return false;

   // Limite trade giornalieri
   if(g_tradesToday >= MaxDailyTrades)
      return false;

   // Finestra oraria
   int hour = TimeHour(TimeCurrent());
   if(hour < StartHour || hour >= EndHour)
      return false;

   // Spread filter
   if((Ask - Bid) / _Point > MaxSpreadPoints)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//|  Lot sizing: (capitale * risk%) / (SL_punti * tick value)         |
//+------------------------------------------------------------------+
double CalcLots(double slPoints)
{
   double riskAmount = AccountBalance() * RiskPercent/100.0;
   double tickValue  = MarketInfo(_Symbol, MODE_TICKVALUE);
   double tickSize   = MarketInfo(_Symbol, MODE_TICKSIZE);
   if(tickSize == 0) tickSize = _Point;
   double valuePerPoint = tickValue * (_Point / tickSize);
   double lots = 0;
   if(slPoints > 0 && valuePerPoint > 0)
      lots = riskAmount / (slPoints * valuePerPoint);

   double minLot = MarketInfo(_Symbol, MODE_MINLOT);
   double maxLot = MarketInfo(_Symbol, MODE_MAXLOT);
   double step   = MarketInfo(_Symbol, MODE_LOTSTEP);
   if(step > 0) lots = MathFloor(lots/step)*step;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   return NormalizeDouble(lots, 2);
}

//--- Segnale: Breakout di Sessione (range asiatico -> breakout)
int GetSignal()
{
   double rangeHigh = 0, rangeLow = 0;
   int bars = iBarShift(_Symbol, PERIOD_M15, StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " 07:00"));
   int startB = iBarShift(_Symbol, PERIOD_M15, StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " 00:00"));
   if(startB <= bars) return SIGNAL_NONE;
   rangeHigh = iHigh(_Symbol, PERIOD_M15, iHighest(_Symbol, PERIOD_M15, MODE_HIGH, startB-bars, bars));
   rangeLow  = iLow(_Symbol, PERIOD_M15, iLowest(_Symbol, PERIOD_M15, MODE_LOW, startB-bars, bars));

   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double ema200 = iMA(_Symbol, TrendTF, 200, 0, MODE_EMA, PRICE_CLOSE, 0);

   // Solo breakout nella direzione del trend H4
   if(close1 > rangeHigh && Close[0] > ema200) return SIGNAL_BUY;
   if(close1 < rangeLow  && Close[0] < ema200) return SIGNAL_SELL;
   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i=OrdersTotal()-1; i>=0; i--)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderSymbol()==_Symbol && OrderMagicNumber()==MagicNumber)
            return true;
   return false;
}

//+------------------------------------------------------------------+
void ManageBreakEven()
{
   if(!UseBreakEven) return;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()!=_Symbol || OrderMagicNumber()!=MagicNumber) continue;
      double openP = OrderOpenPrice();
      double slDist = MathAbs(openP - OrderStopLoss());
      if(slDist<=0) continue;
      if(OrderType()==OP_BUY && (Bid-openP)>=slDist && OrderStopLoss()<openP)
         OrderModify(OrderTicket(), openP, openP, OrderTakeProfit(), 0, clrGreen);
      if(OrderType()==OP_SELL && (openP-Ask)>=slDist && OrderStopLoss()>openP)
         OrderModify(OrderTicket(), openP, openP, OrderTakeProfit(), 0, clrGreen);
   }
}

//+------------------------------------------------------------------+
void OpenTrade(int signal)
{
   double atr = iATR(_Symbol, PERIOD_CURRENT, ATR_Period, 0);
   double slDist = atr * SL_ATR_Mult;
   if(slDist <= 0) return;
   double slPoints = slDist / _Point;
   double lots = CalcLots(slPoints);
   if(lots <= 0) return;

   double price, sl, tp;
   if(signal==SIGNAL_BUY)
   {
      price = Ask;
      sl = price - slDist;
      tp = price + slDist*MinRR;
      if(OrderSend(_Symbol, OP_BUY, lots, price, Slippage, sl, tp,
                   "FTMO-EA", MagicNumber, 0, clrBlue) > 0)
         g_tradesToday++;
   }
   else if(signal==SIGNAL_SELL)
   {
      price = Bid;
      sl = price + slDist;
      tp = price - slDist*MinRR;
      if(OrderSend(_Symbol, OP_SELL, lots, price, Slippage, sl, tp,
                   "FTMO-EA", MagicNumber, 0, clrRed) > 0)
         g_tradesToday++;
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   ManageBreakEven();

   // Una valutazione per barra
   if(g_lastBarTime == Time[0]) return;
   g_lastBarTime = Time[0];

   if(!RiskGuardOK()) return;
   if(HasOpenPosition()) return;

   int signal = GetSignal();
   if(signal != SIGNAL_NONE)
      OpenTrade(signal);
}
//+------------------------------------------------------------------+
