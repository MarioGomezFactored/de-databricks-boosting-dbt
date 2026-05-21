{{ config(materialized='table') }}

with source as (
    select * from db_boosting_april_2026_cohort.gold.product_category_sales
),

-- Active SCD2 records from silver for full category hierarchy
dim_categories as (
    select
        category_key,
        category_name,
        parent_category,
        department,
        full_path
    from db_boosting_april_2026_cohort.silver.dim_category
    where __END_AT is null
),

-- Category-level rollup; join silver for the hierarchy attributes
category_totals as (
    select
        s.category_key,
        d.category_name,
        d.parent_category,
        d.department,
        d.full_path,
        sum(s.item_count)               as total_item_count,
        sum(s.total_revenue)            as total_revenue,
        sum(s.total_gross_margin)       as total_gross_margin,
        avg(s.avg_discount_pct)         as avg_discount_pct,
        sum(s.total_units_sold)         as total_units_sold,
        sum(s.order_count)              as total_orders,
        count(distinct s.order_date_key) as active_days
    from source s
    left join dim_categories d on s.category_key = d.category_key
    group by
        s.category_key,
        d.category_name, d.parent_category, d.department, d.full_path
),

with_share as (
    select
        *,
        sum(total_revenue)      over () as grand_total_revenue,
        sum(total_gross_margin) over () as grand_total_margin,
        rank() over (order by total_revenue desc) as revenue_rank
    from category_totals
),

final as (
    select
        category_key,
        category_name,
        parent_category,
        department,
        full_path,
        total_item_count,
        total_revenue,
        total_gross_margin,
        round(total_gross_margin / nullif(total_revenue, 0) * 100, 2)       as gross_margin_pct,
        round(avg_discount_pct, 2)                                           as avg_discount_pct,
        total_units_sold,
        total_orders,
        active_days,
        revenue_rank,
        round(total_revenue      / nullif(grand_total_revenue, 0) * 100, 2) as revenue_share_pct,
        round(total_gross_margin / nullif(grand_total_margin, 0)  * 100, 2) as margin_share_pct
    from with_share
)

select *
from final
order by revenue_rank
