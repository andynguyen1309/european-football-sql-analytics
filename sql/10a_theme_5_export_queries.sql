-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 10a_theme_5_export_queries.sql
-- THEME: Transfers and Post-Transfer Outcomes
--
-- PURPOSE:
--   Produce final reusable datasets for:
--   1. CSV export
--   2. Findings documentation
--   3. Tableau visualisations
--   4. GitHub portfolio presentation
--
-- DATABASE:
--   eu_football_analytics
--
-- ANALYTICAL SCHEMA:
--   football
--
-- CORE PERIOD:
--   2020-21 to 2024-25
--
-- IMPORTANT METHODOLOGY:
--   - Missing/undisclosed fees are NOT treated as zero.
--   - Recorded zero fees remain a separate category.
--   - Financial analysis uses positive known fees only.
--   - Post-transfer outcome analysis uses July-September
--     transfers for cleaner before/after comparisons.
--   - Performance outcomes require minimum playing-time
--     thresholds where specified.
--   - League flow analysis uses mapped league assignments and
--     should be interpreted with mapping-coverage limitations.
--
-- AUTHOR: Andy Nguyen
-- ============================================================

SET search_path TO football, football_raw, public;

-- ============================================================
-- EXPORT 1: CLUB TRANSFER BALANCES
--
-- SUPPORTS QUESTIONS:
--   Q1, Q2, Q3
--
-- GRAIN:
--   One row per club.
--
-- IMPORTANT:
--   Financial totals use positive known fees only.
-- ============================================================

WITH club_universe AS (

    SELECT
        to_club_id AS club_id,
        MAX(to_club_name) AS club_name,
        MAX(to_competition_id) AS competition_id,
        MAX(to_competition_name) AS competition_name

    FROM football.vw_core_transfer_events

    WHERE to_competition_id IN (
        'GB1', 'ES1', 'L1', 'IT1', 'FR1'
    )

    GROUP BY
        to_club_id

    UNION

    SELECT
        from_club_id AS club_id,
        MAX(from_club_name) AS club_name,
        MAX(from_competition_id) AS competition_id,
        MAX(from_competition_name) AS competition_name

    FROM football.vw_core_transfer_events

    WHERE from_competition_id IN (
        'GB1', 'ES1', 'L1', 'IT1', 'FR1'
    )

    GROUP BY
        from_club_id
),

incoming AS (

    SELECT
        to_club_id AS club_id,

        COUNT(*) AS incoming_transfer_records,

        COUNT(*) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        ) AS known_paid_transfers,

        COUNT(*) FILTER (
            WHERE transfer_fee_status = 'Recorded zero fee'
        ) AS recorded_zero_fee_arrivals,

        COUNT(*) FILTER (
            WHERE transfer_fee_status =
                  'Missing or undisclosed fee'
        ) AS missing_fee_arrivals,

        SUM(transfer_fee) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        ) AS known_transfer_expenditure_eur

    FROM football.vw_core_transfer_events

    GROUP BY
        to_club_id
),

outgoing AS (

    SELECT
        from_club_id AS club_id,

        COUNT(*) AS outgoing_transfer_records,

        COUNT(*) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        ) AS known_fee_sales,

        COUNT(*) FILTER (
            WHERE transfer_fee_status = 'Recorded zero fee'
        ) AS recorded_zero_fee_departures,

        COUNT(*) FILTER (
            WHERE transfer_fee_status =
                  'Missing or undisclosed fee'
        ) AS missing_fee_departures,

        SUM(transfer_fee) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        ) AS known_transfer_income_eur

    FROM football.vw_core_transfer_events

    GROUP BY
        from_club_id
),

