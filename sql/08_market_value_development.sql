-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 08_market_value_development.sql
-- THEME: Market Value and Player Development
--
-- BUSINESS OBJECTIVE:
--   Understand player-value development, positional differences
--   and clubs' ability to develop valuable talent.
--
-- QUESTIONS:
--   1. Largest absolute increase in market value
--   2. Largest percentage increase in market value
--   3. Strongest under-23 market-value growth
--   4. Clubs generating the greatest total value increase
--   5. Clubs developing the most high-growth players
--   6. Leagues containing the most valuable under-23 players
--   7. Median market value by position
--   8. Typical peak-value age by position
--   9. Value growth alongside sporting improvement
--  10. Value decline alongside reduced minutes or performance
--
-- DATABASE: eu_football_analytics
-- ANALYTICAL SCHEMA: football
-- RAW SCHEMA: football_raw
-- AUTHOR: Andy Nguyen
--
-- EXECUTION ORDER:
--   Run after 07a_theme_2_export_queries.sql
--
-- CORE SCOPE:
--   Competitions: GB1, ES1, L1, IT1, FR1
--   Seasons: 2020 to 2024
--   Valuation dates: 2020-07-01 to 2025-06-30
--
-- METHODOLOGICAL RULES:
--   - Absolute and percentage growth are reported separately.
--   - Percentage-growth rankings require a starting value of
--     at least EUR 1 million.
--   - Player-season analyses use the first and last recorded
--     valuation within each season.
--   - Club development analysis excludes transferred players
--     when club attribution would be ambiguous.
--   - Under 23 means age 22 or younger at season end.
--   - Median values are used for positional comparisons.
--   - Performance comparisons require at least 900 minutes in
--     both consecutive seasons.
--
-- IMPORTANT:
--   This file performs analysis only.
--   It does not alter raw or cleaned source data.
-- ============================================================


-- ------------------------------------------------------------
-- 1. CONNECTION AND SCHEMA CHECK
-- ------------------------------------------------------------

SELECT
    current_database() AS database_name,
    current_user AS database_user,
    CURRENT_TIMESTAMP AS analysis_timestamp;

SET search_path TO football, football_raw, public;

SHOW search_path;

-- ============================================================
-- QUESTION 1
-- Which players recorded the largest absolute increase in
-- market value?
--
-- GRAIN:
--   One player across the complete project period.
-- ============================================================

WITH valuation_window AS (

    SELECT
        pv.player_id,
        pv.date AS valuation_date,
        pv.market_value_in_eur,
        pv.current_club_id,
        pv.current_club_name,
        pv.player_club_domestic_competition_id

    FROM football_raw.player_valuations AS pv

    WHERE pv.date >= DATE '2020-07-01'
      AND pv.date <  DATE '2025-07-01'
      AND pv.market_value_in_eur IS NOT NULL
      AND pv.market_value_in_eur >= 0
),

first_valuation AS (

    SELECT DISTINCT ON (player_id)
        player_id,
        valuation_date AS first_valuation_date,
        market_value_in_eur AS starting_market_value_eur

    FROM valuation_window

    ORDER BY
        player_id,
        valuation_date ASC
),

last_valuation AS (

    SELECT DISTINCT ON (player_id)
        player_id,
        valuation_date AS last_valuation_date,
        market_value_in_eur AS ending_market_value_eur,
        current_club_id AS latest_recorded_club_id,
        current_club_name AS latest_recorded_club_name,
        player_club_domestic_competition_id
            AS latest_recorded_competition_id

    FROM valuation_window

    ORDER BY
        player_id,
        valuation_date DESC
),

player_profiles AS (

    SELECT
        player_id,
        MAX(player_name) AS player_name,
        MODE() WITHIN GROUP (
            ORDER BY position
        ) AS position,
        MODE() WITHIN GROUP (
            ORDER BY sub_position
        ) AS sub_position,
        MAX(country_of_citizenship) AS country_of_citizenship,
        MAX(date_of_birth) AS date_of_birth

    FROM football.vw_player_season_performance

    GROUP BY player_id
),

valuation_changes AS (

    SELECT
        f.player_id,
        pp.player_name,
        pp.position,
        pp.sub_position,
        pp.country_of_citizenship,
        pp.date_of_birth,

        f.first_valuation_date,
        l.last_valuation_date,

        f.starting_market_value_eur,
        l.ending_market_value_eur,

        l.latest_recorded_club_id,
        l.latest_recorded_club_name,
        l.latest_recorded_competition_id,

        l.ending_market_value_eur
            - f.starting_market_value_eur
            AS absolute_market_value_change_eur,

        ROUND(
            (
                100.0
                * (
                    l.ending_market_value_eur
                    - f.starting_market_value_eur
                )
                / NULLIF(f.starting_market_value_eur, 0)
            )::NUMERIC,
            2
        ) AS market_value_percentage_change

    FROM first_valuation AS f

    JOIN last_valuation AS l
        ON f.player_id = l.player_id

    LEFT JOIN player_profiles AS pp
        ON f.player_id = pp.player_id

    WHERE l.last_valuation_date > f.first_valuation_date
)

SELECT
    player_id,
    player_name,
    position,
    sub_position,
    country_of_citizenship,
    date_of_birth,
    first_valuation_date,
    last_valuation_date,
    starting_market_value_eur,
    ending_market_value_eur,
    absolute_market_value_change_eur,
    market_value_percentage_change,
    latest_recorded_club_name,
    latest_recorded_competition_id,

    DENSE_RANK() OVER (
        ORDER BY
            absolute_market_value_change_eur DESC,
            ending_market_value_eur DESC
    ) AS absolute_growth_rank

FROM valuation_changes

ORDER BY
    absolute_growth_rank,
    player_name;

-- ============================================================
-- QUESTION 2
-- Which players recorded the largest percentage increase in
-- market value?
--
-- LOW-BASE CONTROL:
--   Starting market value must be at least EUR 1 million.
--
-- PROFILE HANDLING:
--   Player details are taken from football_raw.players first,
--   with the analytical player-season view used as a fallback.
--   Records without an identifiable player name are excluded
--   from the final business-facing ranking.
-- ============================================================

