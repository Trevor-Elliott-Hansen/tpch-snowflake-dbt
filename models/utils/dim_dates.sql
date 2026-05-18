-- =============================================================================
-- dim_dates
-- =============================================================================
-- Calendar/time spine model. One row per day from 1990-01-01 to 2030-12-31,
-- generated declaratively with dbt_utils.date_spine.
--
-- Required by MetricFlow as a time spine for handling time-based metrics
-- (cumulative metrics, period comparisons, time grain rollups). MetricFlow
-- validates the existence of a time spine at parse time even if no metric
-- explicitly uses one.
--
-- Also useful as a generic date dimension in any time-series analysis —
-- join to it to densify sparse data, generate missing periods, etc.
-- =============================================================================

with date_spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('1990-01-01' as date)",
        end_date="cast('2031-01-01' as date)"
    ) }}

),

with_attributes as (
    select
        cast(date_day as date)               as date_day,
        extract(year   from date_day)        as year,
        extract(quarter from date_day)       as quarter,
        extract(month  from date_day)        as month,
        extract(week   from date_day)        as week,
        extract(day    from date_day)        as day_of_month,
        extract(dayofweek from date_day)     as day_of_week,
        date_trunc('week',    date_day)::date  as week_start,
        date_trunc('month',   date_day)::date  as month_start,
        date_trunc('quarter', date_day)::date  as quarter_start,
        date_trunc('year',    date_day)::date  as year_start,
        case when extract(dayofweek from date_day) in (0, 6) then true else false end
                                              as is_weekend
    from date_spine
)

select * from with_attributes