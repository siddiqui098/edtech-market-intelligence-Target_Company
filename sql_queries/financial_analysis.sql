-- FINANCIAL Performance DASHBOARD 1 

-- Database: edtech_market_intelligence | Scope: FY2021-FY2025 (2026 excluded)
--
-- Naming convention used in this file:
--   Q<number> = business question
--   Query <number>A = primary query (its result feeds the dashboard)
--   Query <number>B = validation / cross-check query
 --  SECTION A: COMPANY-WIDE FINANCIAL PERFORMANCE

-- (primary question) How has financial performance evolved across Coursera, Udemy, Skillsoft, and Duolingo from 2021 to 2026?
-- Q1:  What was the overall percentage change in annual revenue for Coursera, Udemy, Skillsoft, and Duolingo from FY2021 to FY2025?


WITH annual_revenue AS (
    SELECT
        c.company_name,
        p.period_label,
        p.period_start,
        cm.revenue_usd_m
    FROM edtech_market_intelligence.company_metrics cm
    JOIN edtech_market_intelligence.companies c
        ON cm.company_id = c.company_id
    JOIN edtech_market_intelligence.periods p
        ON cm.period_id = p.period_id
    WHERE p.period_type = 'Full fiscal year'
      AND p.period_start >= '2021-01-01'
      AND p.period_start < '2026-01-01'
      AND cm.revenue_usd_m IS NOT NULL
),
summary AS (
    SELECT
        company_name,

        FIRST_VALUE(period_label) OVER w AS starting_period,
        LAST_VALUE(period_label) OVER w AS ending_period,

        FIRST_VALUE(period_start) OVER w AS starting_date,
        LAST_VALUE(period_start) OVER w AS ending_date,

        FIRST_VALUE(revenue_usd_m) OVER w AS starting_revenue,
        LAST_VALUE(revenue_usd_m) OVER w AS ending_revenue

    FROM annual_revenue

    WINDOW w AS (
        PARTITION BY company_name
        ORDER BY period_start
        ROWS BETWEEN UNBOUNDED PRECEDING
                 AND UNBOUNDED FOLLOWING
    )
)
SELECT DISTINCT
    company_name,
    starting_period,
    ending_period,
    ROUND(starting_revenue, 3) AS starting_revenue_usd_m,
    ROUND(ending_revenue, 3) AS ending_revenue_usd_m,

    ROUND(
        ending_revenue - starting_revenue, 3
    ) AS revenue_change_usd_m,

    ROUND(
        (ending_revenue - starting_revenue)
        / NULLIF(starting_revenue, 0) * 100,
        2
    ) AS overall_revenue_growth_pct

FROM summary
ORDER BY overall_revenue_growth_pct DESC;


WITH annual_revenue AS (
    SELECT
        c.company_name,
        p.period_label,
        p.period_start,
        p.period_end,
        cm.revenue_usd_m
    FROM edtech_market_intelligence.company_metrics AS cm
    JOIN edtech_market_intelligence.companies AS c
        ON cm.company_id = c.company_id
    JOIN edtech_market_intelligence.periods AS p
        ON cm.period_id = p.period_id
    WHERE p.period_type = 'Full fiscal year'
      AND p.period_end <= '2025-12-31'
      AND cm.revenue_usd_m IS NOT NULL
),
ranked_revenue AS (
    SELECT
        company_name,
        period_start,
        revenue_usd_m,
        ROW_NUMBER() OVER (
            PARTITION BY company_name
            ORDER BY period_start
        ) AS first_rank,
        ROW_NUMBER() OVER (
            PARTITION BY company_name
            ORDER BY period_start DESC
        ) AS last_rank
    FROM annual_revenue
),
company_growth AS (
    SELECT
        company_name,
        MAX(CASE WHEN first_rank = 1
                 THEN revenue_usd_m END) AS starting_revenue,
        MAX(CASE WHEN last_rank = 1
                 THEN revenue_usd_m END) AS ending_revenue
    FROM ranked_revenue
    GROUP BY company_name
)
SELECT
    company_name,
    ROUND(
        (ending_revenue - starting_revenue)
        / NULLIF(starting_revenue, 0) * 100,
        2
    ) AS overall_revenue_growth_pct
FROM company_growth
ORDER BY overall_revenue_growth_pct DESC;


-- Q2: How did the profitability of Coursera, Udemy, Skillsoft, and Duolingo change from FY2021 to FY2025?
    
    
WITH annual_margins AS (
    SELECT
        c.company_name,
        p.period_label,
        p.period_end,
        cm.revenue_usd_m,
        cm.net_income_loss_usd_m,
        cm.net_income_loss_usd_m
            / NULLIF(cm.revenue_usd_m, 0) * 100
            AS net_profit_margin_pct
    FROM edtech_market_intelligence.company_metrics AS cm
    JOIN edtech_market_intelligence.companies AS c
        ON cm.company_id = c.company_id
    JOIN edtech_market_intelligence.periods AS p
        ON cm.period_id = p.period_id
    WHERE p.period_type = 'Full fiscal year'
      AND p.period_end >= '2021-01-01'
      AND p.period_end <= '2025-12-31'
      AND cm.revenue_usd_m IS NOT NULL
      AND cm.net_income_loss_usd_m IS NOT NULL
),
ranked_margins AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY company_name
            ORDER BY period_end
        ) AS first_rank,
        ROW_NUMBER() OVER (
            PARTITION BY company_name
            ORDER BY period_end DESC
        ) AS last_rank
    FROM annual_margins
)
SELECT
    company_name,
    MAX(CASE WHEN first_rank = 1
        THEN period_label END) AS starting_period,
    ROUND(MAX(CASE WHEN first_rank = 1
        THEN net_profit_margin_pct END), 2) AS starting_margin_pct,
    MAX(CASE WHEN last_rank = 1
        THEN period_label END) AS ending_period,
    ROUND(MAX(CASE WHEN last_rank = 1
        THEN net_profit_margin_pct END), 2) AS ending_margin_pct,
    ROUND(
        MAX(CASE WHEN last_rank = 1
            THEN net_profit_margin_pct END)
        - MAX(CASE WHEN first_rank = 1
            THEN net_profit_margin_pct END),
        2
    ) AS net_profit_margin_change_pp
