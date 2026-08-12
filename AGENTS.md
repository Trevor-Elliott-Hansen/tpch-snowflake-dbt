# AGENTS.md — project conventions for AI coding agents

Instructions for any AI agent working in this repo. These encode intent that
cannot be inferred by imitating existing files. When these rules conflict with
what seems locally convenient, the rules win; if a rule seems wrong, say so
instead of silently deviating.

## What this project is

A dbt + Snowflake analytics warehouse over the TPCH_SF1 sample dataset:
Kimball star schema, MetricFlow semantic layer, SCD Type 2 customer history.
Sources flow `staging → intermediate → marts`, with metrics defined once in
the semantic layer.

| Layer | Path | Materialization | Schema | Naming |
|---|---|---|---|---|
| Staging | `models/staging/tpch/` | view | staging | `stg_tpch__<entity>` |
| Intermediate | `models/intermediate/` | view | intermediate | `int_<description>` |
| Marts (core dims) | `models/marts/core/` | table | core | `dim_<entity>` |
| Marts (finance facts) | `models/marts/finance/` | table | finance | `fct_<entity>` |
| Utils | `models/utils/` | table | utils | `dim_dates` etc. |
| Semantic layer | `models/semantic/` | n/a (YAML) | n/a | `sem_<entity>` |

**The naming taxonomy above is closed.** Do not invent new prefixes (`rpt_`,
`agg_`, `mart_`, …) without asking. If a model doesn't fit an existing prefix,
that usually means it shouldn't be a model — see the semantic layer rule.

## The semantic layer rule (most important rule in this file)

Before creating any model whose job is *aggregating existing facts for
reporting* (revenue by X, counts by Y over time), check the semantic layer:
`models/semantic/` defines 16 metrics over `fct_order_items`, `fct_orders`,
and `dim_customer`, sliceable by any joinable dimension via MetricFlow, e.g.:

```bash
mf query --metrics total_net_revenue --group-by customer__nation_name,metric_time__year
```

If the metric (or a trivial combination) already answers the question, **do
not materialize a new aggregate table** — that creates a second definition of
the number that can drift from the governed one. Metric definitions live in
one place. If a genuinely new measure is needed, extend the semantic models
instead, and only materialize an aggregate when there's a stated performance
or tooling reason.

## Model file conventions

Every model file starts with the banner header used throughout the repo:

```sql
-- =============================================================================
-- <model_name>
-- =============================================================================
-- <One- to three-line description: what it is, its grain, notable choices.>
-- =============================================================================
```

**Staging models** follow the two-CTE pattern exactly — raw source isolated in
`source`, all renames/casts/derivations in `renamed`, bare final select:

```sql
with source as (
    select * from {{ source('tpch', '<table>') }}
),

renamed as (
    select ...
    from source
)

select * from renamed
```

**Marts models** use import CTEs named for what they pull (`orders`,
`customers`), then transformation CTEs, ending with a bare
`select * from <last_cte>`. One blank line between CTEs. Facts and dims never
read sources directly — staging is the only layer that touches
`{{ source(...) }}`; downstream layers use `{{ ref(...) }}` only.

Grain is sacred: never mix grains in one fact table, and state the grain in
the model's yml description ("One row per …").

## Testing and documentation standards

Every new model ships in the same PR with:

- An entry in the folder's `_models.yml`: model description **stating the
  grain**, and column-level descriptions.
- `unique` + `not_null` on the primary key (composite keys use
  `dbt_utils.unique_combination_of_columns`).
- `relationships` tests on every foreign key.
- `accepted_values` on low-cardinality categorical columns.
- Test arguments use the dbt 1.11 `arguments:` block syntax (see any existing
  `_models.yml`).
- Reuse the custom generic test `assert_positive_value` for monetary/quantity
  columns.

Cross-grain changes (anything touching both order- and line-item-grain
models) need a singular reconciliation test in `tests/` — see
`assert_fct_orders_revenue_reconciles.sql` for the pattern.

**Documentation policy (two-tier).** Descriptions must carry information the
column name doesn't. Always required, with substance: keys (what they join
to; surrogate keys get their recipe), measures (units + formula), derived
columns (the derivation), flags/statuses/codes (what the values mean), and
anything with a caveat (nullability, timezone, naming collisions like the
TPCH `comment` columns). Pass-through descriptive attributes: describe them
in marts (the consumable layer — one plain sentence is fine), optional in
staging. Never write descriptions that restate the column name ("part_name:
The part name") — boilerplate coverage is worse than a gap because it hides
the descriptions that matter.

## Definition of done — verify, don't declare

Work is not complete until these have actually been run and pass:

```bash
dbt build --select <model>+        # builds the model and runs its tests
sqlfluff lint models/<path>        # must come back clean
```

Writing tests without running them does not count. Report the actual results
(pass/fail counts), not an assumption of success.

## SQL style

`sqlfluff` (Snowflake dialect, dbt templater) is the authority — run
`sqlfluff fix` before `lint`. Key conventions: lowercase keywords,
identifiers, and functions; 100-char lines; trailing commas; explicit `as`
for aliases; `join ... on` (not `using`). The `.sqlfluff` file excludes
specific rules deliberately (e.g., `comment` is a real TPCH column name;
some `case` statements are clearer than `coalesce`) — do not "fix" code that
only violates an excluded rule, and do not edit `.sqlfluff` without asking.

## Guardrails

- **Never run anything with `--target prod`.** Dev work uses the default
  `dev` target only.
- **Never run `dbt snapshot` unless the task explicitly calls for it.** The
  snapshot table is stateful — it accumulates SCD2 history across runs, and
  a careless run against a modified seed or config permanently pollutes
  `dim_customer_history`. The seed `customer_changes_simulated` is the
  snapshot's source: treat edits to it as snapshot operations, and never
  change the snapshot's strategy config on an existing snapshot table.
- `dim_customer_history` invariant: exactly one `is_current = true` row per
  `customer_key` (enforced by a singular test — keep it passing).
- **Warehouse discipline**: everything runs on `TRANSFORMING` (XSMALL,
  auto-suspend). Never resize warehouses, create new ones, or touch the
  resource monitor. Never `drop`/`truncate` outside the `DBT_DEV_*` schemas.
- Credentials live in `.env` (git-ignored) and key-pair files — never print,
  copy, or commit them. `.env.example` is the committed template.

## Commands reference

**Environment activation (required before any dbt/sqlfluff/mf command):**
`dbt` is not on the global PATH — it lives in a project virtualenv. Activate
in the same shell you run commands in:

```bash
source ~/venvs/tpch-dbt/bin/activate          # the project venv
set -a && source .env && set +a               # export env vars (set -a matters:
                                              # plain `source` won't export)
```

```bash
dbt build                                     # everything + all tests
dbt build --select <model>+                   # a model and its descendants
dbt build --select state:modified+ --defer --state target/  # changed models only
sqlfluff fix models/<path> && sqlfluff lint models/<path>
mf list metrics                               # semantic layer contents
mf query --metrics <m> --group-by <dim>       # ad-hoc metric query
```

Note: the MetricFlow CLI needs `DBT_PROFILES_DIR` set (it's in `.env`) — see
README §4a for why.
