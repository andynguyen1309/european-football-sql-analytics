-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 04_data_cleaning.sql
-- PURPOSE:
--   1. Create a cleaned analytical layer
--   2. Preserve all original raw values
--   3. Standardise invalid and missing values
--   4. Add transparent data-quality flags
--   5. Prepare data for later analytical views
--
-- DATABASE: eu_football_analytics
-- RAW SCHEMA: football_raw
-- ANALYTICAL SCHEMA: football
-- AUTHOR: Andy Nguyen
--
-- EXECUTION ORDER:
--   Run after 03_data_quality_checks.sql
--
-- IMPORTANT:
--   This script does not update or delete raw source data.
--   Cleaned objects are created as views in the football schema.
-- ============================================================

-- ------------------------------------------------------------
-- 1. CONNECTION AND SCHEMA CHECK
-- ------------------------------------------------------------

SELECT
    current_database() AS database_name,
    current_user AS database_user,
    CURRENT_TIMESTAMP AS cleaning_timestamp;

SET search_path TO football, football_raw, public;

SHOW search_path;

-- ------------------------------------------------------------
-- 2. CLEAN COMPETITIONS
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.clean_competitions AS

SELECT
    competition_id,
    NULLIF(TRIM(competition_code), '') AS competition_code,
    NULLIF(TRIM(name), '') AS competition_name,
    NULLIF(TRIM(sub_type), '') AS competition_sub_type,
    NULLIF(TRIM(type), '') AS competition_type,

    -- Negative country IDs are source sentinel values.
    CASE
        WHEN country_id < 0 THEN NULL
        ELSE country_id
    END AS country_id,

    NULLIF(TRIM(country_name), '') AS country_name,
    NULLIF(TRIM(domestic_league_code), '')
        AS domestic_league_code,
    NULLIF(TRIM(confederation), '') AS confederation,
    NULLIF(TRIM(url), '') AS competition_url,

    -- Data-quality flag
    CASE
        WHEN country_id < 0 THEN TRUE
        ELSE FALSE
    END AS has_invalid_country_id

FROM football_raw.competitions;

-- ------------------------------------------------------------
-- 3. CLEAN CLUBS
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.clean_clubs AS

SELECT
    club_id,
    NULLIF(TRIM(club_code), '') AS club_code,
    NULLIF(TRIM(name), '') AS club_name,
    NULLIF(TRIM(domestic_competition_id), '')
        AS domestic_competition_id,

    -- This field was completely missing in the inspected data.
    total_market_value,

    CASE
        WHEN squad_size <= 0 THEN NULL
        ELSE squad_size
    END AS squad_size,

    CASE
        WHEN average_age <= 0 THEN NULL
        ELSE average_age
    END AS average_age,

    CASE
        WHEN foreigners_number < 0 THEN NULL
        ELSE foreigners_number
    END AS foreigners_number,

    CASE
        WHEN foreigners_percentage < 0
          OR foreigners_percentage > 100
            THEN NULL
        ELSE foreigners_percentage
    END AS foreigners_percentage,

    CASE
        WHEN national_team_players < 0 THEN NULL
        ELSE national_team_players
    END AS national_team_players,

    NULLIF(TRIM(stadium_name), '') AS stadium_name,

    CASE
        WHEN stadium_seats <= 0 THEN NULL
        ELSE stadium_seats
    END AS stadium_seats,

    NULLIF(TRIM(net_transfer_record), '')
        AS net_transfer_record,

    NULLIF(TRIM(coach_name), '') AS coach_name,
    last_season,
    NULLIF(TRIM(filename), '') AS filename,
    NULLIF(TRIM(url), '') AS club_url,

    -- Data-quality flags
    CASE
        WHEN squad_size <= 0 THEN TRUE
        ELSE FALSE
    END AS has_invalid_squad_size,

    CASE
        WHEN average_age <= 0 THEN TRUE
        ELSE FALSE
    END AS has_invalid_average_age,

    CASE
        WHEN stadium_seats <= 0 THEN TRUE
        ELSE FALSE
    END AS has_invalid_stadium_capacity

FROM football_raw.clubs;

-- ------------------------------------------------------------
-- 4. CLEAN PLAYERS
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.clean_players AS

