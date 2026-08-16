-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 03_data_quality_checks.sql
-- PURPOSE:
--   1. Validate imported row counts
--   2. Check primary-key integrity
--   3. Identify missing values in important columns
--   4. Test relationships between raw tables
--   5. Identify invalid or unusual football data
--   6. Confirm the completeness of the core analytical scope
--
-- DATABASE: eu_football_analytics
-- RAW SCHEMA: football_raw
-- AUTHOR: Andy Nguyen
--
-- EXECUTION ORDER:
--   Run after 02_import_data.sql
--
-- IMPORTANT:
--   This file identifies data-quality issues only.
--   It must not delete, update or overwrite raw source data.
-- ============================================================


-- ------------------------------------------------------------
-- 1. CONNECTION AND SCHEMA CHECK
-- ------------------------------------------------------------

SELECT
    current_database() AS database_name,
    current_user AS database_user,
    CURRENT_TIMESTAMP AS check_timestamp;

SET search_path TO football_raw, football, public;

SHOW search_path;

-- ------------------------------------------------------------
-- 2. SOURCE ROW-COUNT VALIDATION
-- ------------------------------------------------------------

WITH row_counts AS (

    SELECT
        'competitions' AS table_name,
        COUNT(*) AS actual_rows,
        65::BIGINT AS expected_rows
    FROM football_raw.competitions

    UNION ALL

    SELECT
        'clubs',
        COUNT(*),
        796::BIGINT
    FROM football_raw.clubs

    UNION ALL

    SELECT
        'players',
        COUNT(*),
        50149::BIGINT
    FROM football_raw.players

    UNION ALL

    SELECT
        'games',
        COUNT(*),
        88958::BIGINT
    FROM football_raw.games

    UNION ALL

    SELECT
        'club_games',
        COUNT(*),
        177916::BIGINT
    FROM football_raw.club_games

    UNION ALL

    SELECT
        'appearances',
        COUNT(*),
        1894350::BIGINT
    FROM football_raw.appearances

    UNION ALL

    SELECT
        'player_valuations',
        COUNT(*),
        507815::BIGINT
    FROM football_raw.player_valuations

    UNION ALL

    SELECT
        'transfers',
        COUNT(*),
        35139::BIGINT
    FROM football_raw.transfers
)

SELECT
    table_name,
    actual_rows,
    expected_rows,
    actual_rows - expected_rows AS row_difference,
    CASE
        WHEN actual_rows = expected_rows THEN 'PASS'
        ELSE 'REVIEW'
    END AS quality_status
FROM row_counts
ORDER BY table_name;

-- ------------------------------------------------------------
-- 3. PRIMARY-KEY VALIDATION
-- ------------------------------------------------------------

SELECT
    'competitions.competition_id' AS key_name,
    COUNT(*) AS total_rows,
    COUNT(competition_id) AS non_null_keys,
    COUNT(DISTINCT competition_id) AS distinct_keys,
    CASE
        WHEN COUNT(*) = COUNT(competition_id)
         AND COUNT(*) = COUNT(DISTINCT competition_id)
        THEN 'PASS'
        ELSE 'REVIEW'
    END AS quality_status
FROM football_raw.competitions

UNION ALL

SELECT
    'clubs.club_id',
    COUNT(*),
    COUNT(club_id),
    COUNT(DISTINCT club_id),
    CASE
        WHEN COUNT(*) = COUNT(club_id)
         AND COUNT(*) = COUNT(DISTINCT club_id)
        THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM football_raw.clubs

UNION ALL

SELECT
    'players.player_id',
    COUNT(*),
    COUNT(player_id),
    COUNT(DISTINCT player_id),
    CASE
        WHEN COUNT(*) = COUNT(player_id)
         AND COUNT(*) = COUNT(DISTINCT player_id)
        THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM football_raw.players

UNION ALL

SELECT
    'games.game_id',
    COUNT(*),
    COUNT(game_id),
    COUNT(DISTINCT game_id),
    CASE
        WHEN COUNT(*) = COUNT(game_id)
         AND COUNT(*) = COUNT(DISTINCT game_id)
        THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM football_raw.games

UNION ALL

SELECT
    'appearances.appearance_id',
    COUNT(*),
    COUNT(appearance_id),
    COUNT(DISTINCT appearance_id),
    CASE
        WHEN COUNT(*) = COUNT(appearance_id)
         AND COUNT(*) = COUNT(DISTINCT appearance_id)
        THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM football_raw.appearances

UNION ALL

