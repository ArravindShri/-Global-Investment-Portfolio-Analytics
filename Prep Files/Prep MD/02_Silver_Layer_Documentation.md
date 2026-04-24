# Silver Layer Documentation
## Global Investment Portfolio Analytics

**Last Updated:** April 4, 2026  
**Author:** Arravind Shri  
**Database:** Global_Portfolio_Analysis (SQL Server 17.0, localhost)

---

## Overview

The Silver layer contains cleaned, validated, and enriched data transformed from Bronze tables. It includes three transformed tables and three manually-defined reference tables. Key transformations: duplicate removal, null handling, GBp-to-GBP conversion, daily return calculation, and data quality flagging.

**Stored Procedure:** `sp_refresh_silver` (called by `sp_daily_refresh` at 3:00 AM IST)

---

## Transformed Tables

### 1. silver_stock_prices

**Source:** `bronze_stock_prices`  
**Row Count:** ~6,000+ (matches Bronze after deduplication)

```sql
CREATE TABLE silver_stock_prices (
    ticker VARCHAR(50) NOT NULL,
    trade_date DATE NOT NULL,
    open_price DECIMAL(18,4),
    high_price DECIMAL(18,4),
    low_price DECIMAL(18,4),
    close_price DECIMAL(18,4),
    volume BIGINT,
    daily_return_pct DECIMAL(18,4),
    is_valid BIT DEFAULT 1,
    PRIMARY KEY (ticker, trade_date)
)
```

**Transformations Applied:**

1. **Duplicate Removal:** ROW_NUMBER() partitioned by ticker + trade_date, keeping the latest api_fetched_at record.

2. **GBp to GBP Conversion:** LSE stocks (RR, RBW, SHEL) arrive in pence. All four price columns converted:
```sql
CASE WHEN currency = 'GBp' THEN close_price / 100.0 ELSE close_price END
```
Applied to: open_price, high_price, low_price, close_price.

3. **Daily Return Calculation:** Uses LAG window function:
```sql
daily_return_pct = (close_price - LAG(close_price) OVER (PARTITION BY ticker ORDER BY trade_date)) 
                   / LAG(close_price) OVER (PARTITION BY ticker ORDER BY trade_date) * 100
```
First trading day per stock has NULL daily_return_pct (no previous day).

4. **Data Quality Flag:** `is_valid = 1` for all clean records, `0` for imputed or flagged records.

---

### 2. silver_stock_fundamentals

**Source:** `bronze_stock_fundamentals`  
**Row Count:** 12 (one per stock)

```sql
CREATE TABLE silver_stock_fundamentals (
    ticker VARCHAR(50) NOT NULL PRIMARY KEY,
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
    is_valid BIT DEFAULT 1
)
```

**Transformations:** Duplicate removal, null flagging, data type validation. RBW has legitimate NULL revenue/net_profit (pre-revenue company).

---

### 3. silver_forex_rates

**Source:** `bronze_forex_rates`  
**Row Count:** ~2,000+

```sql
CREATE TABLE silver_forex_rates (
    currency_pair VARCHAR(20) NOT NULL,
    trade_date DATE NOT NULL,
    close_rate DECIMAL(18,6),
    daily_change_pct DECIMAL(18,6),
    is_valid BIT DEFAULT 1,
    PRIMARY KEY (currency_pair, trade_date)
)
```

**Transformations:** Duplicate removal, daily change percentage calculated via LAG, only close_rate retained (open/high/low dropped).

---

## Reference Tables (Manually Defined)

### 4. silver_companies

**Size:** 12 rows (one per stock)  
**Purpose:** Central lookup/dimension table. All Power BI slicers and dimensional fields pull from this table.

```sql
CREATE TABLE silver_companies (
    ticker VARCHAR(50) PRIMARY KEY,
    company_name VARCHAR(200),
    country VARCHAR(50),
    exchange VARCHAR(20),
    currency VARCHAR(10),
    category VARCHAR(50),
    region VARCHAR(50)
)
```

**Data:**

