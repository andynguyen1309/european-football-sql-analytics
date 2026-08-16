-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 07_player_performance.sql
-- THEME: Player Performance and Consistency
--
-- BUSINESS OBJECTIVE:
--   Identify productive, reliable and improving players while
--   making fair comparisons across positions and playing time.
--
-- QUESTIONS:
--   1. Which players recorded the highest goals per 90?
--   2. Which players recorded the highest assists per 90?
--   3. Which players generated the highest combined goal
--      contributions per 90?
--   4. Which players contributed the greatest share of their
--      club's total goals or goal contributions?
--   5. Which players ranked highest within their position?
--   6. Which players showed the greatest year-on-year
--      improvement?
--   7. Which players maintained strong performance across
--      several seasons?
--   8. Which under-23 players accumulated the most meaningful
--      league minutes?
--   9. Which players produced strong results despite playing
--      for lower-performing clubs?
--  10. Which players combined high productivity with reliable
--      availability?
--
-- DATABASE: eu_football_analytics
-- ANALYTICAL SCHEMA: football
-- AUTHOR: Andy Nguyen
--
-- EXECUTION ORDER:
--   Run after 06_club_league_performance.sql
--
-- CORE SCOPE:
--   Competitions: GB1, ES1, L1, IT1, FR1
--   Seasons: 2020 to 2024
--
-- METHODOLOGICAL RULES:
--   - 900 minutes is the standard per-90 qualification.
--   - 1,800 minutes is used for high-availability analysis.
--   - Under 23 means age_at_season_end <= 22.
--   - Goalkeepers are excluded from attacking rankings.
--   - Historical club-season membership is retained.
--   - Total output and per-90 output are reported separately.
--
-- IMPORTANT:
--   This file performs analysis only.
--   It does not modify raw or cleaned source data.
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


SELECT *
FROM football.vw_project_scope_summary
ORDER BY metric;

-- ============================================================
-- QUESTION 1
-- Which players recorded the highest goals per 90 minutes?
--
-- ELIGIBILITY:
--   - At least 900 league minutes
--   - Goalkeepers excluded
-- ============================================================

WITH eligible_players AS (

    SELECT
        player_id,
        player_name,
        position,
        sub_position,
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name,
        season,
        season_label,
        age_at_season_end,
        appearances,
        minutes_played,
        goals,
        assists,
        goal_contributions,
        goals_per_90,
        assists_per_90,
        goal_contributions_per_90

    FROM football.vw_player_season_performance

    WHERE minutes_played >= 900
      AND LOWER(position) <> 'goalkeeper'
)

SELECT
    player_name,
    position,
    sub_position,
    club_name,
    competition_name,
    season_label,
    age_at_season_end,
    appearances,
    minutes_played,
    goals,
    goals_per_90,

    DENSE_RANK() OVER (
        PARTITION BY competition_id, season
        ORDER BY
            goals_per_90 DESC,
            goals DESC,
            minutes_played DESC
    ) AS league_season_goals_per_90_rank,

    DENSE_RANK() OVER (
        ORDER BY
            goals_per_90 DESC,
            goals DESC,
            minutes_played DESC
    ) AS overall_goals_per_90_rank

FROM eligible_players

ORDER BY
    overall_goals_per_90_rank,
    player_name;

-- ============================================================
-- QUESTION 2
-- Which players recorded the highest assists per 90 minutes?
--
-- ELIGIBILITY:
--   - At least 900 league minutes
--   - Goalkeepers excluded
-- ============================================================

WITH eligible_players AS (

    SELECT
        player_id,
        player_name,
        position,
        sub_position,
        club_name,
        competition_id,
        competition_name,
        season,
        season_label,
        age_at_season_end,
        appearances,
        minutes_played,
        goals,
        assists,
        assists_per_90

    FROM football.vw_player_season_performance

    WHERE minutes_played >= 900
      AND LOWER(position) <> 'goalkeeper'
)

SELECT
    player_name,
    position,
    sub_position,
    club_name,
    competition_name,
    season_label,
    age_at_season_end,
    appearances,
    minutes_played,
    assists,
    assists_per_90,

    DENSE_RANK() OVER (
        PARTITION BY competition_id, season
        ORDER BY
            assists_per_90 DESC,
            assists DESC,
            minutes_played DESC
    ) AS league_season_assists_per_90_rank,

    DENSE_RANK() OVER (
        ORDER BY
            assists_per_90 DESC,
            assists DESC,
            minutes_played DESC
    ) AS overall_assists_per_90_rank