WITH valuation_window AS (

    SELECT
        pv.player_id,
        pv.date AS valuation_date,
        pv.market_value_in_eur,
        pv.current_club_id,
        pv.current_club_name,
        pv.player_club_domestic_competition_id

    FROM football_raw.player_valuations AS pv

    WHERE pv.date >= DATE '2020-07-01'
      AND pv.date <  DATE '2025-07-01'
      AND pv.market_value_in_eur IS NOT NULL
      AND pv.market_value_in_eur >= 0
),

first_valuation AS (

    SELECT DISTINCT ON (player_id)
        player_id,
        valuation_date AS first_valuation_date,
        market_value_in_eur AS starting_market_value_eur

    FROM valuation_window

    ORDER BY
        player_id,
        valuation_date ASC
),

last_valuation AS (

    SELECT DISTINCT ON (player_id)
        player_id,
        valuation_date AS last_valuation_date,
        market_value_in_eur AS ending_market_value_eur,
        current_club_id AS latest_recorded_club_id,
        current_club_name AS latest_recorded_club_name,
        player_club_domestic_competition_id
            AS latest_recorded_competition_id

    FROM valuation_window

    ORDER BY
        player_id,
        valuation_date DESC
),

analytical_profiles AS (

    SELECT
        player_id,
        MAX(player_name) AS player_name,

        MODE() WITHIN GROUP (
            ORDER BY position
        ) AS position,

        MODE() WITHIN GROUP (
            ORDER BY sub_position
        ) AS sub_position,

        MAX(country_of_citizenship)
            AS country_of_citizenship,

        MAX(date_of_birth) AS date_of_birth

    FROM football.vw_player_season_performance

    GROUP BY player_id
),

player_profiles AS (

    SELECT
        v.player_id,

        COALESCE(
            rp.name,
            ap.player_name
        ) AS player_name,

        COALESCE(
            rp.position,
            ap.position
        ) AS position,

        COALESCE(
            rp.sub_position,
            ap.sub_position
        ) AS sub_position,

        COALESCE(
            rp.country_of_citizenship,
            ap.country_of_citizenship
        ) AS country_of_citizenship,

        COALESCE(
            rp.date_of_birth,
            ap.date_of_birth
        ) AS date_of_birth

    FROM (
        SELECT DISTINCT player_id
        FROM valuation_window
    ) AS v

    LEFT JOIN football_raw.players AS rp
        ON v.player_id = rp.player_id

    LEFT JOIN analytical_profiles AS ap
        ON v.player_id = ap.player_id
),

eligible_changes AS (

    SELECT
        f.player_id,
        pp.player_name,
        pp.position,
        pp.sub_position,
        pp.country_of_citizenship,
        pp.date_of_birth,

        f.first_valuation_date,
        l.last_valuation_date,

        f.starting_market_value_eur,
        l.ending_market_value_eur,

        l.ending_market_value_eur
            - f.starting_market_value_eur
            AS absolute_market_value_change_eur,

        ROUND(
            (
                100.0
                * (
                    l.ending_market_value_eur
                    - f.starting_market_value_eur
                )
                / NULLIF(f.starting_market_value_eur, 0)
            )::NUMERIC,
            2
        ) AS market_value_percentage_change,

        l.latest_recorded_club_id,
        l.latest_recorded_club_name,
        l.latest_recorded_competition_id

    FROM first_valuation AS f

    JOIN last_valuation AS l
        ON f.player_id = l.player_id

    LEFT JOIN player_profiles AS pp
        ON f.player_id = pp.player_id

    WHERE f.starting_market_value_eur >= 1000000
      AND l.last_valuation_date > f.first_valuation_date
      AND pp.player_name IS NOT NULL
)

SELECT
    player_id,
    player_name,
    position,
    sub_position,
    country_of_citizenship,
    date_of_birth,
    first_valuation_date,
    last_valuation_date,
    starting_market_value_eur,
    ending_market_value_eur,
    absolute_market_value_change_eur,
    market_value_percentage_change,
    latest_recorded_club_id,
    latest_recorded_club_name,
    latest_recorded_competition_id,

    DENSE_RANK() OVER (
        ORDER BY
            market_value_percentage_change DESC,
            absolute_market_value_change_eur DESC,
            ending_market_value_eur DESC
    ) AS percentage_growth_rank

FROM eligible_changes

ORDER BY
    percentage_growth_rank,
    player_name;

-- ============================================================
-- QUESTION 3
-- Which under-23 players experienced the strongest
-- market-value growth?
--
-- ELIGIBILITY:
--   - Age at season end <= 22
--   - At least 900 league minutes
--   - Starting value >= EUR 1 million for percentage ranking
-- ============================================================

WITH valuation_seasons AS (

    SELECT
        pv.player_id,
        pv.date AS valuation_date,
        pv.market_value_in_eur,

        CASE
            WHEN EXTRACT(MONTH FROM pv.date) >= 7
                THEN EXTRACT(YEAR FROM pv.date)::INTEGER
            ELSE EXTRACT(YEAR FROM pv.date)::INTEGER - 1
        END AS season

    FROM football_raw.player_valuations AS pv

    WHERE pv.date >= DATE '2020-07-01'
      AND pv.date <  DATE '2025-07-01'
      AND pv.market_value_in_eur IS NOT NULL
      AND pv.market_value_in_eur >= 0
),

first_season_valuation AS (

    SELECT DISTINCT ON (player_id, season)
        player_id,
        season,
        valuation_date AS first_valuation_date,
        market_value_in_eur AS starting_market_value_eur

    FROM valuation_seasons

    WHERE season BETWEEN 2020 AND 2024

    ORDER BY
        player_id,
        season,
        valuation_date ASC
),

last_season_valuation AS (

    SELECT DISTINCT ON (player_id, season)
        player_id,
        season,
        valuation_date AS last_valuation_date,
        market_value_in_eur AS ending_market_value_eur

    FROM valuation_seasons

    WHERE season BETWEEN 2020 AND 2024

    ORDER BY
        player_id,
        season,
        valuation_date DESC
),

