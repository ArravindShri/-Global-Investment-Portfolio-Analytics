# Indexes & Performance Optimization Documentation
## Global Investment Portfolio Analytics

**Last Updated:** April 4, 2026  
**Author:** Arravind Shri  
**Database:** Global_Portfolio_Analysis (SQL Server 17.0, localhost)

---

## Overview

Performance optimization focuses on two areas: indexes on frequently queried columns and stored procedure design using TRUNCATE + INSERT patterns. The database serves Power BI via DirectQuery, meaning every visual interaction triggers a live SQL query — optimization directly impacts dashboard responsiveness.

---

## Indexes

### Primary Key Indexes (Automatic — Clustered)

Every PRIMARY KEY constraint automatically creates a clustered index. These are the most critical indexes in the database.

| Table | Primary Key | Type |
|-------|------------|------|
| silver_companies | ticker | Clustered |
| silver_currency_map | currency_code | Clustered |
| silver_calendar | date_key | Clustered |
| silver_stock_prices | (ticker, trade_date) | Clustered, Composite |
| silver_stock_fundamentals | ticker | Clustered |
| silver_forex_rates | (currency_pair, trade_date) | Clustered, Composite |
| gold_stock_performance | ticker | Clustered |
| gold_currency_adjusted_returns | ticker | Clustered |
| gold_category_performance | category | Clustered |
| gold_region_performance | region | Clustered |
| gold_dividend_analysis | ticker | Clustered |
| gold_correlation_matrix | (stock_1, stock_2) | Clustered, Composite |
| gold_daily_inr_returns | (ticker, trade_date) | Clustered, Composite |

### Non-Clustered Indexes (Manually Created)

```sql
-- Index on trade_date for silver_stock_prices
-- Purpose: Speeds up date-range queries (52-week calculations, YoY returns, 
-- LAG window functions, Power BI date-axis charts)
CREATE NONCLUSTERED INDEX IX_silver_stock_prices_trade_date
ON silver_stock_prices (trade_date)

-- Index on trade_date for silver_forex_rates
-- Purpose: Speeds up date-range joins between stock prices and forex rates
CREATE NONCLUSTERED INDEX IX_silver_forex_rates_trade_date
ON silver_forex_rates (trade_date)
```

**Why these columns:**

1. **silver_stock_prices.trade_date:** The clustered index is on (ticker, trade_date), which is optimal for "give me all dates for CEG." But Gold layer queries often filter by date range across ALL tickers (e.g., `WHERE trade_date >= DATEADD(YEAR, -1, GETDATE())`). The non-clustered index on trade_date alone helps these range scans.

2. **silver_forex_rates.trade_date:** Same reasoning — the JOIN condition `ssp.trade_date = sfr.trade_date` in the gold_daily_inr_returns query benefits from a standalone trade_date index on the forex side.

---

## Stored Procedure Optimization

### TRUNCATE + INSERT Pattern

All Gold table refreshes use TRUNCATE TABLE followed by INSERT. This is significantly faster than:
- DELETE + INSERT (DELETE logs each row individually)
- MERGE (complex logic, slower for full rebuilds)
- DROP + CREATE (loses permissions, indexes, constraints)

```sql
-- Pattern used in sp_refresh_gold for each Gold table
TRUNCATE TABLE gold_stock_performance  -- Instant, minimal logging
INSERT INTO gold_stock_performance ... -- Full rebuild from Silver
```

### CTE-Based Calculations

Complex calculations use Common Table Expressions (CTEs) for readability and query plan optimization:

```sql
;WITH stock_factors AS (...),
current_prices AS (...),
year_ago_prices AS (...),
earliest_prices AS (...)
INSERT INTO gold_stock_performance
SELECT ...
FROM silver_companies sc
JOIN stock_factors sf ON sc.ticker = sf.ticker
JOIN current_prices cp ON cp.ticker = sc.ticker
...
```

