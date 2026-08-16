-- ============================================================
-- PROJECT: European Football Talent and Transfer Analytics
-- FILE: 01_create_tables.sql
-- PURPOSE:
--   1. Create the eight raw source tables
--   2. Match the structure of the downloaded Kaggle CSV files
--   3. Preserve source data before cleaning or transformation
--
-- DATABASE: eu_football_analytics
-- RAW SCHEMA: football_raw
-- AUTHOR: Andy Nguyen
--
-- EXECUTION ORDER:
--   Run after 00_database_setup.sql
--
-- IMPORTANT:
--   These tables represent the raw data layer.
--   Cleaning rules and project-scope filters will be applied
--   later in the football analytical schema.
-- ============================================================

-- ------------------------------------------------------------
-- 1. SESSION AND SCHEMA CHECK
-- ------------------------------------------------------------

SELECT
    current_database() AS database_name,
    current_user AS database_user;

SET search_path TO football_raw, football, public;

SHOW search_path;

-- ------------------------------------------------------------
-- 2. COMPETITIONS
-- One row per competition.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS football_raw.competitions (
    competition_id          VARCHAR(20) PRIMARY KEY,
    competition_code        VARCHAR(100),
    name                    TEXT,
    sub_type                VARCHAR(100),
    type                    VARCHAR(100),
    country_id              INTEGER,
    country_name            VARCHAR(100),
    domestic_league_code    VARCHAR(20),
    confederation           VARCHAR(100),
    url                     TEXT
);

-- ------------------------------------------------------------
-- 3. CLUBS
-- One row per club included in the club reference file.
-- Some historical club IDs used elsewhere are absent from this
-- source table, so club-related foreign keys are not added yet.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS football_raw.clubs (
    club_id                         INTEGER PRIMARY KEY,
    club_code                       VARCHAR(255),
    name                            TEXT,
    domestic_competition_id         VARCHAR(20),
    total_market_value              BIGINT,
    squad_size                      INTEGER,
    average_age                     NUMERIC(5,2),
    foreigners_number               INTEGER,
    foreigners_percentage           NUMERIC(7,2),
    national_team_players           INTEGER,
    stadium_name                    TEXT,
    stadium_seats                   INTEGER,
    net_transfer_record             VARCHAR(100),
    coach_name                      TEXT,
    last_season                     SMALLINT,
    filename                        TEXT,
    url                             TEXT
);

-- ------------------------------------------------------------
-- 4. PLAYERS
-- One row per player profile.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS football_raw.players (
    player_id                               INTEGER PRIMARY KEY,
    first_name                              TEXT,
    last_name                               TEXT,
    name                                    TEXT,
    last_season                             SMALLINT,
    current_club_id                         INTEGER,
    player_code                             TEXT,
    country_of_birth                        VARCHAR(100),
    city_of_birth                           TEXT,
    country_of_citizenship                  VARCHAR(100),
    date_of_birth                           DATE,
    sub_position                            VARCHAR(100),
    position                                VARCHAR(100),
    foot                                    VARCHAR(20),
    height_in_cm                            SMALLINT,
    market_value_in_eur                     BIGINT,
    highest_market_value_in_eur             BIGINT,
    contract_expiration_date                DATE,
    agent_name                              TEXT,
    image_url                               TEXT,
    url                                     TEXT,
    current_club_domestic_competition_id    VARCHAR(20),
    current_club_name                       TEXT,
    current_national_team_id                INTEGER,
    international_caps                      INTEGER,
    international_goals                     INTEGER
);

-- ------------------------------------------------------------
-- 5. GAMES
-- One row per match.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS football_raw.games (
    game_id                     INTEGER PRIMARY KEY,
    competition_id              VARCHAR(20),
    season                      SMALLINT,
    round                       TEXT,
    date                        DATE,
    home_club_id                INTEGER,
    away_club_id                INTEGER,
    home_club_goals             SMALLINT,
    away_club_goals             SMALLINT,
    home_club_position          SMALLINT,
    away_club_position          SMALLINT,
    home_club_manager_name      TEXT,
    away_club_manager_name      TEXT,
    stadium                     TEXT,
    attendance                  INTEGER,
    referee                     TEXT,
    url                         TEXT,
    home_club_name              TEXT,
    away_club_name              TEXT,
    aggregate                   TEXT,
    competition_type            VARCHAR(100)
);

-- ------------------------------------------------------------
-- 6. CLUB_GAMES
-- Two club-perspective rows are normally recorded per match:
-- one for each participating club.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS football_raw.club_games (
    game_id                    INTEGER NOT NULL,
    club_id                    INTEGER NOT NULL,
    own_goals                  SMALLINT,
    own_position               SMALLINT,
    own_manager_name           TEXT,
    opponent_id                INTEGER,
    opponent_goals             SMALLINT,
    opponent_position          SMALLINT,
    opponent_manager_name      TEXT,
    hosting                    VARCHAR(20),
    is_win                     BOOLEAN,

    CONSTRAINT pk_club_games
        PRIMARY KEY (game_id, club_id)
);