FROM eligible_players

ORDER BY
    overall_assists_per_90_rank,
    player_name;

-- ============================================================
-- QUESTION 3
-- Which players generated the highest combined goal
-- contributions per 90 minutes?
--
-- ELIGIBILITY:
--   - At least 900 league minutes
--   - Goalkeepers excluded
-- ============================================================

WITH eligible_players AS (

    SELECT
        player_id,
        player_name,
        position,
        sub_position,
        club_name,
        competition_id,
        competition_name,
        season,
        season_label,
        age_at_season_end,
        appearances,
        minutes_played,
        goals,
        assists,
        goal_contributions,
        goals_per_90,
        assists_per_90,
        goal_contributions_per_90

    FROM football.vw_player_season_performance

    WHERE minutes_played >= 900
      AND LOWER(position) <> 'goalkeeper'
)

SELECT
    player_name,
    position,
    sub_position,
    club_name,
    competition_name,
    season_label,
    age_at_season_end,
    appearances,
    minutes_played,
    goals,
    assists,
    goal_contributions,
    goal_contributions_per_90,

    DENSE_RANK() OVER (
        PARTITION BY competition_id, season
        ORDER BY
            goal_contributions_per_90 DESC,
            goal_contributions DESC,
            minutes_played DESC
    ) AS league_season_contribution_rank,

    DENSE_RANK() OVER (
        ORDER BY
            goal_contributions_per_90 DESC,
            goal_contributions DESC,
            minutes_played DESC
    ) AS overall_contribution_rank

FROM eligible_players

ORDER BY
    overall_contribution_rank,
    player_name;

-- ============================================================
-- QUESTION 4
-- Which players contributed the greatest share of their club's
-- total goals or goal contributions?
--
-- ELIGIBILITY:
--   - At least 900 minutes for the club-season
--   - Goalkeepers excluded
-- ============================================================

WITH player_club_contributions AS (

    SELECT
        ps.player_id,
        ps.player_name,
        ps.position,
        ps.sub_position,
        ps.club_id,
        ps.club_name,
        ps.competition_id,
        ps.competition_name,
        ps.season,
        ps.season_label,
        ps.age_at_season_end,
        ps.appearances,
        ps.minutes_played,
        ps.goals,
        ps.assists,
        ps.goal_contributions,
        ps.goal_contributions_per_90,

        cs.matches_played AS club_matches,
        cs.goals_scored AS club_goals,

        ROUND(
            100.0 * ps.goals
            / NULLIF(cs.goals_scored, 0),
            2
        ) AS club_goal_share_percentage,

        ROUND(
            100.0 * ps.goal_contributions
            / NULLIF(cs.goals_scored, 0),
            2
        ) AS club_goal_involvement_percentage

    FROM football.vw_player_season_performance AS ps

    JOIN football.vw_club_season_performance AS cs
        ON ps.club_id = cs.club_id
       AND ps.competition_id = cs.competition_id
       AND ps.season = cs.season

    WHERE ps.minutes_played >= 900
      AND LOWER(ps.position) <> 'goalkeeper'
)

SELECT
    player_name,
    position,
    sub_position,
    club_name,
    competition_name,
    season_label,
    age_at_season_end,
    appearances,
    minutes_played,
    club_matches,
    club_goals,
    goals,
    assists,
    goal_contributions,
    goal_contributions_per_90,
    club_goal_share_percentage,
    club_goal_involvement_percentage,

    DENSE_RANK() OVER (
        PARTITION BY competition_id, season
        ORDER BY
            club_goal_involvement_percentage DESC,
            goal_contributions DESC
    ) AS league_season_involvement_rank,

    DENSE_RANK() OVER (
        ORDER BY
            club_goal_involvement_percentage DESC,
            goal_contributions DESC
    ) AS overall_involvement_rank

FROM player_club_contributions

ORDER BY
    overall_involvement_rank,
    player_name;