SELECT
    'transfers.transfer_id',
    COUNT(*),
    COUNT(transfer_id),
    COUNT(DISTINCT transfer_id),
    CASE
        WHEN COUNT(*) = COUNT(transfer_id)
         AND COUNT(*) = COUNT(DISTINCT transfer_id)
        THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM football_raw.transfers;

-- ------------------------------------------------------------
-- 3.1 COMPOSITE PRIMARY-KEY VALIDATION
-- ------------------------------------------------------------

SELECT
    'club_games: game_id + club_id' AS key_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE game_id IS NULL
           OR club_id IS NULL
    ) AS rows_with_null_key,
    COUNT(*) - COUNT(
        DISTINCT (game_id, club_id)
    ) AS duplicate_key_rows,
    CASE
        WHEN COUNT(*) FILTER (
            WHERE game_id IS NULL
               OR club_id IS NULL
        ) = 0
         AND COUNT(*) = COUNT(
            DISTINCT (game_id, club_id)
        )
        THEN 'PASS'
        ELSE 'REVIEW'
    END AS quality_status
FROM football_raw.club_games

UNION ALL

SELECT
    'player_valuations: player_id + date',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE player_id IS NULL
           OR date IS NULL
    ),
    COUNT(*) - COUNT(
        DISTINCT (player_id, date)
    ),
    CASE
        WHEN COUNT(*) FILTER (
            WHERE player_id IS NULL
               OR date IS NULL
        ) = 0
         AND COUNT(*) = COUNT(
            DISTINCT (player_id, date)
        )
        THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM football_raw.player_valuations;

-- ------------------------------------------------------------
-- 4. IMPORTANT MISSING-VALUE CHECKS
-- ------------------------------------------------------------

SELECT
    'players' AS table_name,
    'name' AS column_name,
    COUNT(*) FILTER (WHERE name IS NULL) AS null_rows,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE name IS NULL)
        / NULLIF(COUNT(*), 0),
        2
    ) AS null_percentage
FROM football_raw.players

UNION ALL

SELECT
    'players',
    'date_of_birth',
    COUNT(*) FILTER (WHERE date_of_birth IS NULL),
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE date_of_birth IS NULL
        ) / NULLIF(COUNT(*), 0),
        2
    )
FROM football_raw.players

UNION ALL

SELECT
    'players',
    'position',
    COUNT(*) FILTER (WHERE position IS NULL),
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE position IS NULL
        ) / NULLIF(COUNT(*), 0),
        2
    )
FROM football_raw.players

UNION ALL

SELECT
    'games',
    'competition_id',
    COUNT(*) FILTER (WHERE competition_id IS NULL),
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE competition_id IS NULL
        ) / NULLIF(COUNT(*), 0),
        2
    )
FROM football_raw.games

UNION ALL

SELECT
    'games',
    'date',
    COUNT(*) FILTER (WHERE date IS NULL),
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE date IS NULL
        ) / NULLIF(COUNT(*), 0),
        2
    )
FROM football_raw.games

UNION ALL

SELECT
    'appearances',
    'player_id',
    COUNT(*) FILTER (WHERE player_id IS NULL),
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE player_id IS NULL
        ) / NULLIF(COUNT(*), 0),
        4
    )
FROM football_raw.appearances

UNION ALL

SELECT
    'appearances',
    'game_id',
    COUNT(*) FILTER (WHERE game_id IS NULL),
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE game_id IS NULL
        ) / NULLIF(COUNT(*), 0),
        4
    )
FROM football_raw.appearances

UNION ALL

SELECT
    'appearances',
    'minutes_played',
    COUNT(*) FILTER (WHERE minutes_played IS NULL),
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE minutes_played IS NULL
        ) / NULLIF(COUNT(*), 0),
        4
    )
FROM football_raw.appearances

UNION ALL

SELECT
    'player_valuations',
    'market_value_in_eur',
    COUNT(*) FILTER (
        WHERE market_value_in_eur IS NULL
    ),
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE market_value_in_eur IS NULL
        ) / NULLIF(COUNT(*), 0),
        2
    )
FROM football_raw.player_valuations

UNION ALL

SELECT
    'transfers',
    'transfer_fee',
    COUNT(*) FILTER (WHERE transfer_fee IS NULL),
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE transfer_fee IS NULL
        ) / NULLIF(COUNT(*), 0),
        2
    )
FROM football_raw.transfers

ORDER BY
    table_name,
    column_name;

-- ------------------------------------------------------------
-- 5. FOREIGN-KEY-STYLE RELATIONSHIP CHECKS
-- ------------------------------------------------------------

