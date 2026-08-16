# Data Dictionary

## 1. Dataset Source

This project uses the **Football Data from Transfermarkt** dataset published by David Cariboo on Kaggle:

https://www.kaggle.com/datasets/davidcariboo/player-scores

The upstream dataset is actively maintained and may contain additional tables or fields in newer versions. This data dictionary documents the **eight source CSV tables actually imported into this PostgreSQL project**, based on the local project schema defined in `01_create_tables.sql`.

The project preserves the source data in the `football_raw` schema and creates cleaned and analytical views in the `football` schema. Raw records are not updated or deleted during cleaning.

---

## 2. Database Layers

| Layer | Schema | Purpose |
|---|---|---|
| Raw source layer | `football_raw` | Stores the imported CSV data with source-aligned columns and data types |
| Clean analytical layer | `football` | Standardises missing/invalid values and adds transparent quality flags |
| Scoped analytical layer | `football` | Restricts analysis to the five target leagues and 2020–21 to 2024–25 seasons and creates reusable analytical datasets |

### Core project competitions

| Competition ID | Competition |
|---|---|
| `GB1` | Premier League |
| `ES1` | La Liga |
| `L1` | Bundesliga |
| `IT1` | Serie A |
| `FR1` | Ligue 1 |

---

## 3. Key Relationships

The source files are connected through shared IDs rather than a fully enforced foreign-key structure.

Important analytical relationships include:

- `competitions.competition_id` → `games.competition_id`
- `competitions.competition_id` → `clubs.domestic_competition_id`
- `games.game_id` → `club_games.game_id`
- `games.game_id` → `appearances.game_id`
- `players.player_id` → `appearances.player_id`
- `players.player_id` → `player_valuations.player_id`
- `players.player_id` → `transfers.player_id`
- `clubs.club_id` → club IDs stored in games, appearances, valuations and transfers

Club-related foreign keys are not enforced in the raw schema because some historical club IDs referenced in transactional files are absent from the club reference table.

---

# 4. Raw Source Tables

## 4.1 `football_raw.competitions`

**Grain:** one row per competition.

| Column | PostgreSQL type | Key | Description | Project treatment |
|---|---|---|---|---|
| `competition_id` | `VARCHAR(20)` | PK | Unique competition identifier | Used as the main competition join/filter key |
| `competition_code` | `VARCHAR(100)` |  | Competition code from the source | Blank strings → `NULL` |
| `name` | `TEXT` |  | Competition name | Renamed `competition_name` in clean view |
| `sub_type` | `VARCHAR(100)` |  | Competition sub-type | Renamed `competition_sub_type` |
| `type` | `VARCHAR(100)` |  | Competition type | Renamed `competition_type` |
| `country_id` | `INTEGER` |  | Source country identifier | Negative sentinel values → `NULL`; invalid-ID flag added |
| `country_name` | `VARCHAR(100)` |  | Country associated with competition | Blank strings → `NULL` |
| `domestic_league_code` | `VARCHAR(20)` |  | Domestic league code | Blank strings → `NULL` |
| `confederation` | `VARCHAR(100)` |  | Governing confederation | Blank strings → `NULL` |
| `url` | `TEXT` |  | Source competition URL | Renamed `competition_url`; blanks → `NULL` |

---

## 4.2 `football_raw.clubs`

**Grain:** one row per club in the source club reference file.

