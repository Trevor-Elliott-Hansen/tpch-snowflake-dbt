-- =============================================================================
-- fct_orders
-- =============================================================================
-- Fact table at order grain. One row per order. Combines order header info
-- with the pre-aggregated line-item rollup from int_orders_with_line_items.
-- =============================================================================

with orders as (
    select * from {{ ref('stg_tpch__orders') }}
),

order_aggs as (
    select * from {{ ref('int_orders_with_line_items') }}
)

select
    -- ids
    o.order_key,
    o.customer_key,

    -- order attributes
    o.order_status,
    o.order_priority,
    o.clerk,
    o.ship_priority,

    -- dates
    o.order_date,
    a.first_ship_date,
    a.last_ship_date,
    a.last_receipt_date,

    -- header measure (totalprice from source)
    o.total_price as order_total_price,

    -- aggregated line-item measures
    a.line_item_count,
    a.distinct_part_count,
    a.distinct_supplier_count,
    a.total_quantity,
    a.gross_revenue,
    a.net_revenue,
    a.total_discount_amount,
    a.total_tax_amount,
    a.avg_days_in_transit,
    a.returned_item_count,
    a.has_any_return

from orders as o
left join order_aggs as a on o.order_key = a.order_key
