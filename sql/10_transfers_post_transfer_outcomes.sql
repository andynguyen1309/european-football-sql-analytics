-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 10_transfers_post_transfer_outcomes.sql
-- THEME: Transfers and Post-Transfer Outcomes
--
-- BUSINESS OBJECTIVE:
--   Assess transfer-market flows, club recruitment strategies
--   and player outcomes after changing clubs.
--
-- CORE ANALYTICAL WINDOW:
--   Transfer seasons 2020-21 to 2024-25
--
-- IMPORTANT FEE RULES:
--   transfer_fee IS NULL -> Missing / undisclosed fee
--   transfer_fee = 0     -> Recorded zero fee
--   transfer_fee > 0     -> Positive known fee
--
--   A recorded zero fee is NOT automatically classified as a
--   free transfer because transfer type is not available.
--
-- POST-TRANSFER ANALYSIS:
--   Requires a player to have eligible performance/value data
--   before and after the transfer.
--
-- AUTHOR: Andy Nguyen
-- ============================================================

SET search_path TO football, football_raw, public;

-- ============================================================
-- REBUILD NOTE
--
-- The revised transfer-event view changes its output schema.
-- PostgreSQL CREATE OR REPLACE VIEW cannot reorder existing
-- view columns, so the previous dependent transfer views are
-- dropped before rebuilding.
-- ============================================================

DROP VIEW IF EXISTS football.vw_summer_transfer_outcomes CASCADE;
DROP VIEW IF EXISTS football.vw_summer_transfer_events CASCADE;
DROP VIEW IF EXISTS football.vw_transfer_outcomes CASCADE;
DROP VIEW IF EXISTS football.vw_core_transfer_events CASCADE;
DROP VIEW IF EXISTS football.vw_transfer_events CASCADE;

-- ============================================================
-- A1. TRANSFER EVENT BASE
--
-- GRAIN:
--   One row per transfer record.
--
-- TRANSFER SEASON:
--   July-December -> season beginning that calendar year
--   January-June  -> previous calendar year's season
-- ============================================================

CREATE OR REPLACE VIEW football.vw_club_season_league_map AS

SELECT DISTINCT
    club_id,
    club_name,
    season,
    competition_id,
    competition_name,
    country_name

FROM football.vw_club_season_performance;

-- ============================================================
-- A2. CORE FIVE-LEAGUE TRANSFER EVENTS
-- ============================================================

CREATE OR REPLACE VIEW football.vw_club_season_league_map AS

SELECT DISTINCT
    club_id,
    club_name,
    season,
    competition_id,
    competition_name,
    country_name

FROM football.vw_club_season_performance;

CREATE OR REPLACE VIEW football.vw_transfer_events AS

WITH transfer_base AS (

    SELECT
        t.transfer_id,
        t.player_id,
        t.player_name,

        t.transfer_date,

        CASE
            WHEN EXTRACT(MONTH FROM t.transfer_date) >= 7
                THEN EXTRACT(YEAR FROM t.transfer_date)::INTEGER
            ELSE EXTRACT(YEAR FROM t.transfer_date)::INTEGER - 1
        END AS transfer_season,

        t.from_club_id,
        t.from_club_name,

        t.to_club_id,
        t.to_club_name,

        t.transfer_fee,
        t.market_value_in_eur,

        CASE
            WHEN t.transfer_fee IS NULL
                THEN 'Missing or undisclosed fee'

            WHEN t.transfer_fee = 0
                THEN 'Recorded zero fee'

            WHEN t.transfer_fee > 0
                THEN 'Positive known fee'

            ELSE 'Other / review'
        END AS transfer_fee_status

    FROM football_raw.transfers AS t

    WHERE t.transfer_date >= DATE '2020-07-01'
      AND t.transfer_date <  DATE '2025-07-01'
),

with_player AS (

    SELECT
        tb.*,

        p.position,
        p.sub_position,
        p.date_of_birth,
        p.country_of_citizenship,

        DATE_PART(
            'year',
            AGE(
                tb.transfer_date,
                p.date_of_birth
            )
        )::INTEGER AS age_at_transfer,

        CASE
            WHEN EXTRACT(MONTH FROM tb.transfer_date)
                 BETWEEN 7 AND 9
                THEN tb.transfer_season - 1

            ELSE tb.transfer_season
        END AS from_mapping_season,

        tb.transfer_season AS to_mapping_season

    FROM transfer_base AS tb

    LEFT JOIN football_raw.players AS p
        ON tb.player_id = p.player_id
),

mapped AS (

    SELECT
        wp.*,

        fm.competition_id
            AS historical_from_competition_id,

        fm.competition_name
            AS historical_from_competition_name,

        fm.country_name
            AS historical_from_country_name,

        tm.competition_id
            AS historical_to_competition_id,

        tm.competition_name
            AS historical_to_competition_name,

        tm.country_name
            AS historical_to_country_name

    FROM with_player AS wp

    LEFT JOIN football.vw_club_season_league_map AS fm
        ON wp.from_club_id = fm.club_id
       AND wp.from_mapping_season = fm.season

    LEFT JOIN football.vw_club_season_league_map AS tm
        ON wp.to_club_id = tm.club_id
       AND wp.to_mapping_season = tm.season
),

