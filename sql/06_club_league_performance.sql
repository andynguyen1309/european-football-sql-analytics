-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 06_club_league_performance.sql
-- THEME: Club and League Performance
--
-- BUSINESS OBJECTIVE:
--   Evaluate club performance, consistency and efficiency
--   across Europe's five major domestic leagues.
--
-- QUESTIONS:
--   1. Which clubs achieved the highest win percentage
--      in each league-season?
--   2. Which clubs recorded the strongest overall win
--      percentage across the five-season period?
--   3. Which clubs showed the greatest improvement or decline
--      between consecutive seasons?
--   4. Which clubs produced the strongest home performance?
--   5. Which clubs produced the strongest away performance?
--   6. Which clubs had the largest difference between home
--      and away performance?
--   7. Which clubs scored the most and conceded the fewest
--      goals per match?
--   8. Which clubs produced the best results relative to their
--      estimated player market value?
--   9. Which leagues recorded the highest average goals
--      per match?
--  10. Which clubs demonstrated the greatest performance
--      consistency across multiple seasons?
--
-- DATABASE: eu_football_analytics
-- RAW SCHEMA: football_raw
-- ANALYTICAL SCHEMA: football
-- AUTHOR: Andy Nguyen
--
-- EXECUTION ORDER:
--   Run after 05_create_views_and_indexes.sql
--
-- CORE SCOPE:
--   Competitions: GB1, ES1, L1, IT1, FR1
--   Seasons: 2020/21 to 2024/25
--
-- IMPORTANT:
--   This file performs analysis only.
--   It does not modify raw or cleaned data.
-- ============================================================


-- ------------------------------------------------------------
-- 1. CONNECTION AND SCOPE CHECK
-- ------------------------------------------------------------

SELECT
    current_database() AS database_name,
    current_user AS database_user,
    CURRENT_TIMESTAMP AS analysis_timestamp;

SET search_path TO football, football_raw, public;

SHOW search_path;

-- Confirm analytical scope.
SELECT *
FROM football.vw_project_scope_summary
ORDER BY metric;

-- ============================================================
-- QUESTION 1
-- Which clubs achieved the highest win percentage
-- in each league-season?
-- ============================================================

WITH ranked_clubs AS (

    SELECT
        competition_id,
        competition_name,
        country_name,
        season,
        season_label,
        club_id,
        club_name,
        matches_played,
        wins,
        draws,
        losses,
        points_earned,
        win_percentage,
        points_per_match,
        goal_difference,

        DENSE_RANK() OVER (
            PARTITION BY
                competition_id,
                season
            ORDER BY
                win_percentage DESC,
                points_per_match DESC,
                goal_difference DESC
        ) AS performance_rank

    FROM football.vw_club_season_performance
)

SELECT
    competition_name,
    country_name,
    season_label,
    club_name,
    matches_played,
    wins,
    draws,
    losses,
    points_earned,
    win_percentage,
    points_per_match,
    goal_difference,
    performance_rank
FROM ranked_clubs
WHERE performance_rank = 1
ORDER BY
    season,
    competition_name,
    club_name;

-- Optional output: top three clubs in every league-season.

WITH ranked_clubs AS (

    SELECT
        competition_name,
        country_name,
        season,
        season_label,
        club_name,
        matches_played,
        wins,
        points_earned,
        win_percentage,
        points_per_match,
        goal_difference,

        DENSE_RANK() OVER (
            PARTITION BY
                competition_id,
                season
            ORDER BY
                win_percentage DESC,
                points_per_match DESC,
                goal_difference DESC
        ) AS performance_rank

    FROM football.vw_club_season_performance
)

SELECT *
FROM ranked_clubs
WHERE performance_rank <= 3
ORDER BY
    season,
    competition_name,
    performance_rank,
    club_name;

-- ============================================================
-- QUESTION 2
-- Which clubs recorded the strongest overall win percentage
-- across the full five-season period?
--
-- ELIGIBILITY:
--   Club must appear in all five selected seasons.
-- ============================================================