| Column | PostgreSQL type | Key | Description | Project treatment |
|---|---|---|---|---|
| `club_id` | `INTEGER` | PK | Unique club identifier | Main club reference key |
| `club_code` | `VARCHAR(255)` |  | Source club code | Blank strings → `NULL` |
| `name` | `TEXT` |  | Club name | Renamed `club_name` |
| `domestic_competition_id` | `VARCHAR(20)` |  | Club's domestic competition identifier | Used to map clubs to competitions |
| `total_market_value` | `BIGINT` |  | Source club total market value | Field was completely missing in the inspected project snapshot; retained as source field |
| `squad_size` | `INTEGER` |  | Number of players in squad | Values ≤0 → `NULL`; quality flag added |
| `average_age` | `NUMERIC(5,2)` |  | Average squad age | Values ≤0 → `NULL`; quality flag added |
| `foreigners_number` | `INTEGER` |  | Number of foreign players | Negative values → `NULL` |
| `foreigners_percentage` | `NUMERIC(7,2)` |  | Foreign players as percentage of squad | Values outside 0–100 → `NULL` |
| `national_team_players` | `INTEGER` |  | Number of national-team players | Negative values → `NULL` |
| `stadium_name` | `TEXT` |  | Club stadium name | Blank strings → `NULL` |
| `stadium_seats` | `INTEGER` |  | Stadium capacity | Values ≤0 → `NULL`; quality flag added |
| `net_transfer_record` | `VARCHAR(100)` |  | Source text describing net transfer record | Preserved as text; blanks → `NULL` |
| `coach_name` | `TEXT` |  | Coach/manager name in source club record | Blank strings → `NULL` |
| `last_season` | `SMALLINT` |  | Latest season associated with the source club record | Preserved |
| `filename` | `TEXT` |  | Source file-related identifier/name | Blank strings → `NULL` |
| `url` | `TEXT` |  | Source club URL | Renamed `club_url`; blanks → `NULL` |

---

## 4.3 `football_raw.players`

**Grain:** one row per player in the player reference file.

| Column | PostgreSQL type | Key | Description | Project treatment |
|---|---|---|---|---|
| `player_id` | `INTEGER` | PK | Unique player identifier | Main player join key |
| `first_name` | `TEXT` |  | Player first name | Trimmed; blanks → `NULL` |
| `last_name` | `TEXT` |  | Player last name | Trimmed; blanks → `NULL` |
| `name` | `TEXT` |  | Full/display player name | Renamed `player_name` |
| `last_season` | `SMALLINT` |  | Latest season associated with source player record | Preserved |
| `current_club_id` | `INTEGER` |  | Current club identifier in source snapshot | Negative sentinel values → `NULL` |
| `player_code` | `TEXT` |  | Source player code/slug | Blank strings → `NULL` |
| `country_of_birth` | `VARCHAR(100)` |  | Country of birth | Blank strings → `NULL` |
| `city_of_birth` | `TEXT` |  | City of birth | Blank strings → `NULL` |
| `country_of_citizenship` | `VARCHAR(100)` |  | Player citizenship/nationality | Blank strings → `NULL` |
| `date_of_birth` | `DATE` |  | Date of birth | Used for age calculations |
| `sub_position` | `VARCHAR(100)` |  | Detailed playing position | Preserved where useful |
| `position` | `VARCHAR(100)` |  | Broad source position | Used for four-group position analysis |
| `foot` | `VARCHAR(20)` |  | Preferred foot | Renamed `preferred_foot` |
| `height_in_cm` | `SMALLINT` |  | Player height in centimetres | Only 140–220 cm retained; otherwise `NULL`; invalid-height flag added |
| `market_value_in_eur` | `BIGINT` |  | Current estimated market value in source snapshot | Negative values → `NULL`; renamed `current_market_value_in_eur` |
| `highest_market_value_in_eur` | `BIGINT` |  | Highest source-recorded estimated market value | Negative values → `NULL` |
| `contract_expiration_date` | `DATE` |  | Contract expiry date where available | Preserved |
| `agent_name` | `TEXT` |  | Agent name | Blank strings → `NULL` |
| `image_url` | `TEXT` |  | Player image URL | Blank strings → `NULL` |
| `url` | `TEXT` |  | Source player URL | Renamed `player_url`; blanks → `NULL` |
| `current_club_domestic_competition_id` | `VARCHAR(20)` |  | Domestic competition of current club | Used as current-club competition context |
| `current_club_name` | `TEXT` |  | Current club name in source snapshot | Blank strings → `NULL` |
| `current_national_team_id` | `INTEGER` |  | Current national-team identifier | Negative values → `NULL` |
| `international_caps` | `INTEGER` |  | Senior international appearances | Negative values → `NULL` |
| `international_goals` | `INTEGER` |  | Senior international goals | Negative values → `NULL` |

