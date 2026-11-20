-- Enterprise-learning section  Dashboard 1
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

-- Que2. What does Udemy Business's reported Net Dollar Retention (NDR) indicate about revenue retention and expansion among existing enterprise customers from FY2021 to FY2025?

SELECT
    fiscal_year,
    ub_ndr_pct AS ndr_pct,

    ROUND(
        ub_ndr_pct -
        LAG(ub_ndr_pct) OVER (ORDER BY year),
        2
    ) AS yoy_change_percentage_points,

    ROUND(
        ub_ndr_pct -
        FIRST_VALUE(ub_ndr_pct) OVER (
            ORDER BY year
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ),
        2
    ) AS change_from_fy2021_percentage_points,

    CASE
        WHEN ub_ndr_pct > 100 THEN 'Net Expansion'
        WHEN ub_ndr_pct < 100 THEN 'Net Contraction'
        WHEN ub_ndr_pct = 100 THEN 'Stable'
        ELSE 'Missing'
    END AS retention_status

FROM edtech_market_intelligence.udemy_analysis_data
WHERE year BETWEEN 2021 AND 2025
  AND coverage = 'Full year'
ORDER BY year;

-- How did Udemy Business's reported enterprise customer count evolve from FY2021 to FY2025?

SELECT
    fiscal_year,
    ub_customers AS enterprise_customers,

    LAG(ub_customers) OVER (
        ORDER BY year
    ) AS previous_year_customers,

    ub_customers
        - LAG(ub_customers) OVER (
            ORDER BY year
        ) AS yoy_change_customers,

    ROUND(
        (
            ub_customers
            - LAG(ub_customers) OVER (
                ORDER BY year
            )
        )
        / NULLIF(
            LAG(ub_customers) OVER (
                ORDER BY year
            ), 0
        ) * 100,
        2
    ) AS yoy_growth_pct

FROM edtech_market_intelligence.udemy_analysis_data

WHERE year BETWEEN 2021 AND 2025
  AND coverage = 'Full year'

ORDER BY year;



