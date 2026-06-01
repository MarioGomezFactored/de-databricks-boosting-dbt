-- Fails if (brand, category_id) appears more than once in brand_category_sales,
-- indicating a grouping bug.

select
    brand,
    category_id,
    count(*) as row_count
from {{ ref('brand_category_sales') }}
group by brand, category_id
having count(*) > 1