combined AS (

    SELECT
        cu.club_id,
        cu.club_name,
        cu.competition_id,
        cu.competition_name,

        COALESCE(
            i.incoming_transfer_records,
            0
        ) AS incoming_transfer_records,

        COALESCE(
            o.outgoing_transfer_records,
            0
        ) AS outgoing_transfer_records,

        COALESCE(
            i.known_paid_transfers,
            0
        ) AS known_paid_transfers,

        COALESCE(
            o.known_fee_sales,
            0
        ) AS known_fee_sales,

        COALESCE(
            i.recorded_zero_fee_arrivals,
            0
        ) AS recorded_zero_fee_arrivals,

        COALESCE(
            o.recorded_zero_fee_departures,
            0
        ) AS recorded_zero_fee_departures,

        COALESCE(
            i.missing_fee_arrivals,
            0
        ) AS missing_fee_arrivals,

        COALESCE(
            o.missing_fee_departures,
            0
        ) AS missing_fee_departures,

        COALESCE(
            i.known_transfer_expenditure_eur,
            0
        ) AS known_transfer_expenditure_eur,

        COALESCE(
            o.known_transfer_income_eur,
            0
        ) AS known_transfer_income_eur

    FROM club_universe AS cu

    LEFT JOIN incoming AS i
        ON cu.club_id = i.club_id

    LEFT JOIN outgoing AS o
        ON cu.club_id = o.club_id
),

final AS (

    SELECT
        *,

        known_transfer_income_eur
        - known_transfer_expenditure_eur
            AS known_net_transfer_balance_eur,

        DENSE_RANK() OVER (
            ORDER BY
                known_transfer_expenditure_eur DESC
        ) AS expenditure_rank,

        DENSE_RANK() OVER (
            ORDER BY
                known_transfer_income_eur DESC
        ) AS income_rank,

        DENSE_RANK() OVER (
            ORDER BY
                known_transfer_income_eur
                - known_transfer_expenditure_eur DESC
        ) AS positive_balance_rank,

        DENSE_RANK() OVER (
            ORDER BY
                known_transfer_income_eur
                - known_transfer_expenditure_eur ASC
        ) AS negative_balance_rank

    FROM combined
)

SELECT *

FROM final

ORDER BY
    known_transfer_expenditure_eur DESC,
    club_name;

-- ============================================================
-- EXPORT 2: LEAGUE TRANSFER FLOWS
--
-- SUPPORTS QUESTION:
--   Q4
--
-- GRAIN:
--   One row per league.
--
-- INTERNAL SAME-LEAGUE TRANSFERS:
--   Excluded from import/export flow measures.
-- ============================================================

WITH external_transfers AS (

    SELECT *

    FROM football.vw_core_transfer_events

    WHERE from_competition_id IS NOT NULL
      AND to_competition_id IS NOT NULL

      AND from_competition_id
          <> to_competition_id
),

inflows AS (

    SELECT
        to_competition_id AS competition_id,

        COUNT(*) AS incoming_external_transfers,

        COUNT(*) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        ) AS incoming_known_fee_transfers,

        SUM(transfer_fee) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        ) AS known_expenditure_eur

    FROM external_transfers

    GROUP BY
        to_competition_id
),

outflows AS (

    SELECT
        from_competition_id AS competition_id,

        COUNT(*) AS outgoing_external_transfers,

        COUNT(*) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        ) AS outgoing_known_fee_transfers,

        SUM(transfer_fee) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        ) AS known_income_eur

    FROM external_transfers

    GROUP BY
        from_competition_id
)

