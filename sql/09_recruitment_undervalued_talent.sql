-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 09_recruitment_undervalued_talent.sql
-- THEME: Recruitment and Potentially Undervalued Talent
--
-- BUSINESS OBJECTIVE:
--   Build an evidence-based recruitment shortlist combining:
--   - age
--   - performance
--   - playing time
--   - consistency
--   - year-on-year development
--   - estimated market value
--   - club and league context
--
-- PRIMARY RECRUITMENT SEASON:
--   2024-25
--
-- HISTORICAL WINDOW:
--   2020-21 to 2024-25
--
-- IMPORTANT:
--   Goalkeepers are not evaluated using goals/assists.
--   Their position-adjusted performance proxy is based on
--   availability because goalkeeper-specific metrics such as
--   saves, save percentage and clean sheets are unavailable.
--
--   Defender rankings use attacking contribution only within
--   the defender population. This is useful but incomplete
--   because defensive actions are unavailable in the dataset.
--
--   Market values are estimates, not actual transfer fees.
--
-- AUTHOR: Andy Nguyen
-- ============================================================

SET search_path TO football, football_raw, public;

-- ============================================================
-- A1. PLAYER-SEASON RECRUITMENT BASE
--
-- GRAIN:
--   One player per season.
--
-- MEMBERSHIP RULE:
--   If a player represented multiple clubs during a season,
--   the club where he played the most league minutes is used
--   as the primary club for recruitment context.
--
-- PERFORMANCE ELIGIBILITY:
--   Minimum 900 league minutes.
-- ============================================================

CREATE OR REPLACE VIEW football.vw_recruitment_player_season AS

WITH player_club_rows AS (

    SELECT
        ps.*,

        ROW_NUMBER() OVER (
            PARTITION BY ps.player_id, ps.season
            ORDER BY
                ps.minutes_played DESC,
                ps.appearances DESC,
                ps.club_id
        ) AS club_minutes_rank

    FROM football.vw_player_season_performance AS ps
),

player_season_totals AS (

    SELECT
        player_id,
        season,

        MAX(player_name) AS player_name,
        MAX(position) AS position,
        MAX(sub_position) AS sub_position,
        MAX(country_of_citizenship) AS country_of_citizenship,
        MAX(date_of_birth) AS date_of_birth,
        MAX(age_at_season_end) AS age_at_season_end,
        MAX(season_label) AS season_label,

        COUNT(DISTINCT club_id) AS clubs_represented,

        STRING_AGG(
            DISTINCT club_name,
            ', '
            ORDER BY club_name
        ) AS clubs_during_season,

        SUM(appearances) AS appearances,
        SUM(minutes_played) AS minutes_played,
        SUM(goals) AS goals,
        SUM(assists) AS assists,
        SUM(goal_contributions) AS goal_contributions,

        ROUND(
            (
                90.0 * SUM(goals)
                / NULLIF(SUM(minutes_played), 0)
            )::NUMERIC,
            3
        ) AS goals_per_90,

        ROUND(
            (
                90.0 * SUM(assists)
                / NULLIF(SUM(minutes_played), 0)
            )::NUMERIC,
            3
        ) AS assists_per_90,

        ROUND(
            (
                90.0 * SUM(goal_contributions)
                / NULLIF(SUM(minutes_played), 0)
            )::NUMERIC,
            3
        ) AS goal_contributions_per_90

    FROM player_club_rows

    GROUP BY
        player_id,
        season
),

primary_membership AS (

    SELECT
        player_id,
        season,
        club_id,
        club_name,
        competition_id,
        competition_name,
        country_name

    FROM player_club_rows

    WHERE club_minutes_rank = 1
),

valuation_seasons AS (

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
        valuation_date,
        market_value_in_eur

    FROM valuation_seasons

    WHERE season BETWEEN 2020 AND 2024

    ORDER BY
        player_id,
        season,
        valuation_date DESC
),

