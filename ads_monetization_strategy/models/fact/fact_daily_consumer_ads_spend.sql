{{
    config(
        materialized='table',
        meta={'primary_key': ['ads_cpm_id']}
    )
}}

/*
    Assumptions:
    - Grain matches int_daily_consumer_ads_spend: one row per ads_cpm_id
      (date / ad_product_category / region / ad_placement / industry / customer_id / account_id).
    - date joins to dim_date.date.
*/

WITH int_ads_spend AS (
    SELECT
        *
    FROM {{ ref('int_daily_consumer_ads_spend') }}
)

SELECT
    ads_cpm_id,
    date,
    ad_product_category,
    region,
    ad_placement,
    industry,
    customer_id,
    is_customer_id_corrupted,
    account_id,
    impressions,
    cpm,
    ads_spend,
    has_impressions
FROM int_ads_spend