with_fallback AS (

    SELECT
        m.*,

        rc_from.domestic_competition_id
            AS fallback_from_competition_id,

        rc_to.domestic_competition_id
            AS fallback_to_competition_id

    FROM mapped AS m

    LEFT JOIN football_raw.clubs AS rc_from
        ON m.from_club_id = rc_from.club_id

    LEFT JOIN football_raw.clubs AS rc_to
        ON m.to_club_id = rc_to.club_id
)

SELECT
    wf.transfer_id,
    wf.player_id,
    wf.player_name,

    wf.transfer_date,
    wf.transfer_season,

    wf.from_mapping_season,
    wf.to_mapping_season,

    wf.from_club_id,
    wf.from_club_name,

    wf.to_club_id,
    wf.to_club_name,

    wf.transfer_fee,
    wf.market_value_in_eur,

    wf.transfer_fee_status,

    wf.position,
    wf.sub_position,
    wf.date_of_birth,
    wf.country_of_citizenship,
    wf.age_at_transfer,

    COALESCE(
        wf.historical_from_competition_id,
        wf.fallback_from_competition_id
    ) AS from_competition_id,

    COALESCE(
        wf.historical_from_competition_name,
        fc.name
    ) AS from_competition_name,

    COALESCE(
        wf.historical_from_country_name,
        fc.country_name
    ) AS from_country_name,

    COALESCE(
        wf.historical_to_competition_id,
        wf.fallback_to_competition_id
    ) AS to_competition_id,

    COALESCE(
        wf.historical_to_competition_name,
        tc.name
    ) AS to_competition_name,

    COALESCE(
        wf.historical_to_country_name,
        tc.country_name
    ) AS to_country_name,

    CASE
        WHEN wf.historical_from_competition_id IS NOT NULL
            THEN 'Historical club-season mapping'

        WHEN wf.fallback_from_competition_id IS NOT NULL
            THEN 'Current-club fallback'

        ELSE 'Unmapped'
    END AS from_league_mapping_method,

    CASE
        WHEN wf.historical_to_competition_id IS NOT NULL
            THEN 'Historical club-season mapping'

        WHEN wf.fallback_to_competition_id IS NOT NULL
            THEN 'Current-club fallback'

        ELSE 'Unmapped'
    END AS to_league_mapping_method,

    CASE
        WHEN wf.age_at_transfer IS NULL
            THEN 'Unknown'

        WHEN wf.age_at_transfer <= 20
            THEN '20 or younger'

        WHEN wf.age_at_transfer <= 23
            THEN '21-23'

        WHEN wf.age_at_transfer <= 27
            THEN '24-27'

        WHEN wf.age_at_transfer <= 31
            THEN '28-31'

        ELSE '32+'
    END AS age_group

FROM with_fallback AS wf

LEFT JOIN football_raw.competitions AS fc
    ON wf.fallback_from_competition_id
     = fc.competition_id

LEFT JOIN football_raw.competitions AS tc
    ON wf.fallback_to_competition_id
     = tc.competition_id;
        
-- ============================================================
-- A3. PLAYER-SEASON PERFORMANCE FOR TRANSFER ANALYSIS
--
-- GRAIN:
--   One player per season.
-- ============================================================

CREATE OR REPLACE VIEW football.vw_core_transfer_events AS

SELECT *

FROM football.vw_transfer_events

WHERE transfer_season BETWEEN 2020 AND 2024

  AND (
        from_competition_id IN (
            'GB1',
            'ES1',
            'L1',
            'IT1',
            'FR1'
        )

        OR

        to_competition_id IN (
            'GB1',
            'ES1',
            'L1',
            'IT1',
            'FR1'
        )
      );

-- ============================================================
-- A4. PLAYER SEASON-END MARKET VALUES
-- ============================================================

CREATE OR REPLACE VIEW football.vw_transfer_season_end_values AS

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

    WHERE pv.market_value_in_eur IS NOT NULL
      AND pv.market_value_in_eur >= 0

      AND pv.date >= DATE '2019-07-01'
      AND pv.date <  DATE '2026-07-01'
)

SELECT DISTINCT ON (
    player_id,
    season
)

    player_id,
    season,
    valuation_date,
    market_value_in_eur

FROM valuation_seasons

ORDER BY
    player_id,
    season,
    valuation_date DESC;

-- ============================================================
-- A5. TRANSFER OUTCOME ANALYSIS
--
-- PRE PERIOD:
--   Season immediately before transfer season.
--
-- POST PERIOD:
--   Transfer season.
--
-- REQUIREMENT:
--   Player must have performance records in both periods for
--   performance-change calculations.
-- ============================================================

CREATE OR REPLACE VIEW football.vw_transfer_outcomes AS