combined AS (

    SELECT
        ps.player_id,
        ps.player_name,
        ps.position,
        ps.sub_position,
        ps.country_of_citizenship,
        ps.date_of_birth,
        ps.age_at_season_end,

        ps.season,
        ps.season_label,

        pm.club_id,
        pm.club_name,
        pm.competition_id,
        pm.competition_name,
        pm.country_name,

        ps.clubs_represented,
        ps.clubs_during_season,

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
                / NULLIF(cs.matches_played * 90.0, 0)
            )::NUMERIC,
            2
        ) AS availability_percentage,

        sev.valuation_date,
        sev.market_value_in_eur,

        CASE
            WHEN ps.age_at_season_end <= 20
                THEN '20 or younger'
            WHEN ps.age_at_season_end <= 23
                THEN '21-23'
            WHEN ps.age_at_season_end <= 27
                THEN '24-27'
            WHEN ps.age_at_season_end <= 31
                THEN '28-31'
            ELSE '32+'
        END AS age_group

    FROM player_season_totals AS ps

    JOIN primary_membership AS pm
        ON ps.player_id = pm.player_id
       AND ps.season = pm.season

    LEFT JOIN football.vw_club_season_performance AS cs
        ON pm.club_id = cs.club_id
       AND pm.competition_id = cs.competition_id
       AND ps.season = cs.season

    LEFT JOIN season_end_values AS sev
        ON ps.player_id = sev.player_id
       AND ps.season = sev.season

    WHERE ps.minutes_played >= 900
),

performance_population AS (

    SELECT
        *,

        CASE
            WHEN LOWER(position) = 'goalkeeper'
                THEN availability_percentage
            ELSE goal_contributions_per_90
        END AS position_performance_metric

    FROM combined
),

performance_percentiles AS (

    SELECT
        *,

        ROUND(
            (
                100.0 * PERCENT_RANK() OVER (
                    PARTITION BY
                        season,
                        competition_id,
                        position
                    ORDER BY position_performance_metric
                )
            )::NUMERIC,
            2
        ) AS position_adjusted_performance_percentile,

        ROUND(
            (
                100.0 * PERCENT_RANK() OVER (
                    PARTITION BY
                        season,
                        competition_id,
                        position
                    ORDER BY availability_percentage
                )
            )::NUMERIC,
            2
        ) AS availability_percentile

    FROM performance_population
),

value_benchmarks AS (

    SELECT
        season,
        position,
        age_group,

        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY market_value_in_eur
        ) AS position_age_median_market_value_eur

    FROM performance_percentiles

    WHERE market_value_in_eur IS NOT NULL

    GROUP BY
        season,
        position,
        age_group
)

SELECT
    pp.*,

    vb.position_age_median_market_value_eur,

    ROUND(
        (
            100.0 * PERCENT_RANK() OVER (
                PARTITION BY
                    pp.season,
                    pp.position,
                    pp.age_group
                ORDER BY pp.market_value_in_eur
            )
        )::NUMERIC,
        2
    ) AS value_percentile_within_position_age,

    ROUND(
        (
            pp.position_adjusted_performance_percentile
            / NULLIF(pp.market_value_in_eur / 1000000.0, 0)
        )::NUMERIC,
        3
    ) AS performance_percentile_per_eur_million

FROM performance_percentiles AS pp

LEFT JOIN value_benchmarks AS vb
    ON pp.season = vb.season
   AND pp.position = vb.position
   AND pp.age_group = vb.age_group;

-- ============================================================
-- A2. HISTORICAL DEVELOPMENT AND CONSISTENCY
-- ============================================================

CREATE OR REPLACE VIEW football.vw_recruitment_history AS

WITH with_previous AS (

    SELECT
        *,

        LAG(season) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_season,

        LAG(position_adjusted_performance_percentile) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_performance_percentile,

        LAG(market_value_in_eur) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_market_value_eur,

        LAG(minutes_played) OVER (
            PARTITION BY player_id
            ORDER BY season
        ) AS previous_minutes_played

    FROM football.vw_recruitment_player_season
),

consistency AS (

    SELECT
        player_id,

        COUNT(*) AS qualified_seasons,

        ROUND(
            AVG(position_adjusted_performance_percentile)::NUMERIC,
            2
        ) AS average_performance_percentile,

        ROUND(
            STDDEV_SAMP(
                position_adjusted_performance_percentile
            )::NUMERIC,
            2
        ) AS performance_percentile_stddev,

        ROUND(
            MIN(position_adjusted_performance_percentile)::NUMERIC,
            2
        ) AS minimum_performance_percentile,

        SUM(minutes_played) AS total_qualified_minutes

    FROM football.vw_recruitment_player_season

    GROUP BY player_id
)