SELECT
    c.competition_id,
    c.name AS competition_name,
    c.country_name,

    COALESCE(
        i.incoming_external_transfers,
        0
    ) AS incoming_external_transfers,

    COALESCE(
        o.outgoing_external_transfers,
        0
    ) AS outgoing_external_transfers,

    COALESCE(
        i.incoming_external_transfers,
        0
    )
    -
    COALESCE(
        o.outgoing_external_transfers,
        0
    ) AS net_player_flow,

    COALESCE(
        i.incoming_known_fee_transfers,
        0
    ) AS incoming_known_fee_transfers,

    COALESCE(
        o.outgoing_known_fee_transfers,
        0
    ) AS outgoing_known_fee_transfers,

    COALESCE(
        i.known_expenditure_eur,
        0
    ) AS known_transfer_expenditure_eur,

    COALESCE(
        o.known_income_eur,
        0
    ) AS known_transfer_income_eur,

    COALESCE(
        o.known_income_eur,
        0
    )
    -
    COALESCE(
        i.known_expenditure_eur,
        0
    ) AS known_financial_balance_eur,

    CASE
        WHEN COALESCE(
                i.incoming_external_transfers,
                0
             )
             >
             COALESCE(
                o.outgoing_external_transfers,
                0
             )
            THEN 'Net player importer'

        WHEN COALESCE(
                i.incoming_external_transfers,
                0
             )
             <
             COALESCE(
                o.outgoing_external_transfers,
                0
             )
            THEN 'Net player exporter'

        ELSE 'Balanced player flow'
    END AS player_flow_profile

FROM football_raw.competitions AS c

LEFT JOIN inflows AS i
    ON c.competition_id = i.competition_id

LEFT JOIN outflows AS o
    ON c.competition_id = o.competition_id

WHERE c.competition_id IN (
    'GB1', 'ES1', 'L1', 'IT1', 'FR1'
)

ORDER BY
    net_player_flow DESC;

-- ============================================================
-- EXPORT 3: LEAGUE TRANSFER ROUTES
--
-- SUPPORTS QUESTION:
--   Q5
--
-- GRAIN:
--   One origin-league / destination-league route.
--
-- SAME-LEAGUE TRANSFERS:
--   Excluded.
-- ============================================================

SELECT
    from_competition_id,
    from_competition_name,

    to_competition_id,
    to_competition_name,

    COUNT(*) AS transfer_count,

    COUNT(*) FILTER (
        WHERE transfer_fee_status = 'Positive known fee'
    ) AS known_fee_transfer_count,

    COUNT(*) FILTER (
        WHERE transfer_fee_status = 'Recorded zero fee'
    ) AS recorded_zero_fee_count,

    COUNT(*) FILTER (
        WHERE transfer_fee_status =
              'Missing or undisclosed fee'
    ) AS missing_or_undisclosed_fee_count,

    SUM(transfer_fee) FILTER (
        WHERE transfer_fee_status = 'Positive known fee'
    ) AS known_transfer_value_eur,

    ROUND(
        AVG(transfer_fee) FILTER (
            WHERE transfer_fee_status =
                  'Positive known fee'
        )::NUMERIC,
        2
    ) AS average_known_fee_eur,

    DENSE_RANK() OVER (
        ORDER BY
            COUNT(*) DESC
    ) AS route_frequency_rank

FROM football.vw_core_transfer_events

WHERE from_competition_id IS NOT NULL
  AND to_competition_id IS NOT NULL

  AND from_competition_id
      <> to_competition_id

GROUP BY
    from_competition_id,
    from_competition_name,
    to_competition_id,
    to_competition_name

ORDER BY
    route_frequency_rank,
    from_competition_name,
    to_competition_name;

-- ============================================================
-- EXPORT 4: TRANSFER FEE PROFILE
--
-- SUPPORTS QUESTIONS:
--   Q6 - Fee levels by age group
--   Q7 - Fee levels by position
--
-- POSITIVE KNOWN FEES ONLY.
-- ============================================================

WITH age_profile AS (

    SELECT
        'Age Group'::TEXT AS profile_type,

        age_group::TEXT AS profile_group,

        COUNT(*) AS known_fee_transfers,

        SUM(transfer_fee)
            AS total_known_transfer_fees_eur,

        ROUND(
            AVG(transfer_fee)::NUMERIC,
            2
        ) AS average_transfer_fee_eur,

        ROUND(
            PERCENTILE_CONT(0.5)
            WITHIN GROUP (
                ORDER BY transfer_fee
            )::NUMERIC,
            2
        ) AS median_transfer_fee_eur,

        MAX(transfer_fee)
            AS maximum_transfer_fee_eur

    FROM football.vw_core_transfer_events

    WHERE transfer_fee_status =
          'Positive known fee'

      AND age_group <> 'Unknown'

    GROUP BY
        age_group
),

