-- Fails if any row has negative revenue in any gold model.
-- All revenue figures must be >= 0 by definition.

select 'revenue_by_date'       as model, order_date_key::string as grain, total_revenue
from {{ ref('revenue_by_date') }}
where total_revenue < 0

union all

select 'top_sellers_ranked'    as model, seller_key::string     as grain, total_revenue
from {{ ref('top_sellers_ranked') }}
where total_revenue < 0

union all

select 'category_performance'  as model, category_key::string   as grain, total_revenue
from {{ ref('category_performance') }}
where total_revenue < 0
