-- =============================================================================
-- stg_tpch__regions
-- =============================================================================
-- Staging layer for TPCH regions. 5 rows.
-- =============================================================================

with source as (
    select * from {{ source('tpch', 'region') }}
),

renamed as (
    select
        r_regionkey  as region_key,
        r_name       as region_name,
        r_comment    as comment
    from source
)

select * from renamed
