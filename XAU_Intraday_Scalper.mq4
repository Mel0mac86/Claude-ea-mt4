//+------------------------------------------------------------------+
//|                                        XAU_Intraday_Scalper.mq4   |
//|                            Neuromelo - Strategia "Piu' PnL"       |
//|         Intraday aggressive scalping su XAU/USD (M15 / H4)        |
//+------------------------------------------------------------------+
//| Strategia di intraday aggressivo su XAU/USD durante le sessioni   |
//| ad alta volatilita' (Londra / New York). Breakout di micro-range  |
//| e momentum intraday con gestione rigorosa del rischio per         |
//| proteggere l'account da drawdown eccessivi (regole FTMO-style).   |
//+------------------------------------------------------------------+
#property copyright "Neuromelo"
#property link      ""
#property version   "1.10"
#property strict

//==================================================================//
//  INPUT - GESTIONE DEL RISCHIO                                     //
//==================================================================//
input string  __riskHdr            = "===== GESTIONE RISCHIO =====";
input double  InitialBalance       = 10000.0;  // Saldo iniziale di riferimento (0 = usa AccountBalance)
input double  MaxDailyLossUSD       = 500.0;    // Max daily loss (LIMITE INVALICABILE)
input double  MaxOverallLossUSD     = 1000.0;   // Max overall loss (LIMITE INVALICABILE)
input double  RiskPercentPerTrade   = 0.75;     // Rischio % per trade (0.5 - 1.0)
input double  MinRiskUSD            = 50.0;     // Rischio minimo per trade in USD
input double  MaxRiskUSD            = 100.0;    // Rischio massimo per trade in USD
input double  MaxLotPerTrade        = 1.5;      // Lot MASSIMO per trade
input double  HalfDailyLossUSD      = 250.0;    // Soft-stop: 50% del daily loss -> stop trading

//==================================================================//
//  INPUT - SESSIONI (orari in GMT)                                  //
//==================================================================//
input string  __sessHdr            = "===== SESSIONI (GMT) =====";
input int     BrokerGMTOffset      = 0;         // Offset ore server broker rispetto a GMT
input int     LondonStartHour      = 8;         // Inizio Londra (GMT)
input int     LondonEndHour        = 12;        // Fine Londra (GMT)
input int     OverlapStartHour     = 13;        // Inizio overlap Londra-NY (GMT)
input int     OverlapEndHour       = 16;        // Fine overlap / fine operativita' (GMT)
input bool    ObserveFirst15Min    = true;      // Niente trade nei primi 15 min di Londra
input int     CloseAllHourGMT      = 16;        // Chiusura forzata posizioni (GMT) - no overnight
input int     CloseAllMinuteGMT    = 0;         // Minuto chiusura forzata

//==================================================================//
//  INPUT - LOGICA DI INGRESSO                                       //
//==================================================================//
input string  __entryHdr           = "===== INGRESSO =====";
input int     RangeLookbackBars     = 12;        // Barre M15 per S/R del micro-range
input int     RsiPeriod             = 14;        // Periodo RSI
input ENUM_TIMEFRAMES RsiTimeframe  = PERIOD_H4; // Timeframe RSI (contesto direzionale)
input double  RsiLongThreshold      = 50.0;      // RSI > soglia per LONG
input double  RsiShortThreshold     = 50.0;      // RSI < soglia per SHORT
input int     VolumeMAPeriod        = 20;        // Periodo media volume
input double  VolumeFactor          = 1.0;       // Volume > fattore * media
input bool    RequireVolumeFilter   = true;      // Abilita filtro volume
input int     MaxBreakoutExtPips     = 20;       // Non inseguire breakout estesi oltre N pips

//==================================================================//
//  INPUT - STOP / TARGET (in "pips" XAU)                            //
//==================================================================//
input string  __exitHdr            = "===== STOP / TARGET =====";
input double  PipSize               = 0.10;      // Dimensione di 1 "pip" XAU in prezzo (0.10 standard)
input double  StopLossPips          = 10.0;      // Stop Loss fisso (8-12 pips)
input double  RiskRewardRatio       = 1.5;       // R:R minimo (TP = SL * R:R)
input bool    UsePartialClose       = true;      // Chiusura parziale 50%
input double  PartialClosePips       = 8.0;      // +pips per chiusura parziale 50%
input double  PartialClosePercent    = 50.0;     // % della posizione da chiudere
input bool    UseTrailingStop       = true;      // Trailing stop dopo parziale
input double  TrailingStopPips       = 5.0;      // Distanza trailing stop