WITH five_season_club_summary AS (

    SELECT
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name,

        COUNT(DISTINCT season) AS seasons_played,
        SUM(matches_played) AS matches_played,
        SUM(wins) AS wins,
        SUM(draws) AS draws,
        SUM(losses) AS losses,
        SUM(points_earned) AS points_earned,
        SUM(goals_scored) AS goals_scored,
        SUM(goals_conceded) AS goals_conceded,
        SUM(goal_difference) AS goal_difference,

        ROUND(
            100.0 * SUM(wins)
            / NULLIF(SUM(matches_played), 0),
            2
        ) AS overall_win_percentage,

        ROUND(
            SUM(points_earned)::NUMERIC
            / NULLIF(SUM(matches_played), 0),
            3
        ) AS overall_points_per_match,

        ROUND(
            SUM(goals_scored)::NUMERIC
            / NULLIF(SUM(matches_played), 0),
            3
        ) AS goals_scored_per_match,

        ROUND(
            SUM(goals_conceded)::NUMERIC
            / NULLIF(SUM(matches_played), 0),
            3
        ) AS goals_conceded_per_match

    FROM football.vw_club_season_performance

    GROUP BY
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name

    HAVING COUNT(DISTINCT season) = 5
)

SELECT
    club_name,
    competition_name,
    country_name,
    seasons_played,
    matches_played,
    wins,
    draws,
    losses,
    points_earned,
    overall_win_percentage,
    overall_points_per_match,
    goals_scored,
    goals_conceded,
    goal_difference
FROM five_season_club_summary
ORDER BY
    overall_win_percentage DESC,
    overall_points_per_match DESC,
    goal_difference DESC;

-- ============================================================
-- QUESTION 3
-- Which clubs showed the greatest improvement or decline
-- between consecutive seasons?
-- ============================================================

WITH season_metrics AS (

    SELECT
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name,
        season,
        season_label,
        matches_played,
        win_percentage,
        points_per_match,

        ROUND(
            goal_difference::NUMERIC
            / NULLIF(matches_played, 0),
            3
        ) AS goal_difference_per_match

    FROM football.vw_club_season_performance
),

previous_season_comparison AS (

    SELECT
        *,

        LAG(season) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_season,

        LAG(season_label) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_season_label,

        LAG(win_percentage) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_win_percentage,

        LAG(points_per_match) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_points_per_match,

        LAG(goal_difference_per_match) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_goal_difference_per_match

    FROM season_metrics
),

season_changes AS (

    SELECT
        club_id,
        club_name,
        competition_name,
        country_name,
        previous_season_label,
        season_label AS current_season_label,

        previous_win_percentage,
        win_percentage AS current_win_percentage,

        previous_points_per_match,
        points_per_match AS current_points_per_match,

        previous_goal_difference_per_match,
        goal_difference_per_match
            AS current_goal_difference_per_match,

        ROUND(
            win_percentage
            - previous_win_percentage,
            2
        ) AS win_percentage_change,

        ROUND(
            points_per_match
            - previous_points_per_match,
            3
        ) AS points_per_match_change,

        ROUND(
            goal_difference_per_match
            - previous_goal_difference_per_match,
            3
        ) AS goal_difference_per_match_change

    FROM previous_season_comparison

    -- Only compare genuinely consecutive seasons.
    WHERE previous_season = season - 1
)

SELECT
    club_name,
    competition_name,
    country_name,
    previous_season_label,
    current_season_label,
    previous_points_per_match,
    current_points_per_match,
    points_per_match_change,
    previous_win_percentage,
    current_win_percentage,
    win_percentage_change,
    previous_goal_difference_per_match,
    current_goal_difference_per_match,
    goal_difference_per_match_change,

    CASE
        WHEN points_per_match_change > 0
            THEN 'Improvement'
        WHEN points_per_match_change < 0
            THEN 'Decline'
        ELSE 'No change'
    END AS performance_direction

FROM season_changes
ORDER BY
    points_per_match_change DESC,
    win_percentage_change DESC;

--Top improvements

WITH season_metrics AS (

    SELECT
        club_id,
        club_name,
        competition_name,
        country_name,
        season,
        season_label,
        win_percentage,
        points_per_match,

        LAG(season) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_season,

        LAG(season_label) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_season_label,

        LAG(win_percentage) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_win_percentage,

        LAG(points_per_match) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_points_per_match

    FROM football.vw_club_season_performance
)

