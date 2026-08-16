-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 08a_theme_3_export_queries.sql
-- THEME: Market Value and Player Development
--
-- PURPOSE:
--   Produce final reusable Theme 3 datasets for:
--   1. CSV export
--   2. Findings documentation
--   3. Tableau visualisation
--   4. GitHub portfolio presentation
--
-- DATABASE: eu_football_analytics
-- ANALYTICAL SCHEMA: football
-- RAW SCHEMA: football_raw
-- AUTHOR: Andy Nguyen
--
-- EXECUTION ORDER:
--   Run after 08_market_value_development.sql
--
-- CORE SCOPE:
--   Competitions: GB1, ES1, L1, IT1, FR1
--   Seasons: 2020 to 2024
--   Valuation dates: 2020-07-01 to 2025-06-30
--
-- METHODOLOGICAL RULES:
--   - Absolute and percentage value growth are separate.
--   - Percentage rankings require a starting value of at least
--     EUR 1 million.
--   - Under 23 means age 22 or younger at season end.
--   - Multi-club player-seasons are excluded where club-level
--     development attribution would be ambiguous.
--   - Position comparisons use medians rather than averages.
--   - Performance comparisons require consecutive seasons.
-- ============================================================

SET search_path TO football, football_raw, public;

-- ============================================================
-- EXPORT 1: PLAYER MARKET-VALUE GROWTH
-- SUPPORTS QUESTIONS: 1 AND 2
--
-- ROW LEVEL:
--   One player across the full project valuation window.
--
-- PERCENTAGE-GROWTH ELIGIBILITY:
--   Starting value of at least EUR 1 million.
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

    WHERE l.last_valuation_date > f.first_valuation_date
      AND pp.player_name IS NOT NULL
)

SELECT
    *,

    CASE
        WHEN absolute_market_value_change_eur > 0
            THEN 'Growth'
        WHEN absolute_market_value_change_eur < 0
            THEN 'Decline'
        ELSE 'No change'
    END AS value_change_direction,

    CASE
        WHEN starting_market_value_eur >= 1000000
            THEN TRUE
        ELSE FALSE
    END AS eligible_for_percentage_ranking,

    DENSE_RANK() OVER (
        ORDER BY
            absolute_market_value_change_eur DESC,
            ending_market_value_eur DESC
    ) AS absolute_growth_rank,

    DENSE_RANK() OVER (
        ORDER BY
            CASE
                WHEN starting_market_value_eur >= 1000000
                    THEN market_value_percentage_change
                ELSE NULL
            END DESC NULLS LAST,
            absolute_market_value_change_eur DESC,
            ending_market_value_eur DESC
    ) AS percentage_growth_rank

FROM valuation_changes

ORDER BY
    absolute_growth_rank,
    player_name;

-- ============================================================
-- EXPORT 2: UNDER-23 MARKET-VALUE GROWTH
-- SUPPORTS QUESTION: 3
--
-- ROW LEVEL:
--   One under-23 player-season.
--
-- ELIGIBILITY:
--   Age 22 or younger at season end
--   At least 900 league minutes
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

    CASE
        WHEN starting_market_value_eur >= 1000000
            THEN TRUE
        ELSE FALSE
    END AS eligible_for_percentage_ranking,

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
    season,
    under_23_absolute_growth_season_rank,
    player_name;

-- ============================================================
-- EXPORT 3: CLUB VALUE DEVELOPMENT
-- SUPPORTS QUESTIONS: 4 AND 5
--
-- ROW LEVEL:
--   One club across all eligible player-seasons.
--
-- CLUB ATTRIBUTION:
--   Multi-club player-seasons are excluded.
--
-- HIGH-GROWTH PLAYER DEFINITION:
--   Starting value >= EUR 1 million
--   Absolute growth >= EUR 10 million
--   Percentage growth >= 50%
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

single_club_growth AS (

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
            AS market_value_change_eur,

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
        ) AS median_player_value_change_eur,

        COUNT(*) FILTER (
            WHERE starting_market_value_eur >= 1000000
              AND market_value_change_eur >= 10000000
              AND market_value_percentage_change >= 50
        ) AS high_growth_player_seasons,

        COUNT(DISTINCT player_id) FILTER (
            WHERE starting_market_value_eur >= 1000000
              AND market_value_change_eur >= 10000000
              AND market_value_percentage_change >= 50
        ) AS distinct_high_growth_players,

        SUM(
            CASE
                WHEN starting_market_value_eur >= 1000000
                 AND market_value_change_eur >= 10000000
                 AND market_value_percentage_change >= 50
                    THEN market_value_change_eur
                ELSE 0
            END
        ) AS total_high_growth_value_created_eur

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
    ) AS club_gross_growth_rank,

    DENSE_RANK() OVER (
        ORDER BY
            distinct_high_growth_players DESC,
            total_high_growth_value_created_eur DESC
    ) AS high_growth_player_development_rank

FROM club_growth_summary

ORDER BY
    club_net_growth_rank,
    club_name;

