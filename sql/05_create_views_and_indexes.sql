-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 05_create_views_and_indexes.sql
-- PURPOSE:
--   1. Create indexes for common joins and filters
--   2. Define the core five-league project scope
--   3. Create reusable scoped analytical views
--   4. Build club-season and player-season datasets
--   5. Prepare valuation and transfer data for later analysis
--
-- DATABASE: eu_football_analytics
-- RAW SCHEMA: football_raw
-- ANALYTICAL SCHEMA: football
-- AUTHOR: Andy Nguyen
--
-- EXECUTION ORDER:
--   Run after 04_data_cleaning.sql
--
-- CORE SCOPE:
--   Competitions:
--     GB1 - Premier League
--     ES1 - La Liga
--     L1  - Bundesliga
--     IT1 - Serie A
--     FR1 - Ligue 1
--
--   Seasons:
--     2020 to 2024
--     Representing 2020-21 through 2024-25
--
-- IMPORTANT:
--   Raw source tables remain unchanged.
--   This script creates indexes on raw tables and scoped views
--   in the football analytical schema.
-- ============================================================

-- ------------------------------------------------------------
-- 1. CONNECTION AND SCHEMA CHECK
-- ------------------------------------------------------------

SELECT
    current_database() AS database_name,
    current_user AS database_user,
    CURRENT_TIMESTAMP AS preparation_timestamp;

SET search_path TO football, football_raw, public;

SHOW search_path;

-- ------------------------------------------------------------
-- 2. CREATE PERFORMANCE INDEXES
-- ------------------------------------------------------------

-- Speeds up competition and season filtering.
CREATE INDEX IF NOT EXISTS idx_games_competition_season
    ON football_raw.games (
        competition_id,
        season
    );


-- Speeds up joining appearances to games.
CREATE INDEX IF NOT EXISTS idx_appearances_game_id
    ON football_raw.appearances (
        game_id
    );


-- Speeds up player-level appearance aggregation.
CREATE INDEX IF NOT EXISTS idx_appearances_player_id
    ON football_raw.appearances (
        player_id
    );


-- Speeds up club-level player aggregation.
CREATE INDEX IF NOT EXISTS idx_appearances_player_club_id
    ON football_raw.appearances (
        player_club_id
    );


-- Speeds up competition filtering within appearances.
CREATE INDEX IF NOT EXISTS idx_appearances_competition_id
    ON football_raw.appearances (
        competition_id
    );


-- Speeds up player transfer-history analysis.
CREATE INDEX IF NOT EXISTS idx_transfers_player_date
    ON football_raw.transfers (
        player_id,
        transfer_date
    );


-- Speeds up analysis of transfer flows from clubs.
CREATE INDEX IF NOT EXISTS idx_transfers_from_club
    ON football_raw.transfers (
        from_club_id
    );


-- Speeds up analysis of transfer flows to clubs.
CREATE INDEX IF NOT EXISTS idx_transfers_to_club
    ON football_raw.transfers (
        to_club_id
    );


-- Speeds up filtering clubs by their domestic competition.
CREATE INDEX IF NOT EXISTS idx_clubs_domestic_competition
    ON football_raw.clubs (
        domestic_competition_id
    );

-- ------------------------------------------------------------
-- 2.1 UPDATE QUERY-PLANNER STATISTICS
-- ------------------------------------------------------------

ANALYZE football_raw.games;
ANALYZE football_raw.appearances;
ANALYZE football_raw.transfers;
ANALYZE football_raw.clubs;
ANALYZE football_raw.player_valuations;

-- ------------------------------------------------------------
-- 2.2 VERIFY PROJECT INDEXES
-- ------------------------------------------------------------

SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'football_raw'
  AND indexname LIKE 'idx_%'
ORDER BY
    tablename,
    indexname;

-- ------------------------------------------------------------
-- 3. DEFINE CORE COMPETITION SCOPE
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.vw_core_competitions AS

SELECT
    competition_id,
    competition_code,
    competition_name,
    country_name,
    competition_type,
    competition_sub_type,
    domestic_league_code,
    confederation
FROM football.clean_competitions
WHERE competition_id IN (
    'GB1',
    'ES1',
    'L1',
    'IT1',
    'FR1'
);

--Verify 5 

SELECT *
FROM football.vw_core_competitions
ORDER BY competition_id;

-- ------------------------------------------------------------
-- 4. CREATE CORE GAMES VIEW
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.vw_core_games AS

