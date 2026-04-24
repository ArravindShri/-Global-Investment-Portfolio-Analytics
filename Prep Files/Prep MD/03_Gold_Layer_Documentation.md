# Gold Layer Documentation
## Global Investment Portfolio Analytics

**Last Updated:** April 4, 2026  
**Author:** Arravind Shri  
**Database:** Global_Portfolio_Analysis (SQL Server 17.0, localhost)

---

## Overview

The Gold layer contains analytics-ready tables designed for direct consumption by Power BI. Seven tables serve the 10-page dashboard, each pre-aggregated to minimize DirectQuery load. All Gold tables are rebuilt daily via `sp_refresh_gold`.

**Stored Procedure:** `sp_refresh_gold` (7 steps, called by `sp_daily_refresh` at 3:00 AM IST)

---

## Tables

### 1. gold_stock_performance

**Serves:** Pages 1-4 (Category pages: Nuclear, Rare Earth, Oil, Automotive)  
**Size:** 12 rows (one per stock, refreshed daily)

```sql
CREATE TABLE gold_stock_performance (
    ticker VARCHAR(50) NOT NULL PRIMARY KEY,
    company_name VARCHAR(200),
    category VARCHAR(50),
    region VARCHAR(50),
    currency VARCHAR(10),
    current_price DECIMAL(18,4),
    yoy_return_pct DECIMAL(18,4),
    week_52_high DECIMAL(18,4),
    week_52_low DECIMAL(18,4),
    volatility DECIMAL(18,4),
    sharpe_ratio DECIMAL(18,4),
    pe_ratio DECIMAL(18,4),
    market_cap BIGINT,
    roe DECIMAL(18,4),
    debt_to_equity DECIMAL(18,4),
    dividend_yield DECIMAL(18,6)
)
```

**Key Calculations:**

- **current_price:** Latest close_price from silver_stock_prices (ROW_NUMBER DESC)
- **yoy_return_pct:** `(current_price - year_ago_price) / year_ago_price * 100`
  - Uses COALESCE fallback to earliest_price for stocks with < 1 year history (TMPV)
- **week_52_high/low:** MAX/MIN of high_price/low_price over last 365 days
- **volatility:** STDEV(daily_return_pct) over last 365 days
- **sharpe_ratio:** `yoy_return_pct / volatility` (simplified, assumes risk-free rate = 0)

**TMPV Handling:** Post-demerger (Oct 2025) stock lacks full YoY data. An `earliest_prices` CTE with COALESCE ensures TMPV uses its earliest available price instead of being dropped.

---

### 2. gold_currency_adjusted_returns

**Serves:** Page 5 (Currency Appreciation) — summary cards  
**Size:** 12 rows (one per stock)

```sql
CREATE TABLE gold_currency_adjusted_returns (
    ticker VARCHAR(50) NOT NULL PRIMARY KEY,
    company_name VARCHAR(200),
    category VARCHAR(50),
    region VARCHAR(50),
    original_currency VARCHAR(10),
    return_local_pct DECIMAL(18,4),
    inr_start_rate DECIMAL(18,6),
    inr_end_rate DECIMAL(18,6),
    return_inr_pct DECIMAL(18,4),
    currency_impact_pct DECIMAL(18,4)
)
```

**Key Calculations:**

- **return_inr_pct:** `((1 + return_local/100) * (end_rate/start_rate) - 1) * 100`
  - For INR stocks: return_inr_pct = return_local_pct (no forex effect)
- **currency_impact_pct:** `return_inr_pct - return_local_pct`
  - Positive = rupee weakness added returns
  - Zero for INR-denominated stocks

**This is the project's unique differentiator:** Shows true returns for an Indian investor after forex impact.

---

### 3. gold_category_performance

**Serves:** Page 6 (Overall Category Performance) — pre-calculated summaries  
**Size:** 4 rows (Nuclear, Rare Earth Minerals, Oil, Automotive)

```sql
CREATE TABLE gold_category_performance (
    category VARCHAR(50) NOT NULL PRIMARY KEY,
    average_yoy_return_pct DECIMAL(18,4),
    avg_volatility DECIMAL(18,4),
    best_stock VARCHAR(50),
    worst_stock VARCHAR(50),
    avg_pe_ratio DECIMAL(18,4),
    total_market_cap BIGINT,
    avg_dividend_yield DECIMAL(18,6)
)
```

