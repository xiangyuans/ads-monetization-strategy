# Ads Monetization Strategy: Where Ads Spend Comes From

Which regions, placements and accounts drive ads spend, and is spend growing because of more impressions or a higher price (CPM)? This project cleans one file of daily ad delivery data in BigQuery with dbt and answers those questions in a notebook.

## At a glance

| | |
|---|---|
| **Scope** | Complete months Sep 2018 – Apr 2019 (242 days). Raw data runs 19 Aug 2018 – 3 May 2019. |
| **Data** | One CSV of daily ad delivery: 65,534 rows, one per date / ad product / region / placement / industry / customer / account. |
| **Model** | One fact table of daily ads spend, linked to a calendar table. Built with dbt on BigQuery. |
| **Key rules** | Spend = impressions × CPM / 1000 per row. CPM is always recalculated from totals, never averaged. |

## Results

| Headline | What it means |
|---|---|
| **$62.9M** | Total ads spend on 12.0B impressions, an overall CPM of $5.26. |
| **48.7%** | Region Two's share of spend ($30.6M). Two led every month Sep–Dec 2018; Region One led Jan–Apr 2019 on a much higher CPM ($16.62 vs $4.90). |
| **87.9%** | Share of spend on placement Beta ($55.3M). Beta has the lowest CPM ($4.98), so it wins on volume, not price. |
| **+$2.91M** | Spend growth from Sep–Dec 2018 to Jan–Apr 2019 while impressions fell. Higher CPM from identified customers (+$7.33M) drove it. |

Spend is hard to attribute: **59.2% of spend sits under account ID 0**, and among identified accounts the **top 4 hold 74.9%** of spend. The analysis is in [`analyses/ads_spend_sources.ipynb`](ads_monetization_strategy/analyses/ads_spend_sources.ipynb).

## How it was done

1. **Load** the CSV as a dbt seed, every column as text, so long IDs and bad values survive the load.
2. **Clean** in staging: parse dates, cast numbers, flag corrupted customer IDs, turn `'NULL'` account IDs into real nulls, and build a unique row key.
3. **Calculate** ads spend for each row in the intermediate layer.
4. **Model** a fact table of daily spend and a calendar table.
5. **Test and analyze**: dbt tests run on every build, then the notebook answers the four questions.

## Data lineage

```
SOURCE (seed)                   STAGING                       INTERMEDIATE                    MART                              ANALYSIS
tiktok_monetization_strategy -> stg_daily_consumer_ads_cpm -> int_daily_consumer_ads_spend -> fact_daily_consumer_ads_spend -> ads_spend_sources.ipynb
                                         |                                                    dim_date --------------------------^
                                         +--- min/max date --------------------------------------^
```

| Layer | Model | Schema | Grain | What it does |
|---|---|---|---|---|
| Source | `tiktok_monetization_strategy` (seed) | `stg_ads` | one row per delivery combination | Raw CSV, all columns as text |
| Staging | `stg_daily_consumer_ads_cpm` | `stg_ads` | same | Types, cleaning, `ads_cpm_id` key, corruption flag |
| Intermediate | `int_daily_consumer_ads_spend` | `int_ads` | same | Adds `ads_spend` and `has_impressions` |
| Mart | `fact_daily_consumer_ads_spend` | `fact_ads` | same | Analysis-ready fact; `date` joins to `dim_date` |
| Mart | `dim_date` | `dim_ads` | one row per day | Calendar from first to last delivery date, ISO weeks |

The row key `ads_cpm_id` is an MD5 hash of date, ad product, region, placement, industry, customer ID and account ID. These seven columns are unique in the source (0 duplicates), and dbt tests the key for `unique` and `not_null`.

## Key definitions

| Term | Meaning |
|---|---|
| Ads spend | What advertisers paid for a row, treated as platform revenue. See Assumptions for how it is calculated. |
| Impressions | Number of times an ad was served. |
| CPM | Cost per thousand impressions. For any group (region, month, placement…) it is recalculated from totals: `SUM(ads_spend) × 1000 / SUM(impressions)`, and returns null for groups with no impressions. |
| Spend share | A group's spend as a percentage of total spend in the same period. |
| Complete month | A month where the calendar has every day. Only complete months are analyzed (Sep 2018 – Apr 2019). |
| First / second half | Sep–Dec 2018 and Jan–Apr 2019, used to compare the drivers of spend. |
| Customer 0 | Rows with `customer_id = '0'` (always with `account_id = 0`). A placeholder, not one real customer, so it is reported separately. |
| Identified customer | Any customer ID other than `0`. Customer counts cover these only. |
| Active customer / account | Served at least one impression in the period. |
| Retained / Lost / New | Identified customers active in both halves / only the first half / only the second half. |
| Identified account | An account ID that is not `0` and not missing. Only these spend can be tied to an account. |
| Spend tier | Accounts grouped by total spend: $0, under $1K, $1K–10K, $10K–100K, $100K–1M, $1M+. |