position_profile AS (

    SELECT
        'Position'::TEXT AS profile_type,

        position::TEXT AS profile_group,

        COUNT(*) AS known_fee_transfers,

        SUM(transfer_fee)
            AS total_known_transfer_fees_eur,

        ROUND(
            AVG(transfer_fee)::NUMERIC,
            2
        ) AS average_transfer_fee_eur,

        ROUND(
            PERCENTILE_CONT(0.5)
            WITHIN GROUP (
                ORDER BY transfer_fee
            )::NUMERIC,
            2
        ) AS median_transfer_fee_eur,

        MAX(transfer_fee)
            AS maximum_transfer_fee_eur

    FROM football.vw_core_transfer_events

    WHERE transfer_fee_status =
          'Positive known fee'

      AND position IS NOT NULL

    GROUP BY
        position
)

SELECT *

FROM age_profile

UNION ALL

SELECT *

FROM position_profile

ORDER BY
    profile_type,
    median_transfer_fee_eur DESC;

-- ============================================================
-- EXPORT 5: POST-TRANSFER MARKET-VALUE GROWTH
--
-- SUPPORTS QUESTION:
--   Q8
--
-- COHORT:
--   July-September transfers only.
--
-- REQUIREMENT:
--   Pre and post season-end valuations available.
-- ============================================================

WITH eligible AS (

    SELECT
        transfer_id,
        player_id,
        player_name,

        age_at_transfer,
        age_group,

        position,
        sub_position,

        transfer_date,
        transfer_season,

        from_club_id,
        from_club_name,
        from_competition_id,
        from_competition_name,

        to_club_id,
        to_club_name,
        to_competition_id,
        to_competition_name,

        transfer_fee,
        transfer_fee_status,

        market_value_at_transfer_eur,

        pre_transfer_season_end_value_eur,
        post_transfer_season_end_value_eur,

        post_transfer_value_change_eur,
        post_transfer_value_percentage_change

    FROM football.vw_summer_transfer_outcomes

    WHERE pre_transfer_season_end_value_eur IS NOT NULL
      AND post_transfer_season_end_value_eur IS NOT NULL

      AND pre_transfer_season_end_value_eur > 0
)

SELECT
    *,

    DENSE_RANK() OVER (
        ORDER BY
            post_transfer_value_change_eur DESC
    ) AS absolute_value_growth_rank,

    DENSE_RANK() OVER (
        ORDER BY
            post_transfer_value_percentage_change DESC
    ) AS percentage_value_growth_rank,

    CASE
        WHEN post_transfer_value_change_eur > 0
            THEN 'Value increased'

        WHEN post_transfer_value_change_eur < 0
            THEN 'Value decreased'

        ELSE 'No value change'
    END AS post_transfer_value_direction

FROM eligible

ORDER BY
    absolute_value_growth_rank,
    player_name;

-- ============================================================
-- EXPORT 6: POST-TRANSFER SPORTING OUTCOMES
--
-- SUPPORTS QUESTIONS:
--   Q9  - Improved after transfer
--   Q10 - Declined after transfer
--
-- COHORT:
--   July-September transfers.
--
-- ELIGIBILITY:
--   >= 450 league minutes in both pre and post seasons.
--
-- NOTE:
--   Goalkeeper evaluation should focus mainly on playing time.
-- ============================================================

