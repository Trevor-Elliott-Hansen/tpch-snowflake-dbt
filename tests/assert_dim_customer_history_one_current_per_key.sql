-- =============================================================================
-- assert_dim_customer_history_one_current_per_key
-- =============================================================================
-- SCD2 invariant: for every customer_key in dim_customer_history, exactly
-- one row should have is_current = true. More than one means we've corrupted
-- the snapshot. Zero means we lost the latest version somewhere.
-- =============================================================================

with current_counts as (
    select
        customer_key,
        sum(case when is_current then 1 else 0 end) as current_version_count
    from {{ ref('dim_customer_history') }}
    group by 1
)

select *
from current_counts
where current_version_count <> 1