SELECT
    club_name,
    competition_name,
    previous_season_label,
    season_label AS current_season_label,

    ROUND(
        points_per_match - previous_points_per_match,
        3
    ) AS points_per_match_change,

    ROUND(
        win_percentage - previous_win_percentage,
        2
    ) AS win_percentage_change

FROM season_metrics
WHERE previous_season = season - 1
ORDER BY
    points_per_match_change DESC,
    win_percentage_change DESC
LIMIT 10;

--Largest declines

WITH season_metrics AS (

    SELECT
        club_id,
        club_name,
        competition_name,
        season,
        season_label,
        win_percentage,
        points_per_match,

        LAG(season) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_season,

        LAG(season_label) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_season_label,

        LAG(win_percentage) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_win_percentage,

        LAG(points_per_match) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_points_per_match

    FROM football.vw_club_season_performance
)

SELECT
    club_name,
    competition_name,
    previous_season_label,
    season_label AS current_season_label,

    ROUND(
        points_per_match - previous_points_per_match,
        3
    ) AS points_per_match_change,

    ROUND(
        win_percentage - previous_win_percentage,
        2
    ) AS win_percentage_change

FROM season_metrics
WHERE previous_season = season - 1
ORDER BY
    points_per_match_change ASC,
    win_percentage_change ASC
LIMIT 10;

-- ============================================================
-- QUESTION 4
-- Which clubs produced the strongest home performance?
--
-- ELIGIBILITY:
--   Club must appear in all five selected seasons.
-- ============================================================

WITH home_performance AS (

    SELECT
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name,

        COUNT(DISTINCT season) AS seasons_played,
        SUM(home_matches) AS home_matches,
        SUM(home_wins) AS home_wins,

        ROUND(
            100.0 * SUM(home_wins)
            / NULLIF(SUM(home_matches), 0),
            2
        ) AS home_win_percentage

    FROM football.vw_club_season_performance

    GROUP BY
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name

    HAVING COUNT(DISTINCT season) = 5
)

SELECT
    club_name,
    competition_name,
    country_name,
    seasons_played,
    home_matches,
    home_wins,
    home_win_percentage,

    DENSE_RANK() OVER (
        ORDER BY
            home_win_percentage DESC,
            home_wins DESC
    ) AS home_performance_rank

FROM home_performance
ORDER BY
    home_performance_rank,
    club_name;

-- ============================================================
-- QUESTION 5
-- Which clubs produced the strongest away performance?
--
-- ELIGIBILITY:
--   Club must appear in all five selected seasons.
-- ============================================================

WITH away_performance AS (

    SELECT
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name,

        COUNT(DISTINCT season) AS seasons_played,
        SUM(away_matches) AS away_matches,
        SUM(away_wins) AS away_wins,

        ROUND(
            100.0 * SUM(away_wins)
            / NULLIF(SUM(away_matches), 0),
            2
        ) AS away_win_percentage

    FROM football.vw_club_season_performance

    GROUP BY
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name

    HAVING COUNT(DISTINCT season) = 5
)

SELECT
    club_name,
    competition_name,
    country_name,
    seasons_played,
    away_matches,
    away_wins,
    away_win_percentage,

    DENSE_RANK() OVER (
        ORDER BY
            away_win_percentage DESC,
            away_wins DESC
    ) AS away_performance_rank

FROM away_performance
ORDER BY
    away_performance_rank,
    club_name;

-- ============================================================
-- QUESTION 6
-- Which clubs had the largest difference between
-- home and away performance?
--
-- ELIGIBILITY:
--   Club must appear in all five selected seasons.
-- ============================================================

WITH home_away_performance AS (

    SELECT
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name,

        COUNT(DISTINCT season) AS seasons_played,
        SUM(home_matches) AS home_matches,
        SUM(home_wins) AS home_wins,
        SUM(away_matches) AS away_matches,
        SUM(away_wins) AS away_wins,

        ROUND(
            100.0 * SUM(home_wins)
            / NULLIF(SUM(home_matches), 0),
            2
        ) AS home_win_percentage,

        ROUND(
            100.0 * SUM(away_wins)
            / NULLIF(SUM(away_matches), 0),
            2
        ) AS away_win_percentage

    FROM football.vw_club_season_performance

    GROUP BY
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name

    HAVING COUNT(DISTINCT season) = 5
)

