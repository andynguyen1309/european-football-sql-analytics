-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 07a_theme_2_export_queries.sql
-- THEME: Player Performance and Consistency
--
-- PURPOSE:
--   Produce final reusable Theme 2 datasets for:
--   1. CSV export
--   2. Findings documentation
--   3. Tableau visualisation
--   4. GitHub portfolio presentation
--
-- DATABASE: eu_football_analytics
-- ANALYTICAL SCHEMA: football
-- AUTHOR: Andy Nguyen
--
-- EXECUTION ORDER:
--   Run after 07_player_performance.sql
--
-- STANDARD ELIGIBILITY:
--   - 900 minutes for per-90 comparisons
--   - 1,800 minutes for availability analysis
--   - Goalkeepers excluded from attacking rankings
--   - Under 23 means age 22 or younger at season end
-- ============================================================

SET search_path TO football, football_raw, public;

-- ============================================================
-- EXPORT 1: PLAYER-SEASON PRODUCTIVITY
-- SUPPORTS QUESTIONS: 1, 2 AND 3
--
-- ROW LEVEL:
--   One player-club-season
--
-- ELIGIBILITY:
--   At least 900 minutes; goalkeepers excluded.
-- ============================================================

WITH eligible_players AS (

    SELECT
        player_id,
        player_name,
        position,
        sub_position,
        preferred_foot,
        country_of_citizenship,
        date_of_birth,
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name,
        season,
        season_label,
        age_at_season_end,
        appearances,
        appearances_with_minutes,
        minutes_played,
        goals,
        assists,
        goal_contributions,
        goals_per_90,
        assists_per_90,
        goal_contributions_per_90,
        yellow_cards,
        red_cards

    FROM football.vw_player_season_performance

    WHERE minutes_played >= 900
      AND LOWER(position) <> 'goalkeeper'
)

SELECT
    *,

    DENSE_RANK() OVER (
        PARTITION BY competition_id, season
        ORDER BY
            goals_per_90 DESC,
            goals DESC,
            minutes_played DESC
    ) AS goals_per_90_league_season_rank,

    DENSE_RANK() OVER (
        PARTITION BY competition_id, season
        ORDER BY
            assists_per_90 DESC,
            assists DESC,
            minutes_played DESC
    ) AS assists_per_90_league_season_rank,

    DENSE_RANK() OVER (
        PARTITION BY competition_id, season
        ORDER BY
            goal_contributions_per_90 DESC,
            goal_contributions DESC,
            minutes_played DESC
    ) AS contributions_per_90_league_season_rank,

    DENSE_RANK() OVER (
        PARTITION BY position, competition_id, season
        ORDER BY
            goal_contributions_per_90 DESC,
            goal_contributions DESC,
            minutes_played DESC
    ) AS position_league_season_rank,

    DENSE_RANK() OVER (
        ORDER BY
            goals_per_90 DESC,
            goals DESC,
            minutes_played DESC
    ) AS goals_per_90_overall_rank,

    DENSE_RANK() OVER (
        ORDER BY
            assists_per_90 DESC,
            assists DESC,
            minutes_played DESC
    ) AS assists_per_90_overall_rank,

    DENSE_RANK() OVER (
        ORDER BY
            goal_contributions_per_90 DESC,
            goal_contributions DESC,
            minutes_played DESC
    ) AS contributions_per_90_overall_rank

FROM eligible_players

ORDER BY
    season,
    contributions_per_90_league_season_rank,
    player_name;

-- ============================================================
-- EXPORT 2: CLUB GOAL INVOLVEMENT
-- SUPPORTS QUESTION: 4
--
-- IMPORTANT:
--   Goal involvement percentage can exceed ordinary goal share
--   because a club goal may involve both a scorer and assister.
-- ============================================================