-- 5.1 Games to competitions

SELECT
    'games.competition_id -> competitions.competition_id'
        AS relationship,
    COUNT(*) FILTER (
        WHERE g.competition_id IS NOT NULL
    ) AS child_rows_checked,
    COUNT(*) FILTER (
        WHERE g.competition_id IS NOT NULL
          AND c.competition_id IS NULL
    ) AS unmatched_rows,
    COUNT(DISTINCT g.competition_id) FILTER (
        WHERE g.competition_id IS NOT NULL
          AND c.competition_id IS NULL
    ) AS unmatched_distinct_ids
FROM football_raw.games AS g
LEFT JOIN football_raw.competitions AS c
    ON g.competition_id = c.competition_id;

-- 5.2 Appearances to players

SELECT
    'appearances.player_id -> players.player_id'
        AS relationship,
    COUNT(*) FILTER (
        WHERE a.player_id IS NOT NULL
    ) AS child_rows_checked,
    COUNT(*) FILTER (
        WHERE a.player_id IS NOT NULL
          AND p.player_id IS NULL
    ) AS unmatched_rows,
    COUNT(DISTINCT a.player_id) FILTER (
        WHERE a.player_id IS NOT NULL
          AND p.player_id IS NULL
    ) AS unmatched_distinct_ids
FROM football_raw.appearances AS a
LEFT JOIN football_raw.players AS p
    ON a.player_id = p.player_id;

-- 5.3 Player valuations to players

SELECT
    'player_valuations.player_id -> players.player_id'
        AS relationship,
    COUNT(*) AS child_rows_checked,
    COUNT(*) FILTER (
        WHERE p.player_id IS NULL
    ) AS unmatched_rows,
    COUNT(DISTINCT pv.player_id) FILTER (
        WHERE p.player_id IS NULL
    ) AS unmatched_distinct_ids
FROM football_raw.player_valuations AS pv
LEFT JOIN football_raw.players AS p
    ON pv.player_id = p.player_id;

-- 5.4 Transfers to players

SELECT
    'transfers.player_id -> players.player_id'
        AS relationship,
    COUNT(*) FILTER (
        WHERE t.player_id IS NOT NULL
    ) AS child_rows_checked,
    COUNT(*) FILTER (
        WHERE t.player_id IS NOT NULL
          AND p.player_id IS NULL
    ) AS unmatched_rows,
    COUNT(DISTINCT t.player_id) FILTER (
        WHERE t.player_id IS NOT NULL
          AND p.player_id IS NULL
    ) AS unmatched_distinct_ids
FROM football_raw.transfers AS t
LEFT JOIN football_raw.players AS p
    ON t.player_id = p.player_id;

-- 5.5 Appearances to games

SELECT
    'appearances.game_id -> games.game_id'
        AS relationship,
    COUNT(*) FILTER (
        WHERE a.game_id IS NOT NULL
    ) AS child_rows_checked,
    COUNT(*) FILTER (
        WHERE a.game_id IS NOT NULL
          AND g.game_id IS NULL
    ) AS unmatched_rows,
    COUNT(DISTINCT a.game_id) FILTER (
        WHERE a.game_id IS NOT NULL
          AND g.game_id IS NULL
    ) AS unmatched_distinct_ids
FROM football_raw.appearances AS a
LEFT JOIN football_raw.games AS g
    ON a.game_id = g.game_id;

-- 5.6 Club-game records to games

SELECT
    'club_games.game_id -> games.game_id'
        AS relationship,
    COUNT(*) AS child_rows_checked,
    COUNT(*) FILTER (
        WHERE g.game_id IS NULL
    ) AS unmatched_rows,
    COUNT(DISTINCT cg.game_id) FILTER (
        WHERE g.game_id IS NULL
    ) AS unmatched_distinct_ids
FROM football_raw.club_games AS cg
LEFT JOIN football_raw.games AS g
    ON cg.game_id = g.game_id;

-- ------------------------------------------------------------
-- 6. UNMATCHED COMPETITION-ID DETAILS
-- ------------------------------------------------------------

SELECT
    g.competition_id,
    COUNT(*) AS game_count,
    MIN(g.season) AS earliest_season,
    MAX(g.season) AS latest_season,
    MIN(g.date) AS earliest_game_date,
    MAX(g.date) AS latest_game_date
FROM football_raw.games AS g
LEFT JOIN football_raw.competitions AS c
    ON g.competition_id = c.competition_id
WHERE c.competition_id IS NULL
GROUP BY g.competition_id
ORDER BY game_count DESC;