SELECT
    wp.*,

    CASE
        WHEN previous_season = season - 1
            THEN ROUND(
                (
                    position_adjusted_performance_percentile
                    - previous_performance_percentile
                )::NUMERIC,
                2
            )
    END AS yoy_performance_percentile_change,

    CASE
        WHEN previous_season = season - 1
            THEN market_value_in_eur
                 - previous_market_value_eur
    END AS yoy_market_value_change_eur,

    CASE
        WHEN previous_season = season - 1
         AND previous_market_value_eur > 0
            THEN ROUND(
                (
                    100.0
                    * (
                        market_value_in_eur
                        - previous_market_value_eur
                    )
                    / previous_market_value_eur
                )::NUMERIC,
                2
            )
    END AS yoy_market_value_percentage_change,

    c.qualified_seasons,
    c.average_performance_percentile,
    c.performance_percentile_stddev,
    c.minimum_performance_percentile,
    c.total_qualified_minutes

FROM with_previous AS wp

LEFT JOIN consistency AS c
    ON wp.player_id = c.player_id;

-- ============================================================
-- A3. CLUB VALUE CONTEXT
--
-- ELITE CLUB:
--   Top 20% of estimated squad values within league-season.
-- ============================================================

CREATE OR REPLACE VIEW football.vw_recruitment_club_context AS

WITH club_values AS (

    SELECT
        season,
        competition_id,
        competition_name,
        club_id,
        club_name,

        SUM(market_value_in_eur)
            AS estimated_squad_value_eur,

        COUNT(*) AS valued_players

    FROM football.vw_recruitment_player_season

    WHERE market_value_in_eur IS NOT NULL

    GROUP BY
        season,
        competition_id,
        competition_name,
        club_id,
        club_name
),

ranked AS (

    SELECT
        *,

        NTILE(5) OVER (
            PARTITION BY season, competition_id
            ORDER BY estimated_squad_value_eur DESC
        ) AS club_value_quintile

    FROM club_values
)

SELECT
    *,

    CASE
        WHEN club_value_quintile = 1
            THEN TRUE
        ELSE FALSE
    END AS is_elite_club

FROM ranked;

-- ============================================================
-- QUESTION 1
-- Which under-23 players produced above-average
-- position-adjusted performance?
--
-- CURRENT SEASON:
--   2024-25
--
-- U23:
--   Age <= 22
--
-- ABOVE AVERAGE:
--   Position-adjusted performance percentile >= 50
-- ============================================================

SELECT
    player_id,
    player_name,
    age_at_season_end AS age,
    position,
    sub_position,
    club_name,
    competition_name,
    minutes_played,
    goals,
    assists,
    goal_contributions,
    goal_contributions_per_90,
    availability_percentage,
    position_adjusted_performance_percentile,
    market_value_in_eur,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            position_adjusted_performance_percentile DESC,
            minutes_played DESC
    ) AS under_23_position_rank

FROM recruitment_history

WHERE season = 2024
  AND age_at_season_end <= 22
  AND position_adjusted_performance_percentile >= 50

ORDER BY
    position,
    under_23_position_rank,
    player_name;

-- ============================================================
-- QUESTION 2
-- Which high-performing players remained below the
-- market-value median for their position and age group?
--
-- HIGH PERFORMANCE:
--   >= 70th percentile
--
-- UNDERVALUED:
--   Current value below position-age median.
-- ============================================================

SELECT
    player_id,
    player_name,
    age_at_season_end AS age,
    age_group,
    position,
    sub_position,
    club_name,
    competition_name,

    minutes_played,
    goal_contributions_per_90,
    availability_percentage,

    position_adjusted_performance_percentile,

    market_value_in_eur,
    position_age_median_market_value_eur,

    position_age_median_market_value_eur
        - market_value_in_eur
        AS value_below_position_age_median_eur,

    value_percentile_within_position_age,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            position_adjusted_performance_percentile DESC,
            value_percentile_within_position_age ASC,
            market_value_in_eur ASC
    ) AS value_opportunity_rank

