{{ config(materialized='table') }}

-- gold.orders_daily_summary lost customer_key during aggregation, so we source
-- from silver to recover customer_segment and customer_tier.

with orders as (
    select
        order_date_key,
        currency_code,
        customer_key,
        total_amount    as order_revenue,
        discount_amount as order_discount,
        item_count
    from db_boosting_april_2026_cohort.silver.fact_orders_silver
    where order_status != 'Cancelled'
),

dim_customers as (
    select
        customer_key,
        segment as customer_segment,
        tier    as customer_tier
    from db_boosting_april_2026_cohort.silver.dim_customer
    where __END_AT is null
),

joined as (
    select
        o.order_date_key,
        o.currency_code,
        c.customer_segment,
        c.customer_tier,
        o.order_revenue,
        o.order_discount,
        o.item_count
    from orders o
    left join dim_customers c on o.customer_key = c.customer_key
),

segment_totals as (
    select
        customer_segment,
        customer_tier,
        currency_code,
        count(*)                       as order_count,
        sum(order_revenue)             as total_revenue,
        sum(order_discount)            as total_discount,
        sum(item_count)                as total_items,
        avg(order_revenue)             as avg_order_value,
        count(distinct order_date_key) as active_days
    from joined
    group by customer_segment, customer_tier, currency_code
),

with_share as (
    select
        *,
        sum(total_revenue) over ()                  as grand_total_revenue,
        rank() over (order by total_revenue desc)   as revenue_rank
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
