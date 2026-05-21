{{ config(materialized='table') }}

with source as (
    select * from db_boosting_april_2026_cohort.gold.product_category_sales
),

brand_category_totals as (
    select
        brand,
        category_key,
        max(category_name)              as category_name,
        max(parent_category)            as parent_category,
        max(department)                 as department,
        max(full_path)                  as full_path,
        count(*)                        as total_item_count,
        sum(line_total)                 as total_revenue,
        sum(gross_margin)               as total_gross_margin,
        avg(discount_pct)               as avg_discount_pct,
        sum(quantity)                   as total_units_sold,
        count(distinct order_key)       as total_orders,
        count(distinct order_date_key)  as active_days
    from joined
    group by brand, category_key
),

with_share as (
    select
        *,
        sum(total_revenue) over ()                          as grand_total_revenue,
        sum(total_revenue) over (partition by brand)        as brand_total_revenue,
        sum(total_revenue) over (partition by department)   as dept_total_revenue,
        rank() over (order by total_revenue desc)           as revenue_rank
    from brand_category_totals
)

select
    brand,
    category_key,
    category_name,
    parent_category,
    department,
    full_path,
    total_item_count,
    total_revenue,
    total_gross_margin,
    round(total_gross_margin / nullif(total_revenue, 0) * 100, 2)          as gross_margin_pct,
    round(avg_discount_pct, 2)                                              as avg_discount_pct,
    total_units_sold,
    total_orders,
    active_days,
    revenue_rank,
    round(total_revenue / nullif(grand_total_revenue, 0) * 100, 2)         as revenue_share_pct,
    round(total_revenue / nullif(brand_total_revenue, 0) * 100, 2)         as revenue_share_within_brand_pct,
    round(total_revenue / nullif(dept_total_revenue, 0) * 100, 2)          as revenue_share_within_dept_pct
from with_share
order by revenue_rank
