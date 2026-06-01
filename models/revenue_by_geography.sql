{{ config(materialized='table') }}

-- gold.orders_daily_summary lost ship_location_id during aggregation, so we source
-- from silver to recover ship_country and ship_region.

with orders as (
    select
        order_date_id,
        currency_code,
        ship_location_id,
        total_amount    as order_revenue,
        discount_amount as order_discount,
        item_count
    from db_boosting_april_2026_cohort.silver.fact_orders_silver
    where order_status != 'Cancelled'
),

dim_locations as (
    select
        location_id,
        country as ship_country,
        region  as ship_region
    from db_boosting_april_2026_cohort.silver.dim_location
    where __END_AT is null
),

joined as (
    select
        o.order_date_id,
        o.currency_code,
        l.ship_country,
        l.ship_region,
        o.order_revenue,
        o.order_discount,
        o.item_count
    from orders o
    join dim_locations l on o.ship_location_id = l.location_id
),

geo_totals as (
    select
        ship_country,
        ship_region,
        currency_code,
        count(*)                       as order_count,
        sum(order_revenue)             as total_revenue,
        sum(order_discount)            as total_discount,
        sum(item_count)                as total_items,
        avg(order_revenue)             as avg_order_value,
        count(distinct order_date_id) as active_days
    from joined
    group by ship_country, ship_region, currency_code
),

with_share as (
    select
        *,
        sum(total_revenue) over ()                              as grand_total_revenue,
        sum(total_revenue) over (partition by ship_country)     as country_total_revenue,
        rank() over (order by total_revenue desc)               as revenue_rank
    from geo_totals
)

select
    ship_country,
    ship_region,
    currency_code,
    order_count,
    total_revenue,
    total_discount,
    total_items,
    round(avg_order_value, 2)                                                   as avg_order_value,
    active_days,
    revenue_rank,
    round(total_revenue / nullif(grand_total_revenue, 0) * 100, 2)             as revenue_share_pct,
    round(total_revenue / nullif(country_total_revenue, 0) * 100, 2)           as revenue_share_within_country_pct
from with_share
order by revenue_rank