WITH player_club_contributions AS (

    SELECT
        ps.player_id,
        ps.player_name,
        ps.position,
        ps.sub_position,
        ps.country_of_citizenship,
        ps.club_id,
        ps.club_name,
        ps.competition_id,
        ps.competition_name,
        ps.country_name,
        ps.season,
        ps.season_label,
        ps.age_at_season_end,
        ps.appearances,
        ps.minutes_played,
        ps.goals,
        ps.assists,
        ps.goal_contributions,
        ps.goals_per_90,
        ps.assists_per_90,
        ps.goal_contributions_per_90,

        cs.matches_played AS club_matches,
        cs.goals_scored AS club_goals,
        cs.points_per_match AS club_points_per_match,
        cs.win_percentage AS club_win_percentage,

        ROUND(
            100.0 * ps.goals
            / NULLIF(cs.goals_scored, 0),
            2
        ) AS club_goal_share_percentage,

        ROUND(
            100.0 * ps.assists
            / NULLIF(cs.goals_scored, 0),
            2
        ) AS club_assist_share_percentage,

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
    *,

    DENSE_RANK() OVER (
        PARTITION BY competition_id, season
        ORDER BY
            club_goal_involvement_percentage DESC,
            goal_contributions DESC,
            minutes_played DESC
    ) AS involvement_league_season_rank,

    DENSE_RANK() OVER (
        PARTITION BY club_id, season
        ORDER BY
            club_goal_involvement_percentage DESC,
            goal_contributions DESC,
            minutes_played DESC
    ) AS involvement_club_season_rank,

    DENSE_RANK() OVER (
        ORDER BY
            club_goal_involvement_percentage DESC,
            goal_contributions DESC,
            minutes_played DESC
    ) AS involvement_overall_rank

FROM player_club_contributions

ORDER BY
    season,
    involvement_league_season_rank,
    player_name;

-- ============================================================
-- EXPORT 3: POSITION-SPECIFIC PLAYER RANKINGS
-- SUPPORTS QUESTION: 5
--
-- OUTFIELD METRIC:
--   Goal contributions per 90; minimum 900 minutes.
--
-- GOALKEEPER METRIC:
--   Availability percentage; minimum 1,800 minutes.
-- ============================================================

WITH position_metrics AS (

    SELECT
        ps.player_id,
        ps.player_name,
        ps.position,
        ps.sub_position,
        ps.country_of_citizenship,
        ps.club_id,
        ps.club_name,
        ps.competition_id,
        ps.competition_name,
        ps.country_name,
        ps.season,
        ps.season_label,
        ps.age_at_season_end,
        ps.appearances,
        ps.minutes_played,
        ps.goals,
        ps.assists,
        ps.goal_contributions,
        ps.goals_per_90,
        ps.assists_per_90,
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
        END AS ranking_metric,

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
        END AS ranking_metric_value

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
    *,

    DENSE_RANK() OVER (
        PARTITION BY position, competition_id, season
        ORDER BY
            ranking_metric_value DESC,
            minutes_played DESC
    ) AS position_league_season_rank,

    DENSE_RANK() OVER (
        PARTITION BY position, season
        ORDER BY
            ranking_metric_value DESC,
            minutes_played DESC
    ) AS position_season_rank,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            ranking_metric_value DESC,
            minutes_played DESC
    ) AS position_overall_rank

FROM position_metrics

ORDER BY
    position,
    season,
    position_league_season_rank,
    player_name;

-- ============================================================
-- EXPORT 4: YEAR-ON-YEAR PLAYER IMPROVEMENT
-- SUPPORTS QUESTION: 6
--
-- ROW LEVEL:
--   One player consecutive-season comparison
--
-- ELIGIBILITY:
--   At least 900 minutes in both seasons.
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

        STRING_AGG(
            DISTINCT club_name,
            ', '
            ORDER BY club_name
        ) AS clubs,

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

        LAG(age_at_season_end) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_age,

        LAG(clubs) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_clubs,

        LAG(minutes_played) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_minutes_played,

        LAG(goals) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_goals,

        LAG(assists) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_assists,

        LAG(goal_contributions) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_goal_contributions,

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
    player_id,
    player_name,
    position,
    sub_position,
    country_of_citizenship,
    previous_season_label,
    season_label AS current_season_label,
    previous_age,
    age_at_season_end AS current_age,
    previous_clubs,
    clubs AS current_clubs,
    previous_minutes_played,
    minutes_played AS current_minutes_played,
    previous_goals,
    goals AS current_goals,
    previous_assists,
    assists AS current_assists,
    previous_goal_contributions,
    goal_contributions AS current_goal_contributions,
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
    END AS performance_direction,

    DENSE_RANK() OVER (
        ORDER BY
            (
                goal_contributions_per_90
                - previous_goal_contributions_per_90
            ) DESC,
            (
                goals_per_90
                - previous_goals_per_90
            ) DESC
    ) AS improvement_rank,

    DENSE_RANK() OVER (
        ORDER BY
            (
                goal_contributions_per_90
                - previous_goal_contributions_per_90
            ) ASC,
            (
                goals_per_90
                - previous_goals_per_90
            ) ASC
    ) AS decline_rank

FROM previous_season_metrics

WHERE previous_season = season - 1
  AND previous_minutes_played >= 900
  AND minutes_played >= 900

ORDER BY
    improvement_rank,
    player_name;

-- ============================================================
-- EXPORT 5: SUSTAINED MULTI-SEASON PERFORMANCE
-- SUPPORTS QUESTION: 7
--
-- ELIGIBILITY:
--   At least three seasons with 900 or more minutes.
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

qualified_seasons AS (

    SELECT *
    FROM player_season_totals
    WHERE minutes_played >= 900
),

player_summary AS (

    SELECT
        player_id,
        MAX(player_name) AS player_name,
        MAX(position) AS position,
        MAX(sub_position) AS sub_position,
        MAX(country_of_citizenship) AS country_of_citizenship,

        COUNT(*) AS qualified_seasons,
        MIN(season) AS first_qualified_season,
        MAX(season) AS last_qualified_season,

        STRING_AGG(
            season_label,
            ', '
            ORDER BY season
        ) AS qualified_season_labels,

        SUM(minutes_played) AS total_minutes,
        SUM(goals) AS total_goals,
        SUM(assists) AS total_assists,
        SUM(goal_contributions) AS total_goal_contributions,

        ROUND(
            AVG(goals_per_90),
            3
        ) AS average_goals_per_90,

        ROUND(
            AVG(assists_per_90),
            3
        ) AS average_assists_per_90,

        ROUND(
            AVG(goal_contributions_per_90),
            3
        ) AS average_goal_contributions_per_90,

        ROUND(
            STDDEV_SAMP(goal_contributions_per_90),
            3
        ) AS contributions_per_90_standard_deviation,

        ROUND(
            MIN(goal_contributions_per_90),
            3
        ) AS minimum_contributions_per_90,

        ROUND(
            MAX(goal_contributions_per_90),
            3
        ) AS maximum_contributions_per_90

    FROM qualified_seasons

    GROUP BY player_id

    HAVING COUNT(*) >= 3
)

SELECT
    *,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            average_goal_contributions_per_90 DESC,
            contributions_per_90_standard_deviation ASC,
            total_minutes DESC
    ) AS sustained_position_rank,

    DENSE_RANK() OVER (
        ORDER BY
            average_goal_contributions_per_90 DESC,
            contributions_per_90_standard_deviation ASC,
            total_minutes DESC
    ) AS sustained_overall_rank,

    CASE
        WHEN average_goal_contributions_per_90 >= 0.75
         AND contributions_per_90_standard_deviation <= 0.15
            THEN 'High productivity and high consistency'
        WHEN average_goal_contributions_per_90 >= 0.75
            THEN 'High productivity'
        WHEN contributions_per_90_standard_deviation <= 0.15
            THEN 'High consistency'
        ELSE 'Moderate sustained performance'
    END AS sustained_performance_profile