FROM recruitment_history

WHERE season = 2024

  AND position_adjusted_performance_percentile >= 70

  AND market_value_in_eur
      < position_age_median_market_value_eur

ORDER BY
    position,
    value_opportunity_rank,
    player_name;

-- ============================================================
-- QUESTION 3
-- Which players produced the highest sporting output per
-- EUR 1 million of estimated market value?
--
-- EFFICIENCY:
--   Position-adjusted performance percentile
--   divided by market value in EUR millions.
-- ============================================================

SELECT
    player_id,
    player_name,
    age_at_season_end AS age,
    position,
    sub_position,
    club_name,
    competition_name,

    minutes_played,
    position_adjusted_performance_percentile,

    market_value_in_eur,

    performance_percentile_per_eur_million,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            performance_percentile_per_eur_million DESC,
            position_adjusted_performance_percentile DESC
    ) AS performance_value_efficiency_rank

FROM recruitment_history

WHERE season = 2024
  AND market_value_in_eur >= 1000000
  AND position_adjusted_performance_percentile >= 50

ORDER BY
    position,
    performance_value_efficiency_rank;

-- ============================================================
-- QUESTION 4
-- Which players outside elite clubs produced results
-- comparable to players at higher-valued clubs?
--
-- ELITE CLUB:
--   Top 20% by estimated squad value within league-season.
-- ============================================================

WITH current_players AS (

    SELECT
        rh.*,
        cc.estimated_squad_value_eur,
        cc.club_value_quintile,
        cc.is_elite_club

    FROM recruitment_history AS rh

    LEFT JOIN recruitment_club_context AS cc
        ON rh.season = cc.season
       AND rh.competition_id = cc.competition_id
       AND rh.club_id = cc.club_id

    WHERE rh.season = 2024
),

elite_position_benchmarks AS (

    SELECT
        competition_id,
        position,

        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY position_adjusted_performance_percentile
        ) AS elite_player_median_performance

    FROM current_players

    WHERE is_elite_club = TRUE

    GROUP BY
        competition_id,
        position
)

SELECT
    cp.player_id,
    cp.player_name,
    cp.age_at_season_end AS age,
    cp.position,
    cp.sub_position,
    cp.club_name,
    cp.competition_name,

    cp.minutes_played,

    cp.position_adjusted_performance_percentile,

    ROUND(
        eb.elite_player_median_performance::NUMERIC,
        2
    ) AS elite_player_median_performance,

    cp.market_value_in_eur,

    cp.estimated_squad_value_eur,

    cp.club_value_quintile,

    DENSE_RANK() OVER (
        PARTITION BY cp.position
        ORDER BY
            cp.position_adjusted_performance_percentile DESC,
            cp.market_value_in_eur ASC
    ) AS non_elite_comparable_rank

FROM current_players AS cp

JOIN elite_position_benchmarks AS eb
    ON cp.competition_id = eb.competition_id
   AND cp.position = eb.position

WHERE cp.is_elite_club = FALSE

  AND cp.position_adjusted_performance_percentile
      >= eb.elite_player_median_performance

  AND cp.position_adjusted_performance_percentile >= 70

ORDER BY
    cp.position,
    non_elite_comparable_rank;

-- ============================================================
-- QUESTION 5
-- Which players combined strong current performance with
-- positive year-on-year development?
--
-- STRONG CURRENT PERFORMANCE:
--   >= 70th percentile
--
-- POSITIVE DEVELOPMENT:
--   Performance percentile increased from 2023-24.
-- ============================================================

SELECT
    player_id,
    player_name,
    age_at_season_end AS age,
    position,
    sub_position,
    club_name,
    competition_name,

    previous_performance_percentile,
    position_adjusted_performance_percentile,

    yoy_performance_percentile_change,

    previous_market_value_eur,
    market_value_in_eur,
    yoy_market_value_change_eur,
    yoy_market_value_percentage_change,

    minutes_played,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            yoy_performance_percentile_change DESC,
            position_adjusted_performance_percentile DESC
    ) AS development_rank

FROM recruitment_history

WHERE season = 2024

  AND previous_season = 2023

  AND position_adjusted_performance_percentile >= 70

  AND yoy_performance_percentile_change > 0

