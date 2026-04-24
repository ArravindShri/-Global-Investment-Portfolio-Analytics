# Project 1 Migration Guide: SQL Server → Microsoft Fabric

**Purpose:** Migrate Global Investment Portfolio Analytics from local infrastructure to cloud-native stack.
**Estimated Time:** 6-8 hours
**Prerequisites:** Project 3 (Energy Security) completed on Fabric. Same workspace, Service Principal, and dbt project reusable.

---

## WHAT YOU'RE MIGRATING

| Component | FROM (Local) | TO (Cloud) |
|-----------|-------------|------------|
| Database | SQL Server (local) | Fabric Data Warehouse |
| Bronze ingestion | Python scripts (local) | Fabric Notebooks |
| Silver/Gold transforms | 3 Stored Procedures | dbt models |
| Scheduling | Task Scheduler + SQL Server Agent | GitHub Actions |
| Power BI connection | On-premises Data Gateway + DirectQuery | Fabric direct connection (Import Mode) |
| Tables | 15 total (3 Bronze, 6 Silver, 6 Gold) | Same 15 tables, new platform |

---

## STEP 1: FABRIC SETUP (30 minutes)

### 1.1 Lakehouse
- Open your existing Fabric workspace (same one as Project 3)
- Create a NEW Lakehouse: `lakehouse_investment_portfolio`
- This is where Python notebooks will land Bronze data as Delta tables

### 1.2 Warehouse
- Create a NEW Warehouse: `warehouse_investment_portfolio`
- This is where dbt will create Silver and Gold tables
- Power BI connects to THIS

### 1.3 Verify
- Both should appear in your workspace alongside Project 3's Lakehouse and Warehouse
- Confirm you can open both and see empty schemas

---

## STEP 2: BRONZE LAYER — PYTHON NOTEBOOKS (1-2 hours)

### 2.1 What you have (local)
Your Project 1 has 3 Python scripts:
- Stock prices script (pulls from Twelve Data `/time_series`)
- Forex rates script (pulls from Twelve Data forex endpoint)
- Fundamentals script (pulls from Twelve Data fundamentals endpoint)

### 2.2 What to do
Create 3 Fabric Notebooks (or combine into 1 with sections):

**For each notebook:**
1. Open your existing local Python script
2. Create a new Fabric Notebook in the workspace
3. Copy the API call logic (requests, JSON parsing, DataFrame creation)
4. Replace the SQL Server INSERT logic with Spark `saveAsTable()`

**Key changes from local to Fabric:**
- Remove: `pyodbc` connection strings, `cursor.execute()`, SQL Server INSERT statements
- Add: `spark.createDataFrame()` and `df.write.mode("overwrite").saveAsTable("lakehouse_investment_portfolio.bronze_stock_prices")`
- Keep: API URL construction, headers, JSON parsing, rate limiting (`time.sleep(8)`)
- Keep: Error handling (try/except for API calls)

**Pattern (you did this in Project 3):**
```
# This pattern is identical to your Project 3 notebooks
# 1. Call API
# 2. Parse JSON to list of dictionaries
# 3. Create Spark DataFrame
# 4. Save as Delta table in Lakehouse
```

### 2.3 API Sharing with Project 3
- ONGC and Exxon (XOM) are shared tickers
- Your alternate-day schedule: Project 1 on even days, Project 3 on odd days
- The notebooks should check the day before running (or let GitHub Actions handle scheduling)

### 2.4 Run and Verify
- Run each notebook manually once
- Open Lakehouse → Tables → Verify bronze_stock_prices, bronze_forex_rates, bronze_stock_fundamentals exist
- Check row counts match expectations

---

## STEP 3: REFERENCE TABLES — dbt SEEDS (30 minutes)

### 3.1 What you have (local)
Project 1 has 3 manually-defined reference tables:
- `silver_companies` (12 rows — ticker, company, country, category, region)
- `silver_currency_map` (5 rows — currency codes and forex pairs)
- `silver_calendar` (generated — ~730 rows)

### 3.2 What to do
Create CSV seed files in your dbt project:

```
your_dbt_project/
├── seeds/
│   ├── project1/
│   │   ├── silver_companies.csv
│   │   ├── silver_currency_map.csv
│   │   └── silver_calendar.csv   (or generate via dbt model)
```

**For silver_companies.csv:**
- Open your SQL Server table
- Export the 12 rows to CSV
- Place in seeds/project1/

**For silver_currency_map.csv:**
- Same process — 5 rows to CSV

