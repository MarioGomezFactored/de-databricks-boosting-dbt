{{ config(materialized='table') }}

with source as (
    select * from db_boosting_april_2026_cohort.gold.orders_daily_summary
),

active_orders as (
    select *
    from source
    where order_status != 'Cancelled'
),

daily_totals as (
    select
        order_date_key,
        currency_code,
        sum(order_count)     as order_count,
        sum(total_revenue)   as total_revenue,
        sum(total_discount)  as total_discount,
        sum(total_tax)       as total_tax,
        sum(total_shipping)  as total_shipping,
        sum(total_items)     as total_items,
        avg(avg_order_value) as avg_order_value
    from active_orders
    group by order_date_key, currency_code
),

with_running_totals as (
    select
        *,
        sum(total_revenue) over (
            partition by currency_code
            order by order_date_key
            rows between unbounded preceding and current row
        ) as cumulative_revenue,
        sum(order_count) over (
            partition by currency_code
            order by order_date_key
            rows between unbounded preceding and current row
        ) as cumulative_orders
    from daily_totals
)

select *
from with_running_totals
order by order_date_key desc, currency_code