player_season_totals AS (

    SELECT
        player_id,
        season,
        MAX(player_name) AS player_name,
        MAX(position) AS position,
        MAX(sub_position) AS sub_position,
        MAX(country_of_citizenship) AS country_of_citizenship,
        MAX(season_label) AS season_label,
        MAX(age_at_season_end) AS age_at_season_end,

        COUNT(DISTINCT club_id) AS clubs_represented,

        STRING_AGG(
            DISTINCT club_name,
            ', '
            ORDER BY club_name
        ) AS clubs,

        STRING_AGG(
            DISTINCT competition_name,
            ', '
            ORDER BY competition_name
        ) AS competitions,

        SUM(appearances) AS appearances,
        SUM(minutes_played) AS minutes_played,
        SUM(goals) AS goals,
        SUM(assists) AS assists,
        SUM(goal_contributions) AS goal_contributions

    FROM football.vw_player_season_performance

    GROUP BY
        player_id,
        season
),

under_23_growth AS (

    SELECT
        ps.player_id,
        ps.player_name,
        ps.position,
        ps.sub_position,
        ps.country_of_citizenship,
        ps.season,
        ps.season_label,
        ps.age_at_season_end,
        ps.clubs_represented,
        ps.clubs,
        ps.competitions,
        ps.appearances,
        ps.minutes_played,
        ps.goals,
        ps.assists,
        ps.goal_contributions,

        f.first_valuation_date,
        l.last_valuation_date,
        f.starting_market_value_eur,
        l.ending_market_value_eur,

        l.ending_market_value_eur
            - f.starting_market_value_eur
            AS absolute_market_value_change_eur,

        ROUND(
            (
                100.0
                * (
                    l.ending_market_value_eur
                    - f.starting_market_value_eur
                )
                / NULLIF(f.starting_market_value_eur, 0)
            )::NUMERIC,
            2
        ) AS market_value_percentage_change

    FROM player_season_totals AS ps

    JOIN first_season_valuation AS f
        ON ps.player_id = f.player_id
       AND ps.season = f.season

    JOIN last_season_valuation AS l
        ON ps.player_id = l.player_id
       AND ps.season = l.season

    WHERE ps.age_at_season_end <= 22
      AND ps.minutes_played >= 900
      AND l.last_valuation_date > f.first_valuation_date
)

SELECT
    *,

    DENSE_RANK() OVER (
        PARTITION BY season
        ORDER BY
            absolute_market_value_change_eur DESC,
            ending_market_value_eur DESC
    ) AS under_23_absolute_growth_season_rank,

    DENSE_RANK() OVER (
        PARTITION BY season
        ORDER BY
            CASE
                WHEN starting_market_value_eur >= 1000000
                    THEN market_value_percentage_change
                ELSE NULL
            END DESC NULLS LAST,
            absolute_market_value_change_eur DESC
    ) AS under_23_percentage_growth_season_rank,

    DENSE_RANK() OVER (
        ORDER BY
            absolute_market_value_change_eur DESC,
            ending_market_value_eur DESC
    ) AS under_23_absolute_growth_overall_rank

FROM under_23_growth

ORDER BY
    under_23_absolute_growth_overall_rank,
    player_name;

-- ============================================================
-- QUESTION 4
-- Which clubs generated the greatest total increase in player
-- market value?
--
-- CLUB ATTRIBUTION:
--   Only player-seasons involving one club are included.
--
-- OUTPUTS:
--   - Net market-value change
--   - Gross positive growth
--   - Gross decline
-- ============================================================

WITH valuation_seasons AS (

    SELECT
        pv.player_id,
        pv.date AS valuation_date,
        pv.market_value_in_eur,

        CASE
            WHEN EXTRACT(MONTH FROM pv.date) >= 7
                THEN EXTRACT(YEAR FROM pv.date)::INTEGER
            ELSE EXTRACT(YEAR FROM pv.date)::INTEGER - 1
        END AS season

    FROM football_raw.player_valuations AS pv

    WHERE pv.date >= DATE '2020-07-01'
      AND pv.date <  DATE '2025-07-01'
      AND pv.market_value_in_eur IS NOT NULL
      AND pv.market_value_in_eur >= 0
),

first_values AS (

    SELECT DISTINCT ON (player_id, season)
        player_id,
        season,
        market_value_in_eur AS starting_market_value_eur

    FROM valuation_seasons

    WHERE season BETWEEN 2020 AND 2024

    ORDER BY
        player_id,
        season,
        valuation_date ASC
),

last_values AS (

    SELECT DISTINCT ON (player_id, season)
        player_id,
        season,
        market_value_in_eur AS ending_market_value_eur

    FROM valuation_seasons

    WHERE season BETWEEN 2020 AND 2024

    ORDER BY
        player_id,
        season,
        valuation_date DESC
),

player_club_seasons AS (

    SELECT
        player_id,
        season,
        COUNT(DISTINCT club_id) AS clubs_represented,
        MAX(club_id) AS club_id,
        MAX(club_name) AS club_name,
        MAX(competition_id) AS competition_id,
        MAX(competition_name) AS competition_name,
        MAX(country_name) AS country_name,
        SUM(minutes_played) AS minutes_played

    FROM football.vw_player_season_performance

    GROUP BY
        player_id,
        season
),

single_club_growth AS (

    SELECT
        pcs.player_id,
        pcs.season,
        pcs.club_id,
        pcs.club_name,
        pcs.competition_id,
        pcs.competition_name,
        pcs.country_name,
        pcs.minutes_played,
        f.starting_market_value_eur,
        l.ending_market_value_eur,

        l.ending_market_value_eur
            - f.starting_market_value_eur
            AS market_value_change_eur

    FROM player_club_seasons AS pcs

    JOIN first_values AS f
        ON pcs.player_id = f.player_id
       AND pcs.season = f.season

    JOIN last_values AS l
        ON pcs.player_id = l.player_id
       AND pcs.season = l.season

    WHERE pcs.clubs_represented = 1
      AND pcs.club_id IS NOT NULL
),

