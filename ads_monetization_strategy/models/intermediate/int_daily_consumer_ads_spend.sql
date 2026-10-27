{{
    config(
        materialized='table',
        meta={'primary_key': ['ads_cpm_id']}
    )
}}

/*
    Assumptions:
    - Grain matches stg_daily_consumer_ads_cpm: one row per ads_cpm_id
      (date / ad_product_category / region / ad_placement / industry / customer_id / account_id).
    - ads_spend is the advertiser spend for the row: impressions * cpm / 1000, rounded to 1 decimal.
    - Rows with 0 impressions are kept so that days with no delivery remain visible.
*/

WITH stg AS (
    SELECT
        *
    FROM {{ ref('stg_daily_consumer_ads_cpm') }}
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
    ROUND(impressions * cpm / 1000, 1) AS ads_spend,
    impressions > 0 AS has_impressions
FROM stg
