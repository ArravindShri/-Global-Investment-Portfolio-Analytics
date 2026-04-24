# Project 1 Interview Prep: Global Investment Portfolio Analytics
## Questions a Hiring Manager Would Ask — With Answers

**Date:** April 4, 2026  
**Purpose:** Prepare for technical interviews where this project is discussed  
**Format:** Question → What they're really testing → Answer

---

## SECTION 1: PROJECT OVERVIEW & MOTIVATION

### Q1: Walk me through this project in 60 seconds.
**What they're testing:** Can you explain complex work concisely?

**Answer:** I built a live data analytics platform that tracks 12 government-backed stocks across 4 sectors — Nuclear, Rare Earth, Oil, and Automotive — in 3 regions. The unique angle is INR-adjusted currency returns — showing an Indian investor their true return after forex impact, not just the stock's local return. The pipeline pulls data daily from Twelve Data API and Yahoo Finance, transforms it through a Bronze-Silver-Gold medallion architecture in SQL Server, and serves it via DirectQuery to a live Power BI dashboard published through an On-premises Data Gateway.

---

### Q2: Why these 12 stocks specifically? Why not just track the S&P 500 or Nifty 50?
**What they're testing:** Business thinking — did you just pick random stocks or was there a thesis?

**Answer:** The investor thesis is energy transition + government backing as downside protection. Nuclear for clean baseload, rare earth for EV batteries, oil for transition-era diversification, automotive for clean transport. All 12 companies have significant government relationships — some are state-owned. I excluded China despite its rare earth dominance because of foreign investor accessibility constraints. The point isn't market-beating returns — it's historically consistent, inflation-beating returns with government-backed safety nets.

---

### Q3: Why the INR-adjusted returns? What problem does it solve?
**What they're testing:** Can you articulate the unique value proposition?

**Answer:** Most portfolio trackers show returns in the stock's local currency. But if a US stock gains 20% and the rupee weakens from ₹83 to ₹86 per dollar, the Indian investor actually made 24.3%, not 20%. Conversely, if the rupee strengthens, the investor's real return is lower than the headline number. My dashboard shows both — the local return, the INR return, and the currency impact percentage — so the investor knows exactly how much forex helped or hurt. This is especially relevant now with the rupee moving from ₹85 to ₹95 against the dollar over the analysis period.

---

### Q4: Why not just use a free tool like Google Finance or Yahoo Finance for this?
**What they're testing:** Do you understand what you built that doesn't already exist?

**Answer:** Those tools show individual stock prices but don't do cross-regional comparison with currency conversion, correlation analysis between stock pairs, or risk-adjusted returns via Sharpe ratios. My dashboard lets an investor see: "If I put money in XOM (US Oil) vs SHEL (UK Oil) vs ONGC (Indian Oil) — which gave the best return in INR after forex?" No free tool answers that in one view.

---

## SECTION 2: ARCHITECTURE & DESIGN DECISIONS

### Q5: Explain your medallion architecture. Why three layers instead of just raw data and final tables?
**What they're testing:** Do you understand data architecture principles?

**Answer:** Bronze stores raw API data exactly as received — it's the audit trail. If something breaks downstream, I can always go back to Bronze to debug. Silver is the cleaned layer — duplicates removed, GBp converted to GBP for LSE stocks, daily returns calculated via LAG window functions, data quality flags added. Gold is analytics-ready — pre-aggregated tables optimized for Power BI DirectQuery consumption. The separation means I can reprocess Silver from Bronze without re-calling APIs, and rebuild Gold from Silver without touching the cleaning logic. Each layer has a single responsibility.

---

### Q6: Why did you choose DirectQuery over Import mode in Power BI?
**What they're testing:** Do you understand the trade-offs?