SELECT
    g.game_id,
    g.competition_id,
    c.competition_name,
    c.country_name,
    g.season,

    CONCAT(
        g.season,
        '-',
        RIGHT((g.season + 1)::TEXT, 2)
    ) AS season_label,

    g.competition_round,
    g.game_date,

    -- Standard reference date for season-level calculations.
    MAKE_DATE(
        g.season + 1,
        6,
        30
    ) AS season_end_date,

    g.home_club_id,
    g.away_club_id,
    g.home_club_name,
    g.away_club_name,
    g.home_club_goals,
    g.away_club_goals,
    g.home_club_position,
    g.away_club_position,
    g.home_club_manager_name,
    g.away_club_manager_name,
    g.stadium,
    g.attendance,
    g.referee,
    g.match_result,

    g.home_club_goals
        + g.away_club_goals AS total_goals

FROM football.clean_games AS g
JOIN football.vw_core_competitions AS c
    ON g.competition_id = c.competition_id
WHERE g.season BETWEEN 2020 AND 2024;

--Verify match counts

SELECT
    competition_id,
    competition_name,
    season,
    season_label,
    COUNT(*) AS game_count
FROM football.vw_core_games
GROUP BY
    competition_id,
    competition_name,
    season,
    season_label
ORDER BY
    competition_id,
    season;

-- ------------------------------------------------------------
-- 5. CREATE CORE CLUB-MATCH VIEW
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.vw_core_club_matches AS

SELECT
    cg.game_id,
    g.competition_id,
    g.competition_name,
    g.country_name,
    g.season,
    g.season_label,
    g.game_date,
    g.season_end_date,

    cg.club_id,

    CASE
        WHEN cg.club_id = g.home_club_id
            THEN g.home_club_name
        WHEN cg.club_id = g.away_club_id
            THEN g.away_club_name
        ELSE NULL
    END AS club_name,

    cg.opponent_id,

    CASE
        WHEN cg.opponent_id = g.home_club_id
            THEN g.home_club_name
        WHEN cg.opponent_id = g.away_club_id
            THEN g.away_club_name
        ELSE NULL
    END AS opponent_name,

    cg.hosting,
    cg.own_goals,
    cg.opponent_goals,
    cg.own_position,
    cg.opponent_position,
    cg.own_manager_name,
    cg.opponent_manager_name,
    cg.is_win,
    cg.points_earned,

    CASE
        WHEN cg.own_goals > cg.opponent_goals
            THEN 'Win'
        WHEN cg.own_goals < cg.opponent_goals
            THEN 'Loss'
        WHEN cg.own_goals = cg.opponent_goals
            THEN 'Draw'
        ELSE NULL
    END AS club_result,

    cg.own_goals
        - cg.opponent_goals AS goal_difference

FROM football.clean_club_games AS cg
JOIN football.vw_core_games AS g
    ON cg.game_id = g.game_id;

--Verify two rows per match

SELECT
    COUNT(*) AS club_match_rows,
    COUNT(DISTINCT game_id) AS distinct_games,
    COUNT(*) - 2 * COUNT(DISTINCT game_id)
        AS expected_row_difference
FROM football.vw_core_club_matches;

-- ------------------------------------------------------------
-- 6. CREATE CLUB-SEASON PERFORMANCE VIEW
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.vw_club_season_performance AS

SELECT
    competition_id,
    competition_name,
    country_name,
    season,
    season_label,
    club_id,
    club_name,

    COUNT(DISTINCT game_id) AS matches_played,

    COUNT(*) FILTER (
        WHERE club_result = 'Win'
    ) AS wins,

    COUNT(*) FILTER (
        WHERE club_result = 'Draw'
    ) AS draws,

    COUNT(*) FILTER (
        WHERE club_result = 'Loss'
    ) AS losses,

    COUNT(*) FILTER (
        WHERE hosting = 'Home'
           OR LOWER(hosting) = 'home'
    ) AS home_matches,

    COUNT(*) FILTER (
        WHERE (
            hosting = 'Home'
            OR LOWER(hosting) = 'home'
        )
          AND club_result = 'Win'
    ) AS home_wins,

    COUNT(*) FILTER (
        WHERE hosting = 'Away'
           OR LOWER(hosting) = 'away'
    ) AS away_matches,

    COUNT(*) FILTER (
        WHERE (
            hosting = 'Away'
            OR LOWER(hosting) = 'away'
        )
          AND club_result = 'Win'
    ) AS away_wins,

    SUM(own_goals) AS goals_scored,
    SUM(opponent_goals) AS goals_conceded,
    SUM(goal_difference) AS goal_difference,
    SUM(points_earned) AS points_earned,

    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE club_result = 'Win'
        )
        / NULLIF(COUNT(DISTINCT game_id), 0),
        2
    ) AS win_percentage,

    ROUND(
        SUM(own_goals)::NUMERIC
        / NULLIF(COUNT(DISTINCT game_id), 0),
        2
    ) AS goals_scored_per_match,

    ROUND(
        SUM(opponent_goals)::NUMERIC
        / NULLIF(COUNT(DISTINCT game_id), 0),
        2
    ) AS goals_conceded_per_match,

    ROUND(
        SUM(points_earned)::NUMERIC
        / NULLIF(COUNT(DISTINCT game_id), 0),
        2
    ) AS points_per_match,

    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE (
                hosting = 'Home'
                OR LOWER(hosting) = 'home'
            )
              AND club_result = 'Win'
        )
        / NULLIF(
            COUNT(*) FILTER (
                WHERE hosting = 'Home'
                   OR LOWER(hosting) = 'home'
            ),
            0
        ),
        2
    ) AS home_win_percentage,

    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE (
                hosting = 'Away'
                OR LOWER(hosting) = 'away'
            )
              AND club_result = 'Win'
        )
        / NULLIF(
            COUNT(*) FILTER (
                WHERE hosting = 'Away'
                   OR LOWER(hosting) = 'away'
            ),
            0
        ),
        2
    ) AS away_win_percentage

