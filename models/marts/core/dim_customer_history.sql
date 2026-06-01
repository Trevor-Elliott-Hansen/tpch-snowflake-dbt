-- =============================================================================
-- dim_customer_history
-- =============================================================================
-- SCD Type 2 customer dimension built from customer_snapshot.
-- One row per (customer_key, version). The is_current flag identifies the
-- latest version of each customer for "as-is" queries; valid_from/valid_to
-- support point-in-time joins for "as-was" queries.
--
-- Usage examples:
--
--   -- Latest version of each customer
--   select * from dim_customer_history where is_current
--
--   -- Customer state as of 2024-09-01
--   select *
--   from dim_customer_history
--   where '2024-09-01' >= valid_from
--     and '2024-09-01' <  valid_to_or_max
-- =============================================================================

with snap as (
    select * from {{ ref('customer_snapshot') }}
),

with_flags as (
    select
        -- surrogate version key from the snapshot
        dbt_scd_id as customer_history_key,

        -- natural key
        customer_key,

        -- attributes (current at this version)
        customer_name,
        market_segment,
        account_balance,
        phone,
        address,
        nation_key,

        -- validity window
        dbt_valid_from as valid_from,
        dbt_valid_to as valid_to,

        -- coalesced upper bound for inclusive between-style filters
        coalesce(dbt_valid_to, '9999-12-31'::timestamp_ntz)
            as valid_to_or_max,

        -- convenience flag for "current state" filter
        coalesce(dbt_valid_to is null, false)
            as is_current

    from snap
)

select * from with_flags