**Answer:** My Gold tables rebuild daily at 3 AM via SQL Server Agent. With DirectQuery, every dashboard interaction queries SQL Server live — so the data is always current without manual refresh. Import mode would require scheduling refreshes in Power BI Service and stores a snapshot that can go stale. The trade-off is performance — DirectQuery is slower per interaction because it hits the database each time. But with Gold tables of 12, 4, 3, 66, and ~5,600 rows, the query response time is negligible. For this data volume, DirectQuery is the right choice.

---

### Q7: Why SQL Server? Why not PostgreSQL, or a cloud database like BigQuery?
**What they're testing:** Are you aware of alternatives and can you justify your choice?

**Answer:** SQL Server was chosen for practical reasons — it's what I had available with full Windows integration for Task Scheduler and SQL Server Agent. For a production system, I'd consider PostgreSQL (open source, lower cost) or BigQuery (serverless, no infrastructure management). The SQL skills are transferable — the JOINs, CTEs, window functions, and stored procedures I wrote work with minor syntax changes in any relational database. The architectural patterns (medallion layers, daily refresh, pre-aggregation) are database-agnostic.

---

### Q8: Walk me through what happens at 2:30 AM every day.
**What they're testing:** Do you understand your own automation end-to-end?

**Answer:** At 2:30 AM IST, Windows Task Scheduler triggers a .bat file that runs two Python scripts sequentially. The first calls Twelve Data's `/time_series` API for all 12 stocks — each with the correct exchange parameter to avoid wrong-exchange data — and inserts into `bronze_stock_prices`. The second calls Twelve Data's forex endpoint for USD/INR, GBP/INR, EUR/INR and inserts into `bronze_forex_rates`. Both scripts use dynamic date logic with lookback windows and duplicate-check logic to avoid re-inserting existing data. At 3:00 AM, SQL Server Agent fires `sp_daily_refresh`, which calls `sp_refresh_silver` (truncate and rebuild all three Silver tables from Bronze) followed by `sp_refresh_gold` (truncate and rebuild all seven Gold tables from Silver). By 3:05 AM, the published dashboard reflects today's data via DirectQuery.

---

### Q9: What happens if your machine is off at 2:30 AM?
**What they're testing:** Awareness of failure modes.

**Answer:** The pipeline breaks. Task Scheduler won't fire, Bronze doesn't update, and Silver/Gold stay stale. I've mitigated this by setting sleep, hibernate, and lid-close to "Do nothing" so the VM stays on 24/7. But this is a known weakness — it's a single point of failure. The proper fix is migrating the Python ingestion to GitHub Actions (cloud-native, runs regardless of local machine state) which I'm implementing starting Project 2. The SQL Server Agent job would still need the machine running, but that could be addressed by moving to a cloud database in the future.

---

### Q10: Why did you use a 30-minute gap between Python ingestion and SQL transformation?
**What they're testing:** Thought process behind scheduling decisions.

**Answer:** The Python scripts take 2-5 minutes depending on API response times. The 30-minute gap ensures all Bronze data is fully loaded before Silver/Gold transformations begin. If I set them both at 2:30, the stored procedures might run on yesterday's data because the Python scripts haven't finished yet. The 30 minutes is conservative — I could tighten it to 15 with monitoring, but reliability matters more than speed for a daily batch process.

---

## SECTION 3: SQL & DATA ENGINEERING

### Q11: You have a LAG function in your Silver layer. Explain what it does and why.
**What they're testing:** Can you explain window functions?

**Answer:** LAG looks at the previous row within a partition. I use it to calculate daily return percentage: `(today's close - yesterday's close) / yesterday's close × 100`. The PARTITION BY ticker ensures each stock's returns are calculated independently — CEG's return doesn't accidentally use RR's previous price. ORDER BY trade_date ensures "previous" means the prior trading day. The first row per stock returns NULL because there's no previous day — which is correct, not an error.

---

### Q12: What's the difference between INNER JOIN and LEFT JOIN? Where did you use each and why?
**What they're testing:** JOIN understanding beyond textbook definitions.

