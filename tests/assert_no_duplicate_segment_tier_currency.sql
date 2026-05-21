-- Fails if (customer_segment, customer_tier, currency_code) appears more than once
-- in revenue_by_segment, indicating a grouping bug.

select
    customer_segment,
    customer_tier,
    currency_code,
    count(*) as row_count
from {{ ref('revenue_by_segment') }}
group by customer_segment, customer_tier, currency_code
having count(*) > 1