---

## 4.4 `football_raw.games`

**Grain:** one row per match.

| Column | PostgreSQL type | Key | Description | Project treatment |
|---|---|---|---|---|
| `game_id` | `INTEGER` | PK | Unique match identifier | Main match join key |
| `competition_id` | `VARCHAR(20)` |  | Competition identifier | Used for league filtering |
| `season` | `SMALLINT` |  | Season start year | 2020–2024 retained in core analytical scope |
| `round` | `TEXT` |  | Competition round/matchday description | Renamed `competition_round` |
| `date` | `DATE` |  | Match date | Renamed `game_date` |
| `home_club_id` | `INTEGER` |  | Home club identifier | Negative values → `NULL` |
| `away_club_id` | `INTEGER` |  | Away club identifier | Negative values → `NULL` |
| `home_club_goals` | `SMALLINT` |  | Home team goals | Negative values → `NULL` |
| `away_club_goals` | `SMALLINT` |  | Away team goals | Negative values → `NULL` |
| `home_club_position` | `SMALLINT` |  | Home club league position recorded with match | Values ≤0 → `NULL` |
| `away_club_position` | `SMALLINT` |  | Away club league position recorded with match | Values ≤0 → `NULL` |
| `home_club_manager_name` | `TEXT` |  | Home club manager | Blank strings → `NULL` |
| `away_club_manager_name` | `TEXT` |  | Away club manager | Blank strings → `NULL` |
| `stadium` | `TEXT` |  | Match stadium | Blank strings → `NULL` |
| `attendance` | `INTEGER` |  | Recorded attendance | Negative values → `NULL` |
| `referee` | `TEXT` |  | Match referee | Blank strings → `NULL` |
| `url` | `TEXT` |  | Source match URL | Renamed `game_url`; blanks → `NULL` |
| `home_club_name` | `TEXT` |  | Home club name | Blank strings → `NULL` |
| `away_club_name` | `TEXT` |  | Away club name | Blank strings → `NULL` |
| `aggregate` | `TEXT` |  | Aggregate-score text where applicable | Renamed `aggregate_score` |
| `competition_type` | `VARCHAR(100)` |  | Competition-type field from source | Blank strings → `NULL` |

**Derived clean fields**

- `match_result`: `Home Win`, `Away Win` or `Draw`
- `has_same_home_away_club`: flags records where both club IDs are equal
- `has_invalid_goal_value`: flags negative goal values from the raw source

---

## 4.5 `football_raw.club_games`

**Grain:** one row per club per game; normally two rows per match.

**Primary key:** (`game_id`, `club_id`)

| Column | PostgreSQL type | Key | Description | Project treatment |
|---|---|---|---|---|
| `game_id` | `INTEGER` | PK (composite) | Match identifier | Joined to `games` |
| `club_id` | `INTEGER` | PK (composite) | Club represented by this row | Negative values → `NULL` in clean view |
| `own_goals` | `SMALLINT` |  | Goals scored by the club represented by the row | Negative values → `NULL` |
| `own_position` | `SMALLINT` |  | Club league position | Values ≤0 → `NULL` |
| `own_manager_name` | `TEXT` |  | Club manager | Blank strings → `NULL` |
| `opponent_id` | `INTEGER` |  | Opponent club identifier | Negative values → `NULL` |
| `opponent_goals` | `SMALLINT` |  | Goals scored by opponent | Negative values → `NULL` |
| `opponent_position` | `SMALLINT` |  | Opponent league position | Values ≤0 → `NULL` |
| `opponent_manager_name` | `TEXT` |  | Opponent manager | Blank strings → `NULL` |
| `hosting` | `VARCHAR(20)` |  | Home/away status | Standardised through trimmed text |
| `is_win` | `BOOLEAN` |  | Source win indicator | Preserved |