Benefits:
- SQL Server can optimize the entire CTE chain as one execution plan
- Each CTE is self-contained and testable independently
- ROW_NUMBER() + WHERE rn = 1 pattern efficiently picks latest/earliest records

### ROW_NUMBER Pattern for Latest/Earliest Values

```sql
-- Get latest price per stock
;WITH current_prices AS (
    SELECT ticker, close_price,
        ROW_NUMBER() OVER (PARTITION BY ticker ORDER BY trade_date DESC) AS rn
    FROM silver_stock_prices
)
SELECT * FROM current_prices WHERE rn = 1
```

This pattern avoids subqueries and is index-friendly with the composite primary key.

---

## DirectQuery Optimization Considerations

### What DirectQuery Means for Performance

Every slicer click, filter change, and page navigation in Power BI sends a live SQL query to the database. There is no cached data. This means:

1. **Small Gold tables are fast:** gold_stock_performance (12 rows), gold_category_performance (4 rows), gold_region_performance (3 rows) — these return instantly regardless of indexing.

2. **Larger tables need indexes:** gold_daily_inr_returns (~5,658 rows) and silver_stock_prices (~6,000 rows) are queried with date filters and ticker filters. The composite primary key (ticker, trade_date) handles most patterns efficiently.

3. **DAX measures translate to SQL:** Power BI converts DAX measures like CALCULATE + FIRSTDATE/LASTDATE into SQL queries with date filtering. The trade_date index helps here.

### Power BI Query Patterns

| Visual Type | SQL Pattern Generated | Index Used |
|------------|----------------------|------------|
| Card with ticker slicer | `WHERE ticker = 'CEG'` | PK (ticker, trade_date) |
| Chart filtered by year | `WHERE trade_date BETWEEN ... AND ...` | IX_trade_date |
| Combo chart (price + volume) | `WHERE ticker = 'CEG' ORDER BY trade_date` | PK (ticker, trade_date) |
| Bar chart (all stocks) | `GROUP BY ticker` | PK (ticker) |
| Correlation matrix | Full scan of 66 rows | No index needed |

---

## Execution Plan Analysis

To analyze any slow query:

```sql
-- Enable execution plan display
SET STATISTICS IO ON
SET STATISTICS TIME ON

-- Or use the graphical plan
-- In SSMS: Ctrl+M (Include Actual Execution Plan), then run query
```

**Key metrics to check:**
- **Logical reads:** Number of data pages read from cache. Lower is better.
- **Scan vs Seek:** Index seeks (direct lookup) are much faster than scans (full table read).
- **Sort operations:** Large sorts indicate missing indexes on ORDER BY columns.

---

## Future Optimization Opportunities

1. **Covering Index on silver_stock_prices:** If DirectQuery performance degrades, consider:
```sql
CREATE NONCLUSTERED INDEX IX_silver_stock_prices_covering
ON silver_stock_prices (trade_date)
INCLUDE (ticker, close_price, volume, daily_return_pct)
```
This would satisfy most Power BI queries without touching the clustered index.

2. **Indexed View for gold_daily_inr_returns:** If the 4-table JOIN in sp_refresh_gold becomes slow, an indexed view could materialize the result.

3. **Partitioning:** Not needed at current data volumes (~6,000 rows) but relevant if expanded to 50+ stocks over 10+ years.

---

## Verification

```sql
-- List all indexes in the database
SELECT 
    t.name AS table_name,
    i.name AS index_name,
    i.type_desc,
    STRING_AGG(c.name, ', ') AS columns
FROM sys.indexes i
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE t.is_ms_shipped = 0
GROUP BY t.name, i.name, i.type_desc
ORDER BY t.name, i.name

-- Check index usage stats (run after using the dashboard)
SELECT 
    OBJECT_NAME(s.object_id) AS table_name,
    i.name AS index_name,
    s.user_seeks, s.user_scans, s.user_lookups
FROM sys.dm_db_index_usage_stats s
JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE database_id = DB_ID('Global_Portfolio_Analysis')
ORDER BY s.user_seeks + s.user_scans DESC
```