SELECT
    player_id,

    NULLIF(TRIM(first_name), '') AS first_name,
    NULLIF(TRIM(last_name), '') AS last_name,
    NULLIF(TRIM(name), '') AS player_name,

    last_season,

    CASE
        WHEN current_club_id < 0 THEN NULL
        ELSE current_club_id
    END AS current_club_id,

    NULLIF(TRIM(player_code), '') AS player_code,
    NULLIF(TRIM(country_of_birth), '') AS country_of_birth,
    NULLIF(TRIM(city_of_birth), '') AS city_of_birth,
    NULLIF(TRIM(country_of_citizenship), '')
        AS country_of_citizenship,

    date_of_birth,

    NULLIF(TRIM(sub_position), '') AS sub_position,
    NULLIF(TRIM(position), '') AS position,
    NULLIF(TRIM(foot), '') AS preferred_foot,

    -- Plausible player height range.
    CASE
        WHEN height_in_cm BETWEEN 140 AND 220
            THEN height_in_cm
        ELSE NULL
    END AS height_in_cm,

    CASE
        WHEN market_value_in_eur < 0 THEN NULL
        ELSE market_value_in_eur
    END AS current_market_value_in_eur,

    CASE
        WHEN highest_market_value_in_eur < 0 THEN NULL
        ELSE highest_market_value_in_eur
    END AS highest_market_value_in_eur,

    contract_expiration_date,
    NULLIF(TRIM(agent_name), '') AS agent_name,
    NULLIF(TRIM(image_url), '') AS image_url,
    NULLIF(TRIM(url), '') AS player_url,

    NULLIF(
        TRIM(current_club_domestic_competition_id),
        ''
    ) AS current_club_domestic_competition_id,

    NULLIF(TRIM(current_club_name), '') AS current_club_name,

    CASE
        WHEN current_national_team_id < 0 THEN NULL
        ELSE current_national_team_id
    END AS current_national_team_id,

    CASE
        WHEN international_caps < 0 THEN NULL
        ELSE international_caps
    END AS international_caps,

    CASE
        WHEN international_goals < 0 THEN NULL
        ELSE international_goals
    END AS international_goals,

    -- Data-quality flags
    CASE
        WHEN height_in_cm IS NOT NULL
         AND height_in_cm NOT BETWEEN 140 AND 220
            THEN TRUE
        ELSE FALSE
    END AS has_invalid_height,

    CASE
        WHEN current_club_id < 0 THEN TRUE
        ELSE FALSE
    END AS has_invalid_current_club_id

FROM football_raw.players;

-- ------------------------------------------------------------
-- 5. CLEAN GAMES
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.clean_games AS

SELECT
    game_id,
    NULLIF(TRIM(competition_id), '') AS competition_id,
    season,
    NULLIF(TRIM(round), '') AS competition_round,
    date AS game_date,

    CASE
        WHEN home_club_id < 0 THEN NULL
        ELSE home_club_id
    END AS home_club_id,

    CASE
        WHEN away_club_id < 0 THEN NULL
        ELSE away_club_id
    END AS away_club_id,

    CASE
        WHEN home_club_goals < 0 THEN NULL
        ELSE home_club_goals
    END AS home_club_goals,

    CASE
        WHEN away_club_goals < 0 THEN NULL
        ELSE away_club_goals
    END AS away_club_goals,

    CASE
        WHEN home_club_position <= 0 THEN NULL
        ELSE home_club_position
    END AS home_club_position,

    CASE
        WHEN away_club_position <= 0 THEN NULL
        ELSE away_club_position
    END AS away_club_position,

    NULLIF(TRIM(home_club_manager_name), '')
        AS home_club_manager_name,

    NULLIF(TRIM(away_club_manager_name), '')
        AS away_club_manager_name,

    NULLIF(TRIM(stadium), '') AS stadium,

    CASE
        WHEN attendance < 0 THEN NULL
        ELSE attendance
    END AS attendance,

    NULLIF(TRIM(referee), '') AS referee,
    NULLIF(TRIM(url), '') AS game_url,
    NULLIF(TRIM(home_club_name), '') AS home_club_name,
    NULLIF(TRIM(away_club_name), '') AS away_club_name,
    NULLIF(TRIM(aggregate), '') AS aggregate_score,
    NULLIF(TRIM(competition_type), '') AS competition_type,

    -- Derived result
    CASE
        WHEN home_club_goals IS NULL
          OR away_club_goals IS NULL
            THEN NULL
        WHEN home_club_goals > away_club_goals
            THEN 'Home Win'
        WHEN home_club_goals < away_club_goals
            THEN 'Away Win'
        ELSE 'Draw'
    END AS match_result,

    -- Data-quality flags
    CASE
        WHEN home_club_id = away_club_id THEN TRUE
        ELSE FALSE
    END AS has_same_home_away_club,

    CASE
        WHEN home_club_goals < 0
          OR away_club_goals < 0
            THEN TRUE
        ELSE FALSE
    END AS has_invalid_goal_value

FROM football_raw.games;

-- ------------------------------------------------------------
-- 6. CLEAN CLUB_GAMES
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.clean_club_games AS

