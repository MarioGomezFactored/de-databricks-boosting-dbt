{{ config(materialized='table') }}

with source as (
    select * from db_boosting_april_2026_cohort.gold.orders_daily_summary
    where order_status != 'Cancelled'
),

segment_totals as (
    select
        customer_segment,
        customer_tier,
        currency_code,
        sum(order_count)               as order_count,
        sum(total_revenue)             as total_revenue,
        sum(total_discount)            as total_discount,
        sum(total_items)               as total_items,
        avg(avg_order_value)           as avg_order_value,
        count(distinct order_date_key) as active_days
    from source
    group by customer_segment, customer_tier, currency_code
),

with_share as (
    select
        *,
        sum(total_revenue) over ()                         as grand_total_revenue,
        rank() over (order by total_revenue desc)          as revenue_rank
    from segment_totals
)

select
    customer_segment,
    customer_tier,
    currency_code,
    order_count,
    total_revenue,
    total_discount,
    total_items,
    round(avg_order_value, 2)                                              as avg_order_value,
    active_days,
    revenue_rank,
    round(total_revenue / nullif(grand_total_revenue, 0) * 100, 2)        as revenue_share_pct
from with_share
order by revenue_rank
