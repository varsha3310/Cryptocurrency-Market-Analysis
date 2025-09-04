-- =========================================================
-- Cryptocurrency Analysis Queries
-- Author: Rahul Kumar Singh
-- Dataset: CoinMarketCap 2017 & 2018 snapshots
-- =========================================================

-- ===============================
-- EASY QUERIES (Q1–Q4)
-- ===============================

-- Q1: Top 10 Coins by Market Cap (2017)
SELECT name, market_cap_usd
FROM cmc2017
ORDER BY market_cap_usd DESC
LIMIT 10;

-- Q2: Top 10 Coins by Market Cap (2018)
SELECT name, market_cap_usd
FROM cmc2018
ORDER BY market_cap_usd DESC
LIMIT 10;

-- Q3: Coins with Over 50% Weekly Growth (2018)
SELECT name, percent_change_7d
FROM cmc2018
WHERE percent_change_7d > 50
ORDER BY percent_change_7d DESC;

-- Q4: Count of Coins Missing Market Cap (2017)
SELECT COUNT(*) AS null_market_cap
FROM cmc2017
WHERE market_cap_usd IS NULL;

-- ===============================
-- MEDIUM QUERIES (Q5–Q9)
-- ===============================

-- Q5: Market Cap Share of Top 10 vs Rest (2018)
SELECT 
 ROUND(SUM(CASE WHEN rank <= 10 THEN market_cap_usd ELSE 0 END) * 100.0 / SUM(market_cap_usd), 2) AS top10_pct,
 ROUND(SUM(CASE WHEN rank > 10 THEN market_cap_usd ELSE 0 END) * 100.0 / SUM(market_cap_usd), 2) AS rest_pct
FROM cmc2018;

-- Q6: Rank Coins by 24h Volume (2018)
SELECT name, "24h_volume_usd",
       RANK() OVER (ORDER BY "24h_volume_usd" DESC) AS vol_rank
FROM cmc2018;

-- Q7: Total Market Cap by Symbol (2018)
SELECT symbol, SUM(market_cap_usd) AS total_market_cap
FROM cmc2018
GROUP BY symbol
ORDER BY total_market_cap DESC;

-- Q8: Biggest Gainers (24h) – 2018
SELECT name, percent_change_24h
FROM cmc2018
ORDER BY percent_change_24h DESC
LIMIT 10;

-- Q9: Biggest Losers (7d) – 2018
SELECT name, percent_change_7d
FROM cmc2018
ORDER BY percent_change_7d ASC
LIMIT 10;

-- ===============================
-- ADVANCED QUERIES (Q10–Q14)
-- ===============================

-- Q10: Year-over-Year Market Cap Growth (Only Coins in Both Years)
SELECT c17.name,
       ROUND((c18.market_cap_usd - c17.market_cap_usd) / c17.market_cap_usd * 100, 2) AS pct_growth
FROM cmc2017 c17
JOIN cmc2018 c18 ON LOWER(c17.id) = LOWER(c18.id)
WHERE c17.market_cap_usd IS NOT NULL
  AND c18.market_cap_usd IS NOT NULL
ORDER BY pct_growth DESC
LIMIT 10;

-- Q11: Largest YoY Increase in 24h Volume
SELECT c17.name,
       ROUND((c18."24h_volume_usd" - c17."24h_volume_usd") / c17."24h_volume_usd" * 100, 2) AS pct_increase
FROM cmc2017 c17
JOIN cmc2018 c18 ON LOWER(c17.id) = LOWER(c18.id)
WHERE c17."24h_volume_usd" IS NOT NULL
  AND c18."24h_volume_usd" IS NOT NULL
ORDER BY pct_increase DESC
LIMIT 5;

-- Q12: Coins Entered Top 20 in 2018 but not in 2017
SELECT id, name
FROM cmc2018
WHERE id NOT IN (
    SELECT id FROM cmc2017
    ORDER BY market_cap_usd DESC LIMIT 20
)
ORDER BY market_cap_usd DESC
LIMIT 20;

