-- =============================================================================
-- stg_tpch__customers
-- =============================================================================
-- Staging layer for TPCH customers. One row per customer.
-- =============================================================================

with source as (
    select * from {{ source('tpch', 'customer') }}
),

renamed as (
    select
        -- ids
        c_custkey as customer_key,
        c_nationkey as nation_key,

        -- attributes
        c_name as customer_name,
        c_address as address,
        c_phone as phone,
        c_mktsegment as market_segment,
        c_comment as comment,

        -- measures
        cast(c_acctbal as number(12, 2)) as account_balance

    from source
)

select * from renamed