club_growth_summary AS (

    SELECT
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name,

        COUNT(DISTINCT player_id) AS valued_players,
        COUNT(*) AS player_season_records,

        SUM(market_value_change_eur)
            AS net_market_value_change_eur,

        SUM(
            CASE
                WHEN market_value_change_eur > 0
                    THEN market_value_change_eur
                ELSE 0
            END
        ) AS gross_positive_growth_eur,

        ABS(
            SUM(
                CASE
                    WHEN market_value_change_eur < 0
                        THEN market_value_change_eur
                    ELSE 0
                END
            )
        ) AS gross_market_value_decline_eur,

        ROUND(
            PERCENTILE_CONT(0.5) WITHIN GROUP (
                ORDER BY market_value_change_eur
            )::NUMERIC,
            2
        ) AS median_player_value_change_eur

    FROM single_club_growth

    GROUP BY
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name
)

SELECT
    *,

    DENSE_RANK() OVER (
        ORDER BY
            net_market_value_change_eur DESC,
            gross_positive_growth_eur DESC
    ) AS club_net_growth_rank,

    DENSE_RANK() OVER (
        ORDER BY
            gross_positive_growth_eur DESC,
            net_market_value_change_eur DESC
    ) AS club_gross_growth_rank

FROM club_growth_summary

ORDER BY
    club_net_growth_rank,
    club_name;

-- ============================================================
-- QUESTION 5
-- Which clubs developed the largest number of high-growth
-- players?
--
-- HIGH-GROWTH DEFINITION:
--   Starting value >= EUR 1 million
--   Absolute growth >= EUR 10 million
--   Percentage growth >= 50%
--
-- CLUB ATTRIBUTION:
--   Single-club player-seasons only.
-- ============================================================

WITH valuation_seasons AS (

    SELECT
        pv.player_id,
        pv.date AS valuation_date,
        pv.market_value_in_eur,

        CASE
            WHEN EXTRACT(MONTH FROM pv.date) >= 7
                THEN EXTRACT(YEAR FROM pv.date)::INTEGER
            ELSE EXTRACT(YEAR FROM pv.date)::INTEGER - 1
        END AS season

    FROM football_raw.player_valuations AS pv

    WHERE pv.date >= DATE '2020-07-01'
      AND pv.date <  DATE '2025-07-01'
      AND pv.market_value_in_eur IS NOT NULL
      AND pv.market_value_in_eur >= 0
),

first_values AS (

    SELECT DISTINCT ON (player_id, season)
        player_id,
        season,
        market_value_in_eur AS starting_market_value_eur

    FROM valuation_seasons

    WHERE season BETWEEN 2020 AND 2024

    ORDER BY
        player_id,
        season,
        valuation_date ASC
),

last_values AS (

    SELECT DISTINCT ON (player_id, season)
        player_id,
        season,
        market_value_in_eur AS ending_market_value_eur

    FROM valuation_seasons

    WHERE season BETWEEN 2020 AND 2024

    ORDER BY
        player_id,
        season,
        valuation_date DESC
),

player_club_seasons AS (

    SELECT
        player_id,
        season,
        MAX(player_name) AS player_name,
        COUNT(DISTINCT club_id) AS clubs_represented,
        MAX(club_id) AS club_id,
        MAX(club_name) AS club_name,
        MAX(competition_id) AS competition_id,
        MAX(competition_name) AS competition_name,
        MAX(country_name) AS country_name,
        SUM(minutes_played) AS minutes_played

    FROM football.vw_player_season_performance

    GROUP BY
        player_id,
        season
),

eligible_growth AS (

    SELECT
        pcs.player_id,
        pcs.player_name,
        pcs.season,
        pcs.club_id,
        pcs.club_name,
        pcs.competition_id,
        pcs.competition_name,
        pcs.country_name,
        pcs.minutes_played,
        f.starting_market_value_eur,
        l.ending_market_value_eur,

        l.ending_market_value_eur
            - f.starting_market_value_eur
            AS absolute_market_value_change_eur,

        ROUND(
            (
                100.0
                * (
                    l.ending_market_value_eur
                    - f.starting_market_value_eur
                )
                / NULLIF(f.starting_market_value_eur, 0)
            )::NUMERIC,
            2
        ) AS market_value_percentage_change

    FROM player_club_seasons AS pcs

    JOIN first_values AS f
        ON pcs.player_id = f.player_id
       AND pcs.season = f.season

    JOIN last_values AS l
        ON pcs.player_id = l.player_id
       AND pcs.season = l.season

    WHERE pcs.clubs_represented = 1
      AND pcs.club_id IS NOT NULL
      AND f.starting_market_value_eur >= 1000000
),

high_growth_players AS (

    SELECT *
    FROM eligible_growth

    WHERE absolute_market_value_change_eur >= 10000000
      AND market_value_percentage_change >= 50
)

SELECT
    club_id,
    club_name,
    competition_id,
    competition_name,
    country_name,

    COUNT(*) AS high_growth_player_seasons,
    COUNT(DISTINCT player_id) AS distinct_high_growth_players,

    SUM(absolute_market_value_change_eur)
        AS total_high_growth_value_created_eur,

    ROUND(
        AVG(absolute_market_value_change_eur)::NUMERIC,
        2
    ) AS average_high_growth_value_created_eur,

    DENSE_RANK() OVER (
        ORDER BY
            COUNT(DISTINCT player_id) DESC,
            SUM(absolute_market_value_change_eur) DESC
    ) AS high_growth_player_development_rank

FROM high_growth_players

GROUP BY
    club_id,
    club_name,
    competition_id,
    competition_name,
    country_name

ORDER BY
    high_growth_player_development_rank,
    club_name;

-- ============================================================
-- QUESTION 6
-- Which leagues contained the most valuable under-23 players?
--
-- MEASURES:
--   - Total end-of-season U23 market value
--   - Median U23 market value
--   - Number of U23 players valued at EUR 20 million or more
-- ============================================================

