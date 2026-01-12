
  --checking table 
  SELECT COUNT(*) FROM walmart;
SELECT * FROM walmart LIMIT 10;
PRAGMA table_info(walmart);
--DATA CLEANING 
--Remove rows with missing important info
DELETE
FROM walmart
WHERE Store IS NULL
   OR Date IS NULL
   OR Weekly_Sales IS NULL;
--Remove impossible sales
DELETE
FROM walmart
WHERE Weekly_Sales < 0;
--CHECK DUPLICATE ROWS
--Question 2: Remove duplicate rows safely
DELETE
FROM walmart
WHERE Store IS NULL
   OR Date IS NULL
   OR Weekly_Sales IS NULL;
   --Remove impossible sales values
   DELETE
FROM walmart
WHERE Weekly_Sales < 0;
--Check Holiday_Flag validity
SELECT DISTINCT Holiday_Flag
FROM walmart;
--Remove invalid holiday flags (if any)
DELETE
FROM walmart
WHERE Holiday_Flag NOT IN (0, 1);
--Check temperature range
SELECT
  MIN(Temperature) AS min_temp,
  MAX(Temperature) AS max_temp
FROM walmart;
--Check economic indicators
SELECT COUNT(*)
FROM walmart
WHERE CPI < 0
   OR Unemployment < 0;
   SELECT COUNT(*) AS final_rows
FROM walmart;
--DATE FEATURE ENGINEERING
--Add clean_date column (ONCE)'
ALTER TABLE walmart
ADD COLUMN clean_date TEXT;
--Fill the clean_date column
UPDATE walmart
SET clean_date =
    substr(Date,7,4) || '-' ||
    substr(Date,4,2) || '-' ||
    substr(Date,1,2)
WHERE clean_date IS NULL;
SELECT
  Date,
  clean_date
FROM walmart
LIMIT 10;
--Add year and month columns 
ALTER TABLE walmart ADD COLUMN year INTEGER;
ALTER TABLE walmart ADD COLUMN month INTEGER;
--Fill year and month
UPDATE walmart
SET year  = CAST(strftime('%Y', clean_date) AS INTEGER),
    month = CAST(strftime('%m', clean_date) AS INTEGER)
WHERE year IS NULL OR month IS NULL;

PRAGMA table_info(walmart);
--revenue
ALTER TABLE walmart
ADD COLUMN revenue REAL;
UPDATE walmart
SET revenue = Weekly_Sales
WHERE revenue IS NULL;
--week_of_year
ALTER TABLE walmart
ADD COLUMN week_of_year INTEGER;
UPDATE walmart
SET week_of_year =
    CAST(strftime('%W', clean_date) AS INTEGER)
WHERE week_of_year IS NULL;
--monthly_revenue 
ALTER TABLE walmart
ADD COLUMN monthly_revenue REAL;
UPDATE walmart
SET monthly_revenue = (
    SELECT SUM(w2.revenue)
    FROM walmart w2
    WHERE w2.Store = walmart.Store
      AND w2.year = walmart.year
      AND w2.month = walmart.month
)
WHERE monthly_revenue IS NULL;
--store_avg_revenue
ALTER TABLE walmart
ADD COLUMN store_avg_revenue REAL;
UPDATE walmart
SET store_avg_revenue = (
    SELECT AVG(w2.revenue)
    FROM walmart w2
    WHERE w2.Store = walmart.Store
)
WHERE store_avg_revenue IS NULL;
--revenue_vs_store_avg
ALTER TABLE walmart
ADD COLUMN revenue_vs_store_avg REAL;
UPDATE walmart
SET revenue_vs_store_avg = revenue - store_avg_revenue
WHERE revenue_vs_store_avg IS NULL;
---rolling_4w_avg
PRAGMA table_info(walmart);
UPDATE walmart
SET rolling_4w_avg = (
    SELECT AVG(w2.revenue)
    FROM walmart w2
    WHERE w2.Store = walmart.Store
      AND w2.clean_date BETWEEN
          date(walmart.clean_date, '-28 days')
          AND walmart.clean_date
)
WHERE rolling_4w_avg IS NULL;
--trend_direction
ALTER TABLE walmart
ADD COLUMN trend_direction TEXT;
UPDATE walmart
SET trend_direction =
    CASE
        WHEN revenue > rolling_4w_avg THEN 'UP'
        WHEN revenue < rolling_4w_avg THEN 'DOWN'
        ELSE 'STABLE'
    END