SELECT
    te.transfer_id,
    te.player_id,
    te.player_name,

    te.transfer_date,
    te.transfer_season,

    te.age_at_transfer,
    te.age_group,

    te.position,
    te.sub_position,

    te.from_club_id,
    te.from_club_name,
    te.from_competition_id,
    te.from_competition_name,

    te.to_club_id,
    te.to_club_name,
    te.to_competition_id,
    te.to_competition_name,

    te.transfer_fee,
    te.transfer_fee_status,

    te.market_value_in_eur
        AS market_value_at_transfer_eur,

    pre_perf.minutes_played
        AS pre_transfer_minutes,

    post_perf.minutes_played
        AS post_transfer_minutes,

    post_perf.minutes_played
        - pre_perf.minutes_played
        AS minutes_change,

    ROUND(
        (
            100.0
            * (
                post_perf.minutes_played
                - pre_perf.minutes_played
            )
            / NULLIF(pre_perf.minutes_played, 0)
        )::NUMERIC,
        2
    ) AS minutes_percentage_change,

    pre_perf.goal_contributions_per_90
        AS pre_transfer_goal_contributions_per_90,

    post_perf.goal_contributions_per_90
        AS post_transfer_goal_contributions_per_90,

    ROUND(
        (
            post_perf.goal_contributions_per_90
            - pre_perf.goal_contributions_per_90
        )::NUMERIC,
        3
    ) AS goal_contributions_per_90_change,

    pre_value.market_value_in_eur
        AS pre_transfer_season_end_value_eur,

    post_value.market_value_in_eur
        AS post_transfer_season_end_value_eur,

    post_value.market_value_in_eur
        - pre_value.market_value_in_eur
        AS post_transfer_value_change_eur,

    ROUND(
        (
            100.0
            * (
                post_value.market_value_in_eur
                - pre_value.market_value_in_eur
            )
            / NULLIF(
                pre_value.market_value_in_eur,
                0
            )
        )::NUMERIC,
        2
    ) AS post_transfer_value_percentage_change

FROM football.vw_core_transfer_events AS te

LEFT JOIN football.vw_transfer_player_season_performance
    AS pre_perf

    ON te.player_id = pre_perf.player_id
   AND pre_perf.season = te.transfer_season - 1

LEFT JOIN football.vw_transfer_player_season_performance
    AS post_perf

    ON te.player_id = post_perf.player_id
   AND post_perf.season = te.transfer_season

LEFT JOIN football.vw_transfer_season_end_values
    AS pre_value

    ON te.player_id = pre_value.player_id
   AND pre_value.season = te.transfer_season - 1

LEFT JOIN football.vw_transfer_season_end_values
    AS post_value

    ON te.player_id = post_value.player_id
   AND post_value.season = te.transfer_season;
    
    
-- ============================================================
-- B1. CLEAN SUMMER TRANSFER COHORT
--
-- PURPOSE:
--   Restrict post-transfer outcome analysis to transfers
--   occurring during the primary summer window.
--
-- REASON:
--   Avoid mixing pre- and post-transfer clubs within the same
--   season for January/winter transfers.
--
-- WINDOW:
--   July 1 through September 30
-- ============================================================

CREATE OR REPLACE VIEW
football.vw_summer_transfer_events AS

SELECT *

FROM football.vw_core_transfer_events

WHERE EXTRACT(
        MONTH FROM transfer_date
      ) BETWEEN 7 AND 9;

-- ============================================================
-- B2. CLEAN SUMMER POST-TRANSFER OUTCOME VIEW
--
-- PRE PERIOD:
--   Season immediately before the summer transfer.
--
-- POST PERIOD:
--   First full season following the transfer.
--
-- This produces a cleaner before/after comparison than using
-- winter transfers.
-- ============================================================

CREATE OR REPLACE VIEW
football.vw_summer_transfer_outcomes AS

SELECT
    te.transfer_id,
    te.player_id,
    te.player_name,

    te.transfer_date,
    te.transfer_season,

    te.age_at_transfer,
    te.age_group,

    te.position,
    te.sub_position,

    te.from_club_id,
    te.from_club_name,
    te.from_competition_id,
    te.from_competition_name,

    te.to_club_id,
    te.to_club_name,
    te.to_competition_id,
    te.to_competition_name,

    te.transfer_fee,
    te.transfer_fee_status,

    te.market_value_in_eur
        AS market_value_at_transfer_eur,

    -- --------------------------------------------------------
    -- PRE / POST PLAYING TIME
    -- --------------------------------------------------------

    pre_perf.minutes_played
        AS pre_transfer_minutes,

    post_perf.minutes_played
        AS post_transfer_minutes,

    post_perf.minutes_played
    - pre_perf.minutes_played
        AS minutes_change,

    ROUND(
        (
            100.0
            * (
                post_perf.minutes_played
                - pre_perf.minutes_played
            )
            / NULLIF(
                pre_perf.minutes_played,
                0
            )
        )::NUMERIC,
        2
    ) AS minutes_percentage_change,

    -- --------------------------------------------------------
    -- PRE / POST PRODUCTIVITY
    -- --------------------------------------------------------

    pre_perf.goal_contributions_per_90
        AS pre_transfer_goal_contributions_per_90,

    post_perf.goal_contributions_per_90
        AS post_transfer_goal_contributions_per_90,

    ROUND(
        (
            post_perf.goal_contributions_per_90
            -
            pre_perf.goal_contributions_per_90
        )::NUMERIC,
        3
    ) AS goal_contributions_per_90_change,

    -- --------------------------------------------------------
    -- PRE / POST MARKET VALUE
    -- --------------------------------------------------------

    pre_value.market_value_in_eur
        AS pre_transfer_season_end_value_eur,

    post_value.market_value_in_eur
        AS post_transfer_season_end_value_eur,

    post_value.market_value_in_eur
    - pre_value.market_value_in_eur
        AS post_transfer_value_change_eur,

    ROUND(
        (
            100.0
            * (
                post_value.market_value_in_eur
                -
                pre_value.market_value_in_eur
            )
            / NULLIF(
                pre_value.market_value_in_eur,
                0
            )
        )::NUMERIC,
        2
    ) AS post_transfer_value_percentage_change