SELECT
    club_name,
    competition_name,
    country_name,
    seasons_played,
    home_matches,
    away_matches,
    home_win_percentage,
    away_win_percentage,

    ROUND(
        home_win_percentage
        - away_win_percentage,
        2
    ) AS home_away_win_percentage_gap,

    ABS(
        ROUND(
            home_win_percentage
            - away_win_percentage,
            2
        )
    ) AS absolute_home_away_gap,

    CASE
        WHEN home_win_percentage > away_win_percentage
            THEN 'Stronger at home'
        WHEN home_win_percentage < away_win_percentage
            THEN 'Stronger away'
        ELSE 'Equal home and away performance'
    END AS performance_profile

FROM home_away_performance
ORDER BY
    absolute_home_away_gap DESC,
    home_win_percentage DESC;

-- ============================================================
-- QUESTION 7
-- Which clubs scored the most and conceded the fewest goals
-- per match?
--
-- ELIGIBILITY:
--   Club must appear in all five selected seasons.
-- ============================================================

WITH club_goal_summary AS (

    SELECT
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name,

        COUNT(DISTINCT season) AS seasons_played,
        SUM(matches_played) AS matches_played,
        SUM(goals_scored) AS goals_scored,
        SUM(goals_conceded) AS goals_conceded,
        SUM(goal_difference) AS goal_difference,

        ROUND(
            SUM(goals_scored)::NUMERIC
            / NULLIF(SUM(matches_played), 0),
            3
        ) AS goals_scored_per_match,

        ROUND(
            SUM(goals_conceded)::NUMERIC
            / NULLIF(SUM(matches_played), 0),
            3
        ) AS goals_conceded_per_match,

        ROUND(
            SUM(goal_difference)::NUMERIC
            / NULLIF(SUM(matches_played), 0),
            3
        ) AS goal_difference_per_match

    FROM football.vw_club_season_performance

    GROUP BY
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name

    HAVING COUNT(DISTINCT season) = 5
)

SELECT
    club_name,
    competition_name,
    country_name,
    seasons_played,
    matches_played,
    goals_scored,
    goals_conceded,
    goal_difference,
    goals_scored_per_match,
    goals_conceded_per_match,
    goal_difference_per_match,

    DENSE_RANK() OVER (
        ORDER BY goals_scored_per_match DESC
    ) AS attacking_rank,

    DENSE_RANK() OVER (
        ORDER BY goals_conceded_per_match ASC
    ) AS defensive_rank,

    DENSE_RANK() OVER (
        ORDER BY goal_difference_per_match DESC
    ) AS overall_goal_rank

FROM club_goal_summary
ORDER BY
    overall_goal_rank,
    attacking_rank,
    defensive_rank;

--Top attacking clubs 

WITH club_goal_summary AS (

    SELECT
        club_id,
        club_name,
        competition_name,
        COUNT(DISTINCT season) AS seasons_played,
        SUM(matches_played) AS matches_played,

        ROUND(
            SUM(goals_scored)::NUMERIC
            / NULLIF(SUM(matches_played), 0),
            3
        ) AS goals_scored_per_match

    FROM football.vw_club_season_performance

    GROUP BY
        club_id,
        club_name,
        competition_name

    HAVING COUNT(DISTINCT season) = 5
)

SELECT *
FROM club_goal_summary
ORDER BY goals_scored_per_match DESC
LIMIT 10;

--Best defensive clubs

WITH club_goal_summary AS (

    SELECT
        club_id,
        club_name,
        competition_name,
        COUNT(DISTINCT season) AS seasons_played,
        SUM(matches_played) AS matches_played,

        ROUND(
            SUM(goals_conceded)::NUMERIC
            / NULLIF(SUM(matches_played), 0),
            3
        ) AS goals_conceded_per_match

    FROM football.vw_club_season_performance

    GROUP BY
        club_id,
        club_name,
        competition_name

    HAVING COUNT(DISTINCT season) = 5
)

SELECT *
FROM club_goal_summary
ORDER BY goals_conceded_per_match ASC
LIMIT 10;

-- ============================================================
-- QUESTION 8
-- Which clubs produced the best results relative to their
-- estimated player market value?
--
-- METHODOLOGY:
--   1. Sum eligible player valuations by club-season.
--   2. Require at least 80% valuation coverage.
--   3. Estimate expected points per match within each
--      league-season using LN(squad market value).
--   4. Rank clubs by actual minus expected points per match.
--
-- INTERPRETATION:
--   Positive performance residual = higher sporting performance
--   than expected relative to estimated player value.
-- ============================================================

