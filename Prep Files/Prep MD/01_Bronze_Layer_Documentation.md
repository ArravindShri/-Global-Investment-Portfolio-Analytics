# Bronze Layer Documentation
## Global Investment Portfolio Analytics

**Last Updated:** April 4, 2026  
**Author:** Arravind Shri  
**Database:** Global_Portfolio_Analysis (SQL Server 17.0, localhost)

---

## Overview

The Bronze layer stores raw, untouched API data exactly as received from external sources. No transformations are applied — this serves as the system of record and audit trail. Three tables capture stock prices, fundamentals, and forex rates.

---

## Data Sources

| Source | API | Tier | Cost | Rate Limit |
|--------|-----|------|------|------------|
| Twelve Data | `/time_series` | Grow | $29/month | 55 calls/day |
| Twelve Data | `/exchange_rate` | Grow | Included | 55 calls/day |
| Yahoo Finance | `yfinance` Python library | Free | $0 | No hard limit |

---

## Tables

### 1. bronze_stock_prices

**Source:** Twelve Data `/time_series` endpoint  
**Refresh:** Daily at 2:30 AM IST via Windows Task Scheduler  
**Row Count:** ~6,000+ (12 stocks × ~250 trading days × 2+ years)  
**Script:** `Bronze_stock_ingestionrealtimedata.py`

```sql
CREATE TABLE bronze_stock_prices (
    ticker VARCHAR(50) NOT NULL,
    trade_date DATE NOT NULL,
    open_price DECIMAL(18,4),
    high_price DECIMAL(18,4),
    low_price DECIMAL(18,4),
    close_price DECIMAL(18,4),
    volume BIGINT,
    exchange VARCHAR(20),
    currency VARCHAR(10),
    api_fetched_at DATETIME DEFAULT GETDATE()
)
```

**Stocks Tracked (12 total):**

| Ticker | Company | Exchange | Currency | API Symbol | Category |
|--------|---------|----------|----------|------------|----------|
| CEG | Constellation Energy | NASDAQ | USD | CEG | Nuclear |
| RR | Rolls-Royce | LSE | GBP | RR | Nuclear |
| BHEL | Bharat Heavy Electricals | NSE | INR | BHEL | Nuclear |
| MP | MP Materials | NYSE | USD | MP | Rare Earth |
| RBW | Rainbow Rare Earths | LSE | GBP | RBW | Rare Earth |
| GMDCLTD | Gujarat Mineral Dev. Corp | NSE | INR | GMDCLTD | Rare Earth |
| XOM | ExxonMobil | NYSE | USD | XOM | Oil |
| SHEL | Shell | LSE | GBP | SHEL | Oil |
| ONGC | Oil & Natural Gas Corp | NSE | INR | ONGC | Oil |
| F | Ford Motor Company | NYSE | USD | F | Automotive |
| VOW | Volkswagen | XETRA | EUR | VOW3 | Automotive |
| TMPV | Tata Motors (Post-Demerger) | NSE | INR | TMPV | Automotive |

**Critical Implementation Notes:**

1. **Exchange Parameter Required:** Non-US stocks must include the `exchange` parameter in API calls. Without it, Twelve Data defaults to US exchanges, pulling wrong data.

```python
exchange_map = {
    'CEG': 'NASDAQ', 'MP': 'NYSE', 'XOM': 'NYSE', 'F': 'NYSE',
    'RR': 'LSE', 'RBW': 'LSE', 'SHEL': 'LSE',
    'BHEL': 'NSE', 'GMDCLTD': 'NSE', 'ONGC': 'NSE', 'TMPV': 'NSE',
    'VOW': 'XETR'
}
```

2. **API Symbol Mapping:** Volkswagen trades as `VOW3` on XETRA in Twelve Data, not `VOW`.

```python
api_symbol_map = {'VOW': 'VOW3'}
```

3. **GBp vs GBP:** LSE stocks (RR, RBW, SHEL) return prices in pence (GBp), not pounds (GBP). The Bronze layer stores raw pence values. Conversion happens in Silver layer.

4. **Dynamic Date Logic:** The ingestion script uses lookback windows and duplicate-check logic, never hardcoded dates.

---

### 2. bronze_stock_fundamentals