FROM football.vw_summer_transfer_events AS te

LEFT JOIN
football.vw_transfer_player_season_performance
    AS pre_perf

    ON te.player_id = pre_perf.player_id
   AND pre_perf.season
       = te.transfer_season - 1

LEFT JOIN
football.vw_transfer_player_season_performance
    AS post_perf

    ON te.player_id = post_perf.player_id
   AND post_perf.season
       = te.transfer_season

LEFT JOIN
football.vw_transfer_season_end_values
    AS pre_value

    ON te.player_id = pre_value.player_id
   AND pre_value.season
       = te.transfer_season - 1

LEFT JOIN
football.vw_transfer_season_end_values
    AS post_value

    ON te.player_id = post_value.player_id
   AND post_value.season
       = te.transfer_season;
    
    
-- ============================================================
-- QUESTION 1
-- Which clubs recorded the highest transfer expenditure?
-- ============================================================

SELECT
    to_club_id AS club_id,
    to_club_name AS club_name,

    to_competition_id AS competition_id,
    to_competition_name AS competition_name,

    COUNT(*) AS incoming_transfer_records,

    COUNT(*) FILTER (
        WHERE transfer_fee_status = 'Positive known fee'
    ) AS known_paid_transfers,

    COUNT(*) FILTER (
        WHERE transfer_fee_status = 'Recorded zero fee'
    ) AS recorded_zero_fee_transfers,

    COUNT(*) FILTER (
        WHERE transfer_fee_status = 'Missing or undisclosed fee'
    ) AS missing_or_undisclosed_fee_transfers,

    SUM(transfer_fee) FILTER (
        WHERE transfer_fee_status = 'Positive known fee'
    ) AS known_transfer_expenditure_eur,

    ROUND(
        AVG(transfer_fee) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        )::NUMERIC,
        2
    ) AS average_known_transfer_fee_eur,

    DENSE_RANK() OVER (
        ORDER BY
            SUM(transfer_fee) FILTER (
                WHERE transfer_fee_status = 'Positive known fee'
            ) DESC NULLS LAST
    ) AS expenditure_rank

FROM football.vw_core_transfer_events

WHERE to_competition_id IN (
    'GB1', 'ES1', 'L1', 'IT1', 'FR1'
)

GROUP BY
    to_club_id,
    to_club_name,
    to_competition_id,
    to_competition_name

ORDER BY
    expenditure_rank,
    club_name;

-- ============================================================
-- QUESTION 2
-- Which clubs generated the highest transfer income?
-- ============================================================

SELECT
    from_club_id AS club_id,
    from_club_name AS club_name,

    from_competition_id AS competition_id,
    from_competition_name AS competition_name,

    COUNT(*) AS outgoing_transfer_records,

    COUNT(*) FILTER (
        WHERE transfer_fee_status = 'Positive known fee'
    ) AS known_fee_sales,

    COUNT(*) FILTER (
        WHERE transfer_fee_status = 'Recorded zero fee'
    ) AS recorded_zero_fee_departures,

    COUNT(*) FILTER (
        WHERE transfer_fee_status = 'Missing or undisclosed fee'
    ) AS missing_or_undisclosed_fee_departures,

    SUM(transfer_fee) FILTER (
        WHERE transfer_fee_status = 'Positive known fee'
    ) AS known_transfer_income_eur,

    DENSE_RANK() OVER (
        ORDER BY
            SUM(transfer_fee) FILTER (
                WHERE transfer_fee_status = 'Positive known fee'
            ) DESC NULLS LAST
    ) AS transfer_income_rank

FROM football.vw_core_transfer_events

WHERE from_competition_id IN (
    'GB1', 'ES1', 'L1', 'IT1', 'FR1'
)

GROUP BY
    from_club_id,
    from_club_name,
    from_competition_id,
    from_competition_name

ORDER BY
    transfer_income_rank,
    club_name;

-- ============================================================
-- QUESTION 3
-- Which clubs recorded the largest positive and negative
-- net transfer balances?
-- ============================================================

WITH expenditure AS (

    SELECT
        to_club_id AS club_id,

        SUM(transfer_fee) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        ) AS expenditure_eur,

        COUNT(*) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        ) AS known_purchases

    FROM football.vw_core_transfer_events

    GROUP BY to_club_id
),

income AS (

    SELECT
        from_club_id AS club_id,

        SUM(transfer_fee) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        ) AS income_eur,

        COUNT(*) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        ) AS known_sales

    FROM football.vw_core_transfer_events

    GROUP BY from_club_id
),

core_clubs AS (

    SELECT DISTINCT
        club_id,
        club_name,
        competition_id,
        competition_name

    FROM (

        SELECT
            to_club_id AS club_id,
            to_club_name AS club_name,
            to_competition_id AS competition_id,
            to_competition_name AS competition_name

        FROM football.vw_core_transfer_events

        WHERE to_competition_id IN (
            'GB1', 'ES1', 'L1', 'IT1', 'FR1'
        )

        UNION

        SELECT
            from_club_id,
            from_club_name,
            from_competition_id,
            from_competition_name

        FROM football.vw_core_transfer_events

        WHERE from_competition_id IN (
            'GB1', 'ES1', 'L1', 'IT1', 'FR1'
        )

    ) AS clubs
),

