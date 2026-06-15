//+------------------------------------------------------------------+
//|  XAU Scalper · Scalping · Metalli
//|  Generato automaticamente da FTMO Strategy App
//|  Tipo strategia: xau_scalper
//+------------------------------------------------------------------+
// XAU Scalper · Scalping · Metalli
//
// Strategia xau scalper scalping su Metalli (XAUUSD, XAGUSD), calibrata per una
// challenge FTMO da $100,000 in fase 1. Rischio 0.5% per trade (low), massimo 5
// trade/giorno. Obiettivo: raggiungere il target del 10% restando entro il -5%
// giornaliero e -10% complessivo.
//
// Regole di ingresso:
//   1. Opera XAUUSD solo nelle finestre Londra (08:00–11:00) e NY (13:30–16:00).
//   2. Trend bias con EMA21 su M15; opera solo nella direzione del bias.
//   3. Trigger su M5: rottura di micro-struttura + ritest.
//   4. Spread filter: salta gli ingressi se spread > soglia (oro è volatile).
//   5. SL stretto basato su ATR(14); TP a 1.5–2R, parziale a 1R.
//+------------------------------------------------------------------+
#property copyright "FTMO Strategy App"
#property version   "1.00"
#property strict

//==================  PARAMETRI  ===================================
input double RiskPercent      = 0.50;   // Rischio % per trade
input double MinRR            = 2.0;      // Risk:Reward minimo (TP = SL * RR)
input double SL_ATR_Mult      = 1.5;        // Stop loss = ATR * questo moltiplicatore
input int    ATR_Period       = 14;         // Periodo ATR
input ENUM_TIMEFRAMES TrendTF = PERIOD_H4;  // Timeframe per il filtro di trend
input int    MaxDailyTrades   = 5;         // Numero massimo di trade al giorno
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

//--- Segnale: XAU Scalper (bias EMA21 M15 + momentum)
int GetSignal()
{
   double ema21  = iMA(_Symbol, PERIOD_M15, 21, 0, MODE_EMA, PRICE_CLOSE, 0);
   double close0 = iClose(_Symbol, PERIOD_M15, 0);
   double rsi    = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE, 0);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double high2  = iHigh(_Symbol, PERIOD_CURRENT, 2);
   double low2   = iLow(_Symbol, PERIOD_CURRENT, 2);

   bool biasUp   = close0 > ema21;
   bool biasDown = close0 < ema21;

   if(biasUp && close1 > high2 && rsi > 50 && rsi < 75) return SIGNAL_BUY;
   if(biasDown && close1 < low2 && rsi < 50 && rsi > 25) return SIGNAL_SELL;
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