FROM player_summary

ORDER BY
    sustained_overall_rank,
    player_name;

-- ============================================================
-- EXPORT 6: UNDER-23 MEANINGFUL LEAGUE MINUTES
-- SUPPORTS QUESTION: 8
--
-- DEFINITION:
--   Under 23 = age 22 or younger at season end.
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

        STRING_AGG(
            DISTINCT competition_name,
            ', '
            ORDER BY competition_name
        ) AS competitions,

        SUM(appearances) AS appearances,
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

    WHERE age_at_season_end <= 22

    GROUP BY
        player_id,
        season

    HAVING SUM(minutes_played) >= 900
)

SELECT
    *,

    DENSE_RANK() OVER (
        PARTITION BY season
        ORDER BY
            minutes_played DESC,
            appearances DESC
    ) AS under_23_minutes_season_rank,

    DENSE_RANK() OVER (
        PARTITION BY position, season
        ORDER BY
            minutes_played DESC,
            appearances DESC
    ) AS under_23_position_season_rank,

    DENSE_RANK() OVER (
        ORDER BY
            minutes_played DESC,
            appearances DESC
    ) AS under_23_minutes_overall_rank

FROM under_23_player_seasons

ORDER BY
    season,
    under_23_minutes_season_rank,
    player_name;

-- ============================================================
-- EXPORT 7: PRODUCTIVE PLAYERS AT LOWER-PERFORMING CLUBS
-- SUPPORTS QUESTION: 9
--
-- DEFINITION:
--   Lower-performing club = bottom half of its league-season
--   by points per match.
-- ============================================================