WITH club_player_population AS (

    SELECT
        club_id,
        club_name,
        competition_id,
        competition_name,
        season,
        season_label,

        COUNT(DISTINCT player_id) FILTER (
            WHERE minutes_played > 0
        ) AS players_with_minutes,

        COUNT(DISTINCT player_id) FILTER (
            WHERE minutes_played > 0
              AND market_value_in_eur IS NOT NULL
              AND valuation_age_days BETWEEN 0 AND 180
        ) AS players_with_eligible_valuation,

        SUM(market_value_in_eur) FILTER (
            WHERE minutes_played > 0
              AND market_value_in_eur IS NOT NULL
              AND valuation_age_days BETWEEN 0 AND 180
        ) AS estimated_squad_value_eur

    FROM football.vw_player_season_valuations

    GROUP BY
        club_id,
        club_name,
        competition_id,
        competition_name,
        season,
        season_label
),

club_value_coverage AS (

    SELECT
        *,

        ROUND(
            100.0 * players_with_eligible_valuation
            / NULLIF(players_with_minutes, 0),
            2
        ) AS valuation_coverage_percentage

    FROM club_player_population
),

eligible_club_seasons AS (

    SELECT
        csp.club_id,
        csp.club_name,
        csp.competition_id,
        csp.competition_name,
        csp.country_name,
        csp.season,
        csp.season_label,
        csp.matches_played,
        csp.points_earned,
        csp.points_per_match,
        csp.win_percentage,
        csp.goal_difference,

        cvc.players_with_minutes,
        cvc.players_with_eligible_valuation,
        cvc.valuation_coverage_percentage,
        cvc.estimated_squad_value_eur,

        LN(cvc.estimated_squad_value_eur::NUMERIC)
            AS log_estimated_squad_value

    FROM football.vw_club_season_performance AS csp

    JOIN club_value_coverage AS cvc
        ON csp.club_id = cvc.club_id
       AND csp.competition_id = cvc.competition_id
       AND csp.season = cvc.season

    WHERE cvc.valuation_coverage_percentage >= 80
      AND cvc.estimated_squad_value_eur > 0
),

league_season_models AS (

    SELECT
        competition_id,
        season,

        REGR_INTERCEPT(
            points_per_match,
            log_estimated_squad_value
        ) AS regression_intercept,

        REGR_SLOPE(
            points_per_match,
            log_estimated_squad_value
        ) AS regression_slope,

        REGR_R2(
            points_per_match,
            log_estimated_squad_value
        ) AS regression_r_squared,

        COUNT(*) AS eligible_club_count

    FROM eligible_club_seasons

    GROUP BY
        competition_id,
        season
),

efficiency_results AS (

    SELECT
        ecs.*,
        lsm.eligible_club_count,
        lsm.regression_r_squared,

        lsm.regression_intercept
        + lsm.regression_slope
        * ecs.log_estimated_squad_value
            AS expected_points_per_match,

        ecs.points_per_match
        - (
            lsm.regression_intercept
            + lsm.regression_slope
            * ecs.log_estimated_squad_value
        ) AS performance_residual

    FROM eligible_club_seasons AS ecs

    JOIN league_season_models AS lsm
        ON ecs.competition_id = lsm.competition_id
       AND ecs.season = lsm.season
)

SELECT
    club_name,
    competition_name,
    country_name,
    season_label,
    matches_played,
    points_earned,
    points_per_match,
    win_percentage,
    goal_difference,

    players_with_minutes,
    players_with_eligible_valuation,
    valuation_coverage_percentage,

    estimated_squad_value_eur,

    ROUND(
        estimated_squad_value_eur
        / 1000000.0,
        2
    ) AS estimated_squad_value_millions_eur,

    ROUND(
        expected_points_per_match::NUMERIC,
        3
    ) AS expected_points_per_match,

    ROUND(
        performance_residual::NUMERIC,
        3
    ) AS performance_residual,

    ROUND(
        regression_r_squared::NUMERIC,
        3
    ) AS league_season_model_r_squared,

    DENSE_RANK() OVER (
        PARTITION BY
            competition_id,
            season
        ORDER BY
            performance_residual DESC
    ) AS efficiency_rank_within_league_season