-- ============================================================
-- EXPORT 4: UNDER-23 MARKET VALUE BY LEAGUE
-- SUPPORTS QUESTION: 6
--
-- ROW LEVEL:
--   One league-season.
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

    CASE
        WHEN season = 2020 THEN '2020-21'
        WHEN season = 2021 THEN '2021-22'
        WHEN season = 2022 THEN '2022-23'
        WHEN season = 2023 THEN '2023-24'
        WHEN season = 2024 THEN '2024-25'
    END AS season_label,

    COUNT(*) AS qualified_under_23_players,

    SUM(ending_market_value_eur)
        AS total_under_23_market_value_eur,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY ending_market_value_eur
        )::NUMERIC,
        2
    ) AS median_under_23_market_value_eur,

    ROUND(
        AVG(ending_market_value_eur)::NUMERIC,
        2
    ) AS average_under_23_market_value_eur,

    MAX(ending_market_value_eur)
        AS highest_under_23_market_value_eur,

    COUNT(*) FILTER (
        WHERE ending_market_value_eur >= 20000000
    ) AS under_23_players_above_20m,

    COUNT(*) FILTER (
        WHERE ending_market_value_eur >= 50000000
    ) AS under_23_players_above_50m,

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
-- EXPORT 5: POSITION MARKET-VALUE PROFILES
-- SUPPORTS QUESTION: 7
--
-- ROW LEVEL:
--   One position-season.
--
-- VALUE USED:
--   Last recorded valuation within each season.
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

    CASE
        WHEN ps.season = 2020 THEN '2020-21'
        WHEN ps.season = 2021 THEN '2021-22'
        WHEN ps.season = 2022 THEN '2022-23'
        WHEN ps.season = 2023 THEN '2023-24'
        WHEN ps.season = 2024 THEN '2024-25'
    END AS season_label,

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
    ) AS third_quartile_market_value_eur,

    ROUND(
        AVG(lv.ending_market_value_eur)::NUMERIC,
        2
    ) AS average_market_value_eur,

    MAX(lv.ending_market_value_eur)
        AS maximum_market_value_eur

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
-- EXPORT 6: PEAK MARKET-VALUE AGE
-- SUPPORTS QUESTION: 8
--
-- ROW LEVEL:
--   One player peak valuation.
--
-- ELIGIBILITY:
--   Known date of birth
--   At least three valuation observations
--   Peak market value of at least EUR 1 million
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

        MAX(country_of_citizenship)
            AS country_of_citizenship,

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
        pp.country_of_citizenship,
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
    *,

    PERCENT_RANK() OVER (
        PARTITION BY position
        ORDER BY age_at_peak_value
    ) AS peak_age_position_percentile,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            peak_market_value_eur DESC,
            age_at_peak_value ASC
    ) AS peak_value_position_rank

FROM player_peaks

WHERE age_at_peak_value BETWEEN 16 AND 40

ORDER BY
    position,
    age_at_peak_value,
    player_name;

-- ============================================================
-- EXPORT 7: VALUE GROWTH WITH SPORTING IMPROVEMENT
-- SUPPORTS QUESTION: 9
--
-- ROW LEVEL:
--   One player consecutive-season comparison.
--
-- ELIGIBILITY:
--   At least 900 minutes in both seasons
--   Outfield players only
--   Previous market value of at least EUR 1 million
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
        MAX(country_of_citizenship) AS country_of_citizenship,
        MAX(age_at_season_end) AS age_at_season_end,
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
    country_of_citizenship,
    age_at_season_end,

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
-- EXPORT 8: MARKET-VALUE DECLINE CONTEXT
-- SUPPORTS QUESTION: 10
--
-- ROW LEVEL:
--   One player consecutive-season comparison.
--
-- DECLINE CONDITION:
--   Market value declined and either:
--   - minutes declined, or
--   - outfield attacking productivity declined
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
        MAX(country_of_citizenship) AS country_of_citizenship,
        MAX(age_at_season_end) AS age_at_season_end,
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
    country_of_citizenship,
    age_at_season_end,

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
-- THEME 3 EXPORT SUMMARY
--
-- OUTPUTS:
--
--   1. player_value_growth.csv
--      Questions 1 and 2
--
--   2. under_23_value_growth.csv
--      Question 3
--
--   3. club_value_development.csv
--      Questions 4 and 5
--
--   4. league_under_23_value.csv
--      Question 6
--
--   5. position_value_profiles.csv
--      Question 7
--
--   6. peak_value_age.csv
--      Question 8
--
--   7. value_and_performance_growth.csv
--      Question 9
--
--   8. value_decline_context.csv
--      Question 10
--
-- IMPORTANT INTERPRETATION NOTES:
--   - Market values are estimates rather than realised fees.
--   - Percentage rankings control for very low starting values.
--   - Club development attribution excludes multi-club seasons.
--   - Median values reduce distortion from elite-value outliers.
--   - Growth alongside performance does not prove causation.
-- ============================================================


-- ============================================================
-- END OF FILE
-- Next deliverable:
-- documentation/theme_3_market_value_findings.md
-- ============================================================