WITH valuation_seasons AS (

    SELECT
        pv.player_id,
        pv.date AS valuation_date,
        pv.market_value_in_eur,

        CASE
            WHEN EXTRACT(MONTH FROM pv.date) >= 7
                THEN EXTRACT(YEAR FROM pv.date)::INTEGER
            ELSE EXTRACT(YEAR FROM pv.date)::INTEGER - 1
        END AS season

    FROM football_raw.player_valuations AS pv

    WHERE pv.date >= DATE '2020-07-01'
      AND pv.date <  DATE '2025-07-01'
      AND pv.market_value_in_eur IS NOT NULL
      AND pv.market_value_in_eur >= 0
),

last_values AS (

    SELECT DISTINCT ON (player_id, season)
        player_id,
        season,
        valuation_date AS ending_valuation_date,
        market_value_in_eur AS ending_market_value_eur

    FROM valuation_seasons

    WHERE season BETWEEN 2020 AND 2024

    ORDER BY
        player_id,
        season,
        valuation_date DESC
),

player_league_seasons AS (

    SELECT
        player_id,
        season,
        MAX(player_name) AS player_name,
        MAX(position) AS position,
        MAX(age_at_season_end) AS age_at_season_end,

        COUNT(DISTINCT competition_id)
            AS competitions_represented,

        MAX(competition_id) AS competition_id,
        MAX(competition_name) AS competition_name,
        MAX(country_name) AS country_name,

        SUM(minutes_played) AS minutes_played

    FROM football.vw_player_season_performance

    GROUP BY
        player_id,
        season
),

under_23_values AS (

    SELECT
        ps.*,
        lv.ending_valuation_date,
        lv.ending_market_value_eur

    FROM player_league_seasons AS ps

    JOIN last_values AS lv
        ON ps.player_id = lv.player_id
       AND ps.season = lv.season

    WHERE ps.age_at_season_end <= 22
      AND ps.minutes_played >= 900
      AND ps.competitions_represented = 1
)

SELECT
    competition_id,
    competition_name,
    country_name,
    season,

    COUNT(*) AS qualified_under_23_players,

    SUM(ending_market_value_eur)
        AS total_under_23_market_value_eur,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY ending_market_value_eur
        )::NUMERIC,
        2
    ) AS median_under_23_market_value_eur,

    MAX(ending_market_value_eur)
        AS highest_under_23_market_value_eur,

    COUNT(*) FILTER (
        WHERE ending_market_value_eur >= 20000000
    ) AS under_23_players_above_20m,

    DENSE_RANK() OVER (
        PARTITION BY season
        ORDER BY
            SUM(ending_market_value_eur) DESC,
            PERCENTILE_CONT(0.5) WITHIN GROUP (
                ORDER BY ending_market_value_eur
            ) DESC
    ) AS league_under_23_value_rank

FROM under_23_values

GROUP BY
    competition_id,
    competition_name,
    country_name,
    season

ORDER BY
    season,
    league_under_23_value_rank;

-- ============================================================
-- QUESTION 7
-- What was the median market value by player position?
--
-- VALUE USED:
--   Last recorded valuation within each season.
--
-- ELIGIBILITY:
--   At least 900 league minutes.
-- ============================================================

WITH valuation_seasons AS (

    SELECT
        pv.player_id,
        pv.date AS valuation_date,
        pv.market_value_in_eur,

        CASE
            WHEN EXTRACT(MONTH FROM pv.date) >= 7
                THEN EXTRACT(YEAR FROM pv.date)::INTEGER
            ELSE EXTRACT(YEAR FROM pv.date)::INTEGER - 1
        END AS season

    FROM football_raw.player_valuations AS pv

    WHERE pv.date >= DATE '2020-07-01'
      AND pv.date <  DATE '2025-07-01'
      AND pv.market_value_in_eur IS NOT NULL
      AND pv.market_value_in_eur >= 0
),

last_values AS (

    SELECT DISTINCT ON (player_id, season)
        player_id,
        season,
        market_value_in_eur AS ending_market_value_eur

    FROM valuation_seasons

    WHERE season BETWEEN 2020 AND 2024

    ORDER BY
        player_id,
        season,
        valuation_date DESC
),

player_season_profiles AS (

    SELECT
        player_id,
        season,
        MAX(player_name) AS player_name,
        MAX(position) AS position,
        MAX(sub_position) AS sub_position,
        MAX(age_at_season_end) AS age_at_season_end,
        SUM(minutes_played) AS minutes_played

    FROM football.vw_player_season_performance

    GROUP BY
        player_id,
        season
)

SELECT
    ps.position,
    ps.season,

    COUNT(*) AS qualified_player_seasons,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY lv.ending_market_value_eur
        )::NUMERIC,
        2
    ) AS median_market_value_eur,

    ROUND(
        PERCENTILE_CONT(0.25) WITHIN GROUP (
            ORDER BY lv.ending_market_value_eur
        )::NUMERIC,
        2
    ) AS first_quartile_market_value_eur,

    ROUND(
        PERCENTILE_CONT(0.75) WITHIN GROUP (
            ORDER BY lv.ending_market_value_eur
        )::NUMERIC,
        2
    ) AS third_quartile_market_value_eur

FROM player_season_profiles AS ps

JOIN last_values AS lv
    ON ps.player_id = lv.player_id
   AND ps.season = lv.season

WHERE ps.minutes_played >= 900
  AND ps.position IS NOT NULL

GROUP BY
    ps.position,
    ps.season

ORDER BY
    ps.season,
    median_market_value_eur DESC;

-- ============================================================
-- QUESTION 8
-- At what ages did players in different positions tend to
-- reach their highest recorded market values?
--
-- ELIGIBILITY:
--   - Known date of birth
--   - At least three valuation observations
--   - Peak value of at least EUR 1 million
-- ============================================================