-- ============================================================
-- QUESTION 5
-- Which players ranked highest within their position?
--
-- OUTfield metric:
--   Goal contributions per 90, minimum 900 minutes.
--
-- GOALKEEPER metric:
--   Availability percentage, minimum 1,800 minutes.
-- ============================================================

WITH player_position_metrics AS (

    SELECT
        ps.player_id,
        ps.player_name,
        ps.position,
        ps.sub_position,
        ps.club_id,
        ps.club_name,
        ps.competition_id,
        ps.competition_name,
        ps.season,
        ps.season_label,
        ps.age_at_season_end,
        ps.appearances,
        ps.minutes_played,
        ps.goals,
        ps.assists,
        ps.goal_contributions,
        ps.goal_contributions_per_90,
        cs.matches_played AS club_matches,

        ROUND(
            LEAST(
                100.0,
                100.0 * ps.minutes_played
                / NULLIF(cs.matches_played * 90, 0)
            ),
            2
        ) AS availability_percentage,

        CASE
            WHEN LOWER(ps.position) = 'goalkeeper'
                THEN 'Availability percentage'
            ELSE 'Goal contributions per 90'
        END AS position_ranking_metric,

        CASE
            WHEN LOWER(ps.position) = 'goalkeeper'
                THEN ROUND(
                    LEAST(
                        100.0,
                        100.0 * ps.minutes_played
                        / NULLIF(cs.matches_played * 90, 0)
                    ),
                    3
                )
            ELSE ps.goal_contributions_per_90
        END AS position_metric_value

    FROM football.vw_player_season_performance AS ps

    JOIN football.vw_club_season_performance AS cs
        ON ps.club_id = cs.club_id
       AND ps.competition_id = cs.competition_id
       AND ps.season = cs.season

    WHERE (
            LOWER(ps.position) <> 'goalkeeper'
            AND ps.minutes_played >= 900
          )
       OR (
            LOWER(ps.position) = 'goalkeeper'
            AND ps.minutes_played >= 1800
          )
)

SELECT
    player_name,
    position,
    sub_position,
    club_name,
    competition_name,
    season_label,
    age_at_season_end,
    appearances,
    minutes_played,
    goals,
    assists,
    goal_contributions,
    goal_contributions_per_90,
    availability_percentage,
    position_ranking_metric,
    position_metric_value,

    DENSE_RANK() OVER (
        PARTITION BY
            position,
            competition_id,
            season
        ORDER BY
            position_metric_value DESC,
            minutes_played DESC
    ) AS position_league_season_rank,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            position_metric_value DESC,
            minutes_played DESC
    ) AS overall_position_rank

FROM player_position_metrics

ORDER BY
    position,
    overall_position_rank,
    player_name;

-- ============================================================
-- QUESTION 6
-- Which players showed the greatest year-on-year improvement?
--
-- METHODOLOGY:
--   - Aggregate player performance across clubs within a season.
--   - Compare only consecutive seasons.
--   - Require at least 900 minutes in both seasons.
--   - Goalkeepers excluded.
-- ============================================================

