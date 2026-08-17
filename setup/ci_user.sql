-- =============================================================================
-- setup/ci_user.sql — service identity for the CI review agent
-- =============================================================================
-- Creates a dedicated SERVICE user for GitHub Actions, following the
-- least-privilege pattern: the CI agent gets its own identity (auditable,
-- revocable) restricted to the TRANSFORMER role — the same role whose
-- humans receive the tpch-conventions plugin. Run as ACCOUNTADMIN.
--
-- After running: copy the PAT secret from the ALTER USER output into the
-- GitHub repository secret SNOWFLAKE_CI_PAT. The token is shown ONCE.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE USER IF NOT EXISTS COCO_CI
  TYPE = SERVICE
  DEFAULT_ROLE = TRANSFORMER
  DEFAULT_WAREHOUSE = TRANSFORMING
  COMMENT = 'Service user for the GitHub Actions dbt-reviewer agent';

GRANT ROLE TRANSFORMER TO USER COCO_CI;

-- PATs require the user to be covered by a network policy. GitHub-hosted
-- runners use dynamic IPs, so the policy is necessarily open; the PAT itself
-- (short expiry + role restriction) is the effective control.
CREATE NETWORK POLICY IF NOT EXISTS CI_OPEN_POLICY
  ALLOWED_IP_LIST = ('0.0.0.0/0')
  COMMENT = 'Open policy for CI service user; PAT expiry + role restriction are the controls';

ALTER USER COCO_CI SET NETWORK_POLICY = CI_OPEN_POLICY;

-- Role-restricted, 30-day token. THE SECRET IS DISPLAYED ONCE — copy it to
-- the GitHub secret immediately. Rotate by re-running with a new name.
ALTER USER COCO_CI ADD PROGRAMMATIC ACCESS TOKEN CI_REVIEWER_TOKEN
  ROLE_RESTRICTION = 'TRANSFORMER'
  DAYS_TO_EXPIRY = 30;

-- Verify
SHOW USERS LIKE 'COCO_CI';
SHOW GRANTS TO USER COCO_CI;