FROM efficiency_results
ORDER BY
    performance_residual DESC,
    points_per_match DESC;

--Five season efficiency summary

WITH club_player_population AS (

    SELECT
        club_id,
        club_name,
        competition_id,
        competition_name,
        season,
        season_label,

        COUNT(DISTINCT player_id) FILTER (
            WHERE minutes_played > 0
        ) AS players_with_minutes,

        COUNT(DISTINCT player_id) FILTER (
            WHERE minutes_played > 0
              AND market_value_in_eur IS NOT NULL
              AND valuation_age_days BETWEEN 0 AND 180
        ) AS valued_players,

        SUM(market_value_in_eur) FILTER (
            WHERE minutes_played > 0
              AND market_value_in_eur IS NOT NULL
              AND valuation_age_days BETWEEN 0 AND 180
        ) AS estimated_squad_value_eur

    FROM football.vw_player_season_valuations

    GROUP BY
        club_id,
        club_name,
        competition_id,
        competition_name,
        season,
        season_label
),

eligible_club_seasons AS (

    SELECT
        csp.club_id,
        csp.club_name,
        csp.competition_id,
        csp.competition_name,
        csp.season,
        csp.season_label,
        csp.points_per_match,

        cpp.estimated_squad_value_eur,

        100.0 * cpp.valued_players
        / NULLIF(cpp.players_with_minutes, 0)
            AS valuation_coverage_percentage,

        LN(cpp.estimated_squad_value_eur::NUMERIC)
            AS log_squad_value

    FROM football.vw_club_season_performance AS csp

    JOIN club_player_population AS cpp
        ON csp.club_id = cpp.club_id
       AND csp.competition_id = cpp.competition_id
       AND csp.season = cpp.season

    WHERE cpp.estimated_squad_value_eur > 0

      AND 100.0 * cpp.valued_players
          / NULLIF(cpp.players_with_minutes, 0) >= 80
),

models AS (

    SELECT
        competition_id,
        season,

        REGR_INTERCEPT(
            points_per_match,
            log_squad_value
        ) AS intercept_value,

        REGR_SLOPE(
            points_per_match,
            log_squad_value
        ) AS slope_value

    FROM eligible_club_seasons

    GROUP BY
        competition_id,
        season
),

season_efficiency AS (

    SELECT
        ecs.*,

        ecs.points_per_match
        - (
            m.intercept_value
            + m.slope_value * ecs.log_squad_value
        ) AS performance_residual

    FROM eligible_club_seasons AS ecs

    JOIN models AS m
        ON ecs.competition_id = m.competition_id
       AND ecs.season = m.season
)

SELECT
    club_id,
    club_name,
    competition_name,
    COUNT(*) AS eligible_seasons,

    ROUND(
        AVG(points_per_match),
        3
    ) AS average_points_per_match,

    ROUND(
        AVG(
            estimated_squad_value_eur
            / 1000000.0
        ),
        2
    ) AS average_estimated_squad_value_millions_eur,

    ROUND(
        AVG(performance_residual)::NUMERIC,
        3
    ) AS average_performance_residual,

    ROUND(
        MIN(performance_residual)::NUMERIC,
        3
    ) AS minimum_performance_residual,

    ROUND(
        MAX(performance_residual)::NUMERIC,
        3
    ) AS maximum_performance_residual

FROM season_efficiency

GROUP BY
    club_id,
    club_name,
    competition_name

HAVING COUNT(*) >= 3

ORDER BY
    average_performance_residual DESC,
    average_points_per_match DESC;

-- ============================================================
-- QUESTION 9
-- Which leagues recorded the highest average goals per match?
-- ============================================================

SELECT
    competition_id,
    competition_name,
    country_name,

    COUNT(DISTINCT season) AS seasons_included,
    COUNT(*) AS matches_played,
    SUM(total_goals) AS total_goals,

    ROUND(
        AVG(total_goals)::NUMERIC,
        3
    ) AS average_goals_per_match,

    MIN(total_goals) AS minimum_goals_in_match,
    MAX(total_goals) AS maximum_goals_in_match,

    DENSE_RANK() OVER (
        ORDER BY AVG(total_goals) DESC
    ) AS league_scoring_rank