WITH player_profiles AS (

    SELECT
        player_id,
        MAX(player_name) AS player_name,
        MODE() WITHIN GROUP (
            ORDER BY position
        ) AS position,
        MODE() WITHIN GROUP (
            ORDER BY sub_position
        ) AS sub_position,
        MAX(date_of_birth) AS date_of_birth

    FROM football.vw_player_season_performance

    GROUP BY player_id
),

valuation_window AS (

    SELECT
        pv.player_id,
        pv.date AS valuation_date,
        pv.market_value_in_eur,

        COUNT(*) OVER (
            PARTITION BY pv.player_id
        ) AS valuation_observation_count,

        ROW_NUMBER() OVER (
            PARTITION BY pv.player_id
            ORDER BY
                pv.market_value_in_eur DESC,
                pv.date ASC
        ) AS peak_value_row_number

    FROM football_raw.player_valuations AS pv

    WHERE pv.date >= DATE '2020-07-01'
      AND pv.date <  DATE '2025-07-01'
      AND pv.market_value_in_eur IS NOT NULL
      AND pv.market_value_in_eur >= 0
),

player_peaks AS (

    SELECT
        vw.player_id,
        pp.player_name,
        pp.position,
        pp.sub_position,
        pp.date_of_birth,
        vw.valuation_date AS peak_valuation_date,
        vw.market_value_in_eur AS peak_market_value_eur,
        vw.valuation_observation_count,

        DATE_PART(
            'year',
            AGE(vw.valuation_date, pp.date_of_birth)
        )::INTEGER AS age_at_peak_value

    FROM valuation_window AS vw

    JOIN player_profiles AS pp
        ON vw.player_id = pp.player_id

    WHERE vw.peak_value_row_number = 1
      AND vw.valuation_observation_count >= 3
      AND vw.market_value_in_eur >= 1000000
      AND pp.date_of_birth IS NOT NULL
      AND pp.position IS NOT NULL
)

SELECT
    position,

    COUNT(*) AS players_with_eligible_peak_values,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY age_at_peak_value
        )::NUMERIC,
        1
    ) AS median_peak_value_age,

    ROUND(
        AVG(age_at_peak_value)::NUMERIC,
        1
    ) AS average_peak_value_age,

    MIN(age_at_peak_value) AS youngest_peak_value_age,
    MAX(age_at_peak_value) AS oldest_peak_value_age,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY peak_market_value_eur
        )::NUMERIC,
        2
    ) AS median_peak_market_value_eur

FROM player_peaks

WHERE age_at_peak_value BETWEEN 16 AND 40

GROUP BY position

ORDER BY
    median_peak_value_age,
    position;

-- ============================================================
-- QUESTION 9
-- Which players experienced strong market-value growth
-- alongside improving sporting performance?
--
-- ELIGIBILITY:
--   - Consecutive seasons
--   - At least 900 minutes in both seasons
--   - Outfield players only
--   - Previous end-of-season value >= EUR 1 million
-- ============================================================

WITH valuation_seasons AS (

    SELECT
        pv.player_id,
        pv.date AS valuation_date,
        pv.market_value_in_eur,

        CASE
            WHEN EXTRACT(MONTH FROM pv.date) >= 7
                THEN EXTRACT(YEAR FROM pv.date)::INTEGER
            ELSE EXTRACT(YEAR FROM pv.date)::INTEGER - 1
        END AS season

    FROM football_raw.player_valuations AS pv

    WHERE pv.date >= DATE '2020-07-01'
      AND pv.date <  DATE '2025-07-01'
      AND pv.market_value_in_eur IS NOT NULL
      AND pv.market_value_in_eur >= 0
),

season_end_values AS (

    SELECT DISTINCT ON (player_id, season)
        player_id,
        season,
        valuation_date AS ending_valuation_date,
        market_value_in_eur AS ending_market_value_eur

    FROM valuation_seasons

    WHERE season BETWEEN 2020 AND 2024

    ORDER BY
        player_id,
        season,
        valuation_date DESC
),

player_season_performance AS (

    SELECT
        player_id,
        season,
        MAX(player_name) AS player_name,
        MAX(position) AS position,
        MAX(sub_position) AS sub_position,
        MAX(season_label) AS season_label,
        COUNT(DISTINCT club_id) AS clubs_represented,

        STRING_AGG(
            DISTINCT club_name,
            ', '
            ORDER BY club_name
        ) AS clubs,

        SUM(minutes_played) AS minutes_played,
        SUM(goals) AS goals,
        SUM(assists) AS assists,
        SUM(goal_contributions) AS goal_contributions,

        ROUND(
            90.0 * SUM(goal_contributions)
            / NULLIF(SUM(minutes_played), 0),
            3
        ) AS goal_contributions_per_90

    FROM football.vw_player_season_performance

    WHERE LOWER(position) <> 'goalkeeper'

    GROUP BY
        player_id,
        season
),

combined_seasons AS (

    SELECT
        ps.*,
        sev.ending_valuation_date,
        sev.ending_market_value_eur

    FROM player_season_performance AS ps

    JOIN season_end_values AS sev
        ON ps.player_id = sev.player_id
       AND ps.season = sev.season
),

with_previous_season AS (

    SELECT
        *,

        LAG(season) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_season,

        LAG(season_label) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_season_label,

        LAG(clubs) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_clubs,

        LAG(minutes_played) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_minutes_played,

        LAG(goal_contributions_per_90) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_goal_contributions_per_90,

        LAG(ending_market_value_eur) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_ending_market_value_eur

    FROM combined_seasons
),

growth_and_improvement AS (

    SELECT
        *,

        ending_market_value_eur
            - previous_ending_market_value_eur
            AS market_value_change_eur,

        ROUND(
            (
                100.0
                * (
                    ending_market_value_eur
                    - previous_ending_market_value_eur
                )
                / NULLIF(previous_ending_market_value_eur, 0)
            )::NUMERIC,
            2
        ) AS market_value_percentage_change,

        ROUND(
            goal_contributions_per_90
            - previous_goal_contributions_per_90,
            3
        ) AS goal_contributions_per_90_change,

        minutes_played
            - previous_minutes_played
            AS minutes_change

    FROM with_previous_season

    WHERE previous_season = season - 1
      AND previous_minutes_played >= 900
      AND minutes_played >= 900
      AND previous_ending_market_value_eur >= 1000000
)