FROM football.vw_core_club_matches
GROUP BY
    competition_id,
    competition_name,
    country_name,
    season,
    season_label,
    club_id,
    club_name;

--Verify one row per club-season

SELECT
    competition_id,
    season,
    COUNT(*) AS club_count,
    MIN(matches_played) AS minimum_matches,
    MAX(matches_played) AS maximum_matches
FROM football.vw_club_season_performance
GROUP BY
    competition_id,
    season
ORDER BY
    competition_id,
    season;

-- ------------------------------------------------------------
-- 7. CREATE CORE APPEARANCE VIEW
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.vw_core_appearances AS

SELECT
    a.appearance_id,
    a.game_id,
    a.player_id,
    a.player_club_id,
    a.player_current_club_id,
    a.appearance_date,
    a.player_name,
    a.competition_id,
    a.yellow_cards,
    a.red_cards,
    a.goals,
    a.assists,
    a.minutes_played_raw,
    a.minutes_played,
    a.has_invalid_minutes,

    g.competition_name,
    g.country_name,
    g.season,
    g.season_label,
    g.game_date,
    g.season_end_date,
    g.home_club_id,
    g.away_club_id,
    g.home_club_name,
    g.away_club_name

FROM football.clean_appearances AS a
JOIN football.vw_core_games AS g
    ON a.game_id = g.game_id;

--Verify

SELECT
    COUNT(*) AS core_appearance_rows,
    COUNT(*) FILTER (
        WHERE has_invalid_minutes = TRUE
    ) AS invalid_minute_rows
FROM football.vw_core_appearances;

-- ------------------------------------------------------------
-- 8. CREATE CORE PLAYER POPULATION VIEW
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.vw_core_players AS

SELECT DISTINCT
    p.player_id,
    p.first_name,
    p.last_name,
    p.player_name,
    p.date_of_birth,
    p.position,
    p.sub_position,
    p.preferred_foot,
    p.height_in_cm,
    p.country_of_birth,
    p.country_of_citizenship,
    p.current_club_id,
    p.current_club_name,
    p.current_market_value_in_eur,
    p.highest_market_value_in_eur,
    p.has_invalid_height

FROM football.clean_players AS p
JOIN football.vw_core_appearances AS a
    ON p.player_id = a.player_id;

--Verify 

SELECT
    COUNT(*) AS core_player_count
FROM football.vw_core_players;

-- ------------------------------------------------------------
-- 9. CREATE PLAYER-SEASON PERFORMANCE VIEW
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.vw_player_season_performance AS

