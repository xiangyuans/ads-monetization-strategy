{{
    config(
        materialized='table',
        meta={'primary_key': ['ads_cpm_id']}
    )
}}

/*
    Assumptions:
    - Initial data cleaning: cpm values of '#DIV/0!' were replaced with 0 in the seed file.
    - ads_cpm_id is a hash of date, ad_product_category, region, ad_placement, industry,
      customer_id and account_id, which together uniquely identify a row.
*/

WITH source AS (
    SELECT 
        * 
    FROM {{ ref('tiktok_monetization_strategy') }}

),

renamed AS (
    SELECT
        parse_date('%m/%d/%Y', DATE) AS date,
        ad_product_category,
        region,
        ad_placement,
        industry,
        CAST(impressions AS int64) AS impressions,
        CAST(cpm AS NUMERIC) AS cpm,
        customer_id,
        -- some ids were mangled into scientific notation (e.g. '.62986E+151.62986E+1'); original digits are lost
        NOT regexp_contains(customer_id, r'^\d+$') AS is_customer_id_corrupted,
        SAFE_CAST(NULLIF(account_id, 'NULL') AS int64) AS account_id
    FROM source
)

SELECT
    TO_HEX(MD5(CONCAT(
        CAST(DATE AS STRING), '|',
        COALESCE(ad_product_category, ''), '|',
        COALESCE(region, ''), '|',
        COALESCE(ad_placement, ''), '|',
        COALESCE(industry, ''), '|',
        COALESCE(customer_id, ''), '|',
        COALESCE(CAST(account_id AS STRING), '')
    ))) AS ads_cpm_id,
    date,
    ad_product_category,
    region,
    ad_placement,
    industry,
    impressions,
    cpm,
    customer_id,
    is_customer_id_corrupted,
    account_id
FROM renamed