SELECT
    player_id,
    player_name,
    position,
    sub_position,
    previous_season_label,
    season_label AS current_season_label,
    previous_clubs,
    clubs AS current_clubs,
    previous_minutes_played,
    minutes_played AS current_minutes_played,
    minutes_change,
    previous_goal_contributions_per_90,
    goal_contributions_per_90
        AS current_goal_contributions_per_90,
    goal_contributions_per_90_change,
    previous_ending_market_value_eur,
    ending_market_value_eur
        AS current_ending_market_value_eur,
    market_value_change_eur,
    market_value_percentage_change,

    DENSE_RANK() OVER (
        ORDER BY
            market_value_change_eur DESC,
            goal_contributions_per_90_change DESC
    ) AS value_and_performance_growth_rank

FROM growth_and_improvement

WHERE market_value_change_eur > 0
  AND goal_contributions_per_90_change > 0

ORDER BY
    value_and_performance_growth_rank,
    player_name;

-- ============================================================
-- QUESTION 10
-- Which players experienced market-value decline following
-- reduced playing time or performance?
--
-- ELIGIBILITY:
--   - Consecutive seasons
--   - Previous season >= 900 minutes
--   - Previous end value >= EUR 1 million
--
-- DECLINE SIGNAL:
--   Market value declined AND:
--   - minutes declined, or
--   - outfield goal contributions per 90 declined
-- ============================================================

WITH valuation_seasons AS (

    SELECT
        pv.player_id,
        pv.date AS valuation_date,
        pv.market_value_in_eur,

        CASE
            WHEN EXTRACT(MONTH FROM pv.date) >= 7
                THEN EXTRACT(YEAR FROM pv.date)::INTEGER
            ELSE EXTRACT(YEAR FROM pv.date)::INTEGER - 1
        END AS season

    FROM football_raw.player_valuations AS pv

    WHERE pv.date >= DATE '2020-07-01'
      AND pv.date <  DATE '2025-07-01'
      AND pv.market_value_in_eur IS NOT NULL
      AND pv.market_value_in_eur >= 0
),

season_end_values AS (

    SELECT DISTINCT ON (player_id, season)
        player_id,
        season,
        market_value_in_eur AS ending_market_value_eur

    FROM valuation_seasons

    WHERE season BETWEEN 2020 AND 2024

    ORDER BY
        player_id,
        season,
        valuation_date DESC
),

player_season_performance AS (

    SELECT
        player_id,
        season,
        MAX(player_name) AS player_name,
        MAX(position) AS position,
        MAX(sub_position) AS sub_position,
        MAX(season_label) AS season_label,

        STRING_AGG(
            DISTINCT club_name,
            ', '
            ORDER BY club_name
        ) AS clubs,

        SUM(minutes_played) AS minutes_played,
        SUM(goal_contributions) AS goal_contributions,

        CASE
            WHEN LOWER(MAX(position)) = 'goalkeeper'
                THEN NULL
            ELSE ROUND(
                90.0 * SUM(goal_contributions)
                / NULLIF(SUM(minutes_played), 0),
                3
            )
        END AS goal_contributions_per_90

    FROM football.vw_player_season_performance

    GROUP BY
        player_id,
        season
),

combined_seasons AS (

    SELECT
        ps.*,
        sev.ending_market_value_eur

    FROM player_season_performance AS ps

    JOIN season_end_values AS sev
        ON ps.player_id = sev.player_id
       AND ps.season = sev.season
),

with_previous_season AS (

    SELECT
        *,

        LAG(season) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_season,

        LAG(season_label) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_season_label,

        LAG(clubs) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_clubs,

        LAG(minutes_played) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_minutes_played,

        LAG(goal_contributions_per_90) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_goal_contributions_per_90,

        LAG(ending_market_value_eur) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_ending_market_value_eur

    FROM combined_seasons
),

decline_analysis AS (

    SELECT
        *,

        ending_market_value_eur
            - previous_ending_market_value_eur
            AS market_value_change_eur,

        ROUND(
            (
                100.0
                * (
                    ending_market_value_eur
                    - previous_ending_market_value_eur
                )
                / NULLIF(previous_ending_market_value_eur, 0)
            )::NUMERIC,
            2
        ) AS market_value_percentage_change,

        minutes_played
            - previous_minutes_played
            AS minutes_change,

        CASE
            WHEN LOWER(position) = 'goalkeeper'
                THEN NULL
            ELSE ROUND(
                goal_contributions_per_90
                - previous_goal_contributions_per_90,
                3
            )
        END AS goal_contributions_per_90_change

    FROM with_previous_season

    WHERE previous_season = season - 1
      AND previous_minutes_played >= 900
      AND previous_ending_market_value_eur >= 1000000
)

SELECT
    player_id,
    player_name,
    position,
    sub_position,
    previous_season_label,
    season_label AS current_season_label,
    previous_clubs,
    clubs AS current_clubs,
    previous_minutes_played,
    minutes_played AS current_minutes_played,
    minutes_change,
    previous_goal_contributions_per_90,
    goal_contributions_per_90
        AS current_goal_contributions_per_90,
    goal_contributions_per_90_change,
    previous_ending_market_value_eur,
    ending_market_value_eur
        AS current_ending_market_value_eur,
    market_value_change_eur,
    market_value_percentage_change,

    CASE
        WHEN minutes_change < 0
         AND goal_contributions_per_90_change < 0
            THEN 'Reduced minutes and productivity'

        WHEN minutes_change < 0
            THEN 'Reduced minutes'

        WHEN goal_contributions_per_90_change < 0
            THEN 'Reduced productivity'

        ELSE 'Other'
    END AS decline_context,

    DENSE_RANK() OVER (
        ORDER BY
            market_value_change_eur ASC,
            minutes_change ASC,
            goal_contributions_per_90_change ASC NULLS LAST
    ) AS market_value_decline_rank