**Note:** Page 6 primarily uses DAX measures (AVERAGEX pattern) for dynamic year-filtered calculations. This table serves as a reference/validation source.

---

### 4. gold_region_performance

**Serves:** Page 8 (Portfolio Diversification Analysis)  
**Size:** 3 rows (North America, Europe, Asia)

```sql
CREATE TABLE gold_region_performance (
    region VARCHAR(50) NOT NULL PRIMARY KEY,
    avg_yoy_return_pct DECIMAL(18,4),
    avg_volatility DECIMAL(18,4),
    avg_sharpe_ratio DECIMAL(18,4),
    stock_count INT,
    best_category VARCHAR(50),
    avg_currency_impact_pct DECIMAL(18,4)
)
```

---

### 5. gold_dividend_analysis

**Serves:** Page 7 (Highest Dividend)  
**Size:** 12 rows

```sql
CREATE TABLE gold_dividend_analysis (
    ticker VARCHAR(50) NOT NULL PRIMARY KEY,
    company_name VARCHAR(200),
    category VARCHAR(50),
    region VARCHAR(50),
    stock_price DECIMAL(18,4),
    annual_dividend DECIMAL(18,4),
    dividend_yield_pct DECIMAL(18,6),
    payout_ratio DECIMAL(18,4),
    dividend_in_inr DECIMAL(18,4),
    pays_dividend BIT
)
```

**Key Calculations:**

- **payout_ratio:** `dividend_per_share / (net_profit / shares_outstanding)` — uses NULLIF to prevent division by zero
- **dividend_in_inr:** `dividend_per_share * current_forex_rate` — for INR stocks, equals dividend_per_share directly
- **pays_dividend:** 1 if dividend_yield is not NULL, 0 otherwise

---

### 6. gold_correlation_matrix

**Serves:** Page 8 (Portfolio Diversification Analysis)  
**Size:** 66 rows (12 stocks × 11 / 2 = 66 unique pairs)

```sql
CREATE TABLE gold_correlation_matrix (
    stock_1 VARCHAR(50) NOT NULL,
    stock_2 VARCHAR(50) NOT NULL,
    stock_1_category VARCHAR(50),
    stock_2_category VARCHAR(50),
    stock_1_region VARCHAR(50),
    stock_2_region VARCHAR(50),
    correlation_coefficient DECIMAL(18,4),
    relationship VARCHAR(50),
    PRIMARY KEY (stock_1, stock_2)
)
```

**Pearson Correlation Formula (SQL Implementation):**

```sql
(COUNT(*) * SUM(r1 * r2) - SUM(r1) * SUM(r2)) /
NULLIF(SQRT(
    (COUNT(*) * SUM(r1 * r1) - SUM(r1) * SUM(r1)) *
    (COUNT(*) * SUM(r2 * r2) - SUM(r2) * SUM(r2))
), 0)
```

**Relationship Classification:**
- >= 0.7: Strong Positive
- >= 0.3: Weak Positive
- >= -0.3: Uncorrelated
- < -0.3: Negative

**Note:** Uses `WHERE s1.ticker < s2.ticker` to avoid duplicate pairs (CEG-RR is same as RR-CEG).

---

### 7. gold_daily_inr_returns

**Serves:** Pages 5-7 (Currency Appreciation, Category Performance, Dividend) — daily time-series for dynamic DAX calculations  
**Size:** ~5,658 rows (12 stocks × ~470 trading days)

```sql
CREATE TABLE gold_daily_inr_returns (
    ticker VARCHAR(50) NOT NULL,
    trade_date DATE NOT NULL,
    close_price DECIMAL(10,2) NOT NULL,
    close_price_inr DECIMAL(10,2) NOT NULL,
    daily_return_local_pct DECIMAL(10,2),
    daily_return_inr_pct DECIMAL(10,2),
    forex_rate DECIMAL(10,2) NOT NULL,
    currency_pair VARCHAR(50),
    PRIMARY KEY (ticker, trade_date)
)
```

**Key Calculations:**

