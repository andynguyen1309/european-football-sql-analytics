-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 09a_theme_4_export_queries.sql
-- THEME: Recruitment and Potentially Undervalued Talent
--
-- PURPOSE:
--   Produce reusable Theme 4 datasets for:
--   1. CSV export
--   2. Findings documentation
--   3. Tableau visualisation
--   4. Recruitment shortlist presentation
--
-- DATABASE: eu_football_analytics
-- ANALYTICAL SCHEMA: football
-- RAW SCHEMA: football_raw
-- AUTHOR: Andy Nguyen
--
-- EXECUTION ORDER:
--   Run after Sections A1-A3 of:
--   09_recruitment_undervalued_talent.sql
--
-- PRIMARY RECRUITMENT SEASON:
--   2024-25
--
-- IMPORTANT:
--   The recruitment_* objects used below are TEMP views.
--   If PostgreSQL/DBeaver starts a new session, rerun A1-A3.
-- ============================================================

SET search_path TO football, football_raw, public;

-- ============================================================
-- EXPORT 1: RECRUITMENT CANDIDATE MASTER
--
-- SUPPORTS:
--   Q1  - Productive U23 players
--   Q2  - Performance below position-age value median
--   Q5  - Positive development
--   Q6  - Output + meaningful playing time
--   Q8  - Position-specific recruitment shortlist
--
-- DEFAULT VALUE LIMITS:
--   Goalkeeper: EUR 30m
--   Defender:   EUR 40m
--   Midfield:   EUR 50m
--   Attack:     EUR 60m
--
-- BASE SHORTLIST:
--   Age <= 27
--   >= 900 minutes
--   Performance >= 60th percentile
-- ============================================================

WITH settings AS (

    SELECT
        30000000::BIGINT AS goalkeeper_limit,
        40000000::BIGINT AS defender_limit,
        50000000::BIGINT AS midfield_limit,
        60000000::BIGINT AS attack_limit
),

candidate_pool AS (

    SELECT
        rh.*,

        CASE
            WHEN LOWER(rh.position) = 'goalkeeper'
                THEN s.goalkeeper_limit

            WHEN LOWER(rh.position) = 'defender'
                THEN s.defender_limit

            WHEN LOWER(rh.position) = 'midfield'
                THEN s.midfield_limit

            WHEN LOWER(rh.position) = 'attack'
                THEN s.attack_limit
        END AS position_market_value_limit

    FROM football.vw_recruitment_history AS rh

    CROSS JOIN settings AS s

    WHERE rh.season = 2024
      AND rh.age_at_season_end <= 27
      AND rh.minutes_played >= 900
      AND rh.position_adjusted_performance_percentile >= 60
      AND rh.market_value_in_eur IS NOT NULL
),

within_budget AS (

    SELECT *

    FROM candidate_pool

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
    country_name AS league_country,

    minutes_played,
    appearances,

    goals,
    assists,
    goal_contributions,
    goal_contributions_per_90,

    availability_percentage,
    availability_percentile,

    position_adjusted_performance_percentile
        AS performance_percentile,

    market_value_in_eur
        AS estimated_market_value_eur,

    position_age_median_market_value_eur,

    value_percentile_within_position_age
        AS value_percentile,

    position_market_value_limit,

    previous_performance_percentile,

    yoy_performance_percentile_change,

    yoy_market_value_change_eur
        AS market_value_trend_eur,

    yoy_market_value_percentage_change
        AS market_value_trend_percentage,

    qualified_seasons,
    average_performance_percentile,
    performance_percentile_stddev,
    minimum_performance_percentile,
    total_qualified_minutes,

    recruitment_score,

    recruitment_opportunity_classification,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            recruitment_score DESC,
            position_adjusted_performance_percentile DESC,
            market_value_in_eur ASC
    ) AS position_shortlist_rank,

    DENSE_RANK() OVER (
        ORDER BY
            recruitment_score DESC,
            position_adjusted_performance_percentile DESC,
            market_value_in_eur ASC
    ) AS overall_shortlist_rank

FROM classified

ORDER BY
    position,
    position_shortlist_rank,
    player_name;

-- ============================================================
-- EXPORT 2: UNDERVALUED YOUNG PLAYERS
--
-- SUPPORTS QUESTIONS:
--   Q1 - U23 above-average performers
--   Q2 - High performers below value benchmark
--
-- ELIGIBILITY:
--   Age <= 22
--   Performance >= 70th percentile
--   Value below position-age median
-- ============================================================

