-- =============================================================================
-- assert_no_orphaned_line_items
-- =============================================================================
-- Every line item in fct_order_items must have a matching order in
-- fct_orders. This is technically covered by the relationships test in
-- _models.yml, but a singular test makes the failure mode more readable
-- and lets us return contextual columns for debugging.
-- =============================================================================

select
    li.order_item_key,
    li.order_key,
    li.line_number,
    li.customer_key,
    li.net_revenue

from {{ ref('fct_order_items') }} as li

left join {{ ref('fct_orders') }} as o
    on li.order_key = o.order_key

where o.order_key is null
