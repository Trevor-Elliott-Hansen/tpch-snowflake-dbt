-- =============================================================================
-- fct_order_items
-- =============================================================================
-- Fact table at line-item grain. One row per (order_key, line_number).
-- Brings in order_date and customer_key from stg_tpch__orders so that the
-- semantic layer / BI tools can slice by order_date and customer without
-- needing fct_orders.
--
-- Uses a surrogate key (dbt_utils.generate_surrogate_key) since the natural
-- key is composite. Foreign keys to dim_customer / dim_supplier / dim_part
-- are kept as natural keys (TPCH numeric ids) for join simplicity.
-- =============================================================================

with line_items as (
    select * from {{ ref('stg_tpch__lineitems') }}
),

orders as (
    select
        order_key,
        customer_key,
        order_date,
        order_status,
        order_priority
    from {{ ref('stg_tpch__orders') }}
),

joined as (
    select
        -- surrogate key
        {{ dbt_utils.generate_surrogate_key(['li.order_key', 'li.line_number']) }}
            as order_item_key,

        -- composite natural key parts
        li.order_key,
        li.line_number,

        -- foreign keys (carried up from staging / orders)
        o.customer_key,
        li.supplier_key,
        li.part_key,

        -- order context (denormalized in)
        o.order_date,
        o.order_status,
        o.order_priority,

        -- line-item attributes
        li.return_flag,
        li.line_status,
        li.ship_mode,
        li.ship_instructions,

        -- measures
        li.quantity,
        li.extended_price,
        li.discount_rate,
        li.discount_amount,
        li.tax_rate,
        li.net_revenue,

        -- dates
        li.ship_date,
        li.commit_date,
        li.receipt_date,
        li.days_in_transit,

        -- flags
        li.is_returned

    from line_items li
    left join orders o on li.order_key = o.order_key
)

select * from joined