-- ------------------------------------------------------------
-- 7. APPEARANCES
-- One row per player appearance in a game.
-- This is the largest raw table in the project.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS football_raw.appearances (
    appearance_id              VARCHAR(100) PRIMARY KEY,
    game_id                    INTEGER,
    player_id                  INTEGER,
    player_club_id             INTEGER,
    player_current_club_id     INTEGER,
    date                       DATE,
    player_name                TEXT,
    competition_id             VARCHAR(20),
    yellow_cards               SMALLINT,
    red_cards                  SMALLINT,
    goals                      SMALLINT,
    assists                    SMALLINT,
    minutes_played             SMALLINT
);

-- ------------------------------------------------------------
-- 8. PLAYER_VALUATIONS
-- Multiple historical valuations can exist for each player.
-- The combination of player_id and date is unique.
-- Structure matches the current player_valuations.csv file.
-- ------------------------------------------------------------

CREATE TABLE football_raw.player_valuations (
    player_id                              INTEGER NOT NULL,
    date                                   DATE NOT NULL,
    market_value_in_eur                    BIGINT,
    current_club_name                      TEXT,
    current_club_id                        INTEGER,
    player_club_domestic_competition_id    VARCHAR(20),

    CONSTRAINT pk_player_valuations
        PRIMARY KEY (player_id, date)
);

-- ------------------------------------------------------------
-- 9. TRANSFERS
-- Transfer records do not include a stable source transfer ID.
-- A generated PostgreSQL surrogate key is therefore used.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS football_raw.transfers (
    transfer_id            BIGINT GENERATED ALWAYS AS IDENTITY
                           PRIMARY KEY,
    player_id              INTEGER,
    transfer_date          DATE,
    transfer_season        VARCHAR(20),
    from_club_id           INTEGER,
    to_club_id             INTEGER,
    from_club_name         TEXT,
    to_club_name           TEXT,
    transfer_fee           BIGINT,
    market_value_in_eur    BIGINT,
    player_name            TEXT
);

-- ------------------------------------------------------------
-- 10. TABLE DOCUMENTATION
-- ------------------------------------------------------------

COMMENT ON TABLE football_raw.competitions IS
    'Raw competition reference data imported from competitions.csv.';

COMMENT ON TABLE football_raw.clubs IS
    'Raw club reference data imported from clubs.csv.';

COMMENT ON TABLE football_raw.players IS
    'Raw player profile data imported from players.csv.';

COMMENT ON TABLE football_raw.games IS
    'Raw match-level data imported from games.csv.';

COMMENT ON TABLE football_raw.club_games IS
    'Raw club-perspective match records imported from club_games.csv.';

COMMENT ON TABLE football_raw.appearances IS
    'Raw player-match appearance data imported from appearances.csv.';

COMMENT ON TABLE football_raw.player_valuations IS
    'Raw historical player market valuation data imported from player_valuations.csv.';

COMMENT ON TABLE football_raw.transfers IS
    'Raw player transfer records imported from transfers.csv, with a PostgreSQL-generated transfer ID.';

-- ------------------------------------------------------------
-- 11. VERIFY CREATED TABLES
-- Expected result: eight tables.
-- ------------------------------------------------------------

SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'football_raw'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- ------------------------------------------------------------
-- 12. VERIFY PRIMARY KEYS
-- ------------------------------------------------------------

SELECT
    tc.table_name,
    tc.constraint_name,
    kcu.column_name,
    kcu.ordinal_position
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
   AND tc.table_schema = kcu.table_schema
WHERE tc.table_schema = 'football_raw'
  AND tc.constraint_type = 'PRIMARY KEY'
ORDER BY
    tc.table_name,
    kcu.ordinal_position;

-- ------------------------------------------------------------
-- 13. VERIFY THAT TABLES ARE CURRENTLY EMPTY
-- ------------------------------------------------------------

SELECT 'competitions' AS table_name,
       COUNT(*) AS row_count
FROM football_raw.competitions

UNION ALL

SELECT 'clubs',
       COUNT(*)
FROM football_raw.clubs

UNION ALL

SELECT 'players',
       COUNT(*)
FROM football_raw.players

UNION ALL

SELECT 'games',
       COUNT(*)
FROM football_raw.games

UNION ALL

SELECT 'club_games',
       COUNT(*)
FROM football_raw.club_games

UNION ALL

SELECT 'appearances',
       COUNT(*)
FROM football_raw.appearances

UNION ALL

SELECT 'player_valuations',
       COUNT(*)
FROM football_raw.player_valuations

UNION ALL

SELECT 'transfers',
       COUNT(*)
FROM football_raw.transfers

ORDER BY table_name;


-- ============================================================
-- END OF FILE
-- Next script: 02_import_data.sql
-- ============================================================