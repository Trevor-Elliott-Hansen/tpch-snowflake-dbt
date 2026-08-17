---
name: add-staging-model
description: >
  Add a new staging model to this dbt project for a TPCH source table.
  Use whenever asked to model, stage, or "add staging for" a source table.
  Enforces the project's staging conventions end to end: source declaration,
  the source/renamed CTE pattern, yml documentation and tests, sqlfluff, and
  a verified dbt build. Produces a complete, tested, documented model — not
  just a SQL file.
---

# Add a staging model

Follow every phase in order. Phases marked **[GATE]** must succeed before
continuing — if a gate fails, stop and report rather than working around it.
AGENTS.md applies throughout; where this skill is more specific, this skill
wins.

## Phase 1 — Preconditions [GATE]

1. Confirm the target table is declared in
   `models/staging/tpch/sources.yml`. If missing, add it in the style of
   existing entries. If present but bare (no column tests), harden it now:
   `unique` + `not_null` on the source primary key (composite keys: a
   `dbt_utils.unique_combination_of_columns` at table level), `relationships`
   to parent sources for FKs — matching the syntax of existing entries.
2. Confirm `models/staging/tpch/stg_tpch__<entity>.sql` does not already
   exist. Naming: plural entity, matching existing files
   (`stg_tpch__customers`, `stg_tpch__orders`). Two-word entities use one
   underscore inside the entity name (`stg_tpch__part_suppliers` style) —
   never invent a new prefix.
3. Inspect the real columns before writing SQL:
   `select * from SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.<TABLE> limit 5;` and use
   the results — do not guess column names from memory.

## Phase 2 — Model file

Write `models/staging/tpch/stg_tpch__<entity>.sql`:

- Banner header (exact format used by every model in this repo): model name,
  then a 1–3 line description including approximate row count.
- The two-CTE pattern, exactly:

```sql
with source as (
    select * from {{ source('tpch', '<table>') }}
),

renamed as (
    select
        <col renames>
    from source
)

select * from renamed
```

- In `renamed`: strip the TPCH column prefix (`ps_availqty` →
  `available_quantity`), expand abbreviations to full words
  (`qty` → `quantity`, `supplycost` → `supply_cost`), keep key columns
  named `<entity>_key` to match the rest of the project.
- Deterministic derived columns are allowed (see `stg_tpch__lineitems` for
  precedent) but each must be justified in the yml description. Do not add
  business logic — that belongs in marts.
- Preserve the TPCH `comment` column and name it `comment` (the sqlfluff
  keyword rule is already excluded for this).

## Phase 3 — Documentation and tests

Add the model to `models/staging/tpch/_models.yml`:

- Model description **stating the grain**: "One row per …". Include
  approximate row count.
- Column descriptions per the AGENTS.md two-tier policy: keys say what they
  join to; measures get units/meaning; the `comment` column gets the
  standard TPCH-reserved-word caveat used by the other staging models
  (match it verbatim).
- Tests, using the dbt 1.11 `arguments:` block syntax:
  - Primary key: `unique` + `not_null` (composite key:
    `dbt_utils.unique_combination_of_columns` under the model's
    `data_tests`, plus `not_null` on each component).
  - Every FK: `relationships` to the parent **staging model** (`ref()`, not
    `source()`).
  - Monetary and quantity columns: `assert_positive_value`.
  - Do not add `accepted_values` to high-cardinality columns, and do not
    duplicate tests that only restate a source-level test.

## Phase 4 — Verify [GATE]

Environment first (required — dbt is not on PATH):

```bash
source ~/venvs/tpch-dbt/bin/activate
set -a && source .env && set +a
```

Then, in order, all must pass:

```bash
sqlfluff fix models/staging/tpch/stg_tpch__<entity>.sql
sqlfluff lint models/staging/tpch/stg_tpch__<entity>.sql   # must be clean
dbt build --select stg_tpch__<entity>                      # model + its tests
dbt test --select source:tpch.<table>                      # source tests
```

If anything fails: fix the underlying issue and re-run. Never delete or
weaken a test to make it pass; if a test reveals a real data property
(e.g., a column that legitimately contains zeros), adjust the test choice
and say so explicitly in your report.

## Phase 5 — Report

Summarize: files created/modified; row count built vs. expected; each
verification command with its actual result (pass/fail counts, not
"succeeded"); any judgment calls made (naming, derived columns, test
choices) flagged for human review. Do not commit — git stays with the human.
