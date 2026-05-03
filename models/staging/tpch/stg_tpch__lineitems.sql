-- =============================================================================
-- stg_tpch__lineitems
-- =============================================================================
-- Staging layer for TPCH line items. One row per (order_key, line_number).
--
-- Includes a small number of *deterministic* derivations (net_revenue,
-- discount_amount, days_in_transit, is_returned) because they're simple
-- functions of raw columns — no business interpretation needed. Keeping
-- them here means they're computed once and reused everywhere downstream.
-- =============================================================================

with source as (
    select * from {{ source('tpch', 'lineitem') }}
),

renamed as (
    select
        -- composite key parts
        l_orderkey      as order_key,
        l_linenumber    as line_number,

        -- foreign keys
        l_partkey       as part_key,
        l_suppkey       as supplier_key,

        -- attributes
        l_returnflag    as return_flag,
        l_linestatus    as line_status,
        l_shipinstruct  as ship_instructions,
        l_shipmode      as ship_mode,
        l_comment       as comment,

        -- raw measures
        cast(l_quantity      as number(12, 2)) as quantity,
        cast(l_extendedprice as number(12, 2)) as extended_price,
        cast(l_discount      as number(5, 4))  as discount_rate,
        cast(l_tax           as number(5, 4))  as tax_rate,

        -- derived measures (deterministic; safe to compute in staging)
        cast(l_extendedprice * (1 - l_discount) as number(12, 2))
            as net_revenue,
        cast(l_extendedprice * l_discount as number(12, 2))
            as discount_amount,

        -- dates
        cast(l_shipdate    as date) as ship_date,
        cast(l_commitdate  as date) as commit_date,
        cast(l_receiptdate as date) as receipt_date,

        -- derived date fields
        datediff('day', l_shipdate, l_receiptdate) as days_in_transit,

        -- derived flags
        case when l_returnflag = 'R' then true else false end as is_returned

    from source
)

select * from renamed
