-- =============================================================================
-- dim_customer
-- =============================================================================
-- Customer dimension, denormalized to include nation and region so that
-- BI tools can group on geography without traversing an additional join.
--
-- This is the "current state" view. For point-in-time history (SCD Type 2)
-- see dim_customer_history, which is built from snapshots/customer_snapshot.
-- =============================================================================

with customers as (
    select * from {{ ref('stg_tpch__customers') }}
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
        c.customer_key,
        c.nation_key,
        n.region_key,

        -- customer attributes
        c.customer_name,
        c.address,
        c.phone,
        c.market_segment,
        c.account_balance,

        -- nation attributes (denormalized in)
        n.nation_name,

        -- region attributes (denormalized in)
        r.region_name

    from customers c
    left join nations n on c.nation_key = n.nation_key
    left join regions r on n.region_key = r.region_key
)

select * from joined
