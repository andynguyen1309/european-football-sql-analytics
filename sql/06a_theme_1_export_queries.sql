-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 06a_theme_1_export_queries.sql
-- THEME: Club and League Performance
--
-- PURPOSE:
--   Produce six final, reusable datasets for:
--   1. CSV export
--   2. Findings documentation
--   3. Tableau or chart development
--   4. GitHub portfolio presentation
--
-- DATABASE: eu_football_analytics
-- ANALYTICAL SCHEMA: football
-- AUTHOR: Andy Nguyen
--
-- EXECUTION ORDER:
--   Run after 06_club_league_performance.sql
-- ============================================================


SET search_path TO football, football_raw, public;

-- ============================================================
-- EXPORT 1: CLUB-SEASON PERFORMANCE
-- SUPPORTS QUESTIONS: 1 AND 7
-- ============================================================

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
    points_per_match,
    win_percentage,
    goals_scored,
    goals_conceded,
    goal_difference,
    goals_scored_per_match,
    goals_conceded_per_match,
    home_matches,
    home_wins,
    home_win_percentage,
    away_matches,
    away_wins,
    away_win_percentage,

    DENSE_RANK() OVER (
        PARTITION BY competition_id, season
        ORDER BY
            win_percentage DESC,
            points_per_match DESC,
            goal_difference DESC
    ) AS league_season_rank,

    DENSE_RANK() OVER (
        PARTITION BY season
        ORDER BY
            win_percentage DESC,
            points_per_match DESC,
            goal_difference DESC
    ) AS cross_league_season_rank

FROM football.vw_club_season_performance;

-- ============================================================
-- EXPORT 2: FIVE-SEASON CLUB SUMMARY
-- SUPPORTS QUESTIONS: 2, 7 AND 10
-- ELIGIBILITY: FIVE COMPLETE SEASONS
-- ============================================================

WITH club_summary AS (

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
        ) AS goals_conceded_per_match,

        ROUND(
            SUM(goal_difference)::NUMERIC
            / NULLIF(SUM(matches_played), 0),
            3
        ) AS goal_difference_per_match,

        ROUND(
            STDDEV_SAMP(points_per_match),
            3
        ) AS points_per_match_standard_deviation,

        ROUND(
            STDDEV_SAMP(win_percentage),
            2
        ) AS win_percentage_standard_deviation,

        ROUND(
            MIN(points_per_match),
            3
        ) AS minimum_season_points_per_match,

        ROUND(
            MAX(points_per_match),
            3
        ) AS maximum_season_points_per_match

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
    *,

    DENSE_RANK() OVER (
        ORDER BY
            overall_win_percentage DESC,
            overall_points_per_match DESC,
            goal_difference DESC
    ) AS overall_performance_rank,

    DENSE_RANK() OVER (
        ORDER BY
            points_per_match_standard_deviation ASC,
            win_percentage_standard_deviation ASC
    ) AS overall_consistency_rank,

    DENSE_RANK() OVER (
        PARTITION BY competition_id
        ORDER BY
            overall_win_percentage DESC,
            overall_points_per_match DESC
    ) AS league_performance_rank

FROM club_summary

ORDER BY
    overall_performance_rank,
    club_name;

-- ============================================================
-- EXPORT 3: HOME VERSUS AWAY COMPARISON
-- SUPPORTS QUESTIONS: 4, 5 AND 6
-- ELIGIBILITY: FIVE COMPLETE SEASONS
-- ============================================================

WITH home_away_summary AS (

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
        ) AS home_win_percentage,

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
    *,

    ROUND(
        home_win_percentage - away_win_percentage,
        2
    ) AS home_away_win_percentage_gap,

    ABS(
        ROUND(
            home_win_percentage - away_win_percentage,
            2
        )
    ) AS absolute_home_away_gap,

    CASE
        WHEN home_win_percentage > away_win_percentage
            THEN 'Stronger at home'
        WHEN home_win_percentage < away_win_percentage
            THEN 'Stronger away'
        ELSE 'Equal performance'
    END AS performance_profile,

    DENSE_RANK() OVER (
        ORDER BY
            home_win_percentage DESC,
            home_wins DESC
    ) AS home_performance_rank,

    DENSE_RANK() OVER (
        ORDER BY
            away_win_percentage DESC,
            away_wins DESC
    ) AS away_performance_rank,

    DENSE_RANK() OVER (
        ORDER BY
            ABS(
                home_win_percentage
                - away_win_percentage
            ) DESC
    ) AS home_away_gap_rank

FROM home_away_summary

ORDER BY
    home_away_gap_rank,
    club_name;