WHERE trend_direction IS NULL;
--churn_flag
ALTER TABLE walmart
ADD COLUMN churn_flag INTEGER;
UPDATE walmart
SET churn_flag =
    CASE
        WHEN revenue < store_avg_revenue
             AND trend_direction = 'DOWN'
        THEN 1
        ELSE 0
    END
WHERE churn_flag IS NULL;
PRAGMA table_info(walmart);
--EXPLOATORY DATA ANALYST 
--How big is the dataset?
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT Store) AS total_stores
FROM walmart;
--What time period does this data cover?
SELECT
  MIN(Date) AS start_date,
  MAX(Date) AS end_date
FROM walmart;
--How big are weekly sales normally?
SELECT
  MIN(Weekly_Sales) AS min_sales,
  AVG(Weekly_Sales) AS avg_sales,
  MAX(Weekly_Sales) AS max_sales
FROM walmart;
--Which stores make the most money?
SELECT
  Store,
  SUM(Weekly_Sales) AS total_sales
FROM walmart
GROUP BY Store
ORDER BY total_sales DESC
LIMIT 10;
--SALES TREND OVER TIME
SELECT
  strftime('%Y-%m', Date) AS year_month,
  SUM(Weekly_Sales) AS monthly_sales
FROM walmart
GROUP BY year_month
ORDER BY year_month;
--Do holidays increase sales?
SELECT
  Holiday_Flag,
  AVG(Weekly_Sales) AS avg_sales
FROM walmart
GROUP BY Holiday_Flag;
--Does temperature affect sales?
SELECT
  ROUND(Temperature, 0) AS temp_bucket,
  AVG(Weekly_Sales) AS avg_sales
FROM walmart
GROUP BY temp_bucket
ORDER BY temp_bucket;
-- FUEL PRICE IMPACT 
SELECT
  ROUND(Fuel_Price, 2) AS fuel_bucket,
  AVG(Weekly_Sales) AS avg_sales
FROM walmart
GROUP BY fuel_bucket
ORDER BY fuel_bucket;
--CHURN OVERWIEW
SELECT
  churn_flag,
  COUNT(*) AS rows,
  COUNT(DISTINCT Store) AS stores
FROM walmart
GROUP BY churn_flag;
--WORST CHURN STORES ⚠️
SELECT
  Store,
  COUNT(*) AS churn_weeks
FROM walmart
WHERE churn_flag = 1
GROUP BY Store
ORDER BY churn_weeks DESC
LIMIT 10;
--SALES VOLATILITY: Which stores are unstable? */
SELECT
  Store,
  ROUND(AVG(Weekly_Sales), 2) AS avg_sales,
  ROUND(
    (MAX(Weekly_Sales) - MIN(Weekly_Sales)), 2
  ) AS sales_volatility
FROM walmart
GROUP BY Store
ORDER BY sales_volatility DESC
LIMIT 10;
--CONSISTENCY CHECK: Stores with stable sales */
SELECT
  Store,
  ROUND(AVG(Weekly_Sales), 2) AS avg_sales,
  ROUND(
    (MAX(Weekly_Sales) - MIN(Weekly_Sales)), 2
  ) AS volatility
FROM walmart
GROUP BY Store
ORDER BY volatility ASC
LIMIT 10;
--SALES VS STORE AVERAGE (PERFORMANCE GAP) */
SELECT
  Store,
  ROUND(AVG(revenue_vs_store_avg), 2) AS avg_gap
FROM walmart
GROUP BY Store
ORDER BY avg_gap ASC
LIMIT 10;
--WEATHER SENSITIVITY */
SELECT
  ROUND(Temperature, 0) AS temp_bucket,
  ROUND(AVG(Weekly_Sales), 2) AS avg_sales
FROM walmart
GROUP BY temp_bucket
ORDER BY temp_bucket;
--FUEL PRICE SENSITIVITY 
SELECT
  ROUND(Fuel_Price, 1) AS fuel_bucket,
  ROUND(AVG(Weekly_Sales), 2) AS avg_sales
FROM walmart
GROUP BY fuel_bucket
ORDER BY fuel_bucket;
--ECONOMIC STRESS: CPI vs SALES */
SELECT
  ROUND(CPI, 1) AS cpi_bucket,
  ROUND(AVG(Weekly_Sales), 2) AS avg_sales