//==================================================================//
//  INPUT - EDGE / ROBUSTEZZA                                        //
//==================================================================//
input string  __edgeHdr            = "===== EDGE / ROBUSTEZZA =====";
// --- SL/TP dinamico su ATR (adatta stop e target alla volatilita') ---
input bool    UseAtrStops          = true;       // Usa ATR per SL/TP (override pips fissi)
input int     AtrPeriod            = 14;         // Periodo ATR (su M15)
input double  AtrSlMultiplier      = 1.2;        // SL = ATR * questo moltiplicatore
input double  AtrSlMinPips         = 6.0;        // Clamp minimo SL (pips)
input double  AtrSlMaxPips         = 18.0;       // Clamp massimo SL (pips)
// --- Partial come frazione dello SL reale + breakeven ---
input double  PartialAtSlFraction  = 0.8;        // Parziale a (frazione dello SL) di profitto
input bool    UseBreakeven         = true;       // Sposta SL a pareggio dopo il parziale
input double  BreakevenBufferPips  = 1.0;        // Buffer oltre l'entry al breakeven
// --- Filtro trend H4 (opera solo in direzione del trend) ---
input bool    UseTrendFilter       = true;       // Filtro trend con EMA
input ENUM_TIMEFRAMES TrendTimeframe = PERIOD_H4;// Timeframe del trend
input int     TrendEmaPeriod       = 50;         // Periodo EMA trend
// --- Filtro volatilita' (no chop): richiede range/ATR minimo ---
input bool    UseVolatilityFilter  = true;       // Salta sessioni a bassa volatilita'
input ENUM_TIMEFRAMES VolTimeframe = PERIOD_D1;  // Timeframe per stima volatilita'
input int     VolAtrPeriod         = 14;         // Periodo ATR volatilita'
input double  MinVolRangePips      = 150.0;      // ATR minimo richiesto (pips) - dipende da PipSize
// --- Qualita' del trade: spread non deve erodere lo SL ---
input double  MaxSpreadToSlRatio   = 0.30;       // Spread max come frazione dello SL

//==================================================================//
//  INPUT - FILTRI OPERATIVI                                         //
//==================================================================//
input string  __filtHdr            = "===== FILTRI =====";
input double  MaxSpreadPips         = 25.0;      // Spread massimo per entrare (pips)
input int     MaxTradesPerDay       = 10;        // Max trade al giorno (8-12)
input int     RevengePauseMinutes   = 30;        // Pausa dopo 2 loss consecutivi
input int     ConsecutiveLossLimit  = 2;         // N loss consecutivi prima della pausa
input string  NewsTimesGMT          = "";        // News da evitare "HH:MM,HH:MM" (GMT)
input int     NewsBufferMinutes     = 30;        // Buffer minuti prima/dopo news

//==================================================================//
//  INPUT - GENERALI                                                 //
//==================================================================//
input string  __genHdr             = "===== GENERALI =====";
input int     MagicNumber          = 20260614;  // Magic number
input int     SlippagePoints       = 30;        // Slippage massimo (points)
input string  TradeComment         = "NM_XAU";  // Commento ordini
input bool    OneTradePerBarSignal = true;      // Max 1 entry per barra M15