balances AS (

    SELECT
        cc.*,

        COALESCE(i.income_eur, 0)
            AS known_transfer_income_eur,

        COALESCE(e.expenditure_eur, 0)
            AS known_transfer_expenditure_eur,

        COALESCE(i.income_eur, 0)
        - COALESCE(e.expenditure_eur, 0)
            AS net_transfer_balance_eur,

        COALESCE(i.known_sales, 0)
            AS known_sales,

        COALESCE(e.known_purchases, 0)
            AS known_purchases

    FROM core_clubs AS cc

    LEFT JOIN income AS i
        ON cc.club_id = i.club_id

    LEFT JOIN expenditure AS e
        ON cc.club_id = e.club_id
)

SELECT
    *,

    DENSE_RANK() OVER (
        ORDER BY net_transfer_balance_eur DESC
    ) AS positive_balance_rank,

    DENSE_RANK() OVER (
        ORDER BY net_transfer_balance_eur ASC
    ) AS negative_balance_rank

FROM balances

ORDER BY
    net_transfer_balance_eur DESC;

-- ============================================================
-- QUESTION 4
-- Which leagues were net importers and exporters of players?
--
-- IMPORTANT:
--   Internal transfers within the same league are excluded
--   from net player-flow calculations because they do not
--   represent imports or exports at league level.
-- ============================================================

WITH external_transfers AS (

    SELECT *

    FROM football.vw_core_transfer_events

    WHERE from_competition_id IS NOT NULL
      AND to_competition_id IS NOT NULL
      AND from_competition_id <> to_competition_id
),

league_inflows AS (

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

    WHERE to_competition_id IN (
        'GB1', 'ES1', 'L1', 'IT1', 'FR1'
    )

    GROUP BY
        to_competition_id
),

league_outflows AS (

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

    WHERE from_competition_id IN (
        'GB1', 'ES1', 'L1', 'IT1', 'FR1'
    )

    GROUP BY
        from_competition_id
)

SELECT
    c.competition_id,
    c.name AS competition_name,
    c.country_name,

    COALESCE(
        li.incoming_external_transfers,
        0
    ) AS incoming_external_transfers,

    COALESCE(
        lo.outgoing_external_transfers,
        0
    ) AS outgoing_external_transfers,

    COALESCE(
        li.incoming_external_transfers,
        0
    )
    -
    COALESCE(
        lo.outgoing_external_transfers,
        0
    ) AS net_player_flow,

    COALESCE(
        li.incoming_known_fee_transfers,
        0
    ) AS incoming_known_fee_transfers,

    COALESCE(
        lo.outgoing_known_fee_transfers,
        0
    ) AS outgoing_known_fee_transfers,

    COALESCE(
        lo.known_income_eur,
        0
    ) AS known_transfer_income_eur,

    COALESCE(
        li.known_expenditure_eur,
        0
    ) AS known_transfer_expenditure_eur,

    COALESCE(
        lo.known_income_eur,
        0
    )
    -
    COALESCE(
        li.known_expenditure_eur,
        0
    ) AS known_financial_balance_eur,

    CASE
        WHEN COALESCE(
                li.incoming_external_transfers,
                0
             )
             >
             COALESCE(
                lo.outgoing_external_transfers,
                0
             )
            THEN 'Net player importer'

        WHEN COALESCE(
                li.incoming_external_transfers,
                0
             )
             <
             COALESCE(
                lo.outgoing_external_transfers,
                0
             )
            THEN 'Net player exporter'

        ELSE 'Balanced player flow'
    END AS player_flow_profile

FROM football_raw.competitions AS c

LEFT JOIN league_inflows AS li
    ON c.competition_id = li.competition_id

LEFT JOIN league_outflows AS lo
    ON c.competition_id = lo.competition_id

WHERE c.competition_id IN (
    'GB1',
    'ES1',
    'L1',
    'IT1',
    'FR1'
)

ORDER BY
    net_player_flow DESC;

-- ============================================================
-- QUESTION 5
-- Which transfer routes between leagues occurred most often?
--
-- Uses historical club-season league mapping.
-- Same-league transfers excluded.
-- ============================================================

SELECT
    from_competition_id,
    from_competition_name,

    to_competition_id,
    to_competition_name,

    COUNT(*) AS transfer_count,

    COUNT(*) FILTER (
        WHERE transfer_fee_status
              = 'Positive known fee'
    ) AS known_fee_transfer_count,

    COUNT(*) FILTER (
        WHERE transfer_fee_status
              = 'Recorded zero fee'
    ) AS recorded_zero_fee_count,

    COUNT(*) FILTER (
        WHERE transfer_fee_status
              = 'Missing or undisclosed fee'
    ) AS missing_or_undisclosed_fee_count,

    SUM(transfer_fee) FILTER (
        WHERE transfer_fee_status
              = 'Positive known fee'
    ) AS known_transfer_value_eur,

    ROUND(
        AVG(transfer_fee) FILTER (
            WHERE transfer_fee_status
                  = 'Positive known fee'
        )::NUMERIC,
        2
    ) AS average_known_transfer_fee_eur,

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
-- QUESTION 6
-- Which age groups attracted the highest transfer fees?
-- ============================================================

