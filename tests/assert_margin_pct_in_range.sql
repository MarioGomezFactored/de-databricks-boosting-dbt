-- Fails if gross margin % falls outside [-100, 100].
-- Values outside this range indicate a data quality issue in the source.

select seller_id, margin_pct
from {{ ref('top_sellers_ranked') }}
where margin_pct < -100 or margin_pct > 100

union all

select category_id, gross_margin_pct
from {{ ref('category_performance') }}
where gross_margin_pct < -100 or gross_margin_pct > 100