- **close_price_inr:** `close_price * COALESCE(sfr.close_rate, 1)` — multiplied by 1 for INR stocks
- **daily_return_inr_pct:** LAG-based formula on close_price_inr:
```sql
(close_price * COALESCE(close_rate, 1) - 
 LAG(close_price * COALESCE(close_rate, 1)) OVER (PARTITION BY ticker ORDER BY trade_date)) /
LAG(close_price * COALESCE(close_rate, 1)) OVER (PARTITION BY ticker ORDER BY trade_date) * 100
```
- **forex_rate:** `COALESCE(sfr.close_rate, 1)` — defaults to 1 for INR stocks
- **currency_pair:** NULL for INR stocks (no forex pair exists)

**JOIN Chain:**
```
silver_stock_prices
    → JOIN silver_companies (ticker)
    → JOIN silver_currency_map (currency = currency_code)
    → LEFT JOIN silver_forex_rates (forex_pair = currency_pair AND trade_date)
```

**This table is critical for dynamic DAX measures** — it enables year-filtered calculations on Pages 5, 6, and 7 that the static Gold summary tables cannot support.

---

## Stored Procedure: sp_refresh_gold

```sql
ALTER PROCEDURE sp_refresh_gold
AS
BEGIN
    BEGIN TRY
        -- Step 1: TRUNCATE + INSERT gold_stock_performance
        -- Step 2: TRUNCATE + INSERT gold_currency_adjusted_returns
        -- Step 3: TRUNCATE + INSERT gold_category_performance
        -- Step 4: TRUNCATE + INSERT gold_region_performance
        -- Step 5: TRUNCATE + INSERT gold_dividend_analysis
        -- Step 6: TRUNCATE + INSERT gold_correlation_matrix
        -- Step 7: TRUNCATE + INSERT gold_daily_inr_returns
        
        PRINT 'Gold layer refresh complete.'
    END TRY
    BEGIN CATCH
        PRINT 'Error refreshing Gold layer: ' + ERROR_MESSAGE()
    END CATCH
END
```

**Execution:** `EXEC sp_refresh_gold`  
**Triggered By:** `sp_daily_refresh` → calls `sp_refresh_silver` first, then `sp_refresh_gold`

---

## Data Flow Summary

```
silver_stock_prices ──────┐
silver_stock_fundamentals ┤
silver_companies ─────────┤──→ gold_stock_performance (12 rows)
silver_forex_rates ───────┤──→ gold_currency_adjusted_returns (12 rows)
silver_currency_map ──────┘──→ gold_category_performance (4 rows)
                           ──→ gold_region_performance (3 rows)
                           ──→ gold_dividend_analysis (12 rows)
                           ──→ gold_correlation_matrix (66 rows)
                           ──→ gold_daily_inr_returns (~5,658 rows)
```

---

## Verification Queries

```sql
-- Verify all Gold tables populated
SELECT 'gold_stock_performance' as tbl, COUNT(*) as rows FROM gold_stock_performance
UNION ALL SELECT 'gold_currency_adjusted_returns', COUNT(*) FROM gold_currency_adjusted_returns
UNION ALL SELECT 'gold_category_performance', COUNT(*) FROM gold_category_performance
UNION ALL SELECT 'gold_region_performance', COUNT(*) FROM gold_region_performance
UNION ALL SELECT 'gold_dividend_analysis', COUNT(*) FROM gold_dividend_analysis
UNION ALL SELECT 'gold_correlation_matrix', COUNT(*) FROM gold_correlation_matrix
UNION ALL SELECT 'gold_daily_inr_returns', COUNT(*) FROM gold_daily_inr_returns

-- Expected: 12, 12, 4, 3, 12, 66, ~5658

-- Verify TMPV has data despite limited history
SELECT ticker, yoy_return_pct, current_price FROM gold_stock_performance WHERE ticker = 'TMPV'

-- Verify INR stocks have forex_rate = 1
SELECT TOP 5 * FROM gold_daily_inr_returns WHERE ticker = 'ONGC' ORDER BY trade_date DESC

-- Verify correlation pairs
SELECT COUNT(*) as pairs FROM gold_correlation_matrix  -- Should be 66
```
