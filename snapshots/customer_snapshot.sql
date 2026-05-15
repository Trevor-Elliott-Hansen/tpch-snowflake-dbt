{# =============================================================================
   customer_snapshot
   =============================================================================
   SCD Type 2 snapshot over the simulated current-state customer feed
   (seeds/customer_changes_simulated.csv).

   Strategy: `check` over the tracked attribute columns (customer_name,
   market_segment, account_balance, phone, address, nation_key). Each
   `dbt snapshot` run compares these columns against the snapshot's most
   recent row for each customer_key. If any have changed, the existing
   version is closed (dbt_valid_to set) and a new version is opened.

   Why check strategy?
     - The seed represents current state, not a history feed
     - There's no authoritative `updated_at` column in the source
     - We want changes to *attribute* values to drive new versions,
       not arbitrary timestamp moves

   To demo SCD2:
     1. Edit a value in the seed CSV
     2. Run `dbt seed && dbt snapshot && dbt run --select dim_customer_history`
     3. Query dim_customer_history WHERE customer_key = <edited> and observe
        the new version with is_current = true and the previous version
        closed (valid_to populated, is_current = false)

   In production, the seed would be replaced with a live source table
   (one row per customer = current state) and `dbt snapshot` would run
   on a schedule (typically daily) to accumulate history.

   Output columns added by dbt:
     - dbt_scd_id     : surrogate per-version key
     - dbt_updated_at : timestamp of the snapshot run that captured this version
     - dbt_valid_from : when this version became active
     - dbt_valid_to   : when superseded (NULL = current)
============================================================================= #}

{% snapshot customer_snapshot %}

    {{
        config(
          schema='snapshots',
          unique_key='customer_key',
          strategy='check',
          check_cols=['customer_name', 'market_segment', 'account_balance', 'phone', 'address', 'nation_key'],
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
        nation_key
    from {{ ref('customer_changes_simulated') }}

{% endsnapshot %}