**Answer:** INNER JOIN returns only rows with matches on both sides — rows without a match are dropped. LEFT JOIN keeps all rows from the left table even if there's no match on the right. In `gold_daily_inr_returns`, I use INNER JOINs from `silver_stock_prices` to `silver_companies` to `silver_currency_map` because every stock must have a company entry and currency mapping. But I use LEFT JOIN to `silver_forex_rates` because INR stocks have no forex pair — there's no matching row in the forex table. Without LEFT JOIN, all four INR stocks (BHEL, ONGC, GMDCLTD, TMPV) would be silently dropped from the results.

---

### Q13: Explain COALESCE and where you used it.
**What they're testing:** Null handling awareness.

**Answer:** COALESCE returns the first non-NULL value from a list. I used it in two critical places. First, for forex rates: `COALESCE(sfr.close_rate, 1)` — if a stock trades in INR, there's no forex rate (NULL from the LEFT JOIN), so it defaults to 1. Multiplying by 1 means the INR price equals the local price, which is correct. Second, for YoY returns: `COALESCE(year_ago_price, earliest_price)` — TMPV listed in October 2025 and doesn't have a full year of history, so instead of failing, it falls back to the earliest available price.

---

### Q14: Your correlation matrix has 66 rows. How did you get that number?
**What they're testing:** Mathematical/analytical thinking.

**Answer:** 12 stocks taken 2 at a time without repetition: 12 × 11 / 2 = 66 unique pairs. I used `WHERE s1.ticker < s2.ticker` to avoid duplicates — CEG-RR and RR-CEG are the same pair, so I only keep the one where the first ticker is alphabetically smaller. The correlation uses Pearson's formula implemented in pure SQL: `(n × Σxy - Σx × Σy) / √((n × Σx² - (Σx)²) × (n × Σy² - (Σy)²))`.

---

### Q15: What's a CTE and why did you use them instead of subqueries?
**What they're testing:** Code organization and readability.

**Answer:** A CTE (Common Table Expression) is a named temporary result set defined with the WITH keyword. I used multiple CTEs in `sp_refresh_gold` — `stock_factors`, `current_prices`, `year_ago_prices`, `earliest_prices` — each calculating one piece of the puzzle. The advantages over subqueries: each CTE is independently readable and testable, SQL Server can optimize the entire chain as one execution plan, and if I need to debug, I can run any individual CTE in isolation. The code reads top-to-bottom like a recipe instead of nested inside-out like subqueries.

---

### Q16: What does TRUNCATE TABLE do and why did you use it instead of DELETE?
**What they're testing:** Performance awareness.

**Answer:** TRUNCATE removes all rows from a table with minimal logging — it deallocates data pages rather than logging individual row deletions. DELETE logs every row removal individually, which is much slower for full-table rebuilds. Since my stored procedures rebuild Gold tables entirely from Silver data every day, TRUNCATE + INSERT is the fastest pattern. I didn't use DROP + CREATE because that would lose indexes, constraints, and permissions.

---

### Q17: You have two non-clustered indexes. Why those specific columns?
**What they're testing:** Do you understand indexing or did you just add them because someone told you to?

**Answer:** Both indexes are on `trade_date` — one on `silver_stock_prices` and one on `silver_forex_rates`. The clustered indexes are on the composite primary keys (ticker + trade_date), which are optimal for "give me all dates for one stock." But my Gold layer queries often filter by date range across ALL tickers — like `WHERE trade_date >= DATEADD(YEAR, -1, GETDATE())` for 52-week calculations. The non-clustered index on trade_date alone helps these cross-ticker date range scans. For DirectQuery, this matters because every slicer click sends a live query.

---

### Q18: What's the Sharpe Ratio and how did you calculate it?
**What they're testing:** Do you understand the finance metrics you're showing?