**Derived clean field**

```text
points_earned =
3 if own_goals > opponent_goals
1 if own_goals = opponent_goals
0 if own_goals < opponent_goals
```

---

## 4.6 `football_raw.appearances`

**Grain:** one row per player appearance in a match.

| Column | PostgreSQL type | Key | Description | Project treatment |
|---|---|---|---|---|
| `appearance_id` | `VARCHAR(100)` | PK | Unique appearance identifier | Preserved |
| `game_id` | `INTEGER` |  | Match identifier | Joined to `games` |
| `player_id` | `INTEGER` |  | Player identifier | Joined to `players` |
| `player_club_id` | `INTEGER` |  | Club represented by the player in that appearance | Historical membership field used in player-season analysis; negative values → `NULL` |
| `player_current_club_id` | `INTEGER` |  | Current club ID stored in source appearance record | Negative values → `NULL`; invalid-ID flag added |
| `date` | `DATE` |  | Appearance/match date | Renamed `appearance_date` |
| `player_name` | `TEXT` |  | Player name | Blank strings → `NULL` |
| `competition_id` | `VARCHAR(20)` |  | Competition identifier | Used for scope validation/filtering |
| `yellow_cards` | `SMALLINT` |  | Yellow cards recorded in the appearance | Negative values → `NULL` |
| `red_cards` | `SMALLINT` |  | Red cards recorded in the appearance | Negative values → `NULL` |
| `goals` | `SMALLINT` |  | Goals in the appearance | Negative values → `NULL` |
| `assists` | `SMALLINT` |  | Assists in the appearance | Negative values → `NULL` |
| `minutes_played` | `SMALLINT` |  | Minutes played in the match | Raw value retained as `minutes_played_raw`; analytical value retained only when 0–130 |

**Derived clean fields**

- `minutes_played_raw`: original source value
- `minutes_played`: validated analytical value
- `has_invalid_minutes`: flags values below 0 or above 130
- `has_invalid_current_club_id`: flags negative source current-club IDs

---

## 4.7 `football_raw.player_valuations`

**Grain:** one row per player per valuation date.

**Primary key:** (`player_id`, `date`)

| Column | PostgreSQL type | Key | Description | Project treatment |
|---|---|---|---|---|
| `player_id` | `INTEGER` | PK (composite) | Player identifier | Joined to `players` |
| `date` | `DATE` | PK (composite) | Valuation date | Renamed `valuation_date` |
| `market_value_in_eur` | `BIGINT` |  | Estimated player market value in euros | Negative values → `NULL` |
| `current_club_name` | `TEXT` |  | Club name associated with valuation record | Blank strings → `NULL` |
| `current_club_id` | `INTEGER` |  | Club identifier associated with valuation | Negative values → `NULL` |
| `player_club_domestic_competition_id` | `VARCHAR(20)` |  | Domestic competition associated with player's club | Used for competition context |

**Derived clean field**

`market_value_status` distinguishes:

- `Missing`
- `Zero`
- `Positive`
- `Invalid`

Market values are treated as estimated valuations, not transaction prices.

---

## 4.8 `football_raw.transfers`

**Grain:** one row per source transfer record.

The source transfer data does not provide a stable unique transfer ID in the project snapshot, so PostgreSQL creates a surrogate identity key.