WITH ranked_clubs AS (

    SELECT
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name,
        season,
        season_label,
        matches_played,
        points_per_match,
        win_percentage,
        goals_scored,
        goals_conceded,
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
        ps.country_of_citizenship,
        ps.club_id,
        ps.club_name,
        ps.competition_id,
        ps.competition_name,
        ps.country_name,
        ps.season,
        ps.season_label,
        ps.age_at_season_end,
        ps.appearances,
        ps.minutes_played,
        ps.goals,
        ps.assists,
        ps.goal_contributions,
        ps.goals_per_90,
        ps.assists_per_90,
        ps.goal_contributions_per_90,

        lc.matches_played AS club_matches,
        lc.points_per_match AS club_points_per_match,
        lc.win_percentage AS club_win_percentage,
        lc.goals_scored AS club_goals,
        lc.goal_difference AS club_goal_difference,

        ROUND(
            100.0 * ps.goal_contributions
            / NULLIF(lc.goals_scored, 0),
            2
        ) AS club_goal_involvement_percentage

    FROM football.vw_player_season_performance AS ps

    JOIN lower_half_clubs AS lc
        ON ps.club_id = lc.club_id
       AND ps.competition_id = lc.competition_id
       AND ps.season = lc.season

    WHERE ps.minutes_played >= 900
      AND LOWER(ps.position) <> 'goalkeeper'
)

SELECT
    *,

    DENSE_RANK() OVER (
        PARTITION BY competition_id, season
        ORDER BY
            goal_contributions_per_90 DESC,
            goal_contributions DESC,
            club_goal_involvement_percentage DESC
    ) AS lower_half_league_season_rank,

    DENSE_RANK() OVER (
        ORDER BY
            goal_contributions_per_90 DESC,
            goal_contributions DESC,
            club_goal_involvement_percentage DESC
    ) AS lower_half_overall_rank

FROM eligible_players

ORDER BY
    season,
    lower_half_league_season_rank,
    player_name;

-- ============================================================
-- EXPORT 8: PRODUCTIVITY AND AVAILABILITY
-- SUPPORTS QUESTION: 10
--
-- ELIGIBILITY:
--   At least 1,800 minutes; goalkeepers excluded.
--
-- SCORE:
--   50% goal-contribution productivity percentile
--   50% availability percentile
-- ============================================================

WITH eligible_players AS (

    SELECT
        ps.player_id,
        ps.player_name,
        ps.position,
        ps.sub_position,
        ps.country_of_citizenship,
        ps.club_id,
        ps.club_name,
        ps.competition_id,
        ps.competition_name,
        ps.country_name,
        ps.season,
        ps.season_label,
        ps.age_at_season_end,
        ps.appearances,
        ps.minutes_played,
        ps.goals,
        ps.assists,
        ps.goal_contributions,
        ps.goals_per_90,
        ps.assists_per_90,
        ps.goal_contributions_per_90,

        cs.matches_played AS club_matches,
        cs.points_per_match AS club_points_per_match,

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
    *,

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
        PARTITION BY competition_id, season
        ORDER BY
            productivity_availability_score DESC,
            goal_contributions_per_90 DESC,
            availability_percentage DESC
    ) AS combined_league_season_rank,

    DENSE_RANK() OVER (
        ORDER BY
            productivity_availability_score DESC,
            goal_contributions_per_90 DESC,
            availability_percentage DESC
    ) AS combined_overall_rank

FROM combined_scores

ORDER BY
    season,
    combined_league_season_rank,
    player_name;

-- ============================================================
-- FINAL EXPORT VALIDATION
-- ============================================================


-- Confirm the main productivity population is non-empty.
SELECT
    COUNT(*) AS qualified_productivity_rows
FROM football.vw_player_season_performance
WHERE minutes_played >= 900
  AND LOWER(position) <> 'goalkeeper';


-- Confirm the high-availability population is non-empty.
SELECT
    COUNT(*) AS qualified_availability_rows
FROM football.vw_player_season_performance
WHERE minutes_played >= 1800
  AND LOWER(position) <> 'goalkeeper';


-- Confirm qualified under-23 records exist.
SELECT
    COUNT(*) AS qualified_under_23_rows
FROM football.vw_player_season_performance
WHERE age_at_season_end <= 22
  AND minutes_played >= 900;


-- Check available position values before visualisation.
SELECT
    position,
    COUNT(*) AS player_club_season_rows
FROM football.vw_player_season_performance
GROUP BY position
ORDER BY position;

-- ============================================================
-- THEME 2 EXPORT SUMMARY
--
-- OUTPUTS:
--   1. player_season_productivity.csv
--      Questions 1, 2 and 3
--
--   2. club_goal_involvement.csv
--      Question 4
--
--   3. position_rankings.csv
--      Question 5
--
--   4. year_on_year_improvement.csv
--      Question 6
--
--   5. sustained_player_performance.csv
--      Question 7
--
--   6. under_23_minutes.csv
--      Question 8
--
--   7. lower_performing_club_players.csv
--      Question 9
--
--   8. productivity_availability.csv
--      Question 10
--
-- These exports preserve the correct analytical grain for
-- each business question rather than forcing incompatible
-- outputs into one dataset.
-- ============================================================


-- ============================================================
-- END OF FILE
-- Next deliverable:
-- documentation/theme_2_player_performance_findings.md
-- ============================================================