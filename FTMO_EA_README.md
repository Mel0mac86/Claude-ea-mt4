# FTMO Expert Advisors (.mq4)

Expert Advisor per MetaTrader 4 **generati dal convertitore della FTMO Strategy App**
(repo [`strategie`](https://github.com/mel0mac86/strategie)). Ogni EA implementa una
strategia diversa ma condivide lo stesso **motore di gestione del rischio conforme FTMO**.

| File | Strategia | Simbolo esempio |
|------|-----------|-----------------|
| `FTMO_trend_pullback_EURUSD.mq4` | Trend (EMA50/200) + pullback su EMA20 | EURUSD |
| `FTMO_session_breakout_US30.mq4` | Breakout del range di sessione asiatica | US30 |
| `FTMO_xau_scalper_XAUUSD.mq4` | Scalping oro con bias EMA21 + momentum | XAUUSD |
| `FTMO_mean_reversion_EURUSD.mq4` | Mean reversion Bollinger + RSI in range | EURUSD |

## Gestione del rischio FTMO (in tutti gli EA)
- **Max Daily Loss 5%** e **Max Overall Loss 10%**: l'operatività si blocca prima di violarli.
- **Lot sizing automatico** per rischio % sul saldo, usando il tick value reale del broker.
- **Reset giornaliero** dell'equity di riferimento e contatore trade del giorno.
- **Lock-in**: stop operatività dopo +X% giornaliero (default 3%).
- **Limite trade/giorno**, **finestra oraria** e **filtro spread** configurabili.
- **Stop Loss / Take Profit** basati su ATR, **break-even** dopo +1R, **magic number** dedicato.

## Parametri principali (input)
`RiskPercent`, `MinRR`, `SL_ATR_Mult`, `ATR_Period`, `TrendTF`, `MaxDailyTrades`,
`MaxDailyLossPct`, `MaxOverallLossPct`, `StopDayProfitPct`, `StartHour`, `EndHour`,
`UseBreakEven`, `MagicNumber`, `MaxSpreadPoints`.

## Installazione
1. Copia il file `.mq4` in `MQL4/Experts/` della tua installazione MT4.
2. In MetaEditor apri il file e premi **Compila** (F7).
3. Trascina l'EA sul grafico del simbolo indicato, abilita **AutoTrading**.
4. Verifica i valori di `MaxDailyLossPct` / `MaxOverallLossPct` rispetto alle regole
   del tuo account FTMO prima di operare in reale.

> ⚠️ Testa sempre prima in **Strategy Tester** e su **conto demo**. Questi EA sono un
> punto di partenza didattico: i parametri vanno ottimizzati per il tuo broker e asset.
