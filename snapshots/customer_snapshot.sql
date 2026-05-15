{# =============================================================================
   customer_snapshot
   =============================================================================
   SCD Type 2 snapshot over the simulated customer change feed
   (seeds/customer_changes_simulated.csv).

   Strategy: `timestamp` using `effective_date` as the updated_at column.
   Each time `dbt snapshot` is run, dbt diffs the current state of the source
   against the snapshot table. If a row's tracked columns have changed,
   the existing row is closed (dbt_valid_to is set) and a new row is opened.

   Why timestamp strategy here?
     - The simulated source has an explicit effective_date column that
       represents the point in time the change happened. timestamp strategy
       respects that ordering.
     - In real ETL, you'd snapshot the latest state of each customer (one
       row per customer in the source). For demo purposes the seed contains
       multiple historical rows, so we materialize the snapshot by replaying
       them — see int_customer_history below for the consumable form.

   Output columns added by dbt:
     - dbt_scd_id        : surrogate version key
     - dbt_updated_at    : the effective_date that triggered this version
     - dbt_valid_from    : when this version became active
     - dbt_valid_to      : when this version was superseded (NULL = current)
============================================================================= #}

{% snapshot customer_snapshot %}

    {{
        config(
          schema='snapshots',
          unique_key='customer_key',
          strategy='timestamp',
          updated_at='effective_date',
          invalidate_hard_deletes=True,
        )
    }}

    select
        customer_key,
        customer_name,
        market_segment,
        account_balance,
        phone,
        address,
        nation_key,
        effective_date
    from {{ ref('customer_changes_simulated') }}

    {#
      In production this would point at a live source table, e.g.:

          select * from {{ source('crm', 'customers') }}

      with one row per customer reflecting current state. Snapshotting on a
      live cdc/feed table is the typical pattern.
    #}

{% endsnapshot %}
