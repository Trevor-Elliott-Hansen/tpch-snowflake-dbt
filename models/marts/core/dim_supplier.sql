-- =============================================================================
-- dim_supplier
-- =============================================================================
-- Supplier dimension, denormalized with nation and region. Same pattern as
-- dim_customer.
-- =============================================================================

with suppliers as (
    select * from {{ ref('stg_tpch__suppliers') }}
),

nations as (
    select * from {{ ref('stg_tpch__nations') }}
),

regions as (
    select * from {{ ref('stg_tpch__regions') }}
),

joined as (
    select
        -- ids
        s.supplier_key,
        s.nation_key,
        n.region_key,

        -- supplier attributes
        s.supplier_name,
        s.address,
        s.phone,
        s.account_balance,

        -- nation + region (denormalized in)
        n.nation_name,
        r.region_name

    from suppliers as s
    left join nations as n on s.nation_key = n.nation_key
    left join regions as r on n.region_key = r.region_key
)

select * from joined
