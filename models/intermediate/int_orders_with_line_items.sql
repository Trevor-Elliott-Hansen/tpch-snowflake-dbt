-- =============================================================================
-- int_orders_with_line_items
-- =============================================================================
-- Aggregates line items up to the order grain so that downstream marts can
-- join to customer / nation / region without fan-out.
--
-- Why this lives in the intermediate layer:
--   - Joining stg_tpch__orders directly to stg_tpch__lineitems would
--     multiply rows in fct_orders by the average line items per order.
--   - Pre-aggregating here keeps fct_orders at order grain while still
--     letting fct_order_items use the full line-item-grain staging table.
-- =============================================================================

with line_items as (
    select * from {{ ref('stg_tpch__lineitems') }}
),

aggregated as (
    select
        order_key,

        -- counts
        count(*)                          as line_item_count,
        count(distinct part_key)          as distinct_part_count,
        count(distinct supplier_key)      as distinct_supplier_count,

        -- monetary measures
        sum(extended_price)               as gross_revenue,
        sum(net_revenue)                  as net_revenue,
        sum(discount_amount)              as total_discount_amount,
        sum(net_revenue * tax_rate)       as total_tax_amount,

        -- volume
        sum(quantity)                     as total_quantity,

        -- shipping
        min(ship_date)                    as first_ship_date,
        max(ship_date)                    as last_ship_date,
        max(receipt_date)                 as last_receipt_date,
        avg(days_in_transit)              as avg_days_in_transit,

        -- returns
        sum(case when is_returned then 1 else 0 end) as returned_item_count,
        max(case when is_returned then 1 else 0 end) as has_any_return

    from line_items
    group by 1
)

select * from aggregated
