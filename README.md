# Neuromelo – XAU/USD Intraday Scalper (MT4)

Expert Advisor MQL4 che implementa la strategia **"Neuromelo – Strategia più PnL"**:
scalping intraday aggressivo su **XAU/USD** durante le sessioni ad alta volatilità
(Londra e overlap Londra–New York), basato su **breakout di micro-range** e
**momentum**, con gestione del rischio rigorosa in stile **FTMO**.

> ⚠️ **Disclaimer**: software fornito a scopo didattico. Il trading su leva
> comporta rischio elevato di perdita del capitale. Testare **sempre** su conto
> demo / Strategy Tester prima di qualsiasi uso reale.

---

## File

| File | Descrizione |
|------|-------------|
| `XAU_Intraday_Scalper.mq4` | Expert Advisor principale |
| `README.md` | Questa documentazione |

## Installazione

1. Copiare `XAU_Intraday_Scalper.mq4` nella cartella
   `MQL4/Experts/` del terminale MetaTrader 4.
2. In MT4: **File → Apri cartella dati** per individuare il percorso.
3. Riavviare MT4 o aggiornare la *Navigator* (tasto destro → Aggiorna).
4. Compilare (F7) dal MetaEditor se necessario.
5. Trascinare l'EA su un grafico **XAU/USD M15** e abilitare l'**AutoTrading**.

L'EA usa il timeframe **M15** per gli ingressi e legge l'**H4** per il contesto
direzionale (RSI). Va applicato a un grafico M15.

---

## Regole della strategia implementate

### Gestione del rischio
- **Max daily loss**: `$500` (5% su 10k) – limite invalicabile → chiude tutto e stop per la giornata.
- **Max overall loss**: `$1.000` (10%) – limite invalicabile → chiude tutto e stop definitivo.
- **Soft-stop**: a metà del daily loss (`$250`) blocca i nuovi ingressi.
- **Rischio per trade**: 0,5–1% (`$50–100`), lot calcolato dalla distanza dello SL.
- **Lot massimo per trade**: `1.5`.
- Sizing **money-based** robusto: usa `MODE_TICKVALUE` / `MODE_TICKSIZE` del broker,
  quindi il rischio in USD resta corretto qualunque sia la quotazione.

### Ingresso
- Operatività **solo** in sessione **Londra (08:00–12:00 GMT)** e **overlap Londra–NY (13:00–16:00 GMT)**.
- Primi **15 minuti** di Londra: solo osservazione (nessun trade).
- **LONG**: rottura della resistenza del micro-range M15 + chiusura candela sopra il livello +
  `RSI(14) H4 > 50` + volume > media 20 periodi.
- **SHORT**: rottura del supporto M15 + chiusura sotto il livello +
  `RSI(14) H4 < 50` + volume > media 20 periodi.
- Niente inseguimento di breakout estesi oltre **20 pips**.
- **Spread** < 25 pips per entrare.
- Massimo **8–12 trade/giorno** (default 10).
- Filtro **news** opzionale (lista orari GMT da evitare con buffer ±30 min).

### Uscita / gestione
- **Stop Loss** fisso 8–12 pips (default 10).
- **Take Profit** con R:R minimo 1:1.5.
- **Chiusura parziale 50%** a +8 pips.
- **Trailing stop** di 5 pips dopo il parziale.
- **Nessuna posizione overnight**: chiusura forzata di tutto alle **16:00 GMT**.

### Disciplina
- **Pausa revenge trading** di 30 min dopo 2 loss consecutivi.
- Dashboard a schermo con stato, trend, P&L giornaliero/overall, spread, SL dinamico, n. trade.

### Edge / robustezza (v1.10)
Filtri aggiunti per migliorare la qualità dei segnali e la tenuta su mercati reali
(tutti attivabili/disattivabili da input):
- **SL/TP dinamico su ATR** (`UseAtrStops`): stop e target si adattano alla
  volatilità reale invece di usare pips fissi, con clamp min/max per evitare
  stop assurdi. Il TP resta a `SL × RiskRewardRatio`.
- **Filtro trend H4** (`UseTrendFilter`): i breakout LONG si prendono solo con
  prezzo sopra l'EMA H4 in pendenza positiva (e viceversa per gli SHORT). Riduce
  i falsi breakout contro-trend.
- **Filtro volatilità** (`UseVolatilityFilter`): niente trading quando l'ATR del
  timeframe scelto è sotto la soglia (regime di *chop* a bassa volatilità).
- **Partial = frazione dello SL reale** (`PartialAtSlFraction`): la chiusura
  parziale scatta a una frazione dello stop (default 0,8 → +8 pips con SL 10),
  coerente anche con lo SL dinamico ATR.
- **Breakeven automatico** (`UseBreakeven`): dopo il parziale lo stop va a pareggio
  (+ buffer), poi subentra il trailing. Trasforma rapidamente il trade in
  *risk-free*.
- **Guardia spread/SL** (`MaxSpreadToSlRatio`): rifiuta l'entry se lo spread erode
  una frazione eccessiva dello stop (anti-costo su scalping).

---

## Convenzione "pip" su XAU/USD ⚠️ IMPORTANTE

La specifica usa il termine *pip* in modo non univoco. Nell'EA esiste un input
dedicato **`PipSize`** che definisce, **in prezzo**, quanto vale 1 pip:

