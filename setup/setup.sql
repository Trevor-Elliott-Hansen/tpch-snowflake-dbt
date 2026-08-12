-- =============================================================================
-- setup/setup.sql — one-shot environment bootstrap
-- =============================================================================
-- Creates the role, warehouse, and database this project expects, with the
-- exact names referenced in .env.example, so a fresh Snowflake account (e.g.,
-- a new trial) is dbt-ready in one script.
--
-- Run as ACCOUNTADMIN in a Snowsight worksheet (or `snow sql -f setup/setup.sql`).
-- Idempotent: safe to re-run.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Grant everything to the user running this script
SET current_user_name = (SELECT CURRENT_USER());

-- -----------------------------------------------------------------------------
-- Cortex prerequisite: cross-region inference
-- Required for Cortex Code (CoCo) Desktop/CLI — lets Cortex route requests to
-- models hosted outside the account's home region.
-- -----------------------------------------------------------------------------
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- -----------------------------------------------------------------------------
-- Role
-- -----------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS TRANSFORMER
  COMMENT = 'dbt transformation role for the tpch-snowflake-dbt project';

GRANT ROLE TRANSFORMER TO USER IDENTIFIER($current_user_name);

-- -----------------------------------------------------------------------------
-- Warehouse (XSMALL + aggressive auto-suspend: conserves trial credits)
-- -----------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS TRANSFORMING
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'dbt transformation warehouse for the tpch-snowflake-dbt project';

GRANT USAGE, OPERATE ON WAREHOUSE TRANSFORMING TO ROLE TRANSFORMER;

-- -----------------------------------------------------------------------------
-- Database (dbt creates the DBT_DEV_* schemas itself at run time)
-- -----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS ANALYTICS
  COMMENT = 'Target database for dbt-built staging, marts, and snapshot schemas';

GRANT USAGE, CREATE SCHEMA ON DATABASE ANALYTICS TO ROLE TRANSFORMER;

-- -----------------------------------------------------------------------------
-- Source data: read access to the TPCH sample share
-- -----------------------------------------------------------------------------
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA TO ROLE TRANSFORMER;

-- -----------------------------------------------------------------------------
-- Cortex Code (CoCo) prerequisites: the active role needs these database roles
-- (per docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop)
-- -----------------------------------------------------------------------------
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE TRANSFORMER;
GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE TRANSFORMER;

-- -----------------------------------------------------------------------------
-- Cost guardrails
-- -----------------------------------------------------------------------------
-- 1) Resource monitor: hard-stops ALL warehouse compute at 50 credits/month.
--    (Warehouse compute only — serverless Cortex usage is governed separately
--    by the CoCo limits below.) Raise CREDIT_QUOTA if legitimately needed.
CREATE RESOURCE MONITOR IF NOT EXISTS TRIAL_GUARDRAIL
  WITH CREDIT_QUOTA = 50
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 50 PERCENT DO NOTIFY
    ON 75 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND_IMMEDIATE;

ALTER ACCOUNT SET RESOURCE_MONITOR = TRIAL_GUARDRAIL;

-- 2) CoCo per-user daily credit limits (rolling 24h, estimated). Access to the
--    surface is blocked once the limit is hit, and unblocks as usage rolls off.
--    Default is -1 (unlimited) — never leave an AI agent unmetered.
ALTER ACCOUNT SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 5;
ALTER ACCOUNT SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 5;
ALTER ACCOUNT SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 5;

-- -----------------------------------------------------------------------------
-- Verify
-- -----------------------------------------------------------------------------
SHOW GRANTS TO ROLE TRANSFORMER;

USE ROLE TRANSFORMER;
USE WAREHOUSE TRANSFORMING;

-- Should return 150,000 rows if source access is wired up correctly
SELECT COUNT(*) AS customer_count
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER;