FROM ranked_margins
GROUP BY company_name
ORDER BY net_profit_margin_change_pp DESC;



WITH annual_margins AS (
    SELECT
        c.company_name,
        p.period_end,
        cm.net_income_loss_usd_m
            / NULLIF(cm.revenue_usd_m, 0) * 100
            AS net_profit_margin_pct
    FROM edtech_market_intelligence.company_metrics AS cm
    JOIN edtech_market_intelligence.companies AS c
        ON cm.company_id = c.company_id
    JOIN edtech_market_intelligence.periods AS p
        ON cm.period_id = p.period_id
    WHERE p.period_type = 'Full fiscal year'
      AND p.period_end >= '2021-01-01'
      AND p.period_end <= '2025-12-31'
      AND cm.revenue_usd_m IS NOT NULL
      AND cm.net_income_loss_usd_m IS NOT NULL
),
ranked AS (
    SELECT
        company_name,
        period_end,
        net_profit_margin_pct,
        ROW_NUMBER() OVER (
            PARTITION BY company_name
            ORDER BY period_end
        ) AS first_rank,
        ROW_NUMBER() OVER (
            PARTITION BY company_name
            ORDER BY period_end DESC
        ) AS last_rank
    FROM annual_margins
)
SELECT
    company_name,
    ROUND(
        MAX(CASE WHEN last_rank = 1
            THEN net_profit_margin_pct END), 2
    ) AS latest_net_profit_margin_pct,
    ROUND(
        MAX(CASE WHEN last_rank = 1
            THEN net_profit_margin_pct END)
        -
        MAX(CASE WHEN first_rank = 1
            THEN net_profit_margin_pct END), 2
    ) AS overall_margin_change_pp
FROM ranked
GROUP BY company_name
ORDER BY overall_margin_change_pp DESC;

-- Q3: Which company reported the highest latest annual net profit margin, and what factors affect the comparability of that result?


WITH annual_results AS (
    SELECT
        c.company_name,
        p.period_label,
        p.period_end,
        cm.revenue_usd_m,
        cm.net_income_loss_usd_m,
        ROW_NUMBER() OVER (
            PARTITION BY c.company_name
            ORDER BY p.period_end DESC
        ) AS rn
    FROM edtech_market_intelligence.company_metrics AS cm
    JOIN edtech_market_intelligence.companies AS c
        ON cm.company_id = c.company_id
    JOIN edtech_market_intelligence.periods AS p
        ON cm.period_id = p.period_id
    WHERE p.period_type = 'Full fiscal year'
      AND p.period_end <= '2025-12-31'
      AND cm.revenue_usd_m IS NOT NULL
      AND cm.net_income_loss_usd_m IS NOT NULL
)
SELECT
    company_name,
    period_label,
    revenue_usd_m,
    net_income_loss_usd_m,
    ROUND(
        net_income_loss_usd_m
        / NULLIF(revenue_usd_m, 0) * 100,
        2
    ) AS net_profit_margin_pct
FROM annual_results
WHERE rn = 1
ORDER BY net_profit_margin_pct DESC;

-- Enterprise-learning section within Dashboard 1
-- Q1. How has Udemy Business ARR changed over time?

SELECT
    fiscal_year,
    ub_arr_usd AS ub_arr_usd_thousands,
    ROUND(ub_arr_usd / 1000.0, 3) AS ub_arr_usd_millions,
    ROUND(
        (
            ub_arr_usd -
            LAG(ub_arr_usd) OVER (ORDER BY year)
        )
        / NULLIF(
            LAG(ub_arr_usd) OVER (ORDER BY year),
            0
        ) * 100,
        2
    ) AS annual_arr_growth_pct
FROM edtech_market_intelligence.udemy_analysis_data
WHERE year BETWEEN 2021 AND 2025
  AND coverage = 'Full year'
ORDER BY year;

SELECT
    fiscal_year,
    ROUND(ub_arr_usd / 1000.0, 3)
        AS arr_usd_millions,
    ROUND(
        (
            ub_arr_usd -
            LAG(ub_arr_usd) OVER (ORDER BY year)
        ) /
        NULLIF(
            LAG(ub_arr_usd) OVER (ORDER BY year),
            0
        ) * 100,
        2
    ) AS annual_arr_growth_pct
FROM edtech_market_intelligence.udemy_analysis_data
WHERE year BETWEEN 2021 AND 2025
  AND coverage = 'Full year'
ORDER BY year;