//==================================================================//
//  STATO GLOBALE                                                    //
//==================================================================//
double   g_initialBalance   = 0.0;     // Saldo di riferimento per overall loss
double   g_dayStartEquity   = 0.0;     // Equity inizio giornata (per daily loss)
int      g_currentDay       = -1;      // Giorno corrente (per reset)
int      g_tradesToday      = 0;       // Trade aperti oggi
int      g_consecLosses     = 0;       // Loss consecutivi
datetime g_revengePauseUntil= 0;       // Pausa revenge fino a
datetime g_lastBarTime      = 0;       // Ultima barra M15 processata per entry
bool     g_dailyHardStop    = false;   // Daily loss raggiunto
bool     g_overallHardStop  = false;   // Overall loss raggiunto
long     g_partialDone[];              // Ticket gia' chiusi parzialmente
double   g_pip              = 0.0;     // PipSize effettivo

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_pip = (PipSize > 0.0) ? PipSize : 10.0 * Point;

   g_initialBalance = (InitialBalance > 0.0) ? InitialBalance : AccountBalance();
   ResetDailyState();

   if(StringFind(Symbol(), "XAU") != 0)
      Print("ATTENZIONE: simbolo corrente '", Symbol(), "' non sembra XAU/USD. Verificare parametri pip.");

   Print("Neuromelo XAU Scalper avviato. Pip=", DoubleToStr(g_pip, Digits),
         " Saldo rif=", DoubleToStr(g_initialBalance, 2),
         " DailyLoss=", DoubleToStr(MaxDailyLossUSD,2),
         " OverallLoss=", DoubleToStr(MaxOverallLossUSD,2));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime gmtNow = GmtNow();           // ora GMT corrente (server - offset)

   // Reset stato a inizio nuova giornata
   HandleNewDay(gmtNow);

   // Aggiorna stato perdite (daily / overall)
   UpdateRiskGuards();

   // Gestione posizioni gia' aperte (sempre attiva)
   ManageOpenPositions(gmtNow);

   // Chiusura forzata di fine giornata (no overnight)
   if(IsCloseAllTime(gmtNow))
     {
      CloseAllPositions("EOD close");
     }

   // Hard stop: nessun nuovo ingresso
   if(g_dailyHardStop || g_overallHardStop)
     {
      UpdateDashboard(gmtNow);
      return;
     }

   // Filtri di ammissibilita' all'ingresso
   if(!CanEnterNow(gmtNow))
     {
      UpdateDashboard(gmtNow);
      return;
     }

   // Valuta e apri nuove operazioni (1 per barra M15)
   datetime barTime = iTime(Symbol(), PERIOD_M15, 0);
   if(OneTradePerBarSignal && barTime == g_lastBarTime)
     {
      UpdateDashboard(gmtNow);
      return;
     }

   int signal = GetEntrySignal();   // 1 = LONG, -1 = SHORT, 0 = nessuno
   if(signal != 0)
     {
      if(OpenTrade(signal))
         g_lastBarTime = barTime;
     }

   UpdateDashboard(gmtNow);
  }

//+------------------------------------------------------------------+
//| Reset stato giornaliero                                          |
//+------------------------------------------------------------------+
void ResetDailyState()
  {
   g_dayStartEquity = AccountEquity();
   g_tradesToday    = 0;
   g_dailyHardStop  = false;
   g_currentDay     = DayOfYearGMT(GmtNow());
  }

//+------------------------------------------------------------------+
//| Ora GMT corrente (server time - offset broker)                   |
//+------------------------------------------------------------------+
datetime GmtNow()
  {
   return(TimeCurrent() - BrokerGMTOffset * 3600);
  }

//+------------------------------------------------------------------+
//| Gestione cambio giorno                                           |
//+------------------------------------------------------------------+
void HandleNewDay(datetime gmtNow)
  {
   int doy = DayOfYearGMT(gmtNow);
   if(doy != g_currentDay)
     {
      ResetDailyState();
      Print("Nuovo giorno di trading. Equity start=", DoubleToStr(g_dayStartEquity, 2));
     }
  }

//+------------------------------------------------------------------+
//| Giorno dell'anno in GMT (chiave reset)                           |
//+------------------------------------------------------------------+
int DayOfYearGMT(datetime t)
  {
   return(TimeYear(t) * 1000 + TimeDayOfYear(t));
  }

//+------------------------------------------------------------------+
//| Aggiorna i guard di rischio (daily / overall)                    |
//+------------------------------------------------------------------+
void UpdateRiskGuards()
  {
   double equity = AccountEquity();

   // Daily loss (equity di giornata)
   double dailyPnL = equity - g_dayStartEquity;
   if(dailyPnL <= -MaxDailyLossUSD)
     {
      if(!g_dailyHardStop)
        {
         Print("!!! MAX DAILY LOSS RAGGIUNTO: ", DoubleToStr(dailyPnL, 2), " - STOP TRADING + chiusura posizioni");
         CloseAllPositions("Daily loss limit");
        }
      g_dailyHardStop = true;
     }

   // Overall loss (rispetto saldo iniziale)
   double overallPnL = equity - g_initialBalance;
   if(overallPnL <= -MaxOverallLossUSD)
     {
      if(!g_overallHardStop)
        {
         Print("!!! MAX OVERALL LOSS RAGGIUNTO: ", DoubleToStr(overallPnL, 2), " - STOP TRADING DEFINITIVO + chiusura");
         CloseAllPositions("Overall loss limit");
        }
      g_overallHardStop = true;
     }
  }