SELECT
    age_group,

    COUNT(*) FILTER (
        WHERE transfer_fee_status = 'Positive known fee'
    ) AS known_fee_transfers,

    SUM(transfer_fee) FILTER (
        WHERE transfer_fee_status = 'Positive known fee'
    ) AS total_known_fees_eur,

    ROUND(
        AVG(transfer_fee) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        )::NUMERIC,
        2
    ) AS average_known_fee_eur,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY transfer_fee
        ) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        )::NUMERIC,
        2
    ) AS median_known_fee_eur,

    MAX(transfer_fee) FILTER (
        WHERE transfer_fee_status = 'Positive known fee'
    ) AS highest_known_fee_eur

FROM football.vw_core_transfer_events

WHERE age_group <> 'Unknown'

GROUP BY age_group

ORDER BY
    median_known_fee_eur DESC;

-- ============================================================
-- QUESTION 7
-- Which positions commanded the highest median transfer fees?
-- ============================================================

SELECT
    position,

    COUNT(*) FILTER (
        WHERE transfer_fee_status = 'Positive known fee'
    ) AS known_fee_transfers,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY transfer_fee
        ) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        )::NUMERIC,
        2
    ) AS median_transfer_fee_eur,

    ROUND(
        AVG(transfer_fee) FILTER (
            WHERE transfer_fee_status = 'Positive known fee'
        )::NUMERIC,
        2
    ) AS average_transfer_fee_eur,

    MAX(transfer_fee) FILTER (
        WHERE transfer_fee_status = 'Positive known fee'
    ) AS maximum_transfer_fee_eur

FROM football.vw_core_transfer_events

WHERE position IS NOT NULL

GROUP BY position

ORDER BY
    median_transfer_fee_eur DESC;

-- ============================================================
-- QUESTION 8
-- Which transfers were followed by the largest increases
-- in estimated market value?
-- ============================================================

SELECT
    transfer_id,
    player_id,
    player_name,

    age_at_transfer,
    position,

    transfer_date,
    transfer_season,

    from_club_name,
    to_club_name,

    from_competition_name,
    to_competition_name,

    transfer_fee,
    transfer_fee_status,

    pre_transfer_season_end_value_eur,
    post_transfer_season_end_value_eur,

    post_transfer_value_change_eur,
    post_transfer_value_percentage_change,

    DENSE_RANK() OVER (
        ORDER BY
            post_transfer_value_change_eur DESC
    ) AS absolute_value_growth_rank,

    DENSE_RANK() OVER (
        ORDER BY
            post_transfer_value_percentage_change DESC
    ) AS percentage_value_growth_rank

FROM football.vw_summer_transfer_outcomes

WHERE pre_transfer_season_end_value_eur
      IS NOT NULL

  AND post_transfer_season_end_value_eur
      IS NOT NULL

  AND pre_transfer_season_end_value_eur > 0

  AND post_transfer_value_change_eur > 0

ORDER BY
    absolute_value_growth_rank,
    player_name;

-- ============================================================
-- QUESTION 9
-- Which players improved playing time or productivity
-- after transferring?
--
-- ELIGIBILITY:
--   >= 450 minutes in both pre and post seasons.
--
-- GOALKEEPER NOTE:
--   Productivity change is not an appropriate primary
--   goalkeeper measure; playing-time change is more relevant.
-- ============================================================

SELECT
    transfer_id,
    player_id,
    player_name,

    age_at_transfer,
    position,

    transfer_date,

    from_club_name,
    to_club_name,

    from_competition_name,
    to_competition_name,

    transfer_fee,
    transfer_fee_status,

    pre_transfer_minutes,
    post_transfer_minutes,

    minutes_change,
    minutes_percentage_change,

    pre_transfer_goal_contributions_per_90,
    post_transfer_goal_contributions_per_90,

    goal_contributions_per_90_change,

    CASE

        WHEN LOWER(position) = 'goalkeeper'
         AND minutes_change > 0
            THEN 'Improved goalkeeper playing time'

        WHEN LOWER(position) <> 'goalkeeper'
         AND minutes_change > 0
         AND goal_contributions_per_90_change > 0
            THEN 'Improved minutes and productivity'

        WHEN LOWER(position) <> 'goalkeeper'
         AND goal_contributions_per_90_change > 0
            THEN 'Improved productivity'

        WHEN minutes_change > 0
            THEN 'Improved playing time'

        ELSE 'No improvement'

    END AS post_transfer_improvement_profile,

    DENSE_RANK() OVER (

        ORDER BY

            CASE
                WHEN LOWER(position) = 'goalkeeper'
                    THEN 0

                ELSE COALESCE(
                    goal_contributions_per_90_change,
                    0
                )
            END DESC,

            minutes_change DESC

    ) AS post_transfer_improvement_rank

FROM football.vw_summer_transfer_outcomes

WHERE pre_transfer_minutes >= 450
  AND post_transfer_minutes >= 450

  AND (

        minutes_change > 0

        OR

        (
            LOWER(position) <> 'goalkeeper'
            AND goal_contributions_per_90_change > 0
        )
      )

ORDER BY
    post_transfer_improvement_rank,
    player_name;

-- ============================================================
-- QUESTION 10
-- Which players experienced reduced playing time or
-- performance after transferring?
-- ============================================================

