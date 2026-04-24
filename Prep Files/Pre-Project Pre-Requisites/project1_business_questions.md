# Project #1: Global Investment Portfolio Analytics — Business Questions

---

## Single-Stock Metrics (Per Company Analysis)

These questions apply to each of the 12 individual stocks. They form the foundation of the 4 category dashboard pages.

1. What is the current stock price?
2. What is the 52-week high and low?
3. What is the year-over-year return %?
4. What is the daily trading volume?
5. What is the market capitalization?
6. What is the P/E ratio?
7. What is the P/B ratio?
8. What is the Return on Equity (ROE)?
9. What is the debt-to-equity ratio?
10. What is the book value per share?
11. What is the face value?
12. What is the quarterly revenue and net profit?
13. What is the net worth of the company?
14. What is the dividend yield and annual dividend per share?
15. What is the shareholding pattern (retail, promoters, institutional)?
16. What is the stock's volatility (standard deviation of daily returns)?

---

## Comparison Questions (Cross-Stock Analysis)

These 7 questions drive the comparison dashboard pages and represent the analytical depth of the project.

### Question 1: Which stock gave the best return in each category?
**Dashboard page:** Category pages (1-4)  
**What it answers:** Within Nuclear, Rare Earth, Oil, and Automotive — which of the 3 regional stocks outperformed?  
**Metric:** YoY return % ranked within each category.

### Question 2: Which stock has the best risk-adjusted return?
**Dashboard page:** Portfolio Diversification Analysis (page 8)  
**What it answers:** High return with high volatility isn't necessarily better than moderate return with low volatility. Which stock gives the best return per unit of risk?  
**Metric:** Sharpe Ratio = (Stock return - Risk-free rate) / Volatility. Higher is better.

### Question 3: Which category performed best overall?
**Dashboard page:** Overall Category Performance (page 6)  
**What it answers:** Should the investor put money in Nuclear, Rare Earth, Oil, or Automotive right now?  
**Metric:** Average YoY return across all 3 stocks per category.

### Question 4: Which region performed best overall?
**Dashboard page:** Portfolio Diversification Analysis (page 8)  
**What it answers:** Is the investor's money better deployed in North America, Europe, or Asia?  
**Metric:** Average YoY return across all 4 stocks per region.

### Question 5: What is the actual return in INR after currency conversion?
**Dashboard page:** Currency Appreciation (page 5)  
**What it answers:** A US stock gained 20% in USD. But the rupee weakened from 83 to 86 per USD. The actual INR return is 24.3%, not 20%. This shows the true return for the Indian investor.  
**Metric:** Return in INR % and currency impact % (difference between local return and INR return).  
**This is the project's unique differentiator.**

### Question 6: Which stock gives the best dividend yield relative to price?
**Dashboard page:** Highest Dividend (page 7)  
**What it answers:** For income-focused investing, which company pays the most cash relative to the share price? Also shows dividend converted to INR for the Indian investor.  
**Metric:** Dividend yield % = (Annual dividend per share / Stock price) × 100.

### Question 7: How correlated are stocks across regions?
**Dashboard page:** Portfolio Diversification Analysis (page 8)  
**What it answers:** Does owning stocks across regions actually reduce risk? If US and European stocks move together but Asian stocks move independently, the investor gets true diversification. If everything moves the same way, spreading money across regions doesn't help.  
**Metric:** Correlation coefficient (-1 to +1). Values near 0 = uncorrelated = good diversification. Values near +1 = move together = no diversification benefit.

---

## Dashboard Page Mapping

| Page | Title | Questions Answered |
|---|---|---|
| 1 | Nuclear Energy | Single-stock metrics for Constellation, Rolls-Royce, KEPCO + Q1 within nuclear |
| 2 | Rare Earth Minerals | Single-stock metrics for MP Materials, Rainbow, GMDC + Q1 within rare earth |
| 3 | Oil | Single-stock metrics for Exxon, Shell, ONGC + Q1 within oil |
| 4 | Automotive | Single-stock metrics for Ford, Volkswagen, Tata + Q1 within automotive |
| 5 | Currency Appreciation | Q5 — INR-adjusted returns, forex trends, currency impact |
| 6 | Overall Category Performance | Q3 — best sector, average metrics per category |
| 7 | Highest Dividend | Q6 — yield comparison, INR-adjusted dividend income |
| 8 | Portfolio Diversification Analysis | Q2 + Q4 + Q7 — Sharpe ratios, regional performance, correlation |

---

## SQL Query Estimation

Based on these business questions:
- Single-stock metrics: ~12-15 queries (aggregations, window functions for 52W high/low, daily returns)
- Comparison questions: ~10-12 queries (cross-category rankings, Sharpe ratio calculations, correlation, currency adjustments)
- Data transformation: ~5-8 queries (Bronze → Silver → Gold layer transformations, data validation)
- **Total estimated: 25-35 SQL queries**

This meets the 20-30 query target from the 12 Technical Differentiators.

---

*Last updated: March 24, 2026*