//+------------------------------------------------------------------+
//| Verifica condizioni generali per poter entrare                   |
//+------------------------------------------------------------------+
bool CanEnterNow(datetime gmtNow)
  {
   // Soft-stop a meta' daily loss
   double dailyPnL = AccountEquity() - g_dayStartEquity;
   if(dailyPnL <= -HalfDailyLossUSD)
      return(false);

   // Sessione operativa (Londra o overlap)
   if(!IsTradingSession(gmtNow))
      return(false);

   // Primi 15 minuti di Londra: solo osservazione
   if(ObserveFirst15Min && IsFirstQuarterLondon(gmtNow))
      return(false);

   // Limite trade giornalieri
   if(g_tradesToday >= MaxTradesPerDay)
      return(false);

   // Pausa revenge trading
   if(gmtNow < g_revengePauseUntil)
      return(false);

   // Spread accettabile (limite assoluto)
   if(CurrentSpreadPips() > MaxSpreadPips)
      return(false);

   // Spread non deve erodere lo SL (qualita' del trade)
   double slPips = CurrentSlDistance() / g_pip;
   if(slPips > 0.0 && (CurrentSpreadPips() / slPips) > MaxSpreadToSlRatio)
      return(false);

   // Filtro volatilita': niente trading in regime di chop
   if(!VolatilityOk())
      return(false);

   // Filtro news
   if(IsNewsWindow(gmtNow))
      return(false);

   // Una sola posizione del nostro EA per volta (focus / esposizione)
   if(CountOurPositions() > 0)
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//| Sessione di trading attiva?                                      |
//+------------------------------------------------------------------+
bool IsTradingSession(datetime gmtNow)
  {
   int h = TimeHour(gmtNow);
   bool london  = (h >= LondonStartHour  && h < LondonEndHour);
   bool overlap = (h >= OverlapStartHour && h < OverlapEndHour);
   return(london || overlap);
  }

//+------------------------------------------------------------------+
//| Primi 15 minuti dall'apertura di Londra                          |
//+------------------------------------------------------------------+
bool IsFirstQuarterLondon(datetime gmtNow)
  {
   return(TimeHour(gmtNow) == LondonStartHour && TimeMinute(gmtNow) < 15);
  }

//+------------------------------------------------------------------+
//| E' l'ora di chiudere tutto (fine giornata)?                      |
//+------------------------------------------------------------------+
bool IsCloseAllTime(datetime gmtNow)
  {
   int h = TimeHour(gmtNow);
   int m = TimeMinute(gmtNow);
   if(h > CloseAllHourGMT) return(true);
   if(h == CloseAllHourGMT && m >= CloseAllMinuteGMT) return(true);
   return(false);
  }

//+------------------------------------------------------------------+
//| Spread corrente in pips                                          |
//+------------------------------------------------------------------+
double CurrentSpreadPips()
  {
   double spread = (Ask - Bid);
   return(spread / g_pip);
  }

//+------------------------------------------------------------------+
//| Finestra news da evitare (lista "HH:MM,HH:MM" in GMT)            |
//+------------------------------------------------------------------+
bool IsNewsWindow(datetime gmtNow)
  {
   if(StringLen(NewsTimesGMT) == 0) return(false);

   int nowMin = TimeHour(gmtNow) * 60 + TimeMinute(gmtNow);

   string parts[];
   int n = StringSplit(NewsTimesGMT, ',', parts);
   for(int i = 0; i < n; i++)
     {
      string item = parts[i];
      StringTrimLeft(item);
      StringTrimRight(item);
      int colon = StringFind(item, ":");
      if(colon <= 0) continue;
      int hh = (int)StringToInteger(StringSubstr(item, 0, colon));
      int mm = (int)StringToInteger(StringSubstr(item, colon + 1));
      int newsMin = hh * 60 + mm;
      if(MathAbs(nowMin - newsMin) <= NewsBufferMinutes)
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Segnale di ingresso: 1=LONG, -1=SHORT, 0=nessuno                 |
//+------------------------------------------------------------------+
int GetEntrySignal()
  {
   // Livelli S/R del micro-range M15 (barre chiuse, escludendo la corrente)
   double resistance = iHigh(Symbol(), PERIOD_M15, iHighest(Symbol(), PERIOD_M15, MODE_HIGH, RangeLookbackBars, 1));
   double support    = iLow(Symbol(),  PERIOD_M15, iLowest(Symbol(),  PERIOD_M15, MODE_LOW,  RangeLookbackBars, 1));

   // Candela di conferma = ultima barra chiusa M15
   double closeConf = iClose(Symbol(), PERIOD_M15, 1);
   double highConf  = iHigh(Symbol(),  PERIOD_M15, 1);
   double lowConf   = iLow(Symbol(),   PERIOD_M15, 1);

   // RSI contesto direzionale (H4)
   double rsi = iRSI(Symbol(), RsiTimeframe, RsiPeriod, PRICE_CLOSE, 1);

   // Filtro volume su M15
   bool volOk = true;
   if(RequireVolumeFilter)
     {
      double volMA = VolumeAverage(VolumeMAPeriod);
      double volCur = (double)iVolume(Symbol(), PERIOD_M15, 1);
      volOk = (volMA > 0.0 && volCur > VolumeFactor * volMA);
     }

   double maxExt = MaxBreakoutExtPips * g_pip;

   // Filtro trend H4: opera solo nella direzione dell'EMA (prezzo vs EMA + pendenza)
   int trend = TrendDirection(); // 1=up, -1=down, 0=flat/non-filtrato

   // ---- LONG: breakout resistenza + conferma + RSI + volume + trend ----
   bool longBreak  = (highConf > resistance && closeConf > resistance);
   bool longRsi    = (rsi > RsiLongThreshold);
   bool longNotExt = ((Ask - resistance) <= maxExt); // non inseguire breakout estesi
   bool longTrend  = (!UseTrendFilter || trend >= 0);
   if(longBreak && longRsi && volOk && longNotExt && longTrend)
      return(1);

   // ---- SHORT: breakout supporto + conferma + RSI + volume + trend ----
   bool shortBreak  = (lowConf < support && closeConf < support);
   bool shortRsi    = (rsi < RsiShortThreshold);
   bool shortNotExt = ((support - Bid) <= maxExt);
   bool shortTrend  = (!UseTrendFilter || trend <= 0);
   if(shortBreak && shortRsi && volOk && shortNotExt && shortTrend)
      return(-1);

   return(0);
  }

//+------------------------------------------------------------------+
//| Direzione del trend su TrendTimeframe: 1=up, -1=down, 0=flat     |
//+------------------------------------------------------------------+
int TrendDirection()
  {
   double emaNow  = iMA(Symbol(), TrendTimeframe, TrendEmaPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaPrev = iMA(Symbol(), TrendTimeframe, TrendEmaPeriod, 0, MODE_EMA, PRICE_CLOSE, 3);
   double price   = iClose(Symbol(), TrendTimeframe, 1);

   if(price > emaNow && emaNow >= emaPrev) return(1);
   if(price < emaNow && emaNow <= emaPrev) return(-1);
   return(0);
  }

//+------------------------------------------------------------------+
//| Distanza SL in prezzo: ATR (con clamp) oppure pips fissi         |
//+------------------------------------------------------------------+
double CurrentSlDistance()
  {
   if(!UseAtrStops)
      return(StopLossPips * g_pip);

   double atr = iATR(Symbol(), PERIOD_M15, AtrPeriod, 1);
   double dist = atr * AtrSlMultiplier;

   double minDist = AtrSlMinPips * g_pip;
   double maxDist = AtrSlMaxPips * g_pip;
   if(dist < minDist) dist = minDist;
   if(dist > maxDist) dist = maxDist;
   return(dist);
  }

//+------------------------------------------------------------------+
//| Volatilita' sufficiente? (range/ATR >= soglia minima)            |
//+------------------------------------------------------------------+
bool VolatilityOk()
  {
   if(!UseVolatilityFilter) return(true);
   double atr = iATR(Symbol(), VolTimeframe, VolAtrPeriod, 1);
   return((atr / g_pip) >= MinVolRangePips);
  }

//+------------------------------------------------------------------+
//| Media volume su M15 (tick volume)                                |
//+------------------------------------------------------------------+
double VolumeAverage(int period)
  {
   if(period <= 0) return(0.0);
   double sum = 0.0;
   for(int i = 1; i <= period; i++)
      sum += (double)iVolume(Symbol(), PERIOD_M15, i);
   return(sum / period);
  }

//+------------------------------------------------------------------+
//| Calcolo lot size in base al rischio in USD e SL in prezzo        |
//+------------------------------------------------------------------+
double CalcLotSize(double slPriceDistance)
  {
   // Rischio in USD: % del saldo, vincolato a [MinRiskUSD, MaxRiskUSD]
   double riskMoney = AccountBalance() * RiskPercentPerTrade / 100.0;
   if(riskMoney < MinRiskUSD) riskMoney = MinRiskUSD;
   if(riskMoney > MaxRiskUSD) riskMoney = MaxRiskUSD;

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   if(tickSize <= 0.0 || tickValue <= 0.0 || slPriceDistance <= 0.0)
      return(0.0);

   // Perdita per 1 lot all'SL
   double lossPerLot = (slPriceDistance / tickSize) * tickValue;
   if(lossPerLot <= 0.0) return(0.0);

   double lots = riskMoney / lossPerLot;

   // Normalizzazione ai vincoli del broker e all'input MaxLotPerTrade
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);

   if(lotStep > 0.0)
      lots = MathFloor(lots / lotStep) * lotStep;

   if(lots > MaxLotPerTrade) lots = MaxLotPerTrade;
   if(maxLot > 0.0 && lots > maxLot) lots = maxLot;
   if(lots < minLot) lots = (minLot <= MaxLotPerTrade) ? minLot : 0.0;

   return(NormalizeDouble(lots, 2));
  }

//+------------------------------------------------------------------+
//| Apertura trade                                                   |
//+------------------------------------------------------------------+
bool OpenTrade(int direction)
  {
   double slDist = CurrentSlDistance();
   double tpDist = slDist * RiskRewardRatio;

   double lots = CalcLotSize(slDist);
   if(lots <= 0.0)
     {
      Print("Lot size calcolato = 0, ingresso annullato.");
      return(false);
     }

   int    type;
   double price, sl, tp;
   color  arrow;

   if(direction == 1)
     {
      type  = OP_BUY;
      price = NormalizeDouble(Ask, Digits);
      sl    = NormalizeDouble(price - slDist, Digits);
      tp    = NormalizeDouble(price + tpDist, Digits);
      arrow = clrDodgerBlue;
     }
   else
     {
      type  = OP_SELL;
      price = NormalizeDouble(Bid, Digits);
      sl    = NormalizeDouble(price + slDist, Digits);
      tp    = NormalizeDouble(price - tpDist, Digits);
      arrow = clrRed;
     }

   int ticket = OrderSend(Symbol(), type, lots, price, SlippagePoints, sl, tp, TradeComment, MagicNumber, 0, arrow);
   if(ticket < 0)
     {
      Print("OrderSend fallito err=", GetLastError(), " dir=", direction, " lots=", DoubleToStr(lots,2));
      return(false);
     }

   g_tradesToday++;
   Print("APERTO ", (direction==1?"LONG":"SHORT"), " #", ticket,
         " lots=", DoubleToStr(lots,2),
         " SL=", DoubleToStr(sl,Digits), " TP=", DoubleToStr(tp,Digits),
         " trade#oggi=", g_tradesToday);
   return(true);
  }

//+------------------------------------------------------------------+
//| Gestione posizioni aperte: parziale + trailing                   |
//+------------------------------------------------------------------+
void ManageOpenPositions(datetime gmtNow)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      double profitPips = PositionProfitPips();

      // Soglia parziale: frazione dello SL reale della posizione (fallback a pips fissi)
      double partialTrigger = PartialClosePips;
      if(OrderStopLoss() > 0.0)
        {
         double slPipsOrder = MathAbs(OrderOpenPrice() - OrderStopLoss()) / g_pip;
         if(slPipsOrder > 0.0) partialTrigger = slPipsOrder * PartialAtSlFraction;
        }

      // Chiusura parziale al primo target + spostamento a breakeven
      if(UsePartialClose && !IsPartialDone(OrderTicket()) && profitPips >= partialTrigger)
        {
         DoPartialClose();
         MoveToBreakeven();
        }

      // Trailing stop dopo il parziale (o sempre, se parziale disabilitato)
      if(UseTrailingStop && (IsPartialDone(OrderTicket()) || !UsePartialClose))
         DoTrailingStop();
     }
  }

//+------------------------------------------------------------------+
//| Profitto della posizione selezionata in pips                     |
//+------------------------------------------------------------------+
double PositionProfitPips()
  {
   if(OrderType() == OP_BUY)
      return((Bid - OrderOpenPrice()) / g_pip);
   if(OrderType() == OP_SELL)
      return((OrderOpenPrice() - Ask) / g_pip);
   return(0.0);
  }

//+------------------------------------------------------------------+
//| Chiusura parziale dell'ordine selezionato                        |
//+------------------------------------------------------------------+
void DoPartialClose()
  {
   double closeLots = OrderLots() * PartialClosePercent / 100.0;
   double lotStep   = MarketInfo(Symbol(), MODE_LOTSTEP);
   double minLot    = MarketInfo(Symbol(), MODE_MINLOT);

   if(lotStep > 0.0)
      closeLots = MathFloor(closeLots / lotStep) * lotStep;
   closeLots = NormalizeDouble(closeLots, 2);

   // Se il residuo o la quota da chiudere sono sotto il minimo, non frazionare
   if(closeLots < minLot || (OrderLots() - closeLots) < minLot)
     {
      MarkPartialDone(OrderTicket()); // evita ritentativi continui
      return;
     }

   double price = (OrderType() == OP_BUY) ? Bid : Ask;
   long   ticket = OrderTicket();

   if(OrderClose((int)ticket, closeLots, NormalizeDouble(price, Digits), SlippagePoints, clrYellow))
     {
      Print("Chiusura parziale ", DoubleToStr(PartialClosePercent,0), "% su #", ticket,
            " lots=", DoubleToStr(closeLots,2));
      // La chiusura parziale genera un nuovo ticket per il residuo: marchiamo
      // l'intera posizione tramite ricerca del residuo piu' recente del simbolo.
      MarkPartialDone(ticket);
      MarkLatestPositionPartialDone();
     }
   else
     {
      Print("OrderClose parziale fallito #", ticket, " err=", GetLastError());
     }
  }

//+------------------------------------------------------------------+
//| Trailing stop dell'ordine selezionato                            |
//+------------------------------------------------------------------+
void DoTrailingStop()
  {
   double trail = TrailingStopPips * g_pip;
   double newSL;

   if(OrderType() == OP_BUY)
     {
      newSL = NormalizeDouble(Bid - trail, Digits);
      if(newSL > OrderOpenPrice() && (OrderStopLoss() == 0 || newSL > OrderStopLoss()))
        {
         if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrAqua))
            Print("Trailing modify (BUY) fallito #", OrderTicket(), " err=", GetLastError());
        }
     }
   else if(OrderType() == OP_SELL)
     {
      newSL = NormalizeDouble(Ask + trail, Digits);
      if(newSL < OrderOpenPrice() && (OrderStopLoss() == 0 || newSL < OrderStopLoss()))
        {
         if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrAqua))
            Print("Trailing modify (SELL) fallito #", OrderTicket(), " err=", GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
//| Sposta lo SL a breakeven (+ buffer) sulla posizione residua      |
//| Nota: la chiusura parziale crea un nuovo ticket -> selezioniamo  |
//| la posizione aperta piu' recente dell'EA.                        |
//+------------------------------------------------------------------+
void MoveToBreakeven()
  {
   if(!UseBreakeven) return;

   long   bestTicket = -1;
   datetime bestTime = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(OrderOpenTime() >= bestTime) { bestTime = OrderOpenTime(); bestTicket = OrderTicket(); }
     }
   if(bestTicket < 0) return;
   if(!OrderSelect((int)bestTicket, SELECT_BY_TICKET)) return;

   double buffer = BreakevenBufferPips * g_pip;
   double newSL;

   if(OrderType() == OP_BUY)
     {
      newSL = NormalizeDouble(OrderOpenPrice() + buffer, Digits);
      if(Bid > newSL && (OrderStopLoss() == 0 || newSL > OrderStopLoss()))
         if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrLime))
            Print("Breakeven (BUY) fallito #", OrderTicket(), " err=", GetLastError());
     }
   else if(OrderType() == OP_SELL)
     {
      newSL = NormalizeDouble(OrderOpenPrice() - buffer, Digits);
      if(Ask < newSL && (OrderStopLoss() == 0 || newSL < OrderStopLoss()))
         if(!OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrLime))
            Print("Breakeven (SELL) fallito #", OrderTicket(), " err=", GetLastError());
     }
  }

