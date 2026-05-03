-- =============================================================================
-- stg_tpch__orders
-- =============================================================================
-- Staging layer for TPCH orders. One row per order.
-- Renames cryptic single-letter prefixes (o_*) to descriptive names and
-- enforces consistent types. No business logic here — just rename + cast.
-- =============================================================================

with source as (
    select * from {{ source('tpch', 'orders') }}
),

renamed as (
    select
        -- ids
        o_orderkey         as order_key,
        o_custkey          as customer_key,

        -- attributes
        o_orderstatus      as order_status,
        o_orderpriority    as order_priority,
        o_clerk            as clerk,
        o_shippriority     as ship_priority,
        o_comment          as comment,

        -- measures
        cast(o_totalprice as number(12, 2)) as total_price,

        -- dates
        cast(o_orderdate as date) as order_date

    from source
)

select * from renamed
