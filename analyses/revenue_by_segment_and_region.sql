-- =============================================================================
-- revenue_by_segment_and_region
-- =============================================================================
-- Demonstrates a typical BI question answered against the star schema:
-- "How does net revenue break down by customer market segment and region?"
--
-- This file lives in /analyses (not /models) so it's compiled by `dbt
-- compile` and inspectable in target/compiled/, but never materialized in
-- the warehouse. It serves as living documentation of intended downstream
-- usage.
--
-- The same question is more concisely expressed via the semantic layer:
--
--     dbt sl query \
--       --metrics total_net_revenue,total_orders,avg_order_value \
--       --group-by customer__market_segment,customer__region_name \
--       --order-by -total_net_revenue
-- =============================================================================

with order_items as (
    select * from {{ ref('fct_order_items') }}
),

customers as (
    select * from {{ ref('dim_customer') }}
)

select
    c.region_name,
    c.market_segment,

    count(distinct oi.customer_key)             as customer_count,
    count(distinct oi.order_key)                as order_count,
    count(*)                                    as line_item_count,

    sum(oi.net_revenue)                         as total_net_revenue,
    sum(oi.discount_amount)                     as total_discount_amount,

    sum(oi.net_revenue) / nullif(count(distinct oi.order_key), 0)
                                                as avg_order_value,

    sum(case when oi.is_returned then 1 else 0 end)::float
        / nullif(count(*), 0) * 100             as return_rate_pct

from order_items oi
join customers c on oi.customer_key = c.customer_key

group by 1, 2
order by total_net_revenue desc