//+------------------------------------------------------------------+
//| Chiusura di tutte le posizioni dell'EA                           |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;

      if(OrderType() == OP_BUY)
        {
         if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Bid, Digits), SlippagePoints, clrOrange))
            Print("Close BUY fallito #", OrderTicket(), " err=", GetLastError());
        }
      else if(OrderType() == OP_SELL)
        {
         if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Ask, Digits), SlippagePoints, clrOrange))
            Print("Close SELL fallito #", OrderTicket(), " err=", GetLastError());
        }
     }
   if(StringLen(reason) > 0)
      Print("CloseAllPositions: ", reason);
  }

//+------------------------------------------------------------------+
//| Numero posizioni dell'EA aperte                                  |
//+------------------------------------------------------------------+
int CountOurPositions()
  {
   int c = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() == OP_BUY || OrderType() == OP_SELL) c++;
     }
   return(c);
  }

//+------------------------------------------------------------------+
//| Tracking ticket gia' chiusi parzialmente                         |
//+------------------------------------------------------------------+
bool IsPartialDone(long ticket)
  {
   for(int i = 0; i < ArraySize(g_partialDone); i++)
      if(g_partialDone[i] == ticket) return(true);
   return(false);
  }

void MarkPartialDone(long ticket)
  {
   if(IsPartialDone(ticket)) return;
   int n = ArraySize(g_partialDone);
   ArrayResize(g_partialDone, n + 1);
   g_partialDone[n] = ticket;
  }