WITH eligible AS (

    SELECT
        transfer_id,
        player_id,
        player_name,

        age_at_transfer,
        age_group,

        position,
        sub_position,

        transfer_date,
        transfer_season,

        from_club_name,
        from_competition_name,

        to_club_name,
        to_competition_name,

        transfer_fee,
        transfer_fee_status,

        pre_transfer_minutes,
        post_transfer_minutes,

        minutes_change,
        minutes_percentage_change,

        pre_transfer_goal_contributions_per_90,

        post_transfer_goal_contributions_per_90,

        goal_contributions_per_90_change

    FROM football.vw_summer_transfer_outcomes

    WHERE pre_transfer_minutes >= 450
      AND post_transfer_minutes >= 450
),

classified AS (

    SELECT
        *,

        CASE

            WHEN LOWER(position) = 'goalkeeper'
             AND minutes_change > 0
                THEN 'Improved playing time'

            WHEN LOWER(position) = 'goalkeeper'
             AND minutes_change < 0
                THEN 'Reduced playing time'

            WHEN minutes_change > 0
             AND goal_contributions_per_90_change > 0
                THEN 'Improved minutes and productivity'

            WHEN minutes_change < 0
             AND goal_contributions_per_90_change < 0
                THEN 'Declined minutes and productivity'

            WHEN goal_contributions_per_90_change > 0
                THEN 'Improved productivity'

            WHEN goal_contributions_per_90_change < 0
                THEN 'Reduced productivity'

            WHEN minutes_change > 0
                THEN 'Improved playing time'

            WHEN minutes_change < 0
                THEN 'Reduced playing time'

            ELSE 'broadly stable'

        END AS sporting_outcome_profile

    FROM eligible
)

SELECT
    *,

    DENSE_RANK() OVER (
        ORDER BY
            CASE
                WHEN LOWER(position) = 'goalkeeper'
                    THEN minutes_percentage_change

                ELSE goal_contributions_per_90_change
            END DESC NULLS LAST
    ) AS improvement_rank,

    DENSE_RANK() OVER (
        ORDER BY
            CASE
                WHEN LOWER(position) = 'goalkeeper'
                    THEN minutes_percentage_change

                ELSE goal_contributions_per_90_change
            END ASC NULLS LAST
    ) AS decline_rank

FROM classified

ORDER BY
    improvement_rank,
    player_name;

-- ============================================================
-- EXPORT 7: YOUNG ACQUISITION DEVELOPMENT
--
-- SUPPORTS QUESTION:
--   Q11
--
-- COHORT:
--   Summer transfers
--   Age <= 23
--   Matched pre/post valuations
--
-- MINIMUM SAMPLE:
--   At least 2 eligible young acquisitions per club.
-- ============================================================

WITH young_acquisitions AS (

    SELECT *

    FROM football.vw_summer_transfer_outcomes

    WHERE age_at_transfer <= 23

      AND pre_transfer_season_end_value_eur
          IS NOT NULL

      AND post_transfer_season_end_value_eur
          IS NOT NULL
),

club_summary AS (

    SELECT
        to_club_id AS club_id,
        to_club_name AS club_name,

        to_competition_id AS competition_id,
        to_competition_name AS competition_name,

        COUNT(*)
            AS young_acquisitions_with_value_data,

        COUNT(*) FILTER (
            WHERE post_transfer_value_change_eur > 0
        ) AS young_players_with_value_growth,

        COUNT(*) FILTER (
            WHERE post_transfer_value_change_eur <= 0
        ) AS young_players_without_value_growth,

        SUM(
            GREATEST(
                post_transfer_value_change_eur,
                0
            )
        ) AS total_positive_value_growth_eur,

        SUM(
            post_transfer_value_change_eur
        ) AS net_value_change_eur,

        ROUND(
            AVG(
                post_transfer_value_change_eur
            )::NUMERIC,
            2
        ) AS average_value_change_eur,

        ROUND(
            PERCENTILE_CONT(0.5)
            WITHIN GROUP (
                ORDER BY
                    post_transfer_value_change_eur
            )::NUMERIC,
            2
        ) AS median_value_change_eur,

        ROUND(
            (
                100.0
                * COUNT(*) FILTER (
                    WHERE
                        post_transfer_value_change_eur > 0
                )
                / NULLIF(
                    COUNT(*),
                    0
                )
            )::NUMERIC,
            2
        ) AS successful_value_growth_rate

    FROM young_acquisitions

    GROUP BY
        to_club_id,
        to_club_name,
        to_competition_id,
        to_competition_name
),