**Answer:** The Sharpe Ratio measures return per unit of risk. Formula: (Return - Risk-free rate) / Volatility. A stock returning 20% with 5% volatility (Sharpe = 4) is better risk-adjusted than one returning 30% with 15% volatility (Sharpe = 2). I simplified by assuming risk-free rate = 0, so it's just YoY return divided by volatility (standard deviation of daily returns). Higher is better. In my data, RBW had the highest Sharpe ratio despite not having the highest raw return — because its return relative to its risk was most efficient.

---

## SECTION 4: DATA QUALITY & EDGE CASES

### Q19: What edge cases did you encounter and how did you handle them?
**What they're testing:** Real-world problem-solving, not textbook answers.

**Answer:** Five major ones:

1. **GBp vs GBP:** Twelve Data returns LSE stock prices in pence (GBp), not pounds. RR at 600 GBp is actually £6.00. I added `CASE WHEN currency = 'GBp' THEN price / 100.0 ELSE price END` to all four price columns in the Silver transformation, including the LAG calculation for daily returns.

2. **Wrong exchange data:** Without the `exchange` parameter in API calls, Twelve Data defaults to US exchanges. RR pulled as a US stock in USD instead of LSE in GBP. I added an `exchange_map` dictionary to the Python script mapping each ticker to its correct exchange.

3. **VOW3 symbol:** Volkswagen trades as VOW3 on XETRA in Twelve Data's system, not VOW. I added an `api_symbol_map` to translate before API calls.

4. **TMPV insufficient history:** Tata Motors Passenger Vehicles listed in October 2025 after a demerger — only 5 months of data, not a full year for YoY calculations. Instead of dropping it, I used `COALESCE(year_ago_price, earliest_price)` to fall back to the earliest available price.

5. **INR stocks in forex joins:** Indian stocks have no forex pair, so LEFT JOIN to `silver_forex_rates` returns NULL. Using `COALESCE(forex_rate, 1)` ensures calculations work — multiplying by 1 keeps the INR price unchanged.

---

### Q20: What happens if the Twelve Data API returns a 500 error or empty data?
**What they're testing:** Error handling awareness.

**Answer:** Currently, the Python scripts don't have robust error handling — if the API fails, the script either crashes or inserts nothing, and the downstream stored procedures transform whatever is in Bronze (potentially stale data). This is a known gap. For Project 2, I'm adding HTTP status code checks, NULL validation on critical fields before INSERT, row count verification after ingestion, and logging of failed API calls with timestamps. The goal is that bad data never reaches Silver.

---

### Q21: How would you know if yesterday's pipeline failed?
**What they're testing:** Monitoring and observability thinking.

**Answer:** Right now, I'd have to manually check. I could run `SELECT MAX(trade_date) FROM bronze_stock_prices` — if it doesn't show yesterday's date, something failed. The Task Scheduler shows the last run result (success/failure code), and SQL Server Agent has job history. But there's no automated alerting. A proper system would send an email or Slack notification on failure. This is something I'd add in a production environment.

---

### Q22: Your RBW stock has NULL revenue. Is that a bug?
**What they're testing:** Do you know your data?

**Answer:** No — Rainbow Rare Earths is a pre-revenue exploration-stage company. They're exploring rare earth deposits in Africa but haven't started commercial production yet. NULL revenue is the correct representation. The `is_valid` flag in Silver is still set to 1 because the data isn't missing or erroneous — the company genuinely has no revenue to report.

---

## SECTION 5: POWER BI & VISUALIZATION

### Q23: You used DAX measures for year filtering. Why not just filter the Gold tables by date?
**What they're testing:** Understanding of data modeling constraints.

**Answer:** Most Gold tables have no date column — `gold_stock_performance` has 12 rows (one per stock), `gold_category_performance` has 4 rows. They're pre-calculated summaries with no time dimension. When a user selects "2025" in the year slicer, these tables can't filter because they don't know what year means. So I created DAX measures that dynamically calculate returns from `gold_daily_inr_returns` (which has trade_date) using CALCULATE + FIRSTDATE/LASTDATE. The year slicer filters the date column, and the DAX measure recalculates using only the dates in that filtered context.

