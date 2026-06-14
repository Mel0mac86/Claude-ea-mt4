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
- Dashboard a schermo con stato, P&L giornaliero/overall, spread, n. trade.

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
