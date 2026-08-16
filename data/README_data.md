# Data

## Source Dataset

This project uses **Football Data from Transfermarkt**, published by David Cariboo on Kaggle:

https://www.kaggle.com/datasets/davidcariboo/player-scores

The source dataset is actively maintained, so the current online schema may differ from the snapshot used in this project.

## Raw Data Availability

The raw dataset is **not included in this GitHub repository**.

The local source archive used for the project exceeds 200 MB, and the data can be obtained directly from the original Kaggle page. Keeping the raw files out of the repository also avoids duplicating a dataset that already has a maintained upstream source.

To reproduce the project:

1. Download the dataset from Kaggle.
2. Extract the CSV files locally.
3. Update local file paths in the SQL import script if necessary.
4. Run the PostgreSQL setup/import scripts in numerical order.

## Source Tables Used

The PostgreSQL project imports eight source tables:

| Source file/table | Purpose |
|---|---|
| `competitions` | Competition reference information |
| `clubs` | Club information and current/source attributes |
| `players` | Player reference and demographic information |
| `games` | Match-level domestic competition data |
| `club_games` | Club-perspective match records |
| `appearances` | Player match appearances, minutes, goals and assists |
| `player_valuations` | Historical estimated player market values |
| `transfers` | Player transfer movements and recorded transfer fees |

The upstream Kaggle dataset may now contain additional files. This repository documents only the tables actually imported and analysed in this project.

## Project Database Layers

```text
Source CSV files
      ↓
football_raw schema
      ↓
clean SQL views
      ↓
scoped analytical views
      ↓
Theme 1–5 SQL analysis
```

The raw imported tables are preserved. Cleaning and standardisation are applied through SQL so that source values remain traceable.

## Important Data Notes

- Market values are **estimated values**, not transaction prices.
- Transfer fees can be positive known fees, recorded zero fees, or missing/undisclosed.
- Missing transfer fees are not assumed to represent free transfers.
- Historical player analysis uses the relevant club-season context where available.
- The analysis is restricted to the Premier League, La Liga, Bundesliga, Serie A and Ligue 1 for the 2020–21 to 2024–25 seasons.

## Documentation

For field definitions, PostgreSQL types, keys, cleaning treatment and analytical views, see:

[`../documentation/data_dictionary.md`](../documentation/data_dictionary.md)

For analytical thresholds and methodology, see:

[`../documentation/methodology.md`](../documentation/methodology.md)

## Attribution

**David Cariboo — Football Data from Transfermarkt**  
https://www.kaggle.com/datasets/davidcariboo/player-scores

Please consult the original dataset page for the latest source documentation and applicable usage/licensing terms.