ORDER BY
    position,
    development_rank;

-- ============================================================
-- QUESTION 6
-- Which players demonstrated both strong output and
-- meaningful playing time?
--
-- STRONG OUTPUT:
--   >= 75th percentile
--
-- MEANINGFUL PLAYING TIME:
--   >= 1,800 minutes
-- ============================================================

SELECT
    player_id,
    player_name,
    age_at_season_end AS age,
    position,
    sub_position,
    club_name,
    competition_name,

    appearances,
    minutes_played,
    availability_percentage,

    goals,
    assists,
    goal_contributions,
    goal_contributions_per_90,

    position_adjusted_performance_percentile,

    market_value_in_eur,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            position_adjusted_performance_percentile DESC,
            minutes_played DESC
    ) AS reliable_output_rank

FROM recruitment_history

WHERE season = 2024

  AND minutes_played >= 1800

  AND position_adjusted_performance_percentile >= 75

ORDER BY
    position,
    reliable_output_rank;

-- ============================================================
-- QUESTION 7
-- Which leagues contained the largest number of affordable,
-- productive young players?
-- ============================================================

WITH affordable_young_players AS (

    SELECT *

    FROM recruitment_history

    WHERE season = 2024

      AND age_at_season_end <= 23

      AND position_adjusted_performance_percentile >= 65

      AND market_value_in_eur
          <= position_age_median_market_value_eur
)

SELECT
    competition_id,
    competition_name,
    country_name,

    COUNT(*) AS affordable_productive_young_players,

    ROUND(
        AVG(age_at_season_end)::NUMERIC,
        1
    ) AS average_age,

    ROUND(
        AVG(
            position_adjusted_performance_percentile
        )::NUMERIC,
        2
    ) AS average_performance_percentile,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY market_value_in_eur
        )::NUMERIC,
        2
    ) AS median_market_value_eur,

    SUM(market_value_in_eur)
        AS total_estimated_market_value_eur,

    DENSE_RANK() OVER (
        ORDER BY
            COUNT(*) DESC,
            AVG(position_adjusted_performance_percentile) DESC
    ) AS affordable_talent_league_rank

FROM affordable_young_players

GROUP BY
    competition_id,
    competition_name,
    country_name

ORDER BY
    affordable_talent_league_rank;

-- ============================================================
-- QUESTION 8
-- Which players should be shortlisted for each position
-- under selected market-value limits?
--
-- DEFAULT MARKET-VALUE LIMITS:
--   Goalkeeper: EUR 30m
--   Defender:   EUR 40m
--   Midfield:   EUR 50m
--   Attack:     EUR 60m
--
-- BASE ELIGIBILITY:
--   - Age <= 27
--   - Minimum 900 minutes
--   - Performance >= 60th percentile
-- ============================================================

WITH settings AS (

    SELECT
        30000000::BIGINT AS goalkeeper_limit,
        40000000::BIGINT AS defender_limit,
        50000000::BIGINT AS midfield_limit,
        60000000::BIGINT AS attack_limit
),

eligible_candidates AS (

    SELECT
        rh.*,

        CASE
            WHEN LOWER(position) = 'goalkeeper'
                THEN s.goalkeeper_limit

            WHEN LOWER(position) = 'defender'
                THEN s.defender_limit

            WHEN LOWER(position) = 'midfield'
                THEN s.midfield_limit

            WHEN LOWER(position) = 'attack'
                THEN s.attack_limit
        END AS position_market_value_limit

    FROM recruitment_history AS rh

    CROSS JOIN settings AS s

    WHERE rh.season = 2024
      AND rh.age_at_season_end <= 27
      AND rh.position_adjusted_performance_percentile >= 60
      AND rh.market_value_in_eur IS NOT NULL
),

within_budget AS (

    SELECT *

    FROM eligible_candidates

    WHERE market_value_in_eur
          <= position_market_value_limit
),