//+------------------------------------------------------------------+
//| Marca come "parziale fatto" la posizione residua piu' recente    |
//| (la chiusura parziale crea un nuovo ticket per il residuo)       |
//+------------------------------------------------------------------+
void MarkLatestPositionPartialDone()
  {
   long   bestTicket = -1;
   datetime bestTime = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(OrderOpenTime() >= bestTime)
        {
         bestTime   = OrderOpenTime();
         bestTicket = OrderTicket();
        }
     }
   if(bestTicket >= 0)
      MarkPartialDone(bestTicket);
  }

//+------------------------------------------------------------------+
//| Aggiorna conteggio loss consecutivi dalla storia                 |
//| (chiamato per attivare la pausa revenge)                         |
//+------------------------------------------------------------------+
void OnTradeClosedUpdate()
  {
   // Scansione ultime operazioni chiuse oggi per loss consecutivi
   int losses = 0;
   datetime lastCloseLoss = 0;
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      double pl = OrderProfit() + OrderSwap() + OrderCommission();
      if(pl < 0.0)
        {
         losses++;
         if(lastCloseLoss == 0) lastCloseLoss = OrderCloseTime();
         if(losses >= ConsecutiveLossLimit)
           {
            g_revengePauseUntil = lastCloseLoss + RevengePauseMinutes * 60;
            break;
           }
        }
      else
         break; // streak interrotta dal primo trade positivo
     }
   g_consecLosses = losses;
  }