-- ============================================================
-- EXPORT 4: CLUB PERFORMANCE TRENDS
-- SUPPORTS QUESTIONS: 3 AND 10
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
        wins,
        draws,
        losses,
        points_earned,
        points_per_match,
        win_percentage,
        goals_scored,
        goals_conceded,
        goal_difference,

        ROUND(
            goal_difference::NUMERIC
            / NULLIF(matches_played, 0),
            3
        ) AS goal_difference_per_match

    FROM football.vw_club_season_performance
),

trend_metrics AS (

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

        LAG(points_per_match) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_points_per_match,

        LAG(win_percentage) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_win_percentage,

        LAG(goal_difference_per_match) OVER (
            PARTITION BY club_id
            ORDER BY season
        ) AS previous_goal_difference_per_match

    FROM season_metrics
)

SELECT
    club_id,
    club_name,
    competition_id,
    competition_name,
    country_name,
    season,
    season_label,
    previous_season_label,
    matches_played,
    wins,
    draws,
    losses,
    points_earned,
    points_per_match,
    win_percentage,
    goals_scored,
    goals_conceded,
    goal_difference,
    goal_difference_per_match,

    CASE
        WHEN previous_season = season - 1
        THEN ROUND(
            points_per_match
            - previous_points_per_match,
            3
        )
        ELSE NULL
    END AS points_per_match_change,

    CASE
        WHEN previous_season = season - 1
        THEN ROUND(
            win_percentage
            - previous_win_percentage,
            2
        )
        ELSE NULL
    END AS win_percentage_change,

    CASE
        WHEN previous_season = season - 1
        THEN ROUND(
            goal_difference_per_match
            - previous_goal_difference_per_match,
            3
        )
        ELSE NULL
    END AS goal_difference_per_match_change,

    CASE
        WHEN previous_season <> season - 1
          OR previous_season IS NULL
            THEN 'No consecutive comparison'
        WHEN points_per_match > previous_points_per_match
            THEN 'Improvement'
        WHEN points_per_match < previous_points_per_match
            THEN 'Decline'
        ELSE 'No change'
    END AS performance_direction

FROM trend_metrics

ORDER BY
    club_name,
    season;

-- ============================================================
-- EXPORT 5: PERFORMANCE RELATIVE TO ESTIMATED MARKET VALUE
-- SUPPORTS QUESTION: 8
--
-- ELIGIBILITY:
--   At least 80% of players with minutes must have an eligible
--   valuation dated within 180 days of the season-end reference.
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
        csp.wins,
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
    club_id,
    club_name,
    competition_id,
    competition_name,
    country_name,
    season,
    season_label,
    matches_played,
    wins,
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

    eligible_club_count,

    DENSE_RANK() OVER (
        PARTITION BY competition_id, season
        ORDER BY
            performance_residual DESC,
            points_per_match DESC
    ) AS efficiency_rank_within_league_season,

    DENSE_RANK() OVER (
        PARTITION BY season
        ORDER BY
            performance_residual DESC,
            points_per_match DESC
    ) AS efficiency_rank_across_leagues

FROM efficiency_results

ORDER BY
    season,
    performance_residual DESC,
    club_name;

-- ============================================================
-- EXPORT 6: LEAGUE GOAL COMPARISON
-- SUPPORTS QUESTION: 9
-- ============================================================

WITH league_season_goals AS (

    SELECT
        competition_id,
        competition_name,
        country_name,
        season,
        season_label,
        COUNT(*) AS matches_played,
        SUM(total_goals) AS total_goals,

        ROUND(
            AVG(total_goals)::NUMERIC,
            3
        ) AS average_goals_per_match,

        COUNT(*) FILTER (
            WHERE total_goals = 0
        ) AS goalless_matches,

        COUNT(*) FILTER (
            WHERE total_goals >= 4
        ) AS matches_with_four_plus_goals,

        MIN(total_goals) AS minimum_goals_in_match,
        MAX(total_goals) AS maximum_goals_in_match

    FROM football.vw_core_games

    GROUP BY
        competition_id,
        competition_name,
        country_name,
        season,
        season_label
)

SELECT
    *,

    DENSE_RANK() OVER (
        PARTITION BY season
        ORDER BY average_goals_per_match DESC
    ) AS scoring_rank_within_season,

    ROUND(
        100.0 * goalless_matches
        / NULLIF(matches_played, 0),
        2
    ) AS goalless_match_percentage,

    ROUND(
        100.0 * matches_with_four_plus_goals
        / NULLIF(matches_played, 0),
        2
    ) AS four_plus_goal_match_percentage

FROM league_season_goals

ORDER BY
    season,
    scoring_rank_within_season,
    competition_name;