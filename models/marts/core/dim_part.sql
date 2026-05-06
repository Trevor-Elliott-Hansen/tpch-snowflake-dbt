-- =============================================================================
-- dim_part
-- =============================================================================
-- Part dimension. Pass-through from staging — the type-parsing already
-- happened in stg_tpch__parts. Materialized as a table here for query
-- performance in BI tools.
-- =============================================================================

with parts as (
    select * from {{ ref('stg_tpch__parts') }}
)

select
    part_key,
    part_name,
    manufacturer,
    brand,
    part_type,
    part_category,
    part_finish,
    part_material,
    container,
    size,
    retail_price
from parts