FROM decline_analysis

WHERE market_value_change_eur < 0
  AND (
        minutes_change < 0
        OR goal_contributions_per_90_change < 0
      )

ORDER BY
    market_value_decline_rank,
    player_name;

-- ============================================================
-- FINAL THEME 3 VALIDATION CHECKS
-- ============================================================


-- ------------------------------------------------------------
-- V1. Confirm valuation dates fall within the intended window.
-- ------------------------------------------------------------

SELECT
    MIN(date) AS earliest_valuation_date,
    MAX(date) AS latest_valuation_date,
    COUNT(*) AS valuation_rows
FROM football_raw.player_valuations
WHERE date >= DATE '2020-07-01'
  AND date <  DATE '2025-07-01';


-- ------------------------------------------------------------
-- V2. Confirm no negative market values in the project window.
-- Expected result: zero rows.
-- ------------------------------------------------------------

SELECT
    player_id,
    date,
    market_value_in_eur
FROM football_raw.player_valuations
WHERE date >= DATE '2020-07-01'
  AND date <  DATE '2025-07-01'
  AND market_value_in_eur < 0;


-- ------------------------------------------------------------
-- V3. Review valuation observations per player.
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS players_with_valuations,
    MIN(valuation_count) AS minimum_valuations,
    ROUND(AVG(valuation_count), 2) AS average_valuations,
    MAX(valuation_count) AS maximum_valuations
FROM (
    SELECT
        player_id,
        COUNT(*) AS valuation_count
    FROM football_raw.player_valuations
    WHERE date >= DATE '2020-07-01'
      AND date <  DATE '2025-07-01'
    GROUP BY player_id
) AS player_counts;


-- ------------------------------------------------------------
-- V4. Confirm valuation-season mapping.
-- ------------------------------------------------------------

SELECT
    CASE
        WHEN EXTRACT(MONTH FROM date) >= 7
            THEN EXTRACT(YEAR FROM date)::INTEGER
        ELSE EXTRACT(YEAR FROM date)::INTEGER - 1
    END AS season,
    COUNT(*) AS valuation_rows,
    COUNT(DISTINCT player_id) AS valued_players
FROM football_raw.player_valuations
WHERE date >= DATE '2020-07-01'
  AND date <  DATE '2025-07-01'
GROUP BY 1
ORDER BY 1;


-- ------------------------------------------------------------
-- V5. Review single-club versus multi-club player-seasons.
-- ------------------------------------------------------------

WITH player_club_counts AS (

    SELECT
        player_id,
        season,
        COUNT(DISTINCT club_id) AS clubs_represented

    FROM football.vw_player_season_performance

    GROUP BY
        player_id,
        season
)

SELECT
    clubs_represented,
    COUNT(*) AS player_seasons
FROM player_club_counts
GROUP BY clubs_represented
ORDER BY clubs_represented;


-- ------------------------------------------------------------
-- V6. Review position values available for median analysis.
-- ------------------------------------------------------------

SELECT
    position,
    COUNT(DISTINCT player_id) AS players,
    COUNT(*) AS player_club_season_rows
FROM football.vw_player_season_performance
GROUP BY position
ORDER BY position;


-- ------------------------------------------------------------
-- V7. Confirm age-at-peak calculations are plausible.
-- Expected values should generally fall between 16 and 40.
-- ------------------------------------------------------------

WITH player_profiles AS (

    SELECT
        player_id,
        MAX(date_of_birth) AS date_of_birth

    FROM football.vw_player_season_performance

    GROUP BY player_id
),

peak_rows AS (

    SELECT
        pv.player_id,
        pv.date,
        pv.market_value_in_eur,

        ROW_NUMBER() OVER (
            PARTITION BY pv.player_id
            ORDER BY
                pv.market_value_in_eur DESC,
                pv.date ASC
        ) AS peak_row

    FROM football_raw.player_valuations AS pv

    WHERE pv.date >= DATE '2020-07-01'
      AND pv.date <  DATE '2025-07-01'
)

SELECT
    MIN(
        DATE_PART('year', AGE(pr.date, pp.date_of_birth))
    ) AS minimum_peak_age,

    MAX(
        DATE_PART('year', AGE(pr.date, pp.date_of_birth))
    ) AS maximum_peak_age

FROM peak_rows AS pr

JOIN player_profiles AS pp
    ON pr.player_id = pp.player_id

WHERE pr.peak_row = 1
  AND pp.date_of_birth IS NOT NULL;

-- ============================================================
-- THEME 3 ANALYSIS SUMMARY
--
-- QUESTIONS ANSWERED:
--   1. Largest absolute player-value growth
--   2. Largest percentage player-value growth
--   3. Under-23 value development
--   4. Club-level net and gross value creation
--   5. Club development of high-growth players
--   6. Under-23 market value by league
--   7. Median market value by position
--   8. Peak-value ages by position
--   9. Value growth alongside performance improvement
--  10. Value decline alongside reduced minutes or output
--
-- MAIN SQL SKILLS DEMONSTRATED:
--   - Valuation-date to season mapping
--   - DISTINCT ON for first and last observations
--   - Historical player-season joins
--   - Percentage-growth controls
--   - PERCENTILE_CONT and median analysis
--   - MODE ordered-set aggregation
--   - Window functions
--   - LAG for consecutive-season comparisons
--   - Conditional club attribution
--   - Age calculations using AGE()
--   - Multi-measure ranking
--
-- IMPORTANT INTERPRETATION NOTES:
--   - Market values are estimates, not realised transfer fees.
--   - Percentage rankings exclude starting values below EUR 1m.
--   - Club-development analysis excludes multi-club seasons.
--   - End-of-season value means the last valuation recorded
--     within the defined July-to-June season window.
--   - Valuation growth is descriptive and does not prove that
--     a club caused the increase.
--   - Performance and valuation may respond to shared external
--     factors such as age, injuries, transfers and reputation.
-- ============================================================


-- ============================================================
-- END OF FILE
-- Next file: 08a_theme_3_export_queries.sql
-- ============================================================
