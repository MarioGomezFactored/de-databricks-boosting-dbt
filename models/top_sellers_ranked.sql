{{ config(materialized='table') }}

with source as (
    select * from db_boosting_april_2026_cohort.gold.seller_performance
),

-- Roll up across currencies to get a single total per seller
seller_totals as (
    select
        seller_key,
        sum(order_count)        as order_count,
        sum(total_revenue)      as total_revenue,
        sum(total_gross_margin) as total_gross_margin,
        sum(total_units_sold)   as total_units_sold,
        avg(avg_margin_pct)     as avg_margin_pct
    from source
    group by seller_key
),

ranked as (
    select
        *,
        rank()        over (order by total_revenue desc)   as revenue_rank,
        sum(total_revenue) over ()                         as grand_total_revenue,
        sum(total_units_sold) over ()                      as grand_total_units
    from seller_totals
),

final as (
    select
        seller_key,
        order_count,
        total_revenue,
        total_gross_margin,
        total_units_sold,
        round(avg_margin_pct * 100, 2)                                    as margin_pct,
        revenue_rank,
        round(total_revenue   / nullif(grand_total_revenue, 0) * 100, 2) as revenue_share_pct,
        round(total_units_sold / nullif(grand_total_units, 0) * 100, 2)  as units_share_pct
    from ranked
)

select *
from final
order by revenue_rank
