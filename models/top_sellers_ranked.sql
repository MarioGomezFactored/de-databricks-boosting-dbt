{{ config(materialized='table') }}

with source as (
    select * from db_boosting_april_2026_cohort.gold.seller_performance
),

-- Active SCD2 records from silver for seller profile/geography
dim_sellers as (
    select
        seller_key,
        seller_name,
        seller_type,
        country as seller_country,
        region  as seller_region
    from db_boosting_april_2026_cohort.silver.dim_seller
    where __END_AT is null
),

-- Roll up across currencies; join silver for the dimension attributes
seller_totals as (
    select
        s.seller_key,
        d.seller_name,
        d.seller_type,
        d.seller_country,
        d.seller_region,
        sum(s.order_count)        as order_count,
        sum(s.total_revenue)      as total_revenue,
        sum(s.total_gross_margin) as total_gross_margin,
        sum(s.total_units_sold)   as total_units_sold,
        avg(s.avg_margin_pct)     as avg_margin_pct
    from source s
    left join dim_sellers d on s.seller_key = d.seller_key
    group by s.seller_key, d.seller_name, d.seller_type, d.seller_country, d.seller_region
),

ranked as (
    select
        *,
        rank()                over (order by total_revenue desc) as revenue_rank,
        sum(total_revenue)    over ()                            as grand_total_revenue,
        sum(total_units_sold) over ()                            as grand_total_units
    from seller_totals
),

final as (
    select
        seller_key,
        seller_name,
        seller_type,
        seller_country,
        seller_region,
        order_count,
        total_revenue,
        total_gross_margin,
        total_units_sold,
        round(avg_margin_pct * 100, 2)                                     as margin_pct,
        revenue_rank,
        round(total_revenue    / nullif(grand_total_revenue, 0) * 100, 2)  as revenue_share_pct,
        round(total_units_sold / nullif(grand_total_units, 0)   * 100, 2)  as units_share_pct
    from ranked
)

select *
from final
order by revenue_rank