SELECT
    a.player_id,
    p.player_name,
    p.position,
    p.sub_position,
    p.preferred_foot,
    p.country_of_citizenship,
    p.date_of_birth,

    a.player_club_id AS club_id,

    COALESCE(
        MAX(
            CASE
                WHEN a.player_club_id = a.home_club_id
                    THEN a.home_club_name
                WHEN a.player_club_id = a.away_club_id
                    THEN a.away_club_name
                ELSE NULL
            END
        ),
        MAX(p.current_club_name)
    ) AS club_name,

    a.competition_id,
    a.competition_name,
    a.country_name,
    a.season,
    a.season_label,
    MAX(a.season_end_date) AS season_end_date,

    CASE
        WHEN p.date_of_birth IS NULL
            THEN NULL
        ELSE EXTRACT(
            YEAR FROM AGE(
                MAX(a.season_end_date),
                p.date_of_birth
            )
        )::INTEGER
    END AS age_at_season_end,

    COUNT(DISTINCT a.game_id) AS appearances,

    COUNT(DISTINCT a.game_id) FILTER (
        WHERE a.minutes_played > 0
    ) AS appearances_with_minutes,

    SUM(a.minutes_played) AS minutes_played,
    SUM(a.goals) AS goals,
    SUM(a.assists) AS assists,

    SUM(a.goals)
        + SUM(a.assists) AS goal_contributions,

    SUM(a.yellow_cards) AS yellow_cards,
    SUM(a.red_cards) AS red_cards,

    ROUND(
        90.0 * SUM(a.goals)
        / NULLIF(SUM(a.minutes_played), 0),
        3
    ) AS goals_per_90,

    ROUND(
        90.0 * SUM(a.assists)
        / NULLIF(SUM(a.minutes_played), 0),
        3
    ) AS assists_per_90,

    ROUND(
        90.0
        * (
            SUM(a.goals)
            + SUM(a.assists)
        )
        / NULLIF(SUM(a.minutes_played), 0),
        3
    ) AS goal_contributions_per_90,

    ROUND(
        90.0 * SUM(a.yellow_cards)
        / NULLIF(SUM(a.minutes_played), 0),
        3
    ) AS yellow_cards_per_90,

    ROUND(
        90.0 * SUM(a.red_cards)
        / NULLIF(SUM(a.minutes_played), 0),
        3
    ) AS red_cards_per_90,

    CASE
        WHEN SUM(a.minutes_played) >= 1800
            THEN 'High minutes'
        WHEN SUM(a.minutes_played) >= 900
            THEN 'Qualified'
        WHEN SUM(a.minutes_played) > 0
            THEN 'Limited minutes'
        ELSE 'No valid minutes'
    END AS minutes_eligibility

FROM football.vw_core_appearances AS a
JOIN football.vw_core_players AS p
    ON a.player_id = p.player_id
GROUP BY
    a.player_id,
    p.player_name,
    p.position,
    p.sub_position,
    p.preferred_foot,
    p.country_of_citizenship,
    p.date_of_birth,
    a.player_club_id,
    a.competition_id,
    a.competition_name,
    a.country_name,
    a.season,
    a.season_label;

-- ------------------------------------------------------------
-- 9.1 VERIFY PLAYER-SEASON PERFORMANCE
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS player_club_season_rows,
    COUNT(DISTINCT player_id) AS distinct_players,
    COUNT(*) FILTER (
        WHERE minutes_eligibility IN (
            'Qualified',
            'High minutes'
        )
    ) AS qualified_player_seasons
FROM football.vw_player_season_performance;

SELECT
    player_name,
    club_name,
    competition_name,
    season_label,
    position,
    appearances,
    minutes_played,
    goals,
    assists
FROM football.vw_player_season_performance
ORDER BY minutes_played DESC
LIMIT 20;

-- ------------------------------------------------------------
-- 10. MATCH PLAYER-SEASONS TO LATEST AVAILABLE VALUATIONS
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.vw_player_season_valuations AS

SELECT
    ps.player_id,
    ps.club_id,
    ps.club_name,
    ps.competition_id,
    ps.competition_name,
    ps.season,
    ps.season_label,
    ps.season_end_date,
    ps.age_at_season_end,
    ps.position,
    ps.sub_position,
    ps.minutes_played,
    ps.goals,
    ps.assists,
    ps.goal_contributions,
    ps.goals_per_90,
    ps.assists_per_90,
    ps.goal_contributions_per_90,
    ps.minutes_eligibility,

    valuation.valuation_date,
    valuation.market_value_in_eur,

    ps.season_end_date
        - valuation.valuation_date
        AS valuation_age_days,

    CASE
        WHEN valuation.valuation_date IS NULL
            THEN 'No valuation'
        WHEN ps.season_end_date
             - valuation.valuation_date <= 90
            THEN 'Within 90 days'
        WHEN ps.season_end_date
             - valuation.valuation_date <= 180
            THEN 'Within 180 days'
        ELSE 'Older than 180 days'
    END AS valuation_recency_status

FROM football.vw_player_season_performance AS ps

LEFT JOIN LATERAL (

    SELECT
        pv.valuation_date,
        pv.market_value_in_eur
    FROM football.clean_player_valuations AS pv
    WHERE pv.player_id = ps.player_id
      AND pv.valuation_date <= ps.season_end_date
      AND pv.market_value_in_eur IS NOT NULL
    ORDER BY pv.valuation_date DESC
    LIMIT 1

) AS valuation
    ON TRUE;

