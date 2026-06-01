-- =============================================================================
-- stg_tpch__suppliers
-- =============================================================================
-- Staging layer for TPCH suppliers. One row per supplier.
-- =============================================================================

with source as (
    select * from {{ source('tpch', 'supplier') }}
),

renamed as (
    select
        -- ids
        s_suppkey as supplier_key,
        s_nationkey as nation_key,

        -- attributes
        s_name as supplier_name,
        s_address as address,
        s_phone as phone,
        s_comment as comment,

        -- measures
        cast(s_acctbal as number(12, 2)) as account_balance

    from source
)

select * from renamed
