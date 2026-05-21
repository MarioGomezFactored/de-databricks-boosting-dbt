-- Fails if (ship_country, ship_region, currency_code) appears more than once
-- in revenue_by_geography, indicating a grouping bug.

select
    ship_country,
    ship_region,
    currency_code,
    count(*) as row_count
from {{ ref('revenue_by_geography') }}
group by ship_country, ship_region, currency_code
having count(*) > 1
