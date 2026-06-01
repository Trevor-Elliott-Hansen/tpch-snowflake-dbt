# TPCH Analytics — dbt + Snowflake Portfolio Project

A production-style analytics engineering project built on Snowflake's TPCH_SF1
sample dataset. Demonstrates star schema design, semantic layer development
with MetricFlow, SCD Type 2 history tracking, multi-layer dbt modeling, a
comprehensive test suite, and CI tooling.

[![Lint](https://github.com/Trevor-Elliott-Hansen/tpch-snowflake-dbt/actions/workflows/lint.yml/badge.svg)](https://github.com/Trevor-Elliott-Hansen/tpch-snowflake-dbt/actions/workflows/lint.yml)

---

## Project goals

- Transform a **normalized snowflake schema** into a clean **star schema**
- Build a reusable **semantic layer** with MetricFlow metrics consumable from
  Tableau, Sigma, and other BI tools
- Implement **SCD Type 2** history tracking via dbt snapshots
- Practice dbt best practices: staging → intermediate → marts layering,
  documentation, testing, exposures, and CI
- Serve as a portfolio piece showcasing Snowflake + dbt skills end-to-end

---

## Tech stack

| Tool                       | Version | Purpose                              |
| -------------------------- | ------- | ------------------------------------ |
| dbt Core                   | 1.8+    | Transformation framework             |
| dbt-snowflake adapter      | 1.8+    | Snowflake connection                 |
| Snowflake                  | —       | Cloud data warehouse                 |
| dbt_utils                  | 1.x     | Surrogate keys, generic tests        |
| MetricFlow                 | 1.6+    | Semantic layer (bundled with dbt)    |
| sqlfluff + sqlfmt          | 3.2 / 0.23 | SQL linting and formatting        |
| pre-commit                 | 4.x     | Local hook orchestration             |
| GitHub Actions             | —       | CI: dbt parse + sqlfluff lint        |

---

## Source data

**Database:** `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1`
Available read-only in every Snowflake account.

| Source table | Description             | ~Rows |
| ------------ | ----------------------- | ----- |
| `ORDERS`     | Customer orders         | 1.5M  |
| `LINEITEM`   | Order line items (fact) | 6M    |
| `CUSTOMER`   | Customer master         | 150K  |
| `SUPPLIER`   | Supplier master         | 10K   |
| `PART`       | Part master             | 200K  |
| `PARTSUPP`   | Part-supplier map       | 800K  |
| `NATION`     | 25 nations              | 25    |
| `REGION`     | 5 regions               | 5     |

---

## Architecture

### Snowflake schema → star schema

The raw TPCH data is a **snowflake schema** — normalized, with chained joins
(LINEITEM → ORDERS → CUSTOMER → NATION → REGION). This project denormalizes
it into a flat **star schema** optimized for analytical queries.

```
                       dim_customer
                  (customer + nation + region)
                            │
                            │
   dim_part ──── fct_order_items ──── dim_supplier
                            │   (supplier + nation + region)
                            │
                       fct_orders
                       (order grain)


  dim_customer_history  ←── customer_snapshot ←── customer_changes_simulated
  (SCD Type 2)              (timestamp strategy)   (seed)
```

### Model layers

```
models/
├── staging/tpch/                       # 1:1 source rename + cast
│   ├── sources.yml                     # Source declarations + tests
│   ├── stg_tpch__orders.sql
│   ├── stg_tpch__lineitems.sql         # Includes derived revenue fields
│   ├── stg_tpch__customers.sql
│   ├── stg_tpch__suppliers.sql
│   ├── stg_tpch__parts.sql             # Parses p_type sub-attributes
│   ├── stg_tpch__nations.sql
│   ├── stg_tpch__regions.sql
│   └── _models.yml
│
├── intermediate/
│   ├── int_orders_with_line_items.sql  # Pre-aggregates to order grain
│   └── _models.yml
│
├── marts/
│   ├── core/
│   │   ├── dim_customer.sql            # Current state
│   │   ├── dim_customer_history.sql    # SCD Type 2
│   │   ├── dim_supplier.sql
│   │   ├── dim_part.sql
│   │   └── _models.yml
│   └── finance/
│       ├── fct_order_items.sql         # Line-item grain
│       ├── fct_orders.sql              # Order grain
│       └── _models.yml
│
├── semantic_models/
│   ├── sem_order_items.yml             # MetricFlow metrics
│   └── sem_customers.yml               # Cross-entity dimensions
│
├── utils/                              # MetricFlow time spine + utilities
│   ├── dim_dates.sql                   # Calendar dim, generated via dbt_utils.date_spine
│   └── _time_spine.yml
│
└── _exposures.yml                      # Downstream BI dashboards
```

---

## SCD Type 2 history

`dim_customer_history` tracks how customer attributes change over time
(market segment, account balance, address). Built on top of
`snapshots/customer_snapshot.sql` using dbt's **timestamp strategy** with
`effective_date` as the change basis.

Because TPCH source data doesn't change naturally, `seeds/customer_changes_simulated.csv`
provides a hand-crafted change feed of ~10 customers with realistic
mid-year segment changes (e.g., customer 1 moves from BUILDING → AUTOMOBILE on
2024-06-15). Each `dbt snapshot` run replays these effective dates to build a
proper SCD2 history table.

```sql
-- Current state
select * from dim_customer_history where is_current;

-- Customer state as of a specific date
select *
from dim_customer_history
where '2024-09-01' >= valid_from
  and '2024-09-01' <  valid_to_or_max;
```

In production this seed would be replaced with a live source table that emits
change events (CDC stream, daily extract, etc.) — the rest of the pipeline
stays identical.

---

## Semantic layer (MetricFlow)

Metrics are defined once in version control and consumed from any BI tool via
the dbt Semantic Layer connector. Defining metrics here rather than in
individual dashboards prevents the classic drift where "active customers" in
Tableau ≠ "active customers" in Sigma.

### Metrics defined

| Metric                  | Type    | Description                                   |
| ----------------------- | ------- | --------------------------------------------- |
| `total_net_revenue`     | Simple  | Sum of net revenue                            |
| `total_gross_revenue`   | Simple  | Sum of extended_price (pre-discount)          |
| `total_discount_amount` | Simple  | Sum of discount dollars                       |
| `total_orders`          | Simple  | Count of distinct orders                      |
| `line_item_count`       | Simple  | Count of line items                           |
| `returned_item_count`   | Simple  | Count of returned line items                  |
| `customer_count`        | Simple  | Count of distinct customers                   |
| `total_account_balance` | Simple  | Sum of customer account balances              |
| `avg_order_value`       | Derived | total_net_revenue / total_orders              |
| `discount_rate_pct`     | Derived | total_discount_amount / total_gross_revenue   |
| `return_rate`           | Derived | returned_item_count / line_item_count         |
| `avg_days_in_transit`   | Simple  | Avg days from ship → receipt                  |
| `avg_account_balance`   | Derived | total_account_balance / customer_count        |

### Example MetricFlow query

```bash
mf query \
  --metrics total_net_revenue,total_orders,avg_order_value \
  --group-by order_date__year,customer__market_segment,customer__region_name \
  --order -total_net_revenue
```

The `customer__market_segment` and `customer__region_name` dimensions come
from `sem_customers`; MetricFlow auto-resolves the entity join through the
shared `customer` entity declared on both semantic models.

---

## Tests

### Schema tests (in `_models.yml` / `sources.yml`)

- `unique` and `not_null` on all primary keys
- `relationships` (referential integrity) across all FK → PK pairs
- `accepted_values` on status/flag fields and categoricals

### Singular tests (`tests/`)

| Test                                            | What it checks                                                          |
| ----------------------------------------------- | ----------------------------------------------------------------------- |
| `assert_net_revenue_calculation`                | `net_revenue` = `extended_price * (1 - discount_rate)`                  |
| `assert_no_orphaned_line_items`                 | Every line item has a matching order                                    |
| `assert_fct_orders_revenue_reconciles`          | Order-grain revenue matches sum of line-item revenue                    |
| `assert_dim_customer_history_one_current_per_key` | SCD2 invariant: exactly one `is_current = true` row per customer_key  |

### Custom generic test (`tests/generic/`)

| Test                    | Usage                                                            |
| ----------------------- | ---------------------------------------------------------------- |
| `assert_positive_value` | `assert_positive_value` or `assert_positive_value(allow_null: true)` |

---

## Exposures

Downstream BI consumers are declared in `models/_exposures.yml` so they
appear in the dbt DAG and lineage docs:

| Exposure                       | Type      | Maturity | Depends on                              |
| ------------------------------ | --------- | -------- | --------------------------------------- |
| `revenue_dashboard`            | dashboard | high     | `fct_order_items`, dims                 |
| `shipping_operations_dashboard`| dashboard | medium   | `fct_order_items`, `dim_supplier`       |
| `customer_history_audit`       | analysis  | low      | `dim_customer_history`                  |

This enables targeted refreshes:

```bash
dbt build --select +exposure:revenue_dashboard
```

---

## Setup

### 1. Clone and install

```bash
git clone https://github.com/Trevor-Elliott-Hansen/tpch-snowflake-dbt.git
cd tpch-snowflake-dbt

python -m venv .venv
source .venv/bin/activate

pip install dbt-snowflake
dbt deps
```

### 2. Configure environment

```bash
cp .env.example .env
# edit .env with your Snowflake credentials, then:
source .env
```

### 3. Configure dbt profile

```bash
mkdir -p ~/.dbt
cp profiles.yml.example ~/.dbt/profiles.yml
```

Both **password auth** (`dev` target) and **key-pair auth** (`prod` target) are
documented in `profiles.yml.example`. For key-pair auth, generate a key with:

```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -v2 des3 \
  -inform PEM -out ~/.ssh/snowflake_rsa_key.p8
```

Then register the public key on your Snowflake user and set
`SNOWFLAKE_PRIVATE_KEY_PATH` in `.env`.

### 3a. Set DBT_PROFILES_DIR (required for MetricFlow CLI on dbt-core 1.11)

The `mf` CLI on dbt-core 1.11 sometimes resolves profiles to its bundled
tutorial project instead of `~/.dbt/`. Add this to your `.env` so both
`dbt` and `mf` look in the same place:

```bash
DBT_PROFILES_DIR=/Users/YOUR_USERNAME/.dbt
```

`dbt parse` and `dbt run` work without this, but `mf list metrics` and
`mf query` will fail with "Could not find profile named 'tpch_analytics'"
unless it's set.

### 4. Build

```bash
# Build seeds, snapshots, models, and run all tests
dbt build

# Or, granularly:
dbt seed                                  # load customer_changes_simulated
dbt snapshot                              # build customer_snapshot (run 2x to see SCD2)
dbt run                                   # build models
dbt test                                  # run all tests
dbt docs generate && dbt docs serve       # interactive lineage + docs
```

### 5. (Optional) install pre-commit hooks

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files                # one-off run
```

---

## Project structure

```
.
├── .github/workflows/lint.yml            # CI: dbt parse + sqlfluff lint
├── analyses/
│   └── revenue_by_segment_and_region.sql
├── models/
│   ├── _exposures.yml
│   ├── staging/tpch/
│   ├── intermediate/
│   ├── marts/{core,finance}/
│   └── semantic_models/
├── seeds/
│   ├── customer_changes_simulated.csv
│   └── _seeds.yml
├── snapshots/
│   └── customer_snapshot.sql
├── tests/
│   ├── assert_net_revenue_calculation.sql
│   ├── assert_no_orphaned_line_items.sql
│   ├── assert_fct_orders_revenue_reconciles.sql
│   ├── assert_dim_customer_history_one_current_per_key.sql
│   └── generic/assert_positive_value.sql
├── .env.example
├── .gitignore
├── .pre-commit-config.yaml
├── .sqlfluff
├── .sqlfluffignore
├── dbt_project.yml
├── packages.yml
├── profiles.yml.example
└── README.md
```

---

## Key design decisions

**Why an intermediate layer?**
`int_orders_with_line_items` pre-aggregates line items before they're joined
to customer dimensions. Without it, `fct_orders` would fan out — multiplying
order rows by the average line items per order — giving wrong totals.

**Why derived revenue fields in staging?**
`net_revenue` and `discount_amount` are deterministic functions of raw columns
with no business interpretation. They belong as close to the source as
possible so they're computed once and reused everywhere downstream.

**Natural keys vs. surrogate keys?**
Most dimensions use natural keys from the source (TPCH keys are clean
integers). `fct_order_items` uses a surrogate key generated by
`dbt_utils.generate_surrogate_key` because its grain is composite
(`order_key, line_number`) and a single-column PK is more ergonomic for
downstream joins and tests.

**Why two semantic models?**
`sem_order_items` defines transactional metrics (revenue, returns, transit
time) at line-item grain. `sem_customers` defines customer-grain metrics and
exposes customer dimensions (market_segment, region_name) for cross-entity
slicing. MetricFlow joins them automatically via the shared `customer`
entity — defining them as separate semantic models keeps each one focused
on its native grain.

**Why simulated data for SCD2, and why `check` strategy?**
TPCH source data is static, so to actually exercise the snapshot pipeline
we need simulated changes. The seed approach makes the simulation explicit
and reviewable in version control. In production the snapshot would point
at a live source table instead.

The snapshot uses `check` strategy (compares tracked columns between runs)
rather than `timestamp` strategy. An initial attempt used `timestamp` with
a multi-row-per-customer historical seed, but dbt's timestamp strategy is
designed to detect changes between runs against a one-row-per-key current-
state source — not to backfill from a history feed. Switching to `check`
with a current-state seed matches how SCD2 works in production: each time
the source changes and `dbt snapshot` runs, dbt closes the prior version
and opens a new one for any row whose tracked columns differ.

**Why lint-only CI?**
A full `dbt build` in CI would require a Snowflake service account and
secrets. Lint-only CI catches the most common errors (broken refs, syntax
issues, undocumented columns) without infrastructure overhead. Adding a full
build workflow is a natural next step.

---

## What this project demonstrates

- **Data modeling** — Kimball star schema, dimensional modeling, grain discipline
- **dbt fluency** — sources, staging/intermediate/marts layering, refs, generic + singular tests, snapshots, seeds, exposures, semantic models, custom generic tests
- **Snowflake** — sample data integration, warehouse + role + schema separation, key-pair auth pattern
- **SCD Type 2** — snapshot strategy, validity windows, point-in-time joins
- **Semantic layer** — MetricFlow metrics (simple + derived), entity joins, cross-grain slicing
- **Software engineering** — env-var config, version-controlled credentials, linting (sqlfluff + sqlfmt), pre-commit hooks, CI (GitHub Actions), MIT license
- **Documentation** — column-level descriptions, model descriptions, this README, exposure declarations

---

## Author

Built by [Trevor Elliott-Hansen](https://www.linkedin.com/in/trevor-elliott-hansen/) as a portfolio project demonstrating Snowflake + dbt skills.
