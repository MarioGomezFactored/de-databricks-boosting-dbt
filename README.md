# dbt — Orders Medallion Analytics

dbt models that read from the gold layer produced by the DLT streaming pipeline
(`db_boosting_april_2026_cohort.gold.*`) and expose business-ready aggregations.

Databricks code here: https://github.com/factoredai/de-databricks-boosting

---

## Project structure

```
dbt/
├── models/
│   ├── schema.yml              # generic tests (not_null, unique)
│   ├── revenue_by_date.sql     # daily revenue trends + cumulative totals
│   ├── top_sellers_ranked.sql  # sellers ranked by revenue with market share
│   ├── category_performance.sql# category revenue, margin, and discount summary
│   └── executive_kpis.sql      # single-row executive KPI summary
└── tests/
    ├── assert_revenue_non_negative.sql       # all revenue values ≥ 0
    ├── assert_margin_pct_in_range.sql        # margin % within [-100, 100]
    ├── assert_no_duplicate_date_currency.sql # grain uniqueness on revenue_by_date
    └── assert_executive_kpis_single_row.sql  # executive_kpis returns exactly 1 row
```

---

## Data sources (gold layer)

All models read directly from the Unity Catalog gold tables written by the DLT pipeline.

| Gold table | Description |
|---|---|
| `db_boosting_april_2026_cohort.gold.orders_daily_summary` | Daily order metrics by status and currency |
| `db_boosting_april_2026_cohort.gold.seller_performance` | Seller-level revenue and gross margin |
| `db_boosting_april_2026_cohort.gold.product_category_sales` | Category-level sales and margin |

---

## Models

### `revenue_by_date`
Reads `orders_daily_summary`, drops cancelled orders, re-aggregates by date and currency,
and adds `cumulative_revenue` and `cumulative_orders` window columns.

### `top_sellers_ranked`
Reads `seller_performance`, rolls up across currencies, and ranks sellers by total revenue.
Outputs `revenue_rank`, `revenue_share_pct`, and `units_share_pct`.

### `category_performance`
Reads `product_category_sales`, aggregates to one row per category, and computes
`gross_margin_pct`, `revenue_share_pct`, and `margin_share_pct`.

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
