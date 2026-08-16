-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 00_database_setup.sql
-- PURPOSE:
--   1. Confirm the PostgreSQL connection
--   2. Create the raw-data schema
--   3. Create the cleaned analytical schema
--   4. Set the default working schema
--   5. Verify the database setup
--
-- DATABASE: eu_football_analytics
-- AUTHOR: Andy Nguyen
-- ============================================================

-- ------------------------------------------------------------
-- 1. CONNECTION CHECK
-- Confirm that this script is running in the correct database.
-- ------------------------------------------------------------

SELECT
    current_database() AS database_name,
    current_user AS database_user,
    version() AS postgresql_version;

-- ------------------------------------------------------------
-- 2. CREATE RAW-DATA SCHEMA
-- Stores tables imported directly from the Kaggle CSV files.
-- Raw source values should be preserved without cleaning.
-- ------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS football_raw;

-- ------------------------------------------------------------
-- 3. CREATE ANALYTICAL SCHEMA
-- Stores cleaned views, analytical tables and final outputs.
-- ------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS football;

-- ------------------------------------------------------------
-- 4. SET THE WORKING SCHEMA
-- New unqualified analytical objects will be created in football.
-- Raw source objects should be referenced explicitly with
-- the football_raw schema prefix.
-- ------------------------------------------------------------

SET search_path TO football, football_raw, public;

-- ------------------------------------------------------------
-- 5. VERIFY THE SEARCH PATH
-- Expected result: football, football_raw, public
-- ------------------------------------------------------------

SHOW search_path;

-- ------------------------------------------------------------
-- 6. VERIFY PROJECT SCHEMAS
-- ------------------------------------------------------------

SELECT
    schema_name
FROM information_schema.schemata
WHERE schema_name IN (
    'football_raw',
    'football'
)
ORDER BY schema_name;

-- ------------------------------------------------------------
-- 7. DISPLAY ALL NON-SYSTEM SCHEMAS
-- ------------------------------------------------------------

SELECT
    schema_name
FROM information_schema.schemata
WHERE schema_name NOT IN (
    'information_schema',
    'pg_catalog',
    'pg_toast'
)
ORDER BY schema_name;


-- ============================================================
-- END OF FILE
-- Next script: 01_create_tables.sql
-- ============================================================