FROM walmart
GROUP BY cpi_bucket
ORDER BY cpi_bucket;
--UNEMPLOYMENT IMPACT */
SELECT
  ROUND(Unemployment, 1) AS unemployment_bucket,
  ROUND(AVG(Weekly_Sales), 2) AS avg_sales
FROM walmart
GROUP BY unemployment_bucket
ORDER BY unemployment_bucket;
--HOLIDAY LIFT PER STORE */
SELECT
  Store,
  ROUND(
    AVG(CASE WHEN Holiday_Flag = 1 THEN Weekly_Sales END)
    -
    AVG(CASE WHEN Holiday_Flag = 0 THEN Weekly_Sales END),
    2
  ) AS holiday_lift
FROM walmart
GROUP BY Store
ORDER BY holiday_lift DESC
LIMIT 10;
--ROLLING AVG VS ACTUAL (SMOOTHING CHECK) */
SELECT
  Store,
  Date,
  Weekly_Sales,
  rolling_4w_avg,
  ROUND(Weekly_Sales - rolling_4w_avg, 2) AS deviation
FROM walmart
ORDER BY deviation DESC
LIMIT 10;
-- EARLY WARNING SIGNAL: Trend DOWN + Below Avg */
SELECT
  Store,
  COUNT(*) AS warning_weeks
FROM walmart
WHERE trend_direction = 'DOWN'
  AND revenue_vs_store_avg < 0
GROUP BY Store
ORDER BY warning_weeks DESC
LIMIT 10;

 --ADVANCED SQL – CTEs & WINDOW FUNCTIONS
/* MONTHLY SALES PER STORE */
WITH monthly_sales AS (
  SELECT
    Store,
    strftime('%Y-%m', Date) AS month,
    SUM(Weekly_Sales) AS monthly_sales
  FROM walmart
  GROUP BY Store, month
)


/* 2️⃣ ADD PREVIOUS MONTH SALES (WINDOW FUNCTION) */
, sales_with_lag AS (
  SELECT
    Store,
    month,
    monthly_sales,
    LAG(monthly_sales) OVER (
      PARTITION BY Store
      ORDER BY month
    ) AS prev_month_sales
  FROM monthly_sales
)


/* 3️⃣ SALES CHANGE & TREND DIRECTION */
, sales_trend AS (
  SELECT
    Store,
    month,
    monthly_sales,
    prev_month_sales,
    ROUND(monthly_sales - prev_month_sales, 2) AS sales_change,
    CASE
      WHEN monthly_sales > prev_month_sales THEN 'UP'
      WHEN monthly_sales < prev_month_sales THEN 'DOWN'
      ELSE 'FLAT'
    END AS trend_direction
  FROM sales_with_lag
)


