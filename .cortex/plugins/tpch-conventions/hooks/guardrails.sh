#!/usr/bin/env bash
# =============================================================================
# guardrails.sh — PreToolUse hook: hard policy for agent shell commands
# =============================================================================
# Fires before every tool call (matcher ".*" in .cortex/settings.json).
# No-ops unless the tool input carries a shell command. Exit 2 blocks the
# call; stderr becomes the reason shown to the agent.
#
# These are POLICY, not advice: AGENTS.md asks agents to behave; this hook
# makes the worst mistakes impossible. Layers:
#   1. No prod deploys           (dbt ... --target prod)
#   2. No stateful snapshot runs (dbt snapshot — SCD2 history is append-only;
#      a careless run permanently pollutes dim_customer_history)
#   3. No destructive SQL outside dev schemas (drop/truncate)
#   4. No warehouse/spend changes (create/alter warehouse, resource monitors)
#
# Humans can still do any of this deliberately in their own shell — the hook
# only governs what the AGENT may execute.
# =============================================================================

set -euo pipefail

INPUT=$(cat)

# Extract a shell command from tool_input if one exists (field name varies by
# tool; check the common ones). Non-shell tools pass through untouched.
CMD=$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ti = d.get("tool_input") or {}
for key in ("command", "cmd", "script"):
    v = ti.get(key)
    if isinstance(v, str) and v.strip():
        print(v)
        break
' 2>/dev/null || true)

[ -z "${CMD:-}" ] && exit 0

LC=$(printf '%s' "$CMD" | tr '[:upper:]' '[:lower:]')

block() {
    echo "BLOCKED by .cortex/hooks/guardrails.sh: $1" >&2
    exit 2
}

# --- 1. Prod target ----------------------------------------------------------
if printf '%s' "$LC" | grep -qE -- '--target[= ]+prod\b'; then
    block "prod deploys are not allowed from agent sessions. Dev work uses the default 'dev' target; prod runs are a human-executed, reviewed operation."
fi

# --- 2. Snapshot protection --------------------------------------------------
if printf '%s' "$LC" | grep -qE '(^|[;&|[:space:]])dbt[[:space:]]+([a-z-]+[[:space:]]+)*snapshot\b'; then
    block "dbt snapshot mutates the stateful SCD2 history table (customer_snapshot -> dim_customer_history). Snapshot runs are human-only: a careless run against a modified seed or config permanently pollutes accumulated history. Ask the human to run it if the task truly requires it."
fi

# --- 3. Destructive SQL outside dev schemas ----------------------------------
if printf '%s' "$LC" | grep -qE '\b(drop|truncate)[[:space:]]+(table|view|schema|database|materialized[[:space:]]+view)\b'; then
    if ! printf '%s' "$LC" | grep -q 'dbt_dev'; then
        block "drop/truncate outside DBT_DEV_* schemas is not allowed. Destructive DDL against shared or source objects is a human-only operation."
    fi
fi

# --- 4. Warehouse and spend controls ----------------------------------------
if printf '%s' "$LC" | grep -qE '\b(create|alter|drop)[[:space:]]+warehouse\b|\bresource[[:space:]]+monitor\b'; then
    block "warehouse and resource-monitor changes are not allowed from agent sessions. Compute sizing and spend controls are set in setup/setup.sql and changed only by humans."
fi

exit 0
