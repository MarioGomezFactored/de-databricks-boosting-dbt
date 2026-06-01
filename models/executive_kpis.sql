{{ config(materialized='table') }}

with orders as (
    select * from db_boosting_april_2026_cohort.gold.orders_daily_summary
),

sellers as (
    select * from db_boosting_april_2026_cohort.gold.seller_performance
),

categories as (
    select * from db_boosting_april_2026_cohort.gold.product_category_sales
),

order_kpis as (
    select
        sum(order_count)                                                              as total_orders,
        sum(total_revenue)                                                            as total_revenue,
        sum(total_discount)                                                           as total_discount,
        sum(total_tax)                                                                as total_tax,
        sum(total_items)                                                              as total_items,
        avg(avg_order_value)                                                          as avg_order_value,
        count(distinct order_date_id)                                                as active_days,
        sum(case when order_status = 'Cancelled' then order_count else 0 end)        as cancelled_orders,
        sum(case when order_status = 'Delivered' then order_count else 0 end)        as delivered_orders
    from orders
),

seller_kpis as (
    select
        count(distinct seller_id) as active_sellers,
        sum(total_gross_margin)    as total_gross_margin,
        avg(avg_margin_pct)        as avg_margin_pct
    from sellers
),

category_kpis as (
    select
        count(distinct category_id) as active_categories,
        avg(avg_discount_pct)        as avg_discount_pct
    from categories
),

final as (
    select
        -- Volume
        o.total_orders,
        o.total_items,
        o.active_days,
        -- Revenue
        o.total_revenue,
        round(o.avg_order_value, 2)                                                       as avg_order_value,
        o.total_discount,
        o.total_tax,
        -- Profitability
        s.total_gross_margin,
        round(s.total_gross_margin / nullif(o.total_revenue, 0) * 100, 2)                as overall_margin_pct,
        round(s.avg_margin_pct * 100, 2)                                                  as avg_seller_margin_pct,
        -- Fulfilment
        round(o.cancelled_orders / nullif(o.total_orders, 0) * 100, 2)                   as cancellation_rate_pct,
        round(o.delivered_orders / nullif(o.total_orders, 0) * 100, 2)                   as delivery_rate_pct,
        -- Supply
        s.active_sellers,
        c.active_categories,
        round(c.avg_discount_pct, 2)                                                      as avg_discount_pct
    from order_kpis  o
    cross join seller_kpis   s
    cross join category_kpis c
)

select * from final