FROM football.vw_core_games

GROUP BY
    competition_id,
    competition_name,
    country_name

ORDER BY
    league_scoring_rank,
    competition_name;

--League-season scoring trends

SELECT
    competition_name,
    country_name,
    season,
    season_label,
    COUNT(*) AS matches_played,
    SUM(total_goals) AS total_goals,

    ROUND(
        AVG(total_goals)::NUMERIC,
        3
    ) AS average_goals_per_match

FROM football.vw_core_games

GROUP BY
    competition_id,
    competition_name,
    country_name,
    season,
    season_label

ORDER BY
    competition_name,
    season;

-- ============================================================
-- QUESTION 10
-- Which clubs demonstrated the greatest performance
-- consistency across multiple seasons?
--
-- PRIMARY ELIGIBILITY:
--   Club must appear in all five selected seasons.
--
-- INTERPRETATION:
--   Lower standard deviation = more consistent performance.
--   Average performance is included to distinguish consistent
--   high performers from consistently weak performers.
-- ============================================================

WITH consistency_metrics AS (

    SELECT
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name,

        COUNT(DISTINCT season) AS seasons_played,

        ROUND(
            AVG(points_per_match),
            3
        ) AS average_points_per_match,

        ROUND(
            STDDEV_SAMP(points_per_match),
            3
        ) AS points_per_match_standard_deviation,

        ROUND(
            MIN(points_per_match),
            3
        ) AS minimum_points_per_match,

        ROUND(
            MAX(points_per_match),
            3
        ) AS maximum_points_per_match,

        ROUND(
            MAX(points_per_match)
            - MIN(points_per_match),
            3
        ) AS points_per_match_range,

        ROUND(
            AVG(win_percentage),
            2
        ) AS average_win_percentage,

        ROUND(
            STDDEV_SAMP(win_percentage),
            2
        ) AS win_percentage_standard_deviation,

        ROUND(
            AVG(goal_difference::NUMERIC
                / NULLIF(matches_played, 0)),
            3
        ) AS average_goal_difference_per_match

    FROM football.vw_club_season_performance

    GROUP BY
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name

    HAVING COUNT(DISTINCT season) = 5
)

SELECT
    club_name,
    competition_name,
    country_name,
    seasons_played,
    average_points_per_match,
    points_per_match_standard_deviation,
    minimum_points_per_match,
    maximum_points_per_match,
    points_per_match_range,
    average_win_percentage,
    win_percentage_standard_deviation,
    average_goal_difference_per_match,

    DENSE_RANK() OVER (
        ORDER BY
            points_per_match_standard_deviation ASC,
            win_percentage_standard_deviation ASC
    ) AS overall_consistency_rank,

    DENSE_RANK() OVER (
        PARTITION BY competition_id
        ORDER BY
            points_per_match_standard_deviation ASC,
            win_percentage_standard_deviation ASC
    ) AS league_consistency_rank,

    CASE
        WHEN average_points_per_match >= 2.0
            THEN 'Consistent high performer'
        WHEN average_points_per_match >= 1.5
            THEN 'Consistent above-average performer'
        WHEN average_points_per_match >= 1.0
            THEN 'Consistent mid-level performer'
        ELSE 'Consistent lower performer'
    END AS consistency_profile

FROM consistency_metrics

ORDER BY
    overall_consistency_rank,
    average_points_per_match DESC;

--High-performance consistency ranking

WITH consistency_metrics AS (

    SELECT
        club_id,
        club_name,
        competition_name,
        country_name,

        COUNT(DISTINCT season) AS seasons_played,

        AVG(points_per_match) AS average_points_per_match,

        STDDEV_SAMP(points_per_match)
            AS points_per_match_standard_deviation,

        AVG(win_percentage)
            AS average_win_percentage,

        STDDEV_SAMP(win_percentage)
            AS win_percentage_standard_deviation

    FROM football.vw_club_season_performance

    GROUP BY
        club_id,
        club_name,
        competition_name,
        country_name

    HAVING COUNT(DISTINCT season) = 5
)