scored AS (

    SELECT
        *,

        ROUND(
            (
                0.50
                * position_adjusted_performance_percentile

                + 0.20
                * availability_percentile

                + 0.15
                * (
                    100
                    - value_percentile_within_position_age
                )

                + 0.15
                * LEAST(
                    100,
                    GREATEST(
                        0,
                        50
                        + COALESCE(
                            yoy_performance_percentile_change,
                            0
                        )
                    )
                )
            )::NUMERIC,
            2
        ) AS recruitment_score

    FROM within_budget
),

classified AS (

    SELECT
        *,

        CASE
            WHEN age_at_season_end <= 23
             AND position_adjusted_performance_percentile >= 70
             AND COALESCE(
                    yoy_performance_percentile_change,
                    0
                 ) > 0
             AND value_percentile_within_position_age <= 60
                THEN 'High-upside candidate'

            WHEN position_adjusted_performance_percentile >= 75
             AND value_percentile_within_position_age <= 40
                THEN 'Potential value opportunity'

            WHEN qualified_seasons >= 3
             AND average_performance_percentile >= 65
             AND performance_percentile_stddev <= 15
                THEN 'Consistent performer'

            WHEN age_at_season_end <= 21
             AND position_adjusted_performance_percentile >= 60
                THEN 'Emerging talent'

            WHEN position_adjusted_performance_percentile >= 80
             AND minutes_played >= 1800
                THEN 'Established value'

            ELSE 'Recruitment watchlist'
        END AS recruitment_opportunity_classification

    FROM scored
)

SELECT
    player_id,
    player_name,
    age_at_season_end AS age,

    position,
    sub_position,

    club_name AS club,
    competition_name AS league,

    minutes_played,

    goals,
    assists,
    goal_contributions,
    goal_contributions_per_90,

    availability_percentage,

    market_value_in_eur
        AS estimated_market_value_eur,

    yoy_market_value_change_eur
        AS market_value_trend_eur,

    yoy_market_value_percentage_change
        AS market_value_trend_percentage,

    position_adjusted_performance_percentile
        AS performance_percentile,

    value_percentile_within_position_age
        AS value_percentile,

    qualified_seasons,
    average_performance_percentile,
    performance_percentile_stddev,

    recruitment_score,

    recruitment_opportunity_classification,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            recruitment_score DESC,
            position_adjusted_performance_percentile DESC,
            market_value_in_eur ASC
    ) AS position_shortlist_rank

FROM classified

ORDER BY
    position,
    position_shortlist_rank;

-- ============================================================
-- QUESTION 9
-- Which shortlist candidates appear lower-risk because they
-- performed consistently across multiple seasons?
--
-- LOWER-RISK CRITERIA:
--   >= 3 qualified seasons
--   Current performance >= 65th percentile
--   Historical average >= 65th percentile
--   Performance SD <= 15
--   Current minutes >= 1,800
-- ============================================================

SELECT
    player_id,
    player_name,
    age_at_season_end AS age,

    position,
    sub_position,
    club_name,
    competition_name,

    minutes_played,

    market_value_in_eur,

    position_adjusted_performance_percentile
        AS current_performance_percentile,

    qualified_seasons,

    average_performance_percentile,

    performance_percentile_stddev,

    minimum_performance_percentile,

    total_qualified_minutes,

    yoy_performance_percentile_change,

    CASE
        WHEN performance_percentile_stddev <= 8
            THEN 'Very stable'

        WHEN performance_percentile_stddev <= 15
            THEN 'Stable'

        ELSE 'Moderate variation'
    END AS consistency_profile,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            average_performance_percentile DESC,
            performance_percentile_stddev ASC,
            position_adjusted_performance_percentile DESC
    ) AS lower_risk_position_rank

FROM recruitment_history

WHERE season = 2024

  AND qualified_seasons >= 3

  AND minutes_played >= 1800

  AND position_adjusted_performance_percentile >= 65

  AND average_performance_percentile >= 65

  AND performance_percentile_stddev <= 15

ORDER BY
    position,
    lower_risk_position_rank;

-- ============================================================
-- QUESTION 10
-- Which players represent high-upside candidates based on
-- age, recent improvement and current valuation?
-- ============================================================

WITH high_upside_pool AS (

    SELECT *

    FROM recruitment_history

    WHERE season = 2024

      AND age_at_season_end <= 23

      AND position_adjusted_performance_percentile >= 65

      AND yoy_performance_percentile_change > 0

      AND value_percentile_within_position_age <= 60

      AND COALESCE(
            yoy_market_value_change_eur,
            0
          ) >= 0
),