| Column | PostgreSQL type | Key | Description | Project treatment |
|---|---|---|---|---|
| `transfer_id` | `BIGINT` identity | PK | PostgreSQL-generated surrogate transfer identifier | Generated during import/storage |
| `player_id` | `INTEGER` |  | Player identifier | Joined to `players` |
| `transfer_date` | `DATE` |  | Transfer date | Used for seasonal and summer-transfer cohorts |
| `transfer_season` | `VARCHAR(20)` |  | Source transfer-season label | Trimmed; blanks → `NULL` |
| `from_club_id` | `INTEGER` |  | Origin club identifier | Negative values → `NULL` |
| `to_club_id` | `INTEGER` |  | Destination club identifier | Negative values → `NULL` |
| `from_club_name` | `TEXT` |  | Origin club name | Trimmed; blanks → `NULL` |
| `to_club_name` | `TEXT` |  | Destination club name | Trimmed; blanks → `NULL` |
| `transfer_fee` | `BIGINT` |  | Recorded transfer fee in euros where numeric/available | Negative values → `NULL`; missing, zero and positive fees classified separately |
| `market_value_in_eur` | `BIGINT` |  | Player market value recorded with transfer record | Negative values → `NULL` |
| `player_name` | `TEXT` |  | Player name | Trimmed; blanks → `NULL` |

**Derived clean fields**

`transfer_fee_status`:

| Status | Meaning |
|---|---|
| `Positive known fee` | Numeric fee greater than zero |
| `Recorded zero fee` | Numeric source fee equals zero |
| `Missing or undisclosed fee` | No numeric fee is available |
| `Invalid fee` | Residual invalid case |

Additional flags:

- `is_future_transfer`
- `has_same_origin_destination`

Missing/undisclosed fees are not treated as free transfers.

---

# 5. Clean Analytical Views

The cleaning script creates one view for each raw source table without modifying the original data.

| View | Source | Main purpose |
|---|---|---|
| `football.clean_competitions` | `football_raw.competitions` | Standardise text and invalid country IDs |
| `football.clean_clubs` | `football_raw.clubs` | Validate squad, age, foreign-player and stadium fields |
| `football.clean_players` | `football_raw.players` | Standardise profile fields, validate IDs, height and market values |
| `football.clean_games` | `football_raw.games` | Validate clubs/goals/positions and derive match result |
| `football.clean_club_games` | `football_raw.club_games` | Validate club-perspective match fields and derive points |
| `football.clean_appearances` | `football_raw.appearances` | Validate appearance statistics and preserve raw minutes |
| `football.clean_player_valuations` | `football_raw.player_valuations` | Validate market values and classify value status |
| `football.clean_transfers` | `football_raw.transfers` | Validate IDs/values and distinguish known, zero and missing fees |

### Global cleaning rules

1. Raw source tables remain unchanged.
2. Blank text values are standardised to `NULL`.
3. Negative sentinel IDs are converted to `NULL`.
4. Player heights outside 140–220 cm are converted to `NULL`.
5. Invalid appearance minutes are converted to `NULL`, while the source value remains available as `minutes_played_raw`.
6. Zero and missing transfer fees are treated as different categories.
7. Future transfer records are retained and explicitly flagged.
8. Invalid club squad, age and stadium values are converted to `NULL`.
9. Cleaning remains traceable to the raw source values.

---

# 6. Core Analytical Views

The scoped views in `05_create_views_and_indexes.sql` form the reusable analytical layer for Themes 1–5.

## `football.vw_core_competitions`

Restricts competitions to the five target domestic leagues.

**Main fields:** competition ID/code/name, country, competition type/sub-type, domestic league code and confederation.

---

## `football.vw_core_games`

Restricts games to the five target leagues and seasons 2020–2024.

Important derived fields include:

- `season_label` — display form such as `2020-21`
- `season_end_date` — standard reference date of 30 June following the season start year
- `total_goals` — home plus away goals

Used primarily in club, league and player-season analysis.

---

## `football.vw_core_club_matches`

Converts match data to the club perspective.

**Grain:** one row per club per core match.

Important derived fields include:

- `club_name`
- `opponent_name`
- `club_result`
- `goal_difference`
- `points_earned`

