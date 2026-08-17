-- =============================================================================
-- stg_tpch__part_suppliers
-- =============================================================================
-- Part-supplier relationships. One row per (part, supplier) combination.
-- ~800K rows. Captures supply cost and available quantity for each pairing.
-- =============================================================================

with source as (
    select * from {{ source('tpch', 'partsupp') }}
),

renamed as (
    select
        -- ids (composite key)
        ps_partkey as part_key,
        ps_suppkey as supplier_key,

        -- measures
        cast(ps_availqty as integer) as available_quantity,
        cast(ps_supplycost as number(12, 2)) as supply_cost,

        -- attributes
        ps_comment as comment

    from source
)

select * from renamed