WITH undervalued AS (

    SELECT
        player_id,
        player_name,

        age_at_season_end AS age,
        age_group,

        position,
        sub_position,

        club_name,
        competition_name,
        country_name,

        minutes_played,
        appearances,

        goals,
        assists,
        goal_contributions,
        goal_contributions_per_90,

        availability_percentage,

        position_adjusted_performance_percentile,

        market_value_in_eur,

        position_age_median_market_value_eur,

        position_age_median_market_value_eur
            - market_value_in_eur
            AS value_discount_to_benchmark_eur,

        ROUND(
            (
                100.0
                * (
                    position_age_median_market_value_eur
                    - market_value_in_eur
                )
                / NULLIF(
                    position_age_median_market_value_eur,
                    0
                )
            )::NUMERIC,
            2
        ) AS value_discount_percentage,

        value_percentile_within_position_age,

        yoy_performance_percentile_change,

        yoy_market_value_change_eur,

        qualified_seasons,
        average_performance_percentile,
        performance_percentile_stddev

    FROM football.vw_recruitment_history

    WHERE season = 2024

      AND age_at_season_end <= 22

      AND position_adjusted_performance_percentile >= 70

      AND market_value_in_eur
          < position_age_median_market_value_eur
)

SELECT
    *,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            position_adjusted_performance_percentile DESC,
            value_discount_percentage DESC,
            market_value_in_eur ASC
    ) AS undervalued_young_position_rank,

    DENSE_RANK() OVER (
        ORDER BY
            position_adjusted_performance_percentile DESC,
            value_discount_percentage DESC
    ) AS undervalued_young_overall_rank

FROM undervalued

ORDER BY
    undervalued_young_overall_rank,
    player_name;

-- ============================================================
-- EXPORT 3: PERFORMANCE-VALUE EFFICIENCY
--
-- SUPPORTS QUESTION:
--   Q3 - Highest sporting output per EUR 1m of value
--
-- ELIGIBILITY:
--   Current season 2024-25
--   Market value >= EUR 1m
--   Performance >= 50th percentile
-- ============================================================

SELECT
    player_id,
    player_name,

    age_at_season_end AS age,

    position,
    sub_position,

    club_name,
    competition_name,
    country_name,

    minutes_played,

    goals,
    assists,
    goal_contributions,
    goal_contributions_per_90,

    availability_percentage,

    position_adjusted_performance_percentile,

    market_value_in_eur,

    value_percentile_within_position_age,

    performance_percentile_per_eur_million,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            performance_percentile_per_eur_million DESC,
            position_adjusted_performance_percentile DESC,
            market_value_in_eur ASC
    ) AS efficiency_position_rank,

    DENSE_RANK() OVER (
        ORDER BY
            performance_percentile_per_eur_million DESC,
            position_adjusted_performance_percentile DESC
    ) AS efficiency_overall_rank

FROM football.vw_recruitment_history

WHERE season = 2024

  AND market_value_in_eur >= 1000000

  AND position_adjusted_performance_percentile >= 50

ORDER BY
    efficiency_overall_rank,
    player_name;

-- ============================================================
-- EXPORT 4: NON-ELITE CLUB OPPORTUNITIES
--
-- SUPPORTS QUESTION:
--   Q4 - Players outside elite clubs producing comparable
--        performance
--
-- ELITE CLUB:
--   Top 20% of estimated squad value within league-season.
-- ============================================================

WITH current_players AS (

    SELECT
        rh.*,

        cc.estimated_squad_value_eur,
        cc.club_value_quintile,
        cc.is_elite_club

    FROM football.vw_recruitment_history AS rh

    LEFT JOIN football.vw_recruitment_club_context AS cc
        ON rh.season = cc.season
       AND rh.competition_id = cc.competition_id
       AND rh.club_id = cc.club_id

    WHERE rh.season = 2024
),

elite_benchmarks AS (

    SELECT
        competition_id,
        position,

        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY position_adjusted_performance_percentile
        ) AS elite_position_median_performance

    FROM current_players

    WHERE is_elite_club = TRUE

    GROUP BY
        competition_id,
        position
),

opportunities AS (

    SELECT
        cp.*,

        ROUND(
            eb.elite_position_median_performance::NUMERIC,
            2
        ) AS elite_position_median_performance,

        ROUND(
            (
                cp.position_adjusted_performance_percentile
                - eb.elite_position_median_performance
            )::NUMERIC,
            2
        ) AS performance_above_elite_median

    FROM current_players AS cp

    JOIN elite_benchmarks AS eb
        ON cp.competition_id = eb.competition_id
       AND cp.position = eb.position

    WHERE cp.is_elite_club = FALSE

      AND cp.position_adjusted_performance_percentile >= 70

      AND cp.position_adjusted_performance_percentile
          >= eb.elite_position_median_performance
)

