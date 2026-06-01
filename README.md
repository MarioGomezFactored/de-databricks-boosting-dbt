# dbt — Orders Medallion Analytics

dbt models that read from the gold layer produced by the DLT streaming pipeline
(`db_boosting_april_2026_cohort.gold.*`) and expose business-ready aggregations.
Silver dimension tables (`db_boosting_april_2026_cohort.silver.*`) are joined where
the gold layer lacks hierarchy or segmentation attributes.

Databricks code here: https://github.com/factoredai/de-databricks-boosting

---

## Project structure

```
dbt/
├── models/
│   ├── schema.yml                  # generic tests (not_null, unique)
│   ├── revenue_by_date.sql         # daily revenue trends + cumulative totals
│   ├── revenue_by_segment.sql      # revenue by customer segment and tier
│   ├── revenue_by_geography.sql    # revenue by shipping country and region
│   ├── top_sellers_ranked.sql      # sellers ranked by revenue with market share
│   ├── category_performance.sql    # category revenue, margin, and discount summary
│   ├── brand_category_sales.sql    # sales by brand × category with hierarchy
│   └── executive_kpis.sql          # single-row executive KPI summary
└── tests/
    ├── assert_revenue_non_negative.sql           # all revenue values ≥ 0
    ├── assert_margin_pct_in_range.sql            # margin % within [-100, 100]
    ├── assert_no_duplicate_date_currency.sql     # grain uniqueness on revenue_by_date
    ├── assert_no_duplicate_segment_tier_currency.sql  # grain uniqueness on revenue_by_segment
    ├── assert_no_duplicate_geo_currency.sql      # grain uniqueness on revenue_by_geography
    ├── assert_no_duplicate_brand_category.sql    # grain uniqueness on brand_category_sales
    └── assert_executive_kpis_single_row.sql      # executive_kpis returns exactly 1 row
```

---

## Data sources

### Gold layer (primary facts)


| Gold table                                                  | Description                                                     |
| ----------------------------------------------------------- | --------------------------------------------------------------- |
| `db_boosting_april_2026_cohort.gold.orders_daily_summary`   | Daily order metrics by status, currency, segment, and geography |
| `db_boosting_april_2026_cohort.gold.seller_performance`     | Seller-level revenue and gross margin                           |
| `db_boosting_april_2026_cohort.gold.product_category_sales` | Category-level sales and margin                                 |

### Silver layer (dimension enrichment)

Some gold tables lose dimension keys during aggregation. The following silver tables
are joined to recover hierarchy and segmentation attributes:


| Silver table                | Used by                                        | Provides                                                       |
| --------------------------- | ---------------------------------------------- | -------------------------------------------------------------- |
| `silver.fact_orders_silver` | `revenue_by_segment`, `revenue_by_geography`   | Per-order fact rows with`customer_id` and `ship_location_id` |
| `silver.dim_customer`       | `revenue_by_segment`                           | `customer_segment`, `customer_tier`                            |
| `silver.dim_location`       | `revenue_by_geography`                         | `ship_country`, `ship_region`                                  |
| `silver.dim_seller`         | `top_sellers_ranked`                           | `seller_name`, `seller_type`, `country`, `region`              |
| `silver.dim_category`       | `category_performance`, `brand_category_sales` | `category_name`, `parent_category`, `department`               |

All silver dimension joins use active SCD2 records (`WHERE __END_AT IS NULL`).

---

## Models

### `revenue_by_date`

Reads `orders_daily_summary`, drops cancelled orders, re-aggregates by date and currency,
and adds `cumulative_revenue` and `cumulative_orders` window columns.
Grain: `(order_date_id, currency_code)`.

### `revenue_by_segment`

Sources per-order rows from `silver.fact_orders_silver` (to recover `customer_id`) and
joins `silver.dim_customer` for segment and tier. Aggregates revenue, discount, and order
counts. Grain: `(customer_segment, customer_tier, currency_code)`.

### `revenue_by_geography`

Sources per-order rows from `silver.fact_orders_silver` (to recover `ship_location_id`)
and joins `silver.dim_location` for country and region. Aggregates revenue, discount, and
order counts with country-level share. Grain: `(ship_country, ship_region, currency_code)`.

### `top_sellers_ranked`

Reads `seller_performance`, joins `silver.dim_seller` for seller profile and geography,
rolls up across currencies, and ranks sellers by total revenue. Outputs `revenue_rank`,
`revenue_share_pct`, and `units_share_pct`. Grain: `seller_id`.

### `category_performance`

Reads `product_category_sales`, joins `silver.dim_category` for the category hierarchy,
aggregates to one row per category, and computes `gross_margin_pct`, `revenue_share_pct`,
and `margin_share_pct`. Grain: `category_id`.

### `brand_category_sales`

Reads `product_category_sales`, aggregates fact metrics by `(brand, category_id)`, then
joins `silver.dim_category` for hierarchy attributes. Computes brand-level and
department-level revenue share. Grain: `(brand, category_id)`.

### `executive_kpis`

Joins all three gold tables via a `CROSS JOIN` of three sub-aggregations.
Returns a single row with volume, revenue, profitability, fulfilment, and supply KPIs.

---

## Running the project

```bash
dbt run          # materialize all models as tables
dbt test         # run generic + singular tests
dbt run --select revenue_by_date   # run a single model
dbt test --select revenue_by_date  # test a single model
```
