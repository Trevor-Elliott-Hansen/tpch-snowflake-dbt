-- =============================================================================
-- assert_fct_orders_revenue_reconciles
-- =============================================================================
-- Cross-grain reconciliation: the order-level net_revenue in fct_orders must
-- equal the sum of line-item net_revenue in fct_order_items for the same
-- order. If these diverge, the intermediate aggregation is broken.
--
-- Allows a small per-order floating-point tolerance.
-- =============================================================================

with order_grain as (
    select
        order_key,
        net_revenue as order_grain_net_revenue
    from {{ ref('fct_orders') }}
),

line_item_grain as (
    select
        order_key,
        sum(net_revenue) as line_item_grain_net_revenue
    from {{ ref('fct_order_items') }}
    group by 1
),

joined as (
    select
        o.order_key,
        o.order_grain_net_revenue,
        l.line_item_grain_net_revenue,
        abs(o.order_grain_net_revenue - l.line_item_grain_net_revenue)
            as variance
    from order_grain o
    left join line_item_grain l using (order_key)
)

select *
from joined
where variance > 0.01
   or line_item_grain_net_revenue is null