SELECT
    game_id,

    CASE
        WHEN club_id < 0 THEN NULL
        ELSE club_id
    END AS club_id,

    CASE
        WHEN own_goals < 0 THEN NULL
        ELSE own_goals
    END AS own_goals,

    CASE
        WHEN own_position <= 0 THEN NULL
        ELSE own_position
    END AS own_position,

    NULLIF(TRIM(own_manager_name), '') AS own_manager_name,

    CASE
        WHEN opponent_id < 0 THEN NULL
        ELSE opponent_id
    END AS opponent_id,

    CASE
        WHEN opponent_goals < 0 THEN NULL
        ELSE opponent_goals
    END AS opponent_goals,

    CASE
        WHEN opponent_position <= 0 THEN NULL
        ELSE opponent_position
    END AS opponent_position,

    NULLIF(TRIM(opponent_manager_name), '')
        AS opponent_manager_name,

    NULLIF(TRIM(hosting), '') AS hosting,
    is_win,

    CASE
        WHEN own_goals > opponent_goals THEN 3
        WHEN own_goals = opponent_goals THEN 1
        WHEN own_goals < opponent_goals THEN 0
        ELSE NULL
    END AS points_earned

FROM football_raw.club_games;

-- ------------------------------------------------------------
-- 7. CLEAN APPEARANCES
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.clean_appearances AS

SELECT
    appearance_id,
    game_id,
    player_id,

    CASE
        WHEN player_club_id < 0 THEN NULL
        ELSE player_club_id
    END AS player_club_id,

    CASE
        WHEN player_current_club_id < 0 THEN NULL
        ELSE player_current_club_id
    END AS player_current_club_id,

    date AS appearance_date,
    NULLIF(TRIM(player_name), '') AS player_name,
    NULLIF(TRIM(competition_id), '') AS competition_id,

    CASE
        WHEN yellow_cards < 0 THEN NULL
        ELSE yellow_cards
    END AS yellow_cards,

    CASE
        WHEN red_cards < 0 THEN NULL
        ELSE red_cards
    END AS red_cards,

    CASE
        WHEN goals < 0 THEN NULL
        ELSE goals
    END AS goals,

    CASE
        WHEN assists < 0 THEN NULL
        ELSE assists
    END AS assists,

    -- Preserve the original source value.
    minutes_played AS minutes_played_raw,

    -- Use only valid values in analytical calculations.
    CASE
        WHEN minutes_played BETWEEN 0 AND 130
            THEN minutes_played
        ELSE NULL
    END AS minutes_played,

    -- Data-quality flags
    CASE
        WHEN minutes_played < 0
          OR minutes_played > 130
            THEN TRUE
        ELSE FALSE
    END AS has_invalid_minutes,

    CASE
        WHEN player_current_club_id < 0 THEN TRUE
        ELSE FALSE
    END AS has_invalid_current_club_id

FROM football_raw.appearances;

-- ------------------------------------------------------------
-- 8. CLEAN PLAYER_VALUATIONS
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.clean_player_valuations AS

SELECT
    player_id,
    date AS valuation_date,

    CASE
        WHEN market_value_in_eur < 0 THEN NULL
        ELSE market_value_in_eur
    END AS market_value_in_eur,

    NULLIF(TRIM(current_club_name), '') AS current_club_name,

    CASE
        WHEN current_club_id < 0 THEN NULL
        ELSE current_club_id
    END AS current_club_id,

    NULLIF(
        TRIM(player_club_domestic_competition_id),
        ''
    ) AS player_club_domestic_competition_id,

    CASE
        WHEN market_value_in_eur IS NULL THEN 'Missing'
        WHEN market_value_in_eur = 0 THEN 'Zero'
        WHEN market_value_in_eur > 0 THEN 'Positive'
        ELSE 'Invalid'
    END AS market_value_status

FROM football_raw.player_valuations;

-- ------------------------------------------------------------
-- 9. CLEAN TRANSFERS
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.clean_transfers AS