-- Q12b: Coins Dropped from Top 20 in 2018
SELECT id, name
FROM cmc2017
WHERE id NOT IN (
    SELECT id FROM cmc2018
    ORDER BY market_cap_usd DESC LIMIT 20
)
ORDER BY market_cap_usd DESC
LIMIT 20;

-- Q13: Moving Average of 7-Day Returns (2018)
SELECT name, percent_change_7d,
       ROUND(AVG(percent_change_7d) OVER (
             ORDER BY percent_change_7d
             ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
       ), 2) AS moving_avg_5
FROM cmc2018
ORDER BY percent_change_7d DESC;

-- Q14: Median 7-Day Return by Year
SELECT year,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY percent_change_7d) AS median_7d_return
FROM (
    SELECT percent_change_7d, 2017 AS year FROM cmc2017
    UNION ALL
    SELECT percent_change_7d, 2018 AS year FROM cmc2018
) combined
GROUP BY year;

-- ===============================
-- ADVANCED PLUS (Q15–Q19)
-- ===============================

-- Q15: Top 5 Coins by Volatility (STDDEV of 24h % Change)
SELECT name,
       symbol,
       ROUND(STDDEV_SAMP(percent_change_24h), 2) AS stddev_24h
FROM cmc2018
WHERE percent_change_24h IS NOT NULL
GROUP BY name, symbol
ORDER BY stddev_24h DESC
LIMIT 5;

-- Q16: Correlation between Market Cap and Volume by Cap Category
WITH categorized AS (
    SELECT *,
           CASE
               WHEN market_cap_usd >= 10000000000 THEN 'Large Cap'
               WHEN market_cap_usd >= 1000000000  THEN 'Mid Cap'
               ELSE 'Small Cap'
           END AS cap_category
    FROM cmc2018
)
SELECT cap_category,
       ROUND(
         (SUM((market_cap_usd - (SELECT AVG(market_cap_usd) FROM categorized WHERE cap_category = c.cap_category)) *
              ("24h_volume_usd" - (SELECT AVG("24h_volume_usd") FROM categorized WHERE cap_category = c.cap_category))) /
          ((COUNT(*) - 1) * (STDDEV_SAMP(market_cap_usd) * STDDEV_SAMP("24h_volume_usd")))
       , 3) AS correlation
FROM categorized c
GROUP BY cap_category;

-- Q17: Ranking Coins by Average Weekly Return (2018)
SELECT name,
       ROUND(AVG(percent_change_7d), 2) AS avg_weekly_return,
       RANK() OVER (ORDER BY AVG(percent_change_7d) DESC) AS rank_by_return
FROM cmc2018
WHERE percent_change_7d IS NOT NULL
GROUP BY name
ORDER BY avg_weekly_return DESC
LIMIT 10;

-- Q18: Clusters of Coins with Similar Weekly Returns (Diff <= 10%)
SELECT a.name AS coin_a,
       b.name AS coin_b,
       ABS(a.percent_change_7d - b.percent_change_7d) AS diff_pct
FROM cmc2018 a
JOIN cmc2018 b ON a.name < b.name
WHERE a.percent_change_7d IS NOT NULL
  AND b.percent_change_7d IS NOT NULL
  AND ABS(a.percent_change_7d - b.percent_change_7d) <= 10
ORDER BY diff_pct ASC
LIMIT 20;

-- Q19: Rolling 7-Day Trading Volume (Requires 'daily_crypto_data')
WITH top10 AS (
    SELECT symbol
    FROM cmc2018
    ORDER BY market_cap_usd DESC
    LIMIT 10
),
rolling AS (
    SELECT t.symbol,
           t.date,
           SUM(t."24h_volume_usd") OVER (
             PARTITION BY t.symbol
             ORDER BY t.date
             ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
           ) AS rolling_7d_volume
    FROM daily_crypto_data t
    JOIN top10 ON t.symbol = top10.symbol
)
SELECT *
FROM rolling
ORDER BY symbol, date;