-- ------------------------------------------------------------
-- 7. UNMATCHED PLAYER-ID DETAILS
-- ------------------------------------------------------------

SELECT
    a.player_id,
    COUNT(*) AS appearance_count,
    COUNT(DISTINCT a.game_id) AS game_count,
    MIN(a.date) AS earliest_appearance,
    MAX(a.date) AS latest_appearance
FROM football_raw.appearances AS a
LEFT JOIN football_raw.players AS p
    ON a.player_id = p.player_id
WHERE p.player_id IS NULL
GROUP BY a.player_id
ORDER BY appearance_count DESC;

-- ------------------------------------------------------------
-- 8. FOOTBALL-SPECIFIC INTEGRITY CHECKS
-- ------------------------------------------------------------

-- 8.1 Number of club-game records per game

WITH club_game_counts AS (
    SELECT
        game_id,
        COUNT(*) AS club_rows
    FROM football_raw.club_games
    GROUP BY game_id
)

SELECT
    club_rows,
    COUNT(*) AS number_of_games
FROM club_game_counts
GROUP BY club_rows
ORDER BY club_rows;

-- 8.2 Expected game-club pairs absent from club_games

WITH expected_game_clubs AS (

    SELECT
        game_id,
        home_club_id AS club_id
    FROM football_raw.games
    WHERE home_club_id IS NOT NULL

    UNION ALL

    SELECT
        game_id,
        away_club_id AS club_id
    FROM football_raw.games
    WHERE away_club_id IS NOT NULL
)

SELECT
    COUNT(*) AS missing_game_club_pairs
FROM expected_game_clubs AS egc
LEFT JOIN football_raw.club_games AS cg
    ON egc.game_id = cg.game_id
   AND egc.club_id = cg.club_id
WHERE cg.game_id IS NULL;

-- 8.3 Games where home and away club IDs are identical

SELECT
    COUNT(*) AS same_club_game_count
FROM football_raw.games
WHERE home_club_id = away_club_id;

-- ------------------------------------------------------------
-- 9. APPEARANCE-STATISTIC VALIDATION
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_appearances,

    COUNT(*) FILTER (
        WHERE minutes_played < 0
    ) AS negative_minutes,

    COUNT(*) FILTER (
        WHERE minutes_played > 130
    ) AS appearances_above_130_minutes,

    COUNT(*) FILTER (
        WHERE goals < 0
    ) AS negative_goals,

    COUNT(*) FILTER (
        WHERE assists < 0
    ) AS negative_assists,

    COUNT(*) FILTER (
        WHERE yellow_cards < 0
    ) AS negative_yellow_cards,

    COUNT(*) FILTER (
        WHERE red_cards < 0
    ) AS negative_red_cards,

    MIN(minutes_played) AS minimum_minutes,

    MAX(minutes_played) AS maximum_minutes

FROM football_raw.appearances;

-- ------------------------------------------------------------
-- 10. PLAYER PROFILE VALIDATION
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_players,

    COUNT(*) FILTER (
        WHERE height_in_cm IS NOT NULL
    ) AS players_with_height,

    COUNT(*) FILTER (
        WHERE height_in_cm < 140
    ) AS heights_below_140_cm,

    COUNT(*) FILTER (
        WHERE height_in_cm > 220
    ) AS heights_above_220_cm,

    MIN(height_in_cm) AS minimum_height,

    MAX(height_in_cm) AS maximum_height,

    COUNT(*) FILTER (
        WHERE market_value_in_eur < 0
    ) AS negative_current_market_values,

    COUNT(*) FILTER (
        WHERE highest_market_value_in_eur < 0
    ) AS negative_highest_market_values

FROM football_raw.players;

SELECT
    player_id,
    name,
    position,
    date_of_birth,
    height_in_cm,
    current_club_name,
    country_of_citizenship
FROM football_raw.players
WHERE height_in_cm < 140
   OR height_in_cm > 220
ORDER BY height_in_cm;

-- ------------------------------------------------------------
-- 11. PLAYER-VALUATION VALIDATION
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_valuations,

    COUNT(*) FILTER (
        WHERE market_value_in_eur IS NULL
    ) AS missing_market_values,

    COUNT(*) FILTER (
        WHERE market_value_in_eur = 0
    ) AS zero_market_values,

    COUNT(*) FILTER (
        WHERE market_value_in_eur < 0
    ) AS negative_market_values,

    MIN(market_value_in_eur) AS minimum_market_value,

    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY market_value_in_eur
    ) FILTER (
        WHERE market_value_in_eur IS NOT NULL
    ) AS median_market_value,

    MAX(market_value_in_eur) AS maximum_market_value,

    MIN(date) AS earliest_valuation_date,

    MAX(date) AS latest_valuation_date

