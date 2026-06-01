-- =============================================================================
-- assert_net_revenue_calculation
-- =============================================================================
-- Asserts that net_revenue in stg_tpch__lineitems matches the canonical
-- formula: extended_price * (1 - discount_rate), within a small floating
-- point tolerance.
--
-- This guards against accidental edits to the staging derivation (e.g. a
-- developer accidentally swapping the formula to extended_price * discount).
-- The test passes when zero rows are returned.
-- =============================================================================

select
    order_key,
    line_number,
    extended_price,
    discount_rate,
    net_revenue,
    extended_price * (1 - discount_rate) as expected_net_revenue,
    abs(net_revenue - extended_price * (1 - discount_rate)) as variance

from {{ ref('stg_tpch__lineitems') }}

where abs(net_revenue - extended_price * (1 - discount_rate)) > 0.01