---

### Q24: Explain the CALCULATE function in DAX.
**What they're testing:** DAX understanding.

**Answer:** CALCULATE evaluates an expression under a modified filter context. In Power BI, every visual has a filter context determined by slicers, page filters, and visual axes. CALCULATE lets you override or add to that context. For example: `CALCULATE(MAX(close_price), LASTDATE(trade_date))` means "give me the MAX close_price, but only on the last date in the current filter context." When the user selects 2025 and CEG, LASTDATE returns December 31, 2025, and MAX returns CEG's closing price on that date. Without CALCULATE, MAX would return the highest price ever, not the latest.

---

### Q25: Why did you use AVERAGEX instead of just AVERAGE?
**What they're testing:** DAX iterator function understanding.

**Answer:** AVERAGE works on a single column. But I needed to calculate the return for each stock individually, then average those returns across stocks in a category. AVERAGEX iterates over a table — `AVERAGEX(VALUES(silver_companies[ticker]), ...)` — loops through each ticker, calculates the return for that ticker using CALCULATE + FIRSTDATE/LASTDATE, then averages the results. It's like a for-loop that calculates per-row and then aggregates. Plain AVERAGE can't do per-entity calculations before aggregating.

---

### Q26: Why use `ticker` from `silver_companies` instead of from `gold_stock_performance` in your bar chart?
**What they're testing:** Power BI data modeling — a real bug you encountered.

**Answer:** When I used `ticker` from `gold_stock_performance` on the Y-axis with `yoy_return_pct` from the same table, Power BI summed all values into a single bar instead of showing separate bars per stock. That's because both the axis field and the value field came from the same table with no dimensional context. Using `ticker` from `silver_companies` (the lookup table) forces Power BI to group by each ticker individually and pull the corresponding value from the fact table. This is a fundamental star schema principle — dimensions drive grouping, facts provide values.

---

### Q27: What's the On-premises Data Gateway and why did you need it?
**What they're testing:** Infrastructure understanding.

**Answer:** Power BI Service runs in the cloud at app.powerbi.com. My SQL Server runs on my local machine. DirectQuery means every dashboard interaction needs to reach my local database. The gateway is a bridge — it's a service running on my machine that listens for requests from Power BI cloud, executes the query against local SQL Server, and sends results back. Without it, the cloud can't reach localhost. I had to enable TCP/IP on SQL Server because the gateway connects via network protocol, not shared memory like local SSMS connections.

---

### Q28: What's your Power BI theme and why did you choose it?
**What they're testing:** Design thinking.