WITH player_season_totals AS (

    SELECT
        player_id,
        MAX(player_name) AS player_name,
        MAX(position) AS position,
        MAX(sub_position) AS sub_position,
        MAX(country_of_citizenship) AS country_of_citizenship,
        season,
        MAX(season_label) AS season_label,
        MAX(age_at_season_end) AS age_at_season_end,

        COUNT(DISTINCT club_id) AS clubs_represented,
        SUM(appearances) AS appearances,
        SUM(minutes_played) AS minutes_played,
        SUM(goals) AS goals,
        SUM(assists) AS assists,
        SUM(goal_contributions) AS goal_contributions,

        ROUND(
            90.0 * SUM(goals)
            / NULLIF(SUM(minutes_played), 0),
            3
        ) AS goals_per_90,

        ROUND(
            90.0 * SUM(assists)
            / NULLIF(SUM(minutes_played), 0),
            3
        ) AS assists_per_90,

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

previous_season_metrics AS (

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

        LAG(minutes_played) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_minutes_played,

        LAG(goals_per_90) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_goals_per_90,

        LAG(assists_per_90) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_assists_per_90,

        LAG(goal_contributions_per_90) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_goal_contributions_per_90

    FROM player_season_totals
)

SELECT
    player_name,
    position,
    sub_position,
    previous_season_label,
    season_label AS current_season_label,
    previous_minutes_played,
    minutes_played AS current_minutes_played,
    previous_goals_per_90,
    goals_per_90 AS current_goals_per_90,
    previous_assists_per_90,
    assists_per_90 AS current_assists_per_90,
    previous_goal_contributions_per_90,
    goal_contributions_per_90
        AS current_goal_contributions_per_90,

    ROUND(
        goals_per_90 - previous_goals_per_90,
        3
    ) AS goals_per_90_change,

    ROUND(
        assists_per_90 - previous_assists_per_90,
        3
    ) AS assists_per_90_change,

    ROUND(
        goal_contributions_per_90
        - previous_goal_contributions_per_90,
        3
    ) AS goal_contributions_per_90_change,

    CASE
        WHEN goal_contributions_per_90
             > previous_goal_contributions_per_90
            THEN 'Improvement'
        WHEN goal_contributions_per_90
             < previous_goal_contributions_per_90
            THEN 'Decline'
        ELSE 'No change'
    END AS performance_direction

FROM previous_season_metrics

WHERE previous_season = season - 1
  AND previous_minutes_played >= 900
  AND minutes_played >= 900

ORDER BY
    goal_contributions_per_90_change DESC,
    goals_per_90_change DESC,
    assists_per_90_change DESC;

-- ============================================================
-- QUESTION 7
-- Which players maintained strong performance across several
-- seasons?
--
-- ELIGIBILITY:
--   - At least 900 minutes in each included season
--   - At least three qualified seasons
--   - Goalkeepers excluded
--
-- INTERPRETATION:
--   Higher average productivity is preferred.
--   Lower standard deviation indicates greater consistency.
-- ============================================================

WITH player_season_totals AS (

    SELECT
        player_id,
        MAX(player_name) AS player_name,
        MAX(position) AS position,
        MAX(sub_position) AS sub_position,
        MAX(country_of_citizenship) AS country_of_citizenship,
        season,
        MAX(season_label) AS season_label,
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

qualified_seasons AS (

    SELECT *
    FROM player_season_totals
    WHERE minutes_played >= 900
),

multi_season_summary AS (

    SELECT
        player_id,
        MAX(player_name) AS player_name,
        MAX(position) AS position,
        MAX(sub_position) AS sub_position,
        MAX(country_of_citizenship) AS country_of_citizenship,

        COUNT(*) AS qualified_seasons,
        MIN(season) AS first_qualified_season,
        MAX(season) AS last_qualified_season,
        SUM(minutes_played) AS total_minutes,
        SUM(goals) AS total_goals,
        SUM(assists) AS total_assists,
        SUM(goal_contributions) AS total_goal_contributions,

        ROUND(
            AVG(goal_contributions_per_90),
            3
        ) AS average_goal_contributions_per_90,

        ROUND(
            STDDEV_SAMP(goal_contributions_per_90),
            3
        ) AS goal_contributions_per_90_standard_deviation,

        ROUND(
            MIN(goal_contributions_per_90),
            3
        ) AS minimum_season_contributions_per_90,

        ROUND(
            MAX(goal_contributions_per_90),
            3
        ) AS maximum_season_contributions_per_90

    FROM qualified_seasons

    GROUP BY player_id

    HAVING COUNT(*) >= 3
)

SELECT
    player_name,
    position,
    sub_position,
    country_of_citizenship,
    qualified_seasons,
    first_qualified_season,
    last_qualified_season,
    total_minutes,
    total_goals,
    total_assists,
    total_goal_contributions,
    average_goal_contributions_per_90,
    goal_contributions_per_90_standard_deviation,
    minimum_season_contributions_per_90,
    maximum_season_contributions_per_90,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            average_goal_contributions_per_90 DESC,
            goal_contributions_per_90_standard_deviation ASC,
            total_minutes DESC
    ) AS sustained_position_rank,

    DENSE_RANK() OVER (
        ORDER BY
            average_goal_contributions_per_90 DESC,
            goal_contributions_per_90_standard_deviation ASC,
            total_minutes DESC
    ) AS sustained_overall_rank

FROM multi_season_summary

ORDER BY
    sustained_overall_rank,
    player_name;

-- ============================================================
-- QUESTION 8
-- Which under-23 players accumulated the most meaningful
-- league minutes?
--
-- DEFINITION:
--   Under 23 = age_at_season_end <= 22.
--
-- ELIGIBILITY:
--   At least 900 minutes in the season.
-- ============================================================

WITH under_23_player_seasons AS (

    SELECT
        player_id,
        MAX(player_name) AS player_name,
        MAX(position) AS position,
        MAX(sub_position) AS sub_position,
        MAX(country_of_citizenship) AS country_of_citizenship,
        season,
        MAX(season_label) AS season_label,
        MAX(age_at_season_end) AS age_at_season_end,
        COUNT(DISTINCT club_id) AS clubs_represented,
        STRING_AGG(
            DISTINCT club_name,
            ', '
            ORDER BY club_name
        ) AS clubs,
        SUM(appearances) AS appearances,
        SUM(minutes_played) AS minutes_played,
        SUM(goals) AS goals,
        SUM(assists) AS assists,
        SUM(goal_contributions) AS goal_contributions

    FROM football.vw_player_season_performance

    WHERE age_at_season_end <= 22

    GROUP BY
        player_id,
        season

    HAVING SUM(minutes_played) >= 900
)

SELECT
    player_name,
    position,
    sub_position,
    country_of_citizenship,
    season_label,
    age_at_season_end,
    clubs_represented,
    clubs,
    appearances,
    minutes_played,
    goals,
    assists,
    goal_contributions,

    DENSE_RANK() OVER (
        PARTITION BY season
        ORDER BY
            minutes_played DESC,
            appearances DESC
    ) AS under_23_season_minutes_rank,

    DENSE_RANK() OVER (
        PARTITION BY position, season
        ORDER BY
            minutes_played DESC,
            appearances DESC
    ) AS under_23_position_minutes_rank

FROM under_23_player_seasons

ORDER BY
    season,
    under_23_season_minutes_rank,
    player_name;

-- ============================================================
-- QUESTION 9
-- Which players produced strong results despite playing for
-- lower-performing clubs?
--
-- DEFINITION:
--   Lower-performing club = bottom half of its league-season
--   based on points per match.
--
-- ELIGIBILITY:
--   - At least 900 minutes
--   - Goalkeepers excluded
-- ============================================================

WITH ranked_clubs AS (

    SELECT
        club_id,
        club_name,
        competition_id,
        competition_name,
        season,
        season_label,
        matches_played,
        points_per_match,
        win_percentage,
        goal_difference,

        NTILE(2) OVER (
            PARTITION BY competition_id, season
            ORDER BY
                points_per_match DESC,
                goal_difference DESC
        ) AS league_half

    FROM football.vw_club_season_performance
),

lower_half_clubs AS (

    SELECT *
    FROM ranked_clubs
    WHERE league_half = 2
),

eligible_players AS (

    SELECT
        ps.player_id,
        ps.player_name,
        ps.position,
        ps.sub_position,
        ps.club_id,
        ps.club_name,
        ps.competition_id,
        ps.competition_name,
        ps.season,
        ps.season_label,
        ps.age_at_season_end,
        ps.appearances,
        ps.minutes_played,
        ps.goals,
        ps.assists,
        ps.goal_contributions,
        ps.goal_contributions_per_90,

        lc.points_per_match AS club_points_per_match,
        lc.win_percentage AS club_win_percentage,
        lc.goal_difference AS club_goal_difference

    FROM football.vw_player_season_performance AS ps

    JOIN lower_half_clubs AS lc
        ON ps.club_id = lc.club_id
       AND ps.competition_id = lc.competition_id
       AND ps.season = lc.season

    WHERE ps.minutes_played >= 900
      AND LOWER(ps.position) <> 'goalkeeper'
)

SELECT
    player_name,
    position,
    sub_position,
    club_name,
    competition_name,
    season_label,
    age_at_season_end,
    appearances,
    minutes_played,
    goals,
    assists,
    goal_contributions,
    goal_contributions_per_90,
    club_points_per_match,
    club_win_percentage,
    club_goal_difference,

    DENSE_RANK() OVER (
        PARTITION BY competition_id, season
        ORDER BY
            goal_contributions_per_90 DESC,
            goal_contributions DESC,
            minutes_played DESC
    ) AS lower_half_league_season_rank,

    DENSE_RANK() OVER (
        ORDER BY
            goal_contributions_per_90 DESC,
            goal_contributions DESC,
            minutes_played DESC
    ) AS lower_half_overall_rank

FROM eligible_players

ORDER BY
    lower_half_overall_rank,
    player_name;

-- ============================================================
-- QUESTION 10
-- Which players combined high productivity with reliable
-- availability?
--
-- ELIGIBILITY:
--   - At least 1,800 minutes
--   - Goalkeepers excluded
--
-- COMPOSITE SCORE:
--   50% productivity percentile
--   50% availability percentile
-- ============================================================

WITH eligible_players AS (

    SELECT
        ps.player_id,
        ps.player_name,
        ps.position,
        ps.sub_position,
        ps.club_id,
        ps.club_name,
        ps.competition_id,
        ps.competition_name,
        ps.season,
        ps.season_label,
        ps.age_at_season_end,
        ps.appearances,
        ps.minutes_played,
        ps.goals,
        ps.assists,
        ps.goal_contributions,
        ps.goal_contributions_per_90,

        cs.matches_played AS club_matches,

        ROUND(
            LEAST(
                100.0,
                100.0 * ps.minutes_played
                / NULLIF(cs.matches_played * 90, 0)
            ),
            2
        ) AS availability_percentage

    FROM football.vw_player_season_performance AS ps

    JOIN football.vw_club_season_performance AS cs
        ON ps.club_id = cs.club_id
       AND ps.competition_id = cs.competition_id
       AND ps.season = cs.season

    WHERE ps.minutes_played >= 1800
      AND LOWER(ps.position) <> 'goalkeeper'
),

percentile_scores AS (

    SELECT
        *,

        PERCENT_RANK() OVER (
            PARTITION BY
                position,
                competition_id,
                season
            ORDER BY goal_contributions_per_90
        ) AS productivity_percentile,

        PERCENT_RANK() OVER (
            PARTITION BY
                position,
                competition_id,
                season
            ORDER BY availability_percentage
        ) AS availability_percentile

    FROM eligible_players
),

combined_scores AS (

    SELECT
        *,

        ROUND(
    		(100.0 * productivity_percentile)::NUMERIC,
    		2
		) AS productivity_percentile_score,


        ROUND(
            (100.0 * availability_percentile)::NUMERIC,
            2
        ) AS availability_percentile_score,

        ROUND(
        	(
            100.0
            * (
                productivity_percentile
                + availability_percentile
            )
            / 2.0
        )::NUMERIC,
         	2
        ) AS productivity_availability_score

    FROM percentile_scores
)

SELECT
    player_name,
    position,
    sub_position,
    club_name,
    competition_name,
    season_label,
    age_at_season_end,
    appearances,
    club_matches,
    minutes_played,
    availability_percentage,
    goals,
    assists,
    goal_contributions,
    goal_contributions_per_90,
    productivity_percentile_score,
    availability_percentile_score,
    productivity_availability_score,

    DENSE_RANK() OVER (
        PARTITION BY
            position,
            competition_id,
            season
        ORDER BY
            productivity_availability_score DESC,
            goal_contributions_per_90 DESC,
            availability_percentage DESC
    ) AS combined_position_league_season_rank,

    DENSE_RANK() OVER (
        ORDER BY
            productivity_availability_score DESC,
            goal_contributions_per_90 DESC,
            availability_percentage DESC
    ) AS combined_overall_rank

FROM combined_scores

ORDER BY
    combined_overall_rank,
    player_name;

-- ============================================================
-- FINAL THEME 2 VALIDATION CHECKS
-- ============================================================


-- ------------------------------------------------------------
-- V1. Confirm one row per player-club-season.
-- Expected result: zero rows.
-- ------------------------------------------------------------

SELECT
    player_id,
    club_id,
    competition_id,
    season,
    COUNT(*) AS row_count
FROM football.vw_player_season_performance
GROUP BY
    player_id,
    club_id,
    competition_id,
    season
HAVING COUNT(*) > 1;


-- ------------------------------------------------------------
-- V2. Confirm no negative attacking statistics.
-- Expected result: zero rows.
-- ------------------------------------------------------------

SELECT
    player_name,
    club_name,
    competition_name,
    season_label,
    minutes_played,
    goals,
    assists,
    goal_contributions
FROM football.vw_player_season_performance
WHERE minutes_played < 0
   OR goals < 0
   OR assists < 0
   OR goal_contributions < 0;


-- ------------------------------------------------------------
-- V3. Confirm goal contributions equal goals plus assists.
-- Expected result: zero rows.
-- ------------------------------------------------------------

SELECT
    player_name,
    club_name,
    competition_name,
    season_label,
    goals,
    assists,
    goal_contributions
FROM football.vw_player_season_performance
WHERE goal_contributions <> goals + assists;


-- ------------------------------------------------------------
-- V4. Confirm per-90 metrics are absent when minutes are zero.
-- Expected result: zero rows.
-- ------------------------------------------------------------

SELECT
    player_name,
    club_name,
    season_label,
    minutes_played,
    goals_per_90,
    assists_per_90,
    goal_contributions_per_90
FROM football.vw_player_season_performance
WHERE COALESCE(minutes_played, 0) = 0
  AND (
       goals_per_90 IS NOT NULL
       OR assists_per_90 IS NOT NULL
       OR goal_contributions_per_90 IS NOT NULL
  );


-- ------------------------------------------------------------
-- V5. Review the distribution of qualified player-seasons.
-- ------------------------------------------------------------

SELECT
    position,
    COUNT(*) AS player_club_seasons,
    COUNT(*) FILTER (
        WHERE minutes_played >= 900
    ) AS qualified_900_minutes,
    COUNT(*) FILTER (
        WHERE minutes_played >= 1800
    ) AS qualified_1800_minutes
FROM football.vw_player_season_performance
GROUP BY position
ORDER BY position;


-- ------------------------------------------------------------
-- V6. Confirm under-23 age rule.
-- Expected maximum age: 22.
-- ------------------------------------------------------------

SELECT
    MIN(age_at_season_end) AS minimum_age,
    MAX(age_at_season_end) AS maximum_age,
    COUNT(*) AS qualified_under_23_rows
FROM football.vw_player_season_performance
WHERE age_at_season_end <= 22
  AND minutes_played >= 900;


-- ------------------------------------------------------------
-- V7. Confirm player-club rows match club-season records.
-- Expected unmatched rows: zero.
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS unmatched_player_club_seasons
FROM football.vw_player_season_performance AS ps

LEFT JOIN football.vw_club_season_performance AS cs
    ON ps.club_id = cs.club_id
   AND ps.competition_id = cs.competition_id
   AND ps.season = cs.season

WHERE cs.club_id IS NULL;

-- ============================================================
-- THEME 2 ANALYSIS SUMMARY
--
-- QUESTIONS ANSWERED:
--   1. Highest goals per 90
--   2. Highest assists per 90
--   3. Highest goal contributions per 90
--   4. Largest share of club goal involvement
--   5. Position-specific player rankings
--   6. Greatest consecutive-season improvement
--   7. Sustained multi-season performance
--   8. Under-23 meaningful league minutes
--   9. Strong output at lower-performing clubs
--  10. Productivity combined with availability
--
-- MAIN SQL SKILLS DEMONSTRATED:
--   - Conditional eligibility rules
--   - Per-90 calculations
--   - Historical club-season joins
--   - Window functions
--   - DENSE_RANK
--   - LAG
--   - NTILE
--   - PERCENT_RANK
--   - Position-specific ranking logic
--   - Multi-season aggregation
--   - Standard deviation
--   - Composite scoring
--
-- IMPORTANT INTERPRETATION NOTES:
--   - Per-90 rankings require at least 900 minutes.
--   - Availability analysis requires at least 1,800 minutes.
--   - Goalkeepers are not ranked using attacking output.
--   - Goal-involvement percentage may include both a scorer
--     and an assister for the same club goal.
--   - Player-season totals combine club spells only where the
--     business question concerns total seasonal performance.
--   - Club-specific analyses preserve historical membership.
--   - The productivity-availability score is a transparent
--     percentile-based comparison, not a causal model.
-- ============================================================


-- ============================================================
-- END OF FILE
-- Next file: 07a_theme_2_export_queries.sql
-- ============================================================