SELECT
    player_id,
    player_name,

    age_at_season_end AS age,

    position,
    sub_position,

    club_name,
    competition_name,
    country_name,

    minutes_played,

    goal_contributions_per_90,
    availability_percentage,

    position_adjusted_performance_percentile,

    elite_position_median_performance,

    performance_above_elite_median,

    market_value_in_eur,

    estimated_squad_value_eur,

    club_value_quintile,

    value_percentile_within_position_age,

    yoy_performance_percentile_change,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            position_adjusted_performance_percentile DESC,
            performance_above_elite_median DESC,
            market_value_in_eur ASC
    ) AS non_elite_opportunity_position_rank

FROM opportunities

ORDER BY
    position,
    non_elite_opportunity_position_rank;

-- ============================================================
-- EXPORT 5: POSITIVE DEVELOPMENT CANDIDATES
--
-- SUPPORTS QUESTION:
--   Q5 - Strong current performance plus positive YoY growth
--
-- ELIGIBILITY:
--   2023-24 → 2024-25 consecutive seasons
--   Current performance >= 70th percentile
--   Positive performance-percentile change
-- ============================================================

SELECT
    player_id,
    player_name,

    age_at_season_end AS age,

    position,
    sub_position,

    club_name,
    competition_name,
    country_name,

    minutes_played,

    previous_performance_percentile,

    position_adjusted_performance_percentile
        AS current_performance_percentile,

    yoy_performance_percentile_change,

    previous_market_value_eur,

    market_value_in_eur
        AS current_market_value_eur,

    yoy_market_value_change_eur,

    yoy_market_value_percentage_change,

    value_percentile_within_position_age,

    qualified_seasons,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            yoy_performance_percentile_change DESC,
            position_adjusted_performance_percentile DESC,
            market_value_in_eur ASC
    ) AS development_position_rank,

    DENSE_RANK() OVER (
        ORDER BY
            yoy_performance_percentile_change DESC,
            position_adjusted_performance_percentile DESC
    ) AS development_overall_rank

FROM football.vw_recruitment_history

WHERE season = 2024

  AND previous_season = 2023

  AND position_adjusted_performance_percentile >= 70

  AND yoy_performance_percentile_change > 0

ORDER BY
    development_overall_rank,
    player_name;

-- ============================================================
-- EXPORT 6: AFFORDABLE PRODUCTIVE YOUNG TALENT BY LEAGUE
--
-- SUPPORTS QUESTION:
--   Q7 - Which leagues contained the most affordable,
--        productive young players?
--
-- AFFORDABLE PRODUCTIVE YOUNG PLAYER:
--   Age <= 23
--   Performance >= 65th percentile
--   Value <= position-age median
-- ============================================================

WITH affordable_young AS (

    SELECT *

    FROM football.vw_recruitment_history

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

    COUNT(*) FILTER (
        WHERE LOWER(position) = 'attack'
    ) AS attackers,

    COUNT(*) FILTER (
        WHERE LOWER(position) = 'midfield'
    ) AS midfielders,

    COUNT(*) FILTER (
        WHERE LOWER(position) = 'defender'
    ) AS defenders,

    COUNT(*) FILTER (
        WHERE LOWER(position) = 'goalkeeper'
    ) AS goalkeepers,

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

    ROUND(
        AVG(market_value_in_eur)::NUMERIC,
        2
    ) AS average_market_value_eur,

    SUM(market_value_in_eur)
        AS total_estimated_market_value_eur,

    DENSE_RANK() OVER (
        ORDER BY
            COUNT(*) DESC,
            AVG(
                position_adjusted_performance_percentile
            ) DESC
    ) AS affordable_talent_league_rank

FROM affordable_young

GROUP BY
    competition_id,
    competition_name,
    country_name

ORDER BY
    affordable_talent_league_rank;

-- ============================================================
-- EXPORT 7: LOWER-RISK RECRUITMENT CANDIDATES
--
-- SUPPORTS QUESTION:
--   Q9 - Which candidates appear lower-risk because of
--        sustained performance?
--
-- CRITERIA:
--   >= 3 qualified seasons
--   >= 1,800 current-season minutes
--   Current performance >= 65th percentile
--   Historical average >= 65th percentile
--   Performance standard deviation <= 15
-- ============================================================

SELECT
    player_id,
    player_name,

    age_at_season_end AS age,

    position,
    sub_position,

    club_name,
    competition_name,
    country_name,

    minutes_played,

    market_value_in_eur,

    value_percentile_within_position_age,

    position_adjusted_performance_percentile
        AS current_performance_percentile,

    qualified_seasons,

    average_performance_percentile,

    performance_percentile_stddev,

    minimum_performance_percentile,

    total_qualified_minutes,

    yoy_performance_percentile_change,

    yoy_market_value_change_eur,

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
    ) AS lower_risk_position_rank,

    DENSE_RANK() OVER (
        ORDER BY
            average_performance_percentile DESC,
            performance_percentile_stddev ASC
    ) AS lower_risk_overall_rank