SELECT
    transfer_id,
    player_id,
    player_name,

    age_at_transfer,
    position,

    transfer_date,

    from_club_name,
    to_club_name,

    from_competition_name,
    to_competition_name,

    transfer_fee,
    transfer_fee_status,

    pre_transfer_minutes,
    post_transfer_minutes,

    minutes_change,
    minutes_percentage_change,

    pre_transfer_goal_contributions_per_90,
    post_transfer_goal_contributions_per_90,

    goal_contributions_per_90_change,

    CASE

        WHEN LOWER(position) = 'goalkeeper'
         AND minutes_change < 0
            THEN 'Reduced goalkeeper playing time'

        WHEN LOWER(position) <> 'goalkeeper'
         AND minutes_change < 0
         AND goal_contributions_per_90_change < 0
            THEN 'Declined minutes and productivity'

        WHEN LOWER(position) <> 'goalkeeper'
         AND goal_contributions_per_90_change < 0
            THEN 'Reduced productivity'

        WHEN minutes_change < 0
            THEN 'Reduced playing time'

        ELSE 'No decline'

    END AS post_transfer_decline_profile,

    DENSE_RANK() OVER (

        ORDER BY

            CASE
                WHEN LOWER(position) = 'goalkeeper'
                    THEN 0

                ELSE COALESCE(
                    goal_contributions_per_90_change,
                    0
                )
            END ASC,

            minutes_change ASC

    ) AS post_transfer_decline_rank

FROM football.vw_summer_transfer_outcomes

WHERE pre_transfer_minutes >= 450
  AND post_transfer_minutes >= 450

  AND (

        minutes_change < 0

        OR

        (
            LOWER(position) <> 'goalkeeper'
            AND goal_contributions_per_90_change < 0
        )
      )

ORDER BY
    post_transfer_decline_rank,
    player_name;

-- ============================================================
-- QUESTION 11
-- Which clubs appeared most successful at acquiring young
-- players whose values later increased?
--
-- COHORT:
--   Summer transfers
--   Age <= 23
--   Pre and post value available
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

club_development AS (

    SELECT
        to_club_id AS club_id,
        to_club_name AS club_name,

        to_competition_id
            AS competition_id,

        to_competition_name
            AS competition_name,

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
)

SELECT
    *,

    DENSE_RANK() OVER (

        ORDER BY
            total_positive_value_growth_eur DESC,
            successful_value_growth_rate DESC,
            net_value_change_eur DESC

    ) AS young_player_development_rank

FROM club_development

WHERE young_acquisitions_with_value_data >= 2

ORDER BY
    young_player_development_rank,
    club_name;

-- ============================================================
-- QUESTION 12
-- Which clubs achieved the strongest player-development
-- outcomes relative to known transfer spending?
--
-- COHORT:
--   Summer transfers only.
--
-- FINANCIAL RULE:
--   Only positive known transfer fees.
--
-- ELIGIBILITY:
--   Matched pre/post valuations.
--   At least 3 eligible acquisitions per club.
-- ============================================================

WITH eligible_acquisitions AS (

    SELECT *

    FROM football.vw_summer_transfer_outcomes

    WHERE transfer_fee_status
          = 'Positive known fee'

      AND transfer_fee > 0

      AND pre_transfer_season_end_value_eur
          IS NOT NULL

      AND post_transfer_season_end_value_eur
          IS NOT NULL
),

club_results AS (

    SELECT
        to_club_id AS club_id,
        to_club_name AS club_name,

        to_competition_id
            AS competition_id,

        to_competition_name
            AS competition_name,

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
)

SELECT
    *,

    DENSE_RANK() OVER (

        ORDER BY
            net_value_change_per_euro_spent DESC,
            positive_value_growth_per_euro_spent DESC,
            net_post_transfer_value_change_eur DESC

    ) AS development_efficiency_rank

FROM club_results

WHERE acquisitions_with_known_fee_and_value >= 3

ORDER BY
    development_efficiency_rank,
    club_name;

-- ============================================================
-- THEME 5 VALIDATION
-- ============================================================


-- 1. Transfer fee status distribution

SELECT
    transfer_fee_status,
    COUNT(*) AS transfer_count,

    ROUND(
        (
            100.0
            * COUNT(*)
            / SUM(COUNT(*)) OVER ()
        )::NUMERIC,
        2
    ) AS percentage_of_transfers

FROM football.vw_core_transfer_events

GROUP BY transfer_fee_status

ORDER BY transfer_count DESC;


-- 2. Transfer records by season

SELECT
    transfer_season,
    COUNT(*) AS transfer_records,

    COUNT(*) FILTER (
        WHERE transfer_fee_status = 'Positive known fee'
    ) AS positive_known_fee_records,

    COUNT(*) FILTER (
        WHERE transfer_fee_status = 'Recorded zero fee'
    ) AS zero_fee_records,

    COUNT(*) FILTER (
        WHERE transfer_fee_status =
              'Missing or undisclosed fee'
    ) AS missing_fee_records

FROM football.vw_core_transfer_events

GROUP BY transfer_season

ORDER BY transfer_season;


-- 3. Club-to-league mapping coverage

SELECT
    COUNT(*) AS transfer_records,

    COUNT(from_competition_id)
        AS mapped_from_league,

    COUNT(to_competition_id)
        AS mapped_to_league,

    ROUND(
        (
            100.0
            * COUNT(from_competition_id)
            / NULLIF(COUNT(*), 0)
        )::NUMERIC,
        2
    ) AS from_league_mapping_percentage,

    ROUND(
        (
            100.0
            * COUNT(to_competition_id)
            / NULLIF(COUNT(*), 0)
        )::NUMERIC,
        2
    ) AS to_league_mapping_percentage