## Assumptions

- **CPM is the price the advertiser paid**, so ads spend equals platform revenue. Currency is assumed to be USD.
- **Ads spend is derived per row** from impressions and CPM: `ads_spend = ROUND(impressions × cpm / 1000, 1)`.
- **`#DIV/0!` values in the CPM column are treated as 0**, so those rows add $0 spend.
- **Each row is one unique delivery combination** of the seven grain columns. Checked: no duplicates.
- **Customer 0 and account 0 are placeholders**, such as unassigned or self-serve traffic, not single advertisers.
- **Rows with 0 impressions are kept** so days with no delivery stay visible; they add $0 spend.
- **Partial months are excluded** from the analysis (Aug 2018 has 13 of 31 days, May 2019 has 3 of 31) so monthly comparisons are fair.
- **Regions, placements, products and industries are anonymous labels.** No hierarchy or geography is assumed between them.
- **Weeks start on Monday** (ISO weeks) in `dim_date`.

## Data issues found and fixed

| Issue in the source | What we did | Size |
|---|---|---|
| **Spreadsheet errors in CPM.** Some CPM cells held `#DIV/0!`. | Replaced with 0 in the seed file before loading | Handled before load |
| **Customer IDs too long for a number.** IDs are 20 digits, over the BigQuery INT64 limit. | Loaded and kept as text | 1,313 IDs |
| **Corrupted customer IDs.** Some IDs became scientific notation, e.g. `.62986E+151.62986E+1`. | Kept as-is and flagged with `is_customer_id_corrupted` | 3,925 rows, 66 values |
| **Missing account IDs stored as text.** Missing values were the literal string `'NULL'`. | Converted to real nulls | 1,458 rows |
| **Dates stored as text** in `M/D/YYYY`. | Parsed to `DATE` | All rows |
| **Partial months** at both ends of the data. | Excluded from the analysis | Aug 2018, May 2019 |
| **No row ID** in the source. | Added `ads_cpm_id`, an MD5 hash of the seven grain columns | All rows |
| **Most rows have no delivery.** 83% of rows have 0 impressions. | Kept and flagged with `has_impressions` | 54,516 rows |

## Known issues

- **Customer IDs have lost precision.** 1,309 of 1,313 long customer IDs end in `0000`, a sign they were saved through a spreadsheet with about 15 significant digits. Different customers may share an ID, so customer counts may be understated.
- **Corrupted customer IDs can't be recovered.** One corrupted value may stand for several real customers.
- **Most spend can't be tied to an advertiser.** Account ID 0 holds 59.2% of spend and Customer 0 holds 73–92% of impressions each month.
- **184 rows have impressions but a CPM of 0**, so they count as $0 spend. They may be free delivery or former `#DIV/0!` cells.
- **Rounding.** `ads_spend` is rounded to 1 decimal per row, so totals can differ slightly from impressions × CPM / 1000.
- **Unused categories.** Regions Twelve–Fourteen, placements Delta–Zeta and ad product C have no spend in the analysis period.

## Future improvements

- Get customer IDs from the source system as text, so they keep full precision and corrupted values can be repaired.
- Find out what Customer 0 and account ID 0 represent and map them to advertisers where possible.
- Move the `#DIV/0!` fix from a manual seed edit into staging (`SAFE_CAST`), so the pipeline is reproducible from the raw file.
- Add customer and account dimension tables, and `accepted_values` tests on the staging columns.

## Explaining a change in spend

The notebook uses a driver tree to explain why spend changed:

```
Ads spend   = Impressions × CPM / 1000
Impressions = Active customers × Impressions per customer
```

Spend changes because more customers deliver, each customer gets more impressions, or the price changes. The change between the two halves (Sep–Dec 2018 vs Jan–Apr 2019) is split into a dollar effect for each, using a log-mean Divisia (LMDI) decomposition. The effects add up exactly to the total change.

## Running the project

```bash
# from the repository root, with the virtual environment active and a BigQuery profile set up
cd ads_monetization_strategy
dbt seed     # load the CSV
dbt build    # build and test every model
```

Then open [`analyses/ads_spend_sources.ipynb`](ads_monetization_strategy/analyses/ads_spend_sources.ipynb) to run the analysis.
