-- =============================================================================
-- stg_tpch__parts
-- =============================================================================
-- Staging layer for TPCH parts. One row per part.
--
-- The TPCH `p_type` column is a delimited string of three sub-attributes
-- (e.g. "ECONOMY ANODIZED STEEL"). We parse it into category / finish /
-- material columns here so downstream models can group on them cleanly.
-- =============================================================================

with source as (
    select * from {{ source('tpch', 'part') }}
),

renamed as (
    select
        -- ids
        p_partkey                          as part_key,

        -- attributes
        p_name                             as part_name,
        p_mfgr                             as manufacturer,
        p_brand                            as brand,
        p_type                             as part_type,
        p_container                        as container,
        p_comment                          as comment,

        -- measures
        cast(p_size as integer)            as size,
        cast(p_retailprice as number(12, 2)) as retail_price,

        -- parsed sub-attributes (p_type = "<category> <finish> <material>")
        split_part(p_type, ' ', 1)         as part_category,
        split_part(p_type, ' ', 2)         as part_finish,
        split_part(p_type, ' ', 3)         as part_material

    from source
)

select * from renamed
