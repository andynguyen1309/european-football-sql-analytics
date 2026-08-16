-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 02_import_data.sql
-- PURPOSE:
--   1. Document the raw CSV import process
--   2. Validate imported row counts
--   3. Confirm that source columns loaded correctly
--
-- DATABASE: eu_football_analytics
-- RAW SCHEMA: football_raw
-- AUTHOR: Andy Nguyen
--
-- EXECUTION ORDER:
--   Run after 01_create_tables.sql
--
-- IMPORT METHOD:
--   CSV files are imported using DBeaver's Import Data wizard.
-- ============================================================


-- ------------------------------------------------------------
-- 1. CONNECTION CHECK
-- ------------------------------------------------------------

SELECT
    current_database() AS database_name,
    current_user AS database_user;

SET search_path TO football_raw, football, public;

SHOW search_path;

-- ------------------------------------------------------------
-- 2. IMPORT ORDER
-- ------------------------------------------------------------
--
-- 1. competitions.csv
-- 2. clubs.csv
-- 3. players.csv
-- 4. games.csv
-- 5. club_games.csv
-- 6. appearances.csv
-- 7. player_valuations.csv
-- 8. transfers.csv
--
-- Each CSV should be imported into its matching table
-- inside the football_raw schema.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- 3. EXPECTED SOURCE ROW COUNTS
-- Based on the Python inspection notebook.
-- Update these values if the Kaggle dataset is downloaded again.
-- ------------------------------------------------------------

-- competitions:        65
-- clubs:              796
-- players:         50,149
-- games:           88,958
-- club_games:     177,916
-- appearances:  1,894,350
-- player_valuations: 507,815
-- transfers:       35,139

-- ------------------------------------------------------------
-- 4. POST-IMPORT ROW COUNT VALIDATION
-- ------------------------------------------------------------

SELECT 'competitions' AS table_name,
       COUNT(*) AS imported_rows,
       65 AS expected_rows,
       COUNT(*) - 65 AS row_difference
FROM football_raw.competitions

UNION ALL

SELECT 'clubs',
       COUNT(*),
       796,
       COUNT(*) - 796
FROM football_raw.clubs

UNION ALL

SELECT 'players',
       COUNT(*),
       50149,
       COUNT(*) - 50149
FROM football_raw.players

UNION ALL

SELECT 'games',
       COUNT(*),
       88958,
       COUNT(*) - 88958
FROM football_raw.games

UNION ALL

SELECT 'club_games',
       COUNT(*),
       177916,
       COUNT(*) - 177916
FROM football_raw.club_games

UNION ALL

SELECT 'appearances',
       COUNT(*),
       1894350,
       COUNT(*) - 1894350
FROM football_raw.appearances

UNION ALL

SELECT 'player_valuations',
       COUNT(*),
       507815,
       COUNT(*) - 507815
FROM football_raw.player_valuations

UNION ALL

SELECT 'transfers',
       COUNT(*),
       35139,
       COUNT(*) - 35139
FROM football_raw.transfers

ORDER BY table_name;


-- ------------------------------------------------------------
-- 5. SAMPLE RECORD CHECKS
-- ------------------------------------------------------------

SELECT *
FROM football_raw.competitions
LIMIT 5;

SELECT *
FROM football_raw.clubs
LIMIT 5;

SELECT *
FROM football_raw.players
LIMIT 5;

SELECT *
FROM football_raw.games
LIMIT 5;

SELECT *
FROM football_raw.club_games
LIMIT 5;

SELECT *
FROM football_raw.appearances
LIMIT 5;

SELECT *
FROM football_raw.player_valuations
LIMIT 5;

SELECT *
FROM football_raw.transfers
LIMIT 5;


-- ------------------------------------------------------------
-- 6. BASIC NULL AND KEY CHECKS
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(competition_id) AS non_null_primary_keys,
    COUNT(DISTINCT competition_id) AS distinct_primary_keys
FROM football_raw.competitions;

SELECT
    COUNT(*) AS total_rows,
    COUNT(club_id) AS non_null_primary_keys,
    COUNT(DISTINCT club_id) AS distinct_primary_keys
FROM football_raw.clubs;

SELECT
    COUNT(*) AS total_rows,
    COUNT(player_id) AS non_null_primary_keys,
    COUNT(DISTINCT player_id) AS distinct_primary_keys
FROM football_raw.players;

SELECT
    COUNT(*) AS total_rows,
    COUNT(game_id) AS non_null_primary_keys,
    COUNT(DISTINCT game_id) AS distinct_primary_keys
FROM football_raw.games;

SELECT
    COUNT(*) AS total_rows,
    COUNT(appearance_id) AS non_null_primary_keys,
    COUNT(DISTINCT appearance_id) AS distinct_primary_keys
FROM football_raw.appearances;

-- ------------------------------------------------------------
-- 7. VERIFY GENERATED TRANSFER IDs
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(transfer_id) AS non_null_transfer_ids,
    COUNT(DISTINCT transfer_id) AS distinct_transfer_ids,
    MIN(transfer_id) AS minimum_transfer_id,
    MAX(transfer_id) AS maximum_transfer_id
FROM football_raw.transfers;

-- ============================================================
-- END OF FILE
-- Next script: 03_data_quality_checks.sql
-- ============================================================