//+------------------------------------------------------------------+
//| Aggiorna pausa revenge ad ogni chiusura rilevata                 |
//+------------------------------------------------------------------+
void OnTrade()
  {
   OnTradeClosedUpdate();
  }

//+------------------------------------------------------------------+
//| Dashboard a schermo                                              |
//+------------------------------------------------------------------+
void UpdateDashboard(datetime gmtNow)
  {
   double dailyPnL   = AccountEquity() - g_dayStartEquity;
   double overallPnL = AccountEquity() - g_initialBalance;

   string state = "OPERATIVO";
   if(g_overallHardStop)            state = "STOP OVERALL LOSS";
   else if(g_dailyHardStop)         state = "STOP DAILY LOSS";
   else if(gmtNow < g_revengePauseUntil) state = "PAUSA REVENGE";
   else if(!IsTradingSession(gmtNow))    state = "FUORI SESSIONE";
   else if(!VolatilityOk())              state = "BASSA VOLATILITA'";

   int trend = TrendDirection();
   string trendStr = (trend > 0 ? "UP" : (trend < 0 ? "DOWN" : "FLAT"));

   string msg = StringConcatenate(
      "=== Neuromelo XAU Scalper ===\n",
      "Stato: ", state, "\n",
      "GMT: ", TimeToStr(gmtNow, TIME_DATE|TIME_MINUTES), "\n",
      "Trend ", EnumToString(TrendTimeframe), ": ", trendStr, "\n",
      "Spread: ", DoubleToStr(CurrentSpreadPips(), 1), " pips\n",
      "SL dinamico: ", DoubleToStr(CurrentSlDistance() / g_pip, 1), " pips\n",
      "Daily P&L: ", DoubleToStr(dailyPnL, 2), " / -", DoubleToStr(MaxDailyLossUSD, 0), "\n",
      "Overall P&L: ", DoubleToStr(overallPnL, 2), " / -", DoubleToStr(MaxOverallLossUSD, 0), "\n",
      "Trade oggi: ", g_tradesToday, " / ", MaxTradesPerDay, "\n",
      "Loss consec.: ", g_consecLosses, "\n",
      "Posizioni aperte: ", CountOurPositions());
   Comment(msg);
  }
//+------------------------------------------------------------------+