FROM football.vw_recruitment_history

WHERE season = 2024

  AND qualified_seasons >= 3

  AND minutes_played >= 1800

  AND position_adjusted_performance_percentile >= 65

  AND average_performance_percentile >= 65

  AND performance_percentile_stddev <= 15

ORDER BY
    lower_risk_overall_rank,
    player_name;

-- ============================================================
-- EXPORT 8: HIGH-UPSIDE RECRUITMENT CANDIDATES
--
-- SUPPORTS QUESTION:
--   Q10 - Young, improving and relatively affordable players
--
-- CRITERIA:
--   Age <= 23
--   Performance >= 65th percentile
--   Positive YoY performance improvement
--   Value percentile <= 60
--   Market value stable or increasing
-- ============================================================

WITH high_upside_pool AS (

    SELECT *

    FROM football.vw_recruitment_history

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
    country_name,

    minutes_played,

    goal_contributions_per_90,
    availability_percentage,

    previous_performance_percentile,

    position_adjusted_performance_percentile
        AS current_performance_percentile,

    yoy_performance_percentile_change,

    market_value_in_eur,

    position_age_median_market_value_eur,

    value_percentile_within_position_age,

    yoy_market_value_change_eur,

    yoy_market_value_percentage_change,

    qualified_seasons,

    average_performance_percentile,

    high_upside_score,

    DENSE_RANK() OVER (
        PARTITION BY position
        ORDER BY
            high_upside_score DESC,
            age_at_season_end ASC,
            market_value_in_eur ASC
    ) AS high_upside_position_rank,

    DENSE_RANK() OVER (
        ORDER BY
            high_upside_score DESC,
            age_at_season_end ASC,
            market_value_in_eur ASC
    ) AS high_upside_overall_rank

FROM scored

ORDER BY
    high_upside_overall_rank,
    player_name;

-- ============================================================
-- FINAL THEME 4 EXPORT VALIDATION
-- ============================================================


-- 1. Current recruitment population

SELECT
    position,
    COUNT(*) AS eligible_players,
    COUNT(market_value_in_eur) AS players_with_market_value

FROM football.vw_recruitment_history

WHERE season = 2024

GROUP BY position

ORDER BY position;


-- 2. U23 population

SELECT
    position,
    COUNT(*) AS under_23_players

FROM football.vw_recruitment_history

WHERE season = 2024
  AND age_at_season_end <= 22

GROUP BY position

ORDER BY position;


-- 3. High-performance population

SELECT
    position,

    COUNT(*) FILTER (
        WHERE position_adjusted_performance_percentile >= 70
    ) AS players_above_70th_percentile,

    COUNT(*) FILTER (
        WHERE position_adjusted_performance_percentile >= 75
    ) AS players_above_75th_percentile,

    COUNT(*) FILTER (
        WHERE position_adjusted_performance_percentile >= 80
    ) AS players_above_80th_percentile

FROM football.vw_recruitment_history

WHERE season = 2024

GROUP BY position

ORDER BY position;


-- 4. Value benchmark coverage

SELECT
    position,

    COUNT(*) AS players,

    COUNT(position_age_median_market_value_eur)
        AS players_with_value_benchmark,

    COUNT(*) FILTER (
        WHERE market_value_in_eur
              < position_age_median_market_value_eur
    ) AS players_below_value_median

FROM football.vw_recruitment_history

WHERE season = 2024

GROUP BY position

ORDER BY position;


-- 5. YoY development coverage

SELECT
    position,

    COUNT(*) AS current_players,

    COUNT(*) FILTER (
        WHERE previous_season = 2023
    ) AS consecutive_season_players,

    COUNT(*) FILTER (
        WHERE yoy_performance_percentile_change > 0
    ) AS improving_players

FROM football.vw_recruitment_history

WHERE season = 2024

GROUP BY position

ORDER BY position;


-- 6. Consistency population

SELECT
    qualified_seasons,
    COUNT(*) AS current_players

FROM football.vw_recruitment_history

WHERE season = 2024

GROUP BY qualified_seasons

ORDER BY qualified_seasons;


-- 7. Elite versus non-elite club count

SELECT
    competition_name,

    COUNT(*) AS total_clubs,

    COUNT(*) FILTER (
        WHERE is_elite_club = TRUE
    ) AS elite_clubs,

    COUNT(*) FILTER (
        WHERE is_elite_club = FALSE
    ) AS non_elite_clubs

FROM football.vw_recruitment_club_context

WHERE season = 2024

GROUP BY competition_name

ORDER BY competition_name;