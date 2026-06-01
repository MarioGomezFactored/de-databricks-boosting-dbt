{{ config(materialized='table') }}

with source as (
    select * from db_boosting_april_2026_cohort.gold.product_category_sales
),

dim_categories as (
    select
        category_id,
        category_name,
        parent_category,
        department
    from db_boosting_april_2026_cohort.silver.dim_category
    where __END_AT is null
),

brand_facts as (
    select
        brand,
        category_id,
        sum(item_count)                as total_item_count,
        sum(total_revenue)             as total_revenue,
        sum(total_gross_margin)        as total_gross_margin,
        avg(avg_discount_pct)          as avg_discount_pct,
        sum(total_units_sold)          as total_units_sold,
        sum(order_count)               as total_orders,
        count(distinct order_date_id) as active_days
    from source
    group by brand, category_id
),

brand_category_totals as (
    select
        f.brand,
        f.category_id,
        d.category_name,
        d.parent_category,
        d.department,
        f.total_item_count,
        f.total_revenue,
        f.total_gross_margin,
        f.avg_discount_pct,
        f.total_units_sold,
        f.total_orders,
        f.active_days
    from brand_facts f
    join dim_categories d on f.category_id = d.category_id
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
    category_id,
    category_name,
    parent_category,
    department,
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