SELECT
    transfer_id,
    player_id,
    transfer_date,
    NULLIF(TRIM(transfer_season), '') AS transfer_season,

    CASE
        WHEN from_club_id < 0 THEN NULL
        ELSE from_club_id
    END AS from_club_id,

    CASE
        WHEN to_club_id < 0 THEN NULL
        ELSE to_club_id
    END AS to_club_id,

    NULLIF(TRIM(from_club_name), '') AS from_club_name,
    NULLIF(TRIM(to_club_name), '') AS to_club_name,

    CASE
        WHEN transfer_fee < 0 THEN NULL
        ELSE transfer_fee
    END AS transfer_fee,

    CASE
        WHEN market_value_in_eur < 0 THEN NULL
        ELSE market_value_in_eur
    END AS market_value_in_eur,

    NULLIF(TRIM(player_name), '') AS player_name,

    CASE
        WHEN transfer_fee IS NULL
            THEN 'Missing or undisclosed fee'
        WHEN transfer_fee = 0
            THEN 'Recorded zero fee'
        WHEN transfer_fee > 0
            THEN 'Positive known fee'
        ELSE 'Invalid fee'
    END AS transfer_fee_status,

    CASE
        WHEN transfer_date > CURRENT_DATE
            THEN TRUE
        ELSE FALSE
    END AS is_future_transfer,

    CASE
        WHEN from_club_id = to_club_id
         AND from_club_id IS NOT NULL
            THEN TRUE
        ELSE FALSE
    END AS has_same_origin_destination

FROM football_raw.transfers;

-- ------------------------------------------------------------
-- 10. VERIFY CLEANED VIEWS
-- Expected result: eight views.
-- ------------------------------------------------------------

SELECT
    table_schema,
    table_name
FROM information_schema.views
WHERE table_schema = 'football'
  AND table_name LIKE 'clean_%'
ORDER BY table_name;

-- ------------------------------------------------------------
-- 11. RAW VERSUS CLEAN ROW-COUNT VALIDATION
-- ------------------------------------------------------------

SELECT
    'competitions' AS dataset,
    (SELECT COUNT(*)
     FROM football_raw.competitions) AS raw_rows,
    (SELECT COUNT(*)
     FROM football.clean_competitions) AS clean_rows

UNION ALL

SELECT
    'clubs',
    (SELECT COUNT(*) FROM football_raw.clubs),
    (SELECT COUNT(*) FROM football.clean_clubs)

UNION ALL

SELECT
    'players',
    (SELECT COUNT(*) FROM football_raw.players),
    (SELECT COUNT(*) FROM football.clean_players)

UNION ALL

SELECT
    'games',
    (SELECT COUNT(*) FROM football_raw.games),
    (SELECT COUNT(*) FROM football.clean_games)

UNION ALL

SELECT
    'club_games',
    (SELECT COUNT(*) FROM football_raw.club_games),
    (SELECT COUNT(*) FROM football.clean_club_games)

UNION ALL

SELECT
    'appearances',
    (SELECT COUNT(*) FROM football_raw.appearances),
    (SELECT COUNT(*) FROM football.clean_appearances)

UNION ALL

SELECT
    'player_valuations',
    (SELECT COUNT(*)
     FROM football_raw.player_valuations),
    (SELECT COUNT(*)
     FROM football.clean_player_valuations)

UNION ALL

SELECT
    'transfers',
    (SELECT COUNT(*) FROM football_raw.transfers),
    (SELECT COUNT(*) FROM football.clean_transfers)

ORDER BY dataset;

-- ------------------------------------------------------------
-- 12. CLEANING-RULE VALIDATION
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS flagged_invalid_heights,
    COUNT(*) FILTER (
        WHERE height_in_cm IS NULL
          AND has_invalid_height = TRUE
    ) AS converted_to_null
FROM football.clean_players
WHERE has_invalid_height = TRUE;

SELECT
    appearance_id,
    minutes_played_raw,
    minutes_played,
    has_invalid_minutes
FROM football.clean_appearances
WHERE has_invalid_minutes = TRUE
ORDER BY minutes_played_raw DESC;

SELECT
    transfer_fee_status,
    COUNT(*) AS transfer_count
FROM football.clean_transfers
GROUP BY transfer_fee_status
ORDER BY transfer_count DESC;

SELECT
    COUNT(*) AS future_transfer_count
FROM football.clean_transfers
WHERE is_future_transfer = TRUE;

-- ============================================================
-- CLEANING DECISIONS SUMMARY
--
-- 1. Raw source tables were not modified.
-- 2. Blank text values were standardised to NULL.
-- 3. Negative sentinel IDs were converted to NULL.
-- 4. Player heights outside 140–220 cm were converted to NULL.
-- 5. Invalid appearance minutes were converted to NULL while
--    the original values were retained as minutes_played_raw.
-- 6. Zero and missing transfer fees were kept as separate
--    classifications.
-- 7. Future transfers were retained and explicitly flagged.
-- 8. Invalid club squad, age and stadium values were converted
--    to NULL.
-- 9. All cleaning decisions remain traceable to raw values.
--
-- No five-league or season filtering was applied in this file.
-- Project-scope views will be created in the next script.
-- ============================================================


-- ============================================================
-- END OF FILE
-- Next script: 05_create_views_and_indexes.sql
-- ============================================================