**Source:** Yahoo Finance via `yfinance` Python library  
**Refresh:** Quarterly (manual trigger)  
**Row Count:** 12 (one per stock — latest snapshot)  
**Script:** `Bronze_fundamentals_ingestion.py`

```sql
CREATE TABLE bronze_stock_fundamentals (
    ticker VARCHAR(50) NOT NULL,
    report_date DATE,
    market_cap BIGINT,
    pe_ratio DECIMAL(18,4),
    pb_ratio DECIMAL(18,4),
    dividend_yield DECIMAL(18,6),
    dividend_per_share DECIMAL(18,4),
    revenue BIGINT,
    net_profit BIGINT,
    roe DECIMAL(18,4),
    debt_to_equity DECIMAL(18,4),
    book_value DECIMAL(18,4),
    shares_outstanding BIGINT,
    api_fetched_at DATETIME DEFAULT GETDATE()
)
```

**Yahoo Finance Ticker Mapping:**

| DB Ticker | Yahoo Ticker | Notes |
|-----------|-------------|-------|
| RR | RR.L | LSE suffix required |
| RBW | RBW.L | LSE suffix required |
| SHEL | SHEL.L | LSE suffix required |
| VOW | VOW3.DE | XETRA suffix required |
| TMPV | TMPV.NS | NSE suffix (post-demerger Oct 2025) |
| BHEL | BHEL.NS | NSE suffix required |
| GMDCLTD | GMDCLTD.NS | NSE suffix required |
| ONGC | ONGC.NS | NSE suffix required |
| CEG, MP, XOM, F | Same | No suffix needed for US stocks |

**Known Data Issues:**
- RBW (Rainbow Rare Earths) is a pre-revenue exploration company — revenue and net_profit are legitimately NULL
- `face_value` column was dropped — Yahoo Finance does not provide it
- TMPV listed post-demerger (October 2025) — limited historical data

---

### 3. bronze_forex_rates

**Source:** Twelve Data forex endpoint  
**Refresh:** Daily at 2:30 AM IST via Windows Task Scheduler  
**Row Count:** ~2,000+ (4 currency pairs × ~500 trading days)  
**Script:** `Bronze_forex_ingestion.py`

```sql
CREATE TABLE bronze_forex_rates (
    currency_pair VARCHAR(20) NOT NULL,
    trade_date DATE NOT NULL,
    open_rate DECIMAL(18,6),
    high_rate DECIMAL(18,6),
    low_rate DECIMAL(18,6),
    close_rate DECIMAL(18,6),
    api_fetched_at DATETIME DEFAULT GETDATE()
)
```

**Currency Pairs Tracked:**

| Pair | Purpose |
|------|---------|
| USD/INR | US stocks (CEG, MP, XOM, F) |
| GBP/INR | UK stocks (RR, RBW, SHEL) |
| EUR/INR | German stocks (VOW) |

**Note:** INR stocks (BHEL, GMDCLTD, ONGC, TMPV) do not need forex conversion — handled via COALESCE(forex_rate, 1) in Gold layer.

---

## Ingestion Architecture

```
Windows Task Scheduler (2:30 AM IST daily)
    │
    ├── Bronze_stock_ingestionrealtimedata.py
    │       → Twelve Data /time_series API
    │       → INSERT INTO bronze_stock_prices
    │
    └── Bronze_forex_ingestion.py
            → Twelve Data /exchange_rate API
            → INSERT INTO bronze_forex_rates

Manual (Quarterly):
    └── Bronze_fundamentals_ingestion.py
            → Yahoo Finance yfinance library
            → INSERT INTO bronze_stock_fundamentals
```

---

## Verification Queries

```sql
-- Check latest stock data
SELECT TOP 5 * FROM bronze_stock_prices ORDER BY trade_date DESC

-- Check latest forex data
SELECT TOP 5 * FROM bronze_forex_rates ORDER BY trade_date DESC

-- Verify all 12 stocks present
SELECT ticker, COUNT(*) as row_count, MIN(trade_date) as earliest, MAX(trade_date) as latest
FROM bronze_stock_prices
GROUP BY ticker
ORDER BY ticker

-- Check fundamentals
SELECT ticker, market_cap, pe_ratio, dividend_yield FROM bronze_stock_fundamentals
```