FROM football_raw.player_valuations;

SELECT
    MIN(valuation_count) AS minimum_valuations_per_player,
    ROUND(AVG(valuation_count), 2)
        AS average_valuations_per_player,
    MAX(valuation_count) AS maximum_valuations_per_player
FROM (
    SELECT
        player_id,
        COUNT(*) AS valuation_count
    FROM football_raw.player_valuations
    GROUP BY player_id
) AS player_counts;

-- ------------------------------------------------------------
-- 12. TRANSFER DATA VALIDATION
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_transfers,

    COUNT(*) FILTER (
        WHERE player_id IS NULL
    ) AS missing_player_ids,

    COUNT(*) FILTER (
        WHERE transfer_date IS NULL
    ) AS missing_transfer_dates,

    COUNT(*) FILTER (
        WHERE from_club_id IS NULL
    ) AS missing_from_club_ids,

    COUNT(*) FILTER (
        WHERE to_club_id IS NULL
    ) AS missing_to_club_ids,

    COUNT(*) FILTER (
        WHERE transfer_fee IS NULL
    ) AS missing_transfer_fees,

    COUNT(*) FILTER (
        WHERE transfer_fee = 0
    ) AS zero_transfer_fees,

    COUNT(*) FILTER (
        WHERE transfer_fee > 0
    ) AS positive_transfer_fees,

    COUNT(*) FILTER (
        WHERE transfer_fee < 0
    ) AS negative_transfer_fees,

    COUNT(*) FILTER (
        WHERE market_value_in_eur IS NULL
    ) AS missing_transfer_market_values,

    MIN(transfer_date) AS earliest_transfer_date,

    MAX(transfer_date) AS latest_transfer_date

FROM football_raw.transfers;

-- Potential duplicate natural transfer records

SELECT
    player_id,
    transfer_date,
    from_club_id,
    to_club_id,
    COUNT(*) AS record_count
FROM football_raw.transfers
GROUP BY
    player_id,
    transfer_date,
    from_club_id,
    to_club_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC;

-- Future-dated transfers

SELECT
    transfer_id,
    player_id,
    player_name,
    transfer_date,
    from_club_name,
    to_club_name,
    transfer_fee
FROM football_raw.transfers
WHERE transfer_date > CURRENT_DATE
ORDER BY transfer_date;

-- ------------------------------------------------------------
-- 13. CORE COMPETITION-SCOPE VALIDATION
-- ------------------------------------------------------------

SELECT
    competition_id,
    name,
    country_name,
    type,
    sub_type
FROM football_raw.competitions
WHERE competition_id IN (
    'GB1',
    'ES1',
    'L1',
    'IT1',
    'FR1'
)
ORDER BY competition_id;

-- ------------------------------------------------------------
-- 14. CORE SEASON AND MATCH-COUNT VALIDATION
-- ------------------------------------------------------------

SELECT
    g.competition_id,
    c.name AS competition_name,
    g.season,
    COUNT(DISTINCT g.game_id) AS game_count,
    MIN(g.date) AS earliest_game,
    MAX(g.date) AS latest_game
FROM football_raw.games AS g
LEFT JOIN football_raw.competitions AS c
    ON g.competition_id = c.competition_id
WHERE g.competition_id IN (
    'GB1',
    'ES1',
    'L1',
    'IT1',
    'FR1'
)
  AND g.season BETWEEN 2020 AND 2024
GROUP BY
    g.competition_id,
    c.name,
    g.season
ORDER BY
    g.competition_id,
    g.season;

-- ============================================================
-- DATA-QUALITY SUMMARY
--
-- Expected documented issues:
--   1. Some game competition IDs lack reference records.
--   2. Two appearances refer to one missing player profile.
--   3. Some historical club IDs are absent from clubs.csv.
--   4. Three appearances exceed 130 minutes.
--   5. Some player heights are implausibly low.
--   6. Transfer fees and market values contain missing values.
--   7. Zero transfer fees cannot automatically be classified
--      as free transfers.
--   8. Some transfers are future-dated.
--
-- Raw values remain unchanged.
-- Cleaning decisions will be implemented in:
--   04_data_cleaning.sql
-- ============================================================


-- ============================================================
-- END OF FILE
-- Next script: 04_data_cleaning.sql
-- ============================================================