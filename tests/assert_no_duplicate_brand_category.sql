-- Fails if (brand, category_key) appears more than once in brand_category_sales,
-- indicating a grouping bug.

select
    brand,
    category_key,
    count(*) as row_count
from {{ ref('brand_category_sales') }}
group by brand, category_key
having count(*) > 1