FROM football.vw_core_transfer_events;

--see which mapping method is being used

SELECT
    from_league_mapping_method,
    COUNT(*) AS transfer_count

FROM football.vw_core_transfer_events

GROUP BY
    from_league_mapping_method

ORDER BY
    transfer_count DESC;


SELECT
    to_league_mapping_method,
    COUNT(*) AS transfer_count

FROM football.vw_core_transfer_events

GROUP BY
    to_league_mapping_method

ORDER BY
    transfer_count DESC;



-- 4. Player profile coverage

SELECT
    COUNT(*) AS transfers,

    COUNT(position) AS known_position,

    COUNT(age_at_transfer) AS known_age,

    ROUND(
        (
            100.0 * COUNT(position)
            / NULLIF(COUNT(*), 0)
        )::NUMERIC,
        2
    ) AS position_coverage_percentage,

    ROUND(
        (
            100.0 * COUNT(age_at_transfer)
            / NULLIF(COUNT(*), 0)
        )::NUMERIC,
        2
    ) AS age_coverage_percentage

FROM football.vw_core_transfer_events;


-- 5. Post-transfer performance coverage

SELECT
    COUNT(*) AS transfer_events,

    COUNT(*) FILTER (
        WHERE pre_transfer_minutes IS NOT NULL
    ) AS with_pre_transfer_performance,

    COUNT(*) FILTER (
        WHERE post_transfer_minutes IS NOT NULL
    ) AS with_post_transfer_performance,

    COUNT(*) FILTER (
        WHERE pre_transfer_minutes IS NOT NULL
          AND post_transfer_minutes IS NOT NULL
    ) AS with_both_performance_periods

FROM football.vw_transfer_outcomes;


-- 6. Post-transfer valuation coverage

SELECT
    COUNT(*) AS transfer_events,

    COUNT(*) FILTER (
        WHERE pre_transfer_season_end_value_eur IS NOT NULL
    ) AS with_pre_value,

    COUNT(*) FILTER (
        WHERE post_transfer_season_end_value_eur IS NOT NULL
    ) AS with_post_value,

    COUNT(*) FILTER (
        WHERE pre_transfer_season_end_value_eur IS NOT NULL
          AND post_transfer_season_end_value_eur IS NOT NULL
    ) AS with_both_values

FROM football.vw_transfer_outcomes;


-- 7. Check implausible transfer ages

SELECT
    MIN(age_at_transfer) AS youngest_transfer_age,
    MAX(age_at_transfer) AS oldest_transfer_age,

    COUNT(*) FILTER (
        WHERE age_at_transfer < 15
           OR age_at_transfer > 45
    ) AS potentially_invalid_ages

FROM football.vw_core_transfer_events;


-- 8. Known positive fee summary

SELECT
    COUNT(*) AS positive_fee_transfers,

    MIN(transfer_fee) AS minimum_positive_fee,

    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (
            ORDER BY transfer_fee
        )::NUMERIC,
        2
    ) AS median_positive_fee,

    ROUND(
        AVG(transfer_fee)::NUMERIC,
        2
    ) AS average_positive_fee,

    MAX(transfer_fee) AS maximum_positive_fee

FROM football.vw_core_transfer_events

WHERE transfer_fee_status = 'Positive known fee';


-- 9. Confirm no unknown fee treated as zero

SELECT
    COUNT(*) FILTER (
        WHERE transfer_fee IS NULL
    ) AS null_fee_records,

    COUNT(*) FILTER (
        WHERE transfer_fee = 0
    ) AS recorded_zero_fee_records,

    COUNT(*) FILTER (
        WHERE transfer_fee > 0
    ) AS positive_fee_records

FROM football.vw_core_transfer_events;


-- 10. Outcome sample after minimum-minute rule

SELECT
    COUNT(*) AS eligible_transfer_outcomes

FROM football.vw_transfer_outcomes

WHERE pre_transfer_minutes >= 450
  AND post_transfer_minutes >= 450;

-- size of clean summer cohort

SELECT
    COUNT(*) AS summer_transfer_events,

    ROUND(
        (
            100.0
            * COUNT(*)
            /
            (
                SELECT COUNT(*)
                FROM football.vw_core_transfer_events
            )
        )::NUMERIC,
        2
    ) AS percentage_of_all_core_transfers

FROM football.vw_summer_transfer_events;

-- usable performance outcomes after summer restriction

SELECT
    COUNT(*) AS summer_transfer_events,

    COUNT(*) FILTER (
        WHERE pre_transfer_minutes IS NOT NULL
          AND post_transfer_minutes IS NOT NULL
    ) AS with_both_performance_periods,

    COUNT(*) FILTER (
        WHERE pre_transfer_minutes >= 450
          AND post_transfer_minutes >= 450
    ) AS eligible_450_minute_outcomes,

    COUNT(*) FILTER (
        WHERE pre_transfer_season_end_value_eur
              IS NOT NULL
          AND post_transfer_season_end_value_eur
              IS NOT NULL
    ) AS with_both_market_values

FROM football.vw_summer_transfer_outcomes;