This view is the main input for club-season aggregation.

---

## `football.vw_club_season_performance`

**Grain:** one row per club-season.

Important measures include:

- matches played
- wins, draws and losses
- home/away matches and wins
- goals scored/conceded
- goal difference
- total points
- win percentage
- goals scored per match
- goals conceded per match
- points per match
- home win percentage
- away win percentage

Used primarily in Theme 1 and as club-strength context elsewhere.

---

## `football.vw_core_appearances`

Links validated appearance records to core match and season context.

**Grain:** one row per eligible appearance record.

Provides player, club, competition, season, match, goals, assists and validated minutes data.

---

## `football.vw_core_players`

Creates the scoped player reference population used by downstream player analyses.

It combines cleaned player information with project-relevant club/competition context and supports age and position-based analysis.

---

## `football.vw_player_season_performance`

**Grain:** player–club–season analytical record.

This is the principal reusable player-performance dataset.

It aggregates appearance-level data into season-level measures used for:

- minutes played;
- appearances;
- goals;
- assists;
- goal contributions;
- per-90 productivity;
- player-season rankings;
- recruitment analysis; and
- historical performance comparisons.

---

## `football.vw_player_season_valuations`

Maps historical player valuations to the project season framework and supports season-level valuation analysis.

Used for:

- beginning/end-of-season valuation comparisons;
- market-value growth;
- recruitment value benchmarks; and
- post-transfer valuation analysis.

---

## `football.vw_core_transfers`

Prepares cleaned transfer records for project analysis and adds project-scope club/competition context where available.

Used for:

- known transfer expenditure and income;
- net known-fee balances;
- league transfer flows;
- transfer routes;
- fee analysis by age and position;
- summer-transfer cohorts; and
- post-transfer analysis.

---

## `football.vw_project_scope_summary`

Provides a compact validation summary of the scoped analytical dataset.

Used to verify the expected project population after competition and season filtering.

---

# 7. Indexes Used for Analytical Performance

The project creates indexes on commonly joined or filtered raw-table fields.

| Index target | Purpose |
|---|---|
| `games (competition_id, season)` | Speeds competition/season filtering |
| `appearances (game_id)` | Speeds appearance-to-game joins |
| `appearances (player_id)` | Speeds player-level aggregation |
| `appearances (player_club_id)` | Speeds historical club-player aggregation |
| `appearances (competition_id)` | Speeds appearance competition filtering |
| `transfers (player_id, transfer_date)` | Speeds transfer-history analysis |
| `transfers (from_club_id)` | Speeds origin-club transfer analysis |
| `transfers (to_club_id)` | Speeds destination-club transfer analysis |
| `clubs (domestic_competition_id)` | Speeds club competition filtering |

---

# 8. Important Interpretation Notes

### Market value

`market_value_in_eur` represents an **estimated market value**, not a realised transaction price.

### Transfer fees

Transfer financial analyses use numeric fees where available. The project distinguishes:

- positive known fees;
- recorded zero fees; and
- missing/undisclosed fees.

Therefore, reported spending, income and balances are described as **known-fee** measures.

### Historical club membership

For historical player-performance analysis, `player_club_id` from appearance records is preferred over current-club fields, because current-club fields represent a later source snapshot rather than historical membership.

### Positions

The project standardises player analysis into four broad groups:

- Goalkeeper
- Defender
- Midfield
- Attack

Position grouping and downstream recruitment rules are documented in `methodology.md`.

---

# 9. Source and Project Provenance

The upstream Kaggle dataset is updated over time, so its current schema may differ from the project snapshot used here. This dictionary therefore treats the project's PostgreSQL schema as the authoritative record of the data actually analysed.

The raw layer was designed to match the downloaded CSV structure. Project-specific cleaning, classifications, derived measures and analytical views are documented separately so that source fields remain distinguishable from transformations introduced by the analysis.