**Answer:** A Bloomberg terminal-inspired dark theme — deep navy-black background (#0D0D1A), teal accent (#00D4AA), white values, muted grey labels. I chose dark because finance professionals spend hours looking at dashboards — dark reduces eye strain. The teal accent provides high contrast for data values without being flashy. The theme is applied via a JSON file that controls all visual backgrounds, fonts, borders, and data colors globally, ensuring consistency across all 10 pages.

---

## SECTION 6: WHAT WOULD YOU DO DIFFERENTLY?

### Q29: If you were rebuilding this from scratch, what would you change?
**What they're testing:** Self-awareness and growth mindset.

**Answer:** Three things. First, I'd use GitHub Actions instead of Windows Task Scheduler for Python ingestion — removes the single point of failure of my machine being on. Second, I'd add data quality checks from day one — API error handling, NULL validation, row count verification — rather than building the happy path first and bolting on reliability later. Third, I'd consider dbt instead of stored procedures for the Silver-to-Gold transformations — it provides built-in testing, documentation generation, and better version control for SQL transformations.

---

### Q30: How would you scale this to 100 stocks instead of 12?
**What they're testing:** Can you think beyond the current scope?

**Answer:** The architecture scales well with minor changes. The Twelve Data API would be the bottleneck — at 55 calls/day on the Grow tier, I'd need a higher plan or batch the calls across multiple days. The SQL pipeline handles it — the stored procedures are ticker-agnostic and would rebuild for any number of stocks. Power BI would need rethinking — the category pages assume 3 stocks each, and the slicer with 100 options would need search or cascading filters. The correlation matrix would explode to 4,950 pairs (100 × 99 / 2), which would need a heatmap visual instead of a scrollable table. The Gold table pre-aggregation pattern remains the same — just more rows.

---

### Q31: Can you explain the currency impact formula?
**What they're testing:** Do you understand the math behind your numbers?

**Answer:** It's compound, not additive. If a stock returns 20% in USD and the dollar strengthens 10% against the rupee, the INR return isn't 20% + 10% = 30%. It's: `((1 + 0.20) × (1 + 0.10) - 1) × 100 = 32%`. The currency impact is then 32% - 20% = 12%, not 10%. This is because the forex gain applies to the grown investment, not just the principal. My SQL implements this as: `((1 + local_return/100) × (end_rate/start_rate) - 1) × 100`.

---

### Q32: Why did you track correlation? What does an investor do with that information?
**What they're testing:** Can you connect analytics to business decisions?

**Answer:** Correlation tells you if diversification is real. If you own CEG (US Nuclear) and XOM (US Oil) and they're strongly correlated (move together), owning both doesn't reduce your risk — when one drops, the other probably drops too. But if CEG and ONGC (Indian Oil) are uncorrelated (correlation near 0), owning both genuinely reduces portfolio volatility because their price movements are independent. My data showed most cross-region pairs are uncorrelated — which validates the investor thesis that spreading across USA, UK, Germany, India, and Korea provides real diversification, not just geographic spread.

---

## SECTION 7: RAPID-FIRE TECHNICAL QUESTIONS

### Q33: What's the difference between STDEV and STDEVP?
**Answer:** STDEV calculates sample standard deviation (divides by n-1). STDEVP calculates population standard deviation (divides by n). I used STDEV in SQL because the daily returns are a sample of all possible trading days, not the complete population.

### Q34: What's ROW_NUMBER and how is it different from RANK?
**Answer:** ROW_NUMBER assigns sequential numbers — 1, 2, 3 — with no ties. RANK assigns the same number to ties and skips the next — 1, 1, 3. I used ROW_NUMBER with ORDER BY trade_date DESC and WHERE rn = 1 to get the latest record per stock, where ties don't matter because each stock has one price per date.

### Q35: What does NULLIF do?
**Answer:** NULLIF(a, b) returns NULL if a equals b, otherwise returns a. I used `NULLIF(shares_outstanding, 0)` to prevent division by zero in payout ratio calculations — dividing by NULL produces NULL instead of an error.

### Q36: What's the difference between WHERE and HAVING?
**Answer:** WHERE filters individual rows before aggregation. HAVING filters groups after aggregation. Example: `WHERE daily_return_pct IS NOT NULL` removes null returns before calculating correlation. `HAVING COUNT(*) > 100` would filter out stock pairs with too few data points after grouping.

### Q37: What's a composite primary key?
**Answer:** A primary key made of two or more columns together. `silver_stock_prices` has PRIMARY KEY (ticker, trade_date) — neither column is unique alone (CEG appears 500 times, and 2024-01-15 appears for all 12 stocks), but the combination uniquely identifies each row.

### Q38: What does the asterisk in `SELECT *` do and why should you avoid it?
**Answer:** `SELECT *` returns all columns. It's bad practice in production because: it pulls unnecessary data over the network, it breaks if columns are added/removed, and it makes the query's intent unclear. I use it only for quick debugging (`SELECT TOP 5 *`), never in stored procedures or production queries.

### Q39: Explain window functions vs GROUP BY.
**Answer:** GROUP BY collapses rows — one output row per group. Window functions calculate across rows without collapsing them — every input row remains in the output. That's why I can calculate daily_return_pct with LAG (needs the current row AND the previous row in the output) but couldn't do it with GROUP BY (which would collapse both rows into one).

### Q40: What's the difference between TRUNCATE and DELETE?
**Answer:** TRUNCATE: removes all rows, minimal logging, can't filter with WHERE, resets identity columns, can't fire triggers. DELETE: removes rows one by one, fully logged, supports WHERE clause, doesn't reset identity, fires triggers. TRUNCATE is faster for full rebuilds, which is why I use it in stored procedures.

---

## SECTION 8: BEHAVIORAL / SOFT SKILL QUESTIONS

### Q41: What was the hardest problem you solved in this project?
**Answer:** The GBp-to-GBP conversion bug. LSE stocks were showing prices 100x too high, which cascaded into wrong returns, wrong Sharpe ratios, and wrong currency conversions. It took multiple debugging steps — first noticing the data looked wrong, then tracing it back to the API response, then realizing Twelve Data returns pence not pounds for LSE, then implementing the fix across all four price columns AND the LAG calculation for daily returns. It taught me that data quality issues upstream silently corrupt everything downstream.

### Q42: How do you handle being stuck on a technical problem?
**Answer:** I break it into smaller pieces. When the gateway wouldn't connect, I didn't panic — I checked the gateway status (green), checked the connection mapping (correct), checked SQL Server (running), then realized TCP/IP protocol was disabled. Systematic elimination. I also keep documentation of every decision and fix, so when similar issues arise in future projects, I have a reference.

### Q43: This project uses a lot of different technologies. How did you learn them?
**Answer:** I learned each tool as I needed it, not in advance. SQL Server and Power BI from mock projects. Python ingestion scripts for this project. DAX measures by understanding the pattern (CALCULATE modifies filter context) and then adapting it for each use case. Gateway configuration by reading Microsoft documentation and debugging errors one by one. The common thread is understanding the WHY before the HOW — once I understood why DirectQuery needs a gateway (cloud can't reach localhost), the setup steps made logical sense.

### Q44: How would you present this dashboard to a non-technical stakeholder?
**Answer:** I'd skip the architecture and focus on what it answers: "Which sector should I invest in? Which region? How much will I actually make in rupees after the currency moves? Which stocks move independently so my portfolio is truly diversified?" I'd walk through one stock — say CEG — showing the current price, return, where it sits in the 52-week range, and then flip to the currency page to show that the 34% USD return was actually 47% in INR because the rupee weakened. That one example tells the whole story.

---

## QUICK REFERENCE: Numbers You Should Know

| Metric | Value |
|--------|-------|
| Total tables | 15 (3 Bronze, 6 Silver, 7 Gold) — Gold originally 6, added gold_daily_inr_returns mid-project |
| Total stocks | 12 |
| Sectors | 4 (Nuclear, Rare Earth, Oil, Automotive) |
| Regions | 3 (North America, Europe, Asia) |
| Currencies | 4 (USD, GBP, EUR, INR) |
| Exchanges | 5 (NYSE, NASDAQ, LSE, XETRA, NSE) |
| Correlation pairs | 66 |
| Dashboard pages | 10 |
| DAX measures | 12+ |
| Stored procedures | 3 |
| Daily automation jobs | 2 (Task Scheduler 2:30 AM, SQL Server Agent 3:00 AM) |
| Gold table total rows | ~5,800 |
| silver_stock_prices rows | ~6,000 |
| API | Twelve Data (Grow tier, $29/month, 55 calls/day) |
| Power BI license | Pro ($14/month or 60-day trial) |
| Stocks paying dividends | 7 of 12 |
| Highest Sharpe ratio stock | RBW |
| Best performing region | North America |
| USD/INR movement | ~85 → ~95 (added ~10-15% to US stock returns) |