**For silver_calendar:**
- Option A: Create as a CSV seed (730 rows — tedious but works)
- Option B: Create as a dbt model that generates dates (you can reuse Project 3's approach)

### 3.3 Run seeds
```
dbt seed --select project1
```

### 3.4 Update sources.yml
Add Project 1's Lakehouse as a source in your dbt project's sources.yml:

```yaml
# Add this to your existing sources.yml
- name: lakehouse_investment_portfolio
  schema: dbo
  database: lakehouse_investment_portfolio
  tables:
    - name: bronze_stock_prices
    - name: bronze_forex_rates
    - name: bronze_stock_fundamentals
```

---

## STEP 4: SILVER LAYER — dbt MODELS (1-1.5 hours)

### 4.1 What you have (local)
Your `sp_refresh_silver` stored procedure contains all Silver transformations:
- Clean stock prices + calculate daily_return_pct (LAG window function)
- Clean forex rates + normalize to INR
- Clean fundamentals + validate nulls

### 4.2 What to do
Create dbt models in your project:

```
your_dbt_project/
├── models/
│   ├── project1/
│   │   ├── silver/
│   │   │   ├── silver_stock_prices.sql
│   │   │   ├── silver_forex_rates.sql
│   │   │   └── silver_stock_fundamentals.sql
│   │   ├── gold/
│   │   │   ├── (Step 5)
```

**For each Silver model:**
1. Open your stored procedure `sp_refresh_silver`
2. Find the section that creates/refreshes that specific Silver table
3. Copy ONLY the SELECT statement (the transformation logic)
4. Remove: `CREATE PROCEDURE`, `BEGIN/END`, `TRUNCATE TABLE`, `INSERT INTO`
5. Add: dbt config block at the top
6. Replace: direct table references with `{{ source('lakehouse_investment_portfolio', 'bronze_stock_prices') }}` for Bronze tables and `{{ ref('silver_companies') }}` for seed tables

**Config block pattern:**
```sql
{{ config(
    materialized='table',
    schema='dbo'
) }}

-- Your SELECT statement from the stored procedure goes here
-- Replace table names with source() and ref()
```

**Important Fabric/dbt notes:**
- Fabric's T-SQL may have minor syntax differences from SQL Server — check date functions
- Use `{{ source() }}` for Bronze tables (in Lakehouse)
- Use `{{ ref() }}` for seed tables and other models (in Warehouse)
- You already solved the cross-database query pattern in Project 3 (Lakehouse → Warehouse via sources.yml)

### 4.3 Run and verify
```
dbt run --select project1.silver
```
- Check each Silver table in Warehouse
- Run 2-3 sanity check queries:
  - Row count matches expected (12 tickers × ~500 trading days)
  - daily_return_pct values look reasonable (-5% to +5% range)
  - No NULL close_prices where data should exist

---

## STEP 5: GOLD LAYER — dbt MODELS (1.5-2 hours)

### 5.1 What you have (local)
Your `sp_refresh_gold` stored procedure contains all Gold transformations:
- gold_stock_performance (current metrics per stock)
- gold_currency_adjusted_returns (INR returns)
- gold_category_performance (average per category)
- gold_region_performance (average per region)
- gold_dividend_analysis (dividend yields)
- gold_correlation_matrix (66 unique pairs)

### 5.2 What to do
Create dbt models:

```
your_dbt_project/
├── models/
│   ├── project1/
│   │   ├── gold/
│   │   │   ├── gold_stock_performance.sql
│   │   │   ├── gold_currency_adjusted_returns.sql
│   │   │   ├── gold_category_performance.sql
│   │   │   ├── gold_region_performance.sql
│   │   │   ├── gold_dividend_analysis.sql
│   │   │   └── gold_correlation_matrix.sql
```

**Same conversion process as Silver:**
1. Open `sp_refresh_gold`
2. Extract each Gold table's SELECT logic
3. Remove procedure wrapper
4. Add config block
5. Replace table references with `{{ ref('silver_stock_prices') }}`, `{{ ref('silver_companies') }}`, etc.

**The correlation matrix** is your most complex model — 66 pairs with Pearson correlation. You wrote this SQL yourself in Project 1. The logic doesn't change — only the table references.

### 5.3 Additional Gold table
Project 1 had a 7th Gold table added mid-project: `gold_daily_inr_returns`. Check your local SQL Server for the exact list and include all of them.

### 5.4 Run and verify
```
dbt run --select project1.gold
```
- Verify gold_stock_performance has 12 rows (one per stock)
- Verify gold_correlation_matrix has 66 rows
- Spot-check: does the Sharpe ratio for Exxon look reasonable?
- Spot-check: does the INR-adjusted return for ONGC differ from the local return?

---

## STEP 6: GITHUB ACTIONS (30 minutes)

### 6.1 What you have
Your Project 3 GitHub Actions workflow already exists. You need to ADD Project 1 to it.

### 6.2 What to do
Option A: Add Project 1 steps to the existing workflow with even-day scheduling
Option B: Create a separate workflow file for Project 1

**Recommended: Option A** — single workflow, conditional execution:
- Check day of month: even = Project 1, odd = Project 3
- Project 1 steps: run notebooks → run `dbt run --select project1`

### 6.3 Update GitHub Secrets
- Project 1 uses the same Twelve Data API key — already in secrets
- Same Service Principal — already configured
- No new secrets needed

### 6.4 Test
- Push the updated workflow
- Trigger manually via GitHub Actions UI
- Verify: notebooks ran → Bronze populated → dbt ran → Silver/Gold populated

---

## STEP 7: POWER BI (1 hour)

### 7.1 What you have
Your existing Power BI file (.pbix) with 10 dashboard pages connected to local SQL Server.

### 7.2 What to do

**Option A: Reconnect existing file**
1. Open your .pbix file
2. Home → Transform Data → Data Source Settings
3. Change the connection from SQL Server to Fabric Warehouse
4. Map each table to its Fabric equivalent (same names = easy)
5. Verify all visuals still work
6. Publish to Power BI Service

**Option B: New file connected to Fabric**
1. Create new .pbix
2. Get Data → Microsoft Fabric → Select your Warehouse
3. Import all Gold tables
4. Rebuild visuals (you have the original as reference)

**Recommended: Option A** — faster, preserves all your DAX measures, formatting, and layout.

### 7.3 Import Mode
- Set storage mode to **Import** (not DirectQuery, not Direct Lake)
- This ensures the dashboard survives Fabric trial expiration
- Schedule refresh in Power BI Service (or rely on GitHub Actions trigger)

### 7.4 Publish
- Publish to Power BI Service
- Verify all 10 pages render correctly
- Test slicers and filters

---

## STEP 8: THE LAPTOP-OFF TEST (30 minutes)

1. Close everything on your laptop
2. Wait for the next scheduled GitHub Actions run (or trigger manually from your phone via GitHub mobile)
3. After the run completes, open Power BI Service on your phone or another device
4. Verify: dashboard shows fresh data
5. If it works — your pipeline is fully cloud-native

---

## VERIFICATION CHECKLIST

| # | Check | Status |
|---|-------|--------|
| 1 | Lakehouse has 3 Bronze tables with data | ☐ |
| 2 | Warehouse has 3 Silver cleaned tables | ☐ |
| 3 | Warehouse has 3 reference/seed tables | ☐ |
| 4 | Warehouse has 6-7 Gold tables | ☐ |
| 5 | dbt run completes without errors | ☐ |
| 6 | GitHub Actions workflow triggers successfully | ☐ |
| 7 | Power BI connects to Fabric Warehouse | ☐ |
| 8 | All 10 dashboard pages render correctly | ☐ |
| 9 | Slicers and filters work across pages | ☐ |
| 10 | DAX measures calculate correctly | ☐ |
| 11 | Import Mode configured | ☐ |
| 12 | Published to Power BI Service | ☐ |
| 13 | Laptop-off test passed | ☐ |

---

## COMMON PITFALLS (From Project 3 Experience)

1. **Spark vs T-SQL boundary** — Notebooks write to Lakehouse (Spark). dbt writes to Warehouse (T-SQL). Don't mix them.
2. **sources.yml database name** — must exactly match the Lakehouse name in Fabric
3. **Fabric T-SQL differences** — some SQL Server functions may not exist in Fabric. Check if your stored procedure uses any SQL Server-specific syntax.
4. **Date functions** — GETDATE() works in Fabric but SYSDATETIME() may not. Test.
5. **Semantic model refresh** — after publishing Power BI, you may need to configure credentials for the semantic model to refresh from Fabric.
6. **Column name case sensitivity** — Fabric may treat column names differently than SQL Server. Verify exact case matches.

---

## TIMELINE

| Step | Duration | Cumulative |
|------|----------|------------|
| 1. Fabric Setup | 30 min | 0:30 |
| 2. Bronze Notebooks | 1.5 hrs | 2:00 |
| 3. dbt Seeds | 30 min | 2:30 |
| 4. Silver dbt Models | 1.5 hrs | 4:00 |
| 5. Gold dbt Models | 2 hrs | 6:00 |
| 6. GitHub Actions | 30 min | 6:30 |
| 7. Power BI | 1 hr | 7:30 |
| 8. Laptop-off Test | 30 min | 8:00 |

---

*Migration guide created: April 24, 2026*
*Target completion: April 24-25, 2026*
