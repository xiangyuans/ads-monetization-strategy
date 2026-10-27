{{
    config(
        materialized='table',
        meta={'primary_key': ['date']}
    )
}}

/*
    Assumptions:
    - One row per calendar day, from the first to the last date in stg_daily_consumer_ads_cpm,
      including days with no ad activity.
    - Weeks start on Monday (ISO weeks).
*/

WITH date_bounds AS (
    SELECT
        MIN(DATE) AS min_date,
        MAX(DATE) AS max_date
    FROM {{ ref('stg_daily_consumer_ads_cpm') }}
),

date_spine AS (
    SELECT
        day AS date
    FROM date_bounds,
        UNNEST(GENERATE_DATE_ARRAY(min_date, max_date)) AS day
)

SELECT
    date,
    EXTRACT(YEAR FROM DATE) AS year,
    EXTRACT(QUARTER FROM DATE) AS quarter,
    EXTRACT(MONTH FROM DATE) AS month,
    FORMAT_DATE('%B', DATE) AS month_name,
    DATE_TRUNC(DATE, MONTH) AS month_start_date,
    EXTRACT(ISOWEEK FROM DATE) AS iso_week,
    DATE_TRUNC(DATE, ISOWEEK) AS week_start_date,
    MOD(EXTRACT(DAYOFWEEK FROM DATE) + 5, 7) + 1 AS day_of_week,
    FORMAT_DATE('%A', DATE) AS day_name,
    EXTRACT(DAYOFWEEK FROM DATE) IN (1, 7) AS is_weekend
FROM date_spine
