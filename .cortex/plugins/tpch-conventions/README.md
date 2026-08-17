# tpch-conventions plugin

Governance bundle for this project's AI coding agents. One versioned unit
containing:

| Component | What it does |
|---|---|
| `skills/add-staging-model` | Gated workflow for adding staging models: source hardening, CTE conventions, tests, docs, mandatory build verification |
| `agents/dbt-reviewer` | Read-only code reviewer (`tools: read, grep, glob, tgrep` — by construction, not by promise); reviews diffs against AGENTS.md and dimensional-modeling correctness |
| `hooks/guardrails.sh` | PreToolUse enforcement: blocks prod targets, `dbt snapshot` (stateful SCD2), destructive DDL outside dev schemas, and warehouse/spend changes |

Conventions (AGENTS.md) are advice; this plugin makes agent behavior
consistent and the dangerous operations impossible.

## Installation

**Working in this repo?** Nothing to do — Cortex Code auto-discovers
project plugins in `.cortex/plugins/`. Clone the repo, get the governance.

**From the Snowflake Plugins Catalog** (requires the `TRANSFORMER` role —
access to the extension is a Snowflake grant, same governance model as the
data itself):

```
snow://skill_catalog/USER$ADMIN.SKILL_SHARING.TPCH_CONVENTIONS/
```

Published as a versioned `CORTEX EXTENSION` object; find it in the catalog
or install via the URI.

**From Git** (CoCo CLI):

```bash
cortex plugin install https://github.com/Trevor-Elliott-Hansen/tpch-snowflake-dbt
```

## Versioning

Semantic version in `.cortex-plugin/plugin.json`. Republishing to the
catalog commits a new version of the extension object; installed copies
are versioned snapshots, not live syncs.