- `PipSize = 0.10` → convenzione broker più comune (1 pip = 0,10 $ di movimento).
- `PipSize = 1.00` → 1 pip = 1 $ (come nell'esempio "$10 per pip su 0.10 lot").

Tutti i parametri espressi in *pips* (SL, TP, trailing, spread, breakout esteso)
usano questo valore. **Verificare la convenzione del proprio broker** e adattare
`PipSize`, `StopLossPips`, `MaxSpreadPips`, ecc. di conseguenza prima dell'uso.

---

## Parametri principali (input)

| Gruppo | Input | Default | Note |
|--------|-------|---------|------|
| Rischio | `InitialBalance` | 10000 | 0 = usa il saldo corrente |
| Rischio | `MaxDailyLossUSD` | 500 | Limite invalicabile |
| Rischio | `MaxOverallLossUSD` | 1000 | Limite invalicabile |
| Rischio | `RiskPercentPerTrade` | 0.75 | 0,5–1,0 |
| Rischio | `MaxLotPerTrade` | 1.5 | Cap lot |
| Sessioni | `BrokerGMTOffset` | 0 | Offset server vs GMT |
| Sessioni | `LondonStartHour/EndHour` | 8 / 12 | GMT |
| Sessioni | `OverlapStartHour/EndHour` | 13 / 16 | GMT |
| Sessioni | `CloseAllHourGMT` | 16 | Chiusura forzata |
| Ingresso | `RangeLookbackBars` | 12 | Barre M15 per S/R |
| Ingresso | `RsiTimeframe` | H4 | Contesto direzionale |
| Ingresso | `VolumeMAPeriod` | 20 | Media volume |
| Stop/Target | `PipSize` | 0.10 | Vedi nota sopra |
| Stop/Target | `StopLossPips` | 10 | 8–12 |
| Stop/Target | `RiskRewardRatio` | 1.5 | TP = SL × R:R |
| Stop/Target | `PartialClosePips` | 8 | Parziale 50% |
| Stop/Target | `TrailingStopPips` | 5 | Dopo parziale |
| Filtri | `MaxSpreadPips` | 25 | Rifiuta entry oltre |
| Filtri | `MaxTradesPerDay` | 10 | 8–12 |
| Filtri | `NewsTimesGMT` | "" | es. `"12:30,18:00"` |
| Edge | `UseAtrStops` | true | SL/TP su ATR |
| Edge | `AtrSlMultiplier` | 1.2 | SL = ATR × mult |
| Edge | `AtrSlMinPips / MaxPips` | 6 / 18 | Clamp SL |
| Edge | `PartialAtSlFraction` | 0.8 | Parziale a frazione dello SL |
| Edge | `UseBreakeven` | true | BE dopo parziale |
| Edge | `UseTrendFilter` | true | EMA H4 |
| Edge | `TrendEmaPeriod` | 50 | Periodo EMA trend |
| Edge | `UseVolatilityFilter` | true | Floor ATR |
| Edge | `MinVolRangePips` | 150 | Dipende da `PipSize` |
| Edge | `MaxSpreadToSlRatio` | 0.30 | Spread max vs SL |

> **Nota fuso orario**: gli orari di sessione sono in **GMT**. L'EA usa
> `TimeGMT()`. Se il calcolo GMT del terminale non è affidabile, impostare
> `BrokerGMTOffset` e, se necessario, adattare gli orari delle sessioni
> all'ora del server del broker.

---

## Note tecniche e limiti

- Il **filtro news** è manuale (lista orari): MT4 non fornisce un calendario
  economico nativo accessibile da MQL4. Inserire gli orari dei principali eventi
  USD/GOLD (NFP, FOMC, CPI) in `NewsTimesGMT`.
- L'EA gestisce **una sola posizione per volta** (focus ed esposizione controllata).
- Backtest consigliato in modalità **"Every tick"** con dati di qualità; lo
  spread reale incide molto sullo scalping.
- I limiti di daily/overall loss sono calcolati sull'**equity** (floating incluso)
  rispetto, rispettivamente, all'equity di inizio giornata e al saldo di riferimento.

---

## ⚠️ Rendere l'EA profittevole: cosa serve davvero

**Nessuna modifica al codice può *garantire* profittabilità.** I filtri della v1.10
(ATR, trend, volatilità, breakeven) migliorano la *robustezza* — riducono falsi
breakout e operatività nel chop — ma l'unico modo per stabilire se la strategia
guadagna sui tuoi dati e sul tuo broker è **testarla**. Procedura consigliata:

1. **Backtest** nel MT4 Strategy Tester su XAU/USD M15, modalità *"Every tick"*,
   con dati storici di qualità e **spread realistico** (lo spread incide moltissimo
   sullo scalping).
2. **Imposta correttamente** `PipSize` e `BrokerGMTOffset` per il tuo broker
   *prima* di qualsiasi test, altrimenti SL/TP e sessioni saranno sbagliati.
3. **Ottimizza** i parametri chiave su un periodo *in-sample*:
   `AtrSlMultiplier`, `RiskRewardRatio`, `TrendEmaPeriod`, `RangeLookbackBars`,
   `MinVolRangePips`, soglie RSI.
4. **Valida out-of-sample** (walk-forward) su un periodo diverso da quello di
   ottimizzazione per evitare l'*overfitting*: parametri che brillano solo nel
   passato non reggono in reale.
5. **Forward test su demo** per alcune settimane prima del conto reale/funded.

Metriche target coerenti con la specifica: **win rate ≥ 55%** con R:R 1:1.5,
**profit factor ≥ 1.3**. Se il backtest non li raggiunge, agisci sui parametri
sopra prima di operare con denaro reale.