--Verify valuation matching

SELECT
    valuation_recency_status,
    COUNT(*) AS player_season_count
FROM football.vw_player_season_valuations
GROUP BY valuation_recency_status
ORDER BY player_season_count DESC;

-- ------------------------------------------------------------
-- 11. CREATE CORE TRANSFER VIEW
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.vw_core_transfers AS

SELECT
    t.transfer_id,
    t.player_id,
    p.player_name,
    p.position,
    p.sub_position,
    p.date_of_birth,
    p.country_of_citizenship,

    t.transfer_date,
    t.transfer_season,
    t.from_club_id,
    t.from_club_name,
    t.to_club_id,
    t.to_club_name,
    t.transfer_fee,
    t.transfer_fee_status,
    t.market_value_in_eur,
    t.is_future_transfer,
    t.has_same_origin_destination,

    CASE
        WHEN p.date_of_birth IS NULL
          OR t.transfer_date IS NULL
            THEN NULL
        ELSE EXTRACT(
            YEAR FROM AGE(
                t.transfer_date,
                p.date_of_birth
            )
        )::INTEGER
    END AS age_at_transfer

FROM football.clean_transfers AS t
JOIN football.vw_core_players AS p
    ON t.player_id = p.player_id
WHERE t.transfer_date BETWEEN
      DATE '2020-07-01'
      AND DATE '2025-06-30';

--Verify 

SELECT
    COUNT(*) AS scoped_transfer_count,
    COUNT(DISTINCT player_id) AS transferred_players,
    COUNT(*) FILTER (
        WHERE transfer_fee_status = 'Positive known fee'
    ) AS positive_fee_transfers,
    COUNT(*) FILTER (
        WHERE transfer_fee_status =
              'Missing or undisclosed fee'
    ) AS missing_fee_transfers
FROM football.vw_core_transfers;

-- ------------------------------------------------------------
-- 12. CREATE PROJECT-SCOPE SUMMARY VIEW
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW football.vw_project_scope_summary AS

SELECT
    'Core competitions' AS metric,
    COUNT(*)::BIGINT AS metric_value
FROM football.vw_core_competitions

UNION ALL

SELECT
    'Core games',
    COUNT(*)
FROM football.vw_core_games

UNION ALL

SELECT
    'Core club-match rows',
    COUNT(*)
FROM football.vw_core_club_matches

UNION ALL

SELECT
    'Core appearance rows',
    COUNT(*)
FROM football.vw_core_appearances

UNION ALL

SELECT
    'Core players',
    COUNT(*)
FROM football.vw_core_players

UNION ALL

SELECT
    'Player-club-season rows',
    COUNT(*)
FROM football.vw_player_season_performance

UNION ALL

SELECT
    'Core transfers',
    COUNT(*)
FROM football.vw_core_transfers;

SELECT *
FROM football.vw_project_scope_summary;

-- ------------------------------------------------------------
-- 13. VERIFY PROJECT-SPECIFIC VIEWS
-- ------------------------------------------------------------

SELECT
    table_schema,
    table_name
FROM information_schema.views
WHERE table_schema = 'football'
  AND table_name IN (
      'vw_core_competitions',
      'vw_core_games',
      'vw_core_club_matches',
      'vw_club_season_performance',
      'vw_core_appearances',
      'vw_core_players',
      'vw_player_season_performance',
      'vw_player_season_valuations',
      'vw_core_transfers',
      'vw_project_scope_summary'
  )
ORDER BY table_name;

-- ============================================================
-- VIEW AND INDEX SUMMARY
--
-- INDEXES CREATED:
--   1. Games by competition and season
--   2. Appearances by game
--   3. Appearances by player
--   4. Appearances by historical club
--   5. Appearances by competition
--   6. Transfers by player and date
--   7. Transfers by source club
--   8. Transfers by destination club
--   9. Clubs by domestic competition
--
-- CORE SCOPE:
--   Competitions: GB1, ES1, L1, IT1, FR1
--   Seasons: 2020 to 2024
--
-- ANALYTICAL VIEWS CREATED:
--   1. Core competition definitions
--   2. Core games
--   3. Club-perspective match records
--   4. Club-season performance
--   5. Core appearances
--   6. Core player population
--   7. Player-season performance
--   8. Player-season valuations
--   9. Core transfers
--  10. Project scope summary
--
-- Raw source tables remain unchanged.
-- ============================================================


-- ============================================================
-- END OF FILE
-- Next script: 06_club_league_performance.sql
-- ============================================================