| ticker | company_name | country | exchange | currency | category | region |
|--------|-------------|---------|----------|----------|----------|--------|
| CEG | Constellation Energy Corporation | USA | NASDAQ | USD | Nuclear | North America |
| RR | Rolls-Royce | United Kingdom | LSE | GBP | Nuclear | Europe |
| BHEL | Bharat Heavy Electricals Limited | India | NSE | INR | Nuclear | Asia |
| MP | MP Materials Corp | USA | NYSE | USD | Rare Earth Minerals | North America |
| RBW | Rainbow Rare Earths Limited | United Kingdom | LSE | GBP | Rare Earth Minerals | Europe |
| GMDCLTD | Gujarat Mineral Development Corporation | India | NSE | INR | Rare Earth Minerals | Asia |
| XOM | Exxon Mobil Corporation | USA | NYSE | USD | Oil | North America |
| SHEL | Shell PLC | United Kingdom | LSE | GBP | Oil | Europe |
| ONGC | Oil and Natural Gas Corporation | India | NSE | INR | Oil | Asia |
| F | Ford Motor Company | USA | NYSE | USD | Automotive | North America |
| VOW | Volkswagen AG | Germany | XETRA | EUR | Automotive | Europe |
| TMPV | Tata Motors Passenger Vehicles Limited | India | NSE | INR | Automotive | Asia |

---

### 5. silver_currency_map

**Size:** 5 rows  
**Purpose:** Bridges currency codes to Twelve Data forex pair identifiers.

```sql
CREATE TABLE silver_currency_map (
    currency_code VARCHAR(10) PRIMARY KEY,
    currency_name VARCHAR(50),
    currency_country VARCHAR(50),
    forex_pair VARCHAR(20)
)
```

**Data:**

| currency_code | currency_name | currency_country | forex_pair |
|--------------|---------------|-----------------|------------|
| USD | US Dollar | USA | USD/INR |
| GBP | British Pound | United Kingdom | GBP/INR |
| EUR | Euro | Germany | EUR/INR |
| INR | Indian Rupee | India | NULL |
| KRW | South Korean Won | South Korea | NULL |

**Note:** INR has NULL forex_pair — INR stocks don't need currency conversion. KRW retained for schema completeness but not actively used (KEPCO was replaced with BHEL due to API limitations).

---

### 6. silver_calendar

**Size:** ~730 rows (2+ years)  
**Purpose:** Date dimension table for Power BI time intelligence.

```sql
CREATE TABLE silver_calendar (
    date_key DATE PRIMARY KEY,
    day_of_week INT,
    day_name VARCHAR(20),
    week_number INT,
    month_number INT,
    month_name VARCHAR(20),
    quarter INT,
    quarter_name VARCHAR(5),
    year INT,
    is_weekend BIT,
    is_trading_day BIT
)
```

---

## Stored Procedure: sp_refresh_silver

```sql
EXEC sp_refresh_silver
```

**Execution Order:**
1. TRUNCATE all three Silver transformed tables
2. INSERT INTO silver_stock_prices (with GBp conversion + LAG calculation)
3. INSERT INTO silver_stock_fundamentals (with deduplication)
4. INSERT INTO silver_forex_rates (with deduplication + daily change)

**Triggered By:** `sp_daily_refresh` at 3:00 AM IST via SQL Server Agent

---

## Key Design Decisions

1. **GBp Conversion in Silver, Not Bronze:** Bronze stores raw API data. The pence-to-pounds conversion is a transformation that belongs in Silver.

2. **silver_companies as Central Hub:** All Power BI relationships radiate from this table. Slicers always use fields from silver_companies to ensure cross-filter propagation.

3. **Composite Primary Keys:** Both silver_stock_prices (ticker + trade_date) and silver_forex_rates (currency_pair + trade_date) use composite keys for natural uniqueness.

4. **NULL forex_pair for INR:** Rather than creating a fake INR/INR pair, the NULL is handled downstream with COALESCE(forex_rate, 1) in Gold tables.

---

## Verification Queries

```sql
-- Verify GBp conversion worked (RR should be in pounds, not pence)
SELECT TOP 5 ticker, trade_date, close_price FROM silver_stock_prices 
WHERE ticker = 'RR' ORDER BY trade_date DESC

-- Verify daily returns calculated
SELECT ticker, trade_date, close_price, daily_return_pct 
FROM silver_stock_prices WHERE ticker = 'CEG' 
ORDER BY trade_date DESC

-- Verify all 12 companies present
SELECT * FROM silver_companies ORDER BY category, region

-- Verify forex rates
SELECT currency_pair, COUNT(*) as rows, MIN(trade_date) as earliest, MAX(trade_date) as latest
FROM silver_forex_rates GROUP BY currency_pair
```
