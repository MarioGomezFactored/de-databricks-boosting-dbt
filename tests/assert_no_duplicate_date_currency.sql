-- Fails if the same (order_date_id, currency_code) appears more than once
-- in revenue_by_date, which would indicate a grouping bug in the upstream model.

select
    order_date_id,
    currency_code,
    count(*) as row_count
from {{ ref('revenue_by_date') }}
group by order_date_id, currency_code
having count(*) > 1
