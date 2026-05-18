-- Fails if executive_kpis returns more than one row.
-- This model is a CROSS JOIN of three aggregations and must always produce exactly one row.

select count(*) as row_count
from {{ ref('executive_kpis') }}
having count(*) != 1