/* 4️⃣ RUNNING TOTAL (WINDOW FUNCTION) */
, running_revenue AS (
  SELECT
    Store,
    month,
    monthly_sales,
    SUM(monthly_sales) OVER (
      PARTITION BY Store
      ORDER BY month
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_sales
  FROM monthly_sales
)


/* 5️⃣ ROLLING 3-MONTH AVERAGE */
, rolling_avg AS (
  SELECT
    Store,
    month,
    monthly_sales,
    ROUND(
      AVG(monthly_sales) OVER (
        PARTITION BY Store
        ORDER BY month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
      ), 2
    ) AS rolling_3m_avg
  FROM monthly_sales
)


/* 6️⃣ CHURN RISK FLAG (ADVANCED LOGIC) */
SELECT
  t.Store,
  t.month,
  t.monthly_sales,
  t.prev_month_sales,
  t.sales_change,
  t.trend_direction,
  r.cumulative_sales,
  ra.rolling_3m_avg,
  CASE
    WHEN t.trend_direction = 'DOWN'
         AND t.sales_change < -0.05 * t.prev_month_sales
    THEN 1
    ELSE 0
  END AS churn_risk_flag
FROM sales_trend t
LEFT JOIN running_revenue r
  ON t.Store = r.Store AND t.month = r.month
LEFT JOIN rolling_avg ra
  ON t.Store = ra.Store AND t.month = ra.month
ORDER BY churn_risk_flag DESC, t.sales_change ASC;
--Which stores have 3 or more consecutive months of decline?
WITH monthly_sales AS (
    SELECT
        Store,
        strftime('%Y-%m', Date) AS month,
        SUM(Weekly_Sales) AS monthly_sales
    FROM walmart
    GROUP BY Store, month
),
lagged AS (
    SELECT
        Store,
        month,
        monthly_sales,
        LAG(monthly_sales) OVER (
            PARTITION BY Store ORDER BY month
        ) AS prev_sales
    FROM monthly_sales
),
declines AS (
    SELECT
        Store,
        month,
        CASE
            WHEN monthly_sales < prev_sales THEN 1
            ELSE 0
        END AS is_decline
    FROM lagged
)
SELECT
    Store,
    COUNT(*) AS declining_months
FROM declines
WHERE is_decline = 1
GROUP BY Store
HAVING COUNT(*) >= 3;
--Which stores recover after a decline?
WITH monthly_sales AS (
    SELECT
        Store,
        strftime('%Y-%m', Date) AS month,
        SUM(Weekly_Sales) AS sales
    FROM walmart
    GROUP BY Store, month
),
trend AS (
    SELECT
        Store,
        month,
        sales,
        LAG(sales) OVER (
            PARTITION BY Store ORDER BY month
        ) AS prev_sales
    FROM monthly_sales
)
SELECT
    Store,
    COUNT(*) AS recovery_months
FROM trend
WHERE sales > prev_sales
GROUP BY Store
ORDER BY recovery_months DESC;
---Which stores have high volatility month-to-month?
WITH monthly_sales AS (
    SELECT
        Store,
        strftime('%Y-%m', Date) AS month,
        SUM(Weekly_Sales) AS sales
    FROM walmart
    GROUP BY Store, month
),
changes AS (
    SELECT
        Store,
        ABS(sales - LAG(sales) OVER (
            PARTITION BY Store ORDER BY month
        )) AS abs_change
    FROM monthly_sales
)
SELECT
    Store,
    AVG(abs_change) AS avg_volatility
FROM changes
GROUP BY Store
ORDER BY avg_volatility DESC;
--Which stores depend too much on holidays?
WITH holiday_sales AS (
    SELECT
        Store,
        Holiday_Flag,
        SUM(Weekly_Sales) AS sales
    FROM walmart
    GROUP BY Store, Holiday_Flag
)
SELECT
    Store,
    ROUND(
        SUM(CASE WHEN Holiday_Flag = 1 THEN sales END) * 1.0 /
        SUM(sales),
        2
    ) AS holiday_dependency
FROM holiday_sales
GROUP BY Store
ORDER BY holiday_dependency DESC;
--Which stores contribute the top 80% of revenue?
WITH store_revenue AS (
    SELECT
        Store,
        SUM(Weekly_Sales) AS revenue
    FROM walmart
    GROUP BY Store
),
ranked AS (
    SELECT
        Store,
        revenue,
        SUM(revenue) OVER (
            ORDER BY revenue DESC
        ) AS running_total,
        SUM(revenue) OVER () AS total_revenue
    FROM store_revenue
)
SELECT
    Store,
    revenue
FROM ranked
WHERE running_total <= 0.8 * total_revenue;
--Which stores have worsening trend recently (last 3 months)
WITH recent_months AS (
    SELECT
        Store,
        strftime('%Y-%m', Date) AS month,
        SUM(Weekly_Sales) AS sales
    FROM walmart
    GROUP BY Store, month
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY Store ORDER BY month DESC
           ) AS rn
    FROM recent_months
)
SELECT
    Store,
    COUNT(*) AS recent_declines
FROM ranked
WHERE rn <= 3
GROUP BY Store
HAVING COUNT(*) >= 2;

--Which stores show early churn signals?
WITH churn_signals AS (
    SELECT
        Store,
        churn_flag
    FROM walmart
)
SELECT
    Store,
    COUNT(*) AS churn_weeks
FROM churn_signals
WHERE churn_flag = 1
GROUP BY Store
ORDER BY churn_weeks DESC;
--Rank stores by overall health score
WITH metrics AS (
    SELECT
        Store,
        AVG(Weekly_Sales) AS avg_sales,
        AVG(ABS(revenue_vs_store_avg)) AS instability
    FROM walmart
    GROUP BY Store
)
SELECT
    Store,
    ROUND(avg_sales / (instability + 1), 2) AS health_score
FROM metrics
ORDER BY health_score DESC;