ranked AS (

    SELECT
        *,

        DENSE_RANK() OVER (
            ORDER BY
                total_positive_value_growth_eur DESC,
                successful_value_growth_rate DESC,
                net_value_change_eur DESC
        ) AS young_player_development_rank

    FROM club_summary

    WHERE young_acquisitions_with_value_data >= 2
)

SELECT *

FROM ranked

ORDER BY
    young_player_development_rank,
    club_name;

-- ============================================================
-- EXPORT 8: DEVELOPMENT EFFICIENCY VS TRANSFER SPENDING
--
-- SUPPORTS QUESTION:
--   Q12
--
-- COHORT:
--   Summer transfers only
--   Positive known transfer fees only
--   Matched pre/post valuations
--
-- MINIMUM SAMPLE:
--   >= 3 eligible acquisitions per club.
-- ============================================================

WITH eligible_acquisitions AS (

    SELECT *

    FROM football.vw_summer_transfer_outcomes

    WHERE transfer_fee_status =
          'Positive known fee'

      AND transfer_fee > 0

      AND pre_transfer_season_end_value_eur
          IS NOT NULL

      AND post_transfer_season_end_value_eur
          IS NOT NULL
),

club_summary AS (

    SELECT
        to_club_id AS club_id,
        to_club_name AS club_name,

        to_competition_id AS competition_id,
        to_competition_name AS competition_name,

        COUNT(*)
            AS acquisitions_with_known_fee_and_value,

        SUM(transfer_fee)
            AS known_transfer_spending_eur,

        SUM(
            GREATEST(
                post_transfer_value_change_eur,
                0
            )
        ) AS positive_post_transfer_value_growth_eur,

        SUM(
            post_transfer_value_change_eur
        ) AS net_post_transfer_value_change_eur,

        ROUND(
            AVG(
                post_transfer_value_change_eur
            )::NUMERIC,
            2
        ) AS average_post_transfer_value_change_eur,

        ROUND(
            PERCENTILE_CONT(0.5)
            WITHIN GROUP (
                ORDER BY
                    post_transfer_value_change_eur
            )::NUMERIC,
            2
        ) AS median_post_transfer_value_change_eur,

        ROUND(
            (
                SUM(
                    GREATEST(
                        post_transfer_value_change_eur,
                        0
                    )
                )
                /
                NULLIF(
                    SUM(transfer_fee),
                    0
                )
            )::NUMERIC,
            3
        ) AS positive_value_growth_per_euro_spent,

        ROUND(
            (
                SUM(
                    post_transfer_value_change_eur
                )
                /
                NULLIF(
                    SUM(transfer_fee),
                    0
                )
            )::NUMERIC,
            3
        ) AS net_value_change_per_euro_spent,

        ROUND(
            (
                100.0
                * SUM(
                    post_transfer_value_change_eur
                )
                /
                NULLIF(
                    SUM(transfer_fee),
                    0
                )
            )::NUMERIC,
            2
        ) AS net_value_change_vs_spending_percentage

    FROM eligible_acquisitions

    GROUP BY
        to_club_id,
        to_club_name,
        to_competition_id,
        to_competition_name
),

ranked AS (

    SELECT
        *,

        DENSE_RANK() OVER (
            ORDER BY
                net_value_change_per_euro_spent DESC,
                positive_value_growth_per_euro_spent DESC,
                net_post_transfer_value_change_eur DESC
        ) AS development_efficiency_rank

    FROM club_summary

    WHERE acquisitions_with_known_fee_and_value >= 3
)

SELECT *

FROM ranked

ORDER BY
    development_efficiency_rank,
    club_name;