SELECT
    club_name,
    competition_name,
    country_name,
    seasons_played,

    ROUND(
        average_points_per_match,
        3
    ) AS average_points_per_match,

    ROUND(
        points_per_match_standard_deviation,
        3
    ) AS points_per_match_standard_deviation,

    ROUND(
        average_win_percentage,
        2
    ) AS average_win_percentage,

    ROUND(
        win_percentage_standard_deviation,
        2
    ) AS win_percentage_standard_deviation

FROM consistency_metrics

WHERE average_points_per_match >= 1.5

ORDER BY
    points_per_match_standard_deviation ASC,
    average_points_per_match DESC;

-- ============================================================
-- FINAL THEME 1 VALIDATION CHECKS
-- ============================================================


-- ------------------------------------------------------------
-- V1. Confirm one row per club-season.
-- Expected result: zero rows.
-- ------------------------------------------------------------

SELECT
    club_id,
    competition_id,
    season,
    COUNT(*) AS row_count
FROM football.vw_club_season_performance
GROUP BY
    club_id,
    competition_id,
    season
HAVING COUNT(*) > 1;


-- ------------------------------------------------------------
-- V2. Confirm matches equal wins + draws + losses.
-- Expected result: zero rows.
-- ------------------------------------------------------------

SELECT
    club_name,
    competition_name,
    season_label,
    matches_played,
    wins,
    draws,
    losses
FROM football.vw_club_season_performance
WHERE matches_played <> wins + draws + losses;


-- ------------------------------------------------------------
-- V3. Confirm points calculation.
-- Expected result: zero rows.
-- ------------------------------------------------------------

SELECT
    club_name,
    competition_name,
    season_label,
    wins,
    draws,
    points_earned,
    wins * 3 + draws AS recalculated_points
FROM football.vw_club_season_performance
WHERE points_earned <> wins * 3 + draws;


-- ------------------------------------------------------------
-- V4. Confirm club-match rows equal twice the match count.
-- Expected difference: zero.
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS club_match_rows,
    COUNT(DISTINCT game_id) AS distinct_games,
    COUNT(*)
        - 2 * COUNT(DISTINCT game_id)
        AS row_difference
FROM football.vw_core_club_matches;


-- ------------------------------------------------------------
-- V5. Confirm league game totals used in Question 9.
-- ------------------------------------------------------------

SELECT
    competition_name,
    COUNT(*) AS matches_played,
    SUM(total_goals) AS total_goals
FROM football.vw_core_games
GROUP BY
    competition_id,
    competition_name
ORDER BY competition_name;


-- ------------------------------------------------------------
-- V6. Confirm full five-season club eligibility population.
-- ------------------------------------------------------------

SELECT
    competition_name,
    COUNT(*) AS clubs_in_all_five_seasons
FROM (
    SELECT
        competition_id,
        competition_name,
        club_id
    FROM football.vw_club_season_performance
    GROUP BY
        competition_id,
        competition_name,
        club_id
    HAVING COUNT(DISTINCT season) = 5
) AS eligible_clubs
GROUP BY competition_name
ORDER BY competition_name;

-- ============================================================
-- THEME 1 ANALYSIS SUMMARY
--
-- QUESTIONS ANSWERED:
--   1. Highest win percentage by league-season
--   2. Strongest five-season win percentage
--   3. Greatest consecutive-season improvement and decline
--   4. Strongest home performance
--   5. Strongest away performance
--   6. Largest home-away performance difference
--   7. Strongest attacking and defensive records
--   8. Performance relative to estimated player value
--   9. League goals-per-match comparison
--  10. Multi-season club consistency
--
-- MAIN SQL SKILLS DEMONSTRATED:
--   - Common table expressions
--   - Conditional aggregation
--   - Window functions
--   - DENSE_RANK
--   - LAG
--   - FILTER
--   - Lateral valuation matching through prepared views
--   - Statistical aggregate functions
--   - Linear regression aggregates
--   - Standard deviation
--   - Eligibility and coverage rules
--
-- IMPORTANT INTERPRETATION NOTES:
--   - Five-season rankings generally require five complete
--     seasons of participation.
--   - Market values are estimates, not confirmed squad costs.
--   - Efficiency represents association, not causation.
--   - The efficiency model uses participating-player values,
--     not necessarily every registered squad member.
--   - Consistency does not automatically mean strong
--     performance; average performance must also be considered.
-- ============================================================


-- ============================================================
-- END OF FILE
-- Next script: 07_player_performance.sql
-- ============================================================