scored AS (

    SELECT
        *,

        ROUND(
            (
                0.45
                * position_adjusted_performance_percentile

                + 0.30
                * LEAST(
                    100,
                    GREATEST(
                        0,
                        50
                        + yoy_performance_percentile_change
                    )
                )

                + 0.25
                * (
                    100
                    - value_percentile_within_position_age
                )
            )::NUMERIC,
            2
        ) AS high_upside_score

    FROM high_upside_pool
)

SELECT
    player_id,
    player_name,

    age_at_season_end AS age,

    position,
    sub_position,

    club_name,
    competition_name,

    minutes_played,

    position_adjusted_performance_percentile,

    previous_performance_percentile,

    yoy_performance_percentile_change,

    market_value_in_eur,

    value_percentile_within_position_age,

    yoy_market_value_change_eur,

    yoy_market_value_percentage_change,

    qualified_seasons,

    high_upside_score,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            high_upside_score DESC,
            age_at_season_end ASC,
            market_value_in_eur ASC
    ) AS high_upside_position_rank

FROM scored

ORDER BY
    position,
    high_upside_position_rank;

-- ============================================================
-- THEME 4 VALIDATION
-- ============================================================


-- 1. Recruitment population by season and position

SELECT
    season_label,
    position,
    COUNT(*) AS eligible_players
FROM recruitment_player_season
GROUP BY
    season_label,
    position
ORDER BY
    season_label,
    position;


-- 2. Current-season recruitment population

SELECT
    position,
    COUNT(*) AS players,
    MIN(age_at_season_end) AS youngest,
    MAX(age_at_season_end) AS oldest,
    ROUND(
        AVG(minutes_played)::NUMERIC,
        0
    ) AS average_minutes
FROM recruitment_history
WHERE season = 2024
GROUP BY position
ORDER BY position;


-- 3. Check position-adjusted percentile ranges

SELECT
    position,
    MIN(position_adjusted_performance_percentile)
        AS minimum_percentile,
    MAX(position_adjusted_performance_percentile)
        AS maximum_percentile,
    ROUND(
        AVG(position_adjusted_performance_percentile)::NUMERIC,
        2
    ) AS average_percentile
FROM recruitment_history
WHERE season = 2024
GROUP BY position
ORDER BY position;


-- 4. Check market-value coverage

SELECT
    position,

    COUNT(*) AS eligible_players,

    COUNT(market_value_in_eur)
        AS players_with_market_value,

    ROUND(
        (
            100.0
            * COUNT(market_value_in_eur)
            / NULLIF(COUNT(*), 0)
        )::NUMERIC,
        2
    ) AS valuation_coverage_percentage

FROM recruitment_history

WHERE season = 2024

GROUP BY position

ORDER BY position;


-- 5. Review age groups

SELECT
    age_group,
    position,
    COUNT(*) AS players
FROM recruitment_history
WHERE season = 2024
GROUP BY
    age_group,
    position
ORDER BY
    age_group,
    position;


-- 6. Check elite-club classification

SELECT
    competition_name,
    COUNT(*) AS clubs,
    COUNT(*) FILTER (
        WHERE is_elite_club = TRUE
    ) AS elite_clubs
FROM recruitment_club_context
WHERE season = 2024
GROUP BY competition_name
ORDER BY competition_name;


-- 7. Historical consistency population

SELECT
    qualified_seasons,
    COUNT(DISTINCT player_id) AS players
FROM recruitment_history
WHERE season = 2024
GROUP BY qualified_seasons
ORDER BY qualified_seasons;


-- 8. Confirm YoY comparisons available

SELECT
    COUNT(*) AS current_players,

    COUNT(*) FILTER (
        WHERE previous_season = 2023
    ) AS players_with_consecutive_previous_season,

    COUNT(*) FILTER (
        WHERE yoy_performance_percentile_change > 0
    ) AS players_with_positive_performance_development,

    COUNT(*) FILTER (
        WHERE yoy_market_value_change_eur > 0
    ) AS players_with_positive_value_growth

FROM recruitment_history

WHERE season = 2024;