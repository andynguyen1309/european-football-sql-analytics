# Theme 2 — Player Performance and Consistency

## Business objective

Identify productive, reliable and improving players across Europe’s five major domestic leagues while making fair comparisons across positions, seasons and playing time.

## Analytical scope

- **Competitions:** Premier League, La Liga, Bundesliga, Serie A and Ligue 1
- **Seasons:** 2020–21 to 2024–25
- **Standard per-90 threshold:** at least 900 league minutes
- **Availability analysis:** at least 1,800 league minutes
- **Under-23 definition:** age 22 or younger at season end
- **Historical membership:** players are linked to their club in the relevant season rather than their current club
- **Goalkeepers:** excluded from attacking productivity rankings

> The Tableau dashboard opens on the 2024–25 season. The productivity metric, season, league and position can be changed interactively. Year-on-year improvement uses a separate **Improvement to Season** control because the first season has no preceding season for comparison.

---

## Executive summary

The 2024–25 productivity view identified **Omar Marmoush at Eintracht Frankfurt** as the leading player-club record for goal contributions per 90, at **1.545**, narrowly ahead of **Ousmane Dembélé at Paris Saint-Germain** at **1.503**. Harry Kane, Ferran Torres, Alexander Sørloth and Mohamed Salah also exceeded 1.25 goal contributions per 90 under the 900-minute qualification rule.

The strongest year-on-year improvement belonged to **Mateo Retegui**, whose goal contributions per 90 increased from **0.364 in 2023–24 to 1.235 in 2024–25**, a rise of **0.871**. Dembélé recorded the second-largest increase, from 0.716 to 1.503.

Across multiple qualified seasons, the sustained-performance analysis highlighted **Kylian Mbappé, Erling Haaland, Robert Lewandowski, Harry Kane and Mohamed Salah** as prominent high-productivity players. The chart also shows that high average output does not always mean low season-to-season variation.

The productivity-and-availability analysis demonstrates that players can reach a strong combined profile in different ways. The top-right quadrant identifies those who rank above the position- and league-adjusted median for both productivity and availability.

---

## Dashboard

![Theme 2 dashboard](../images/theme_2/theme_2_dashboard.png)

The dashboard combines four reader-facing outputs:

1. Top player-club performances by a selectable per-90 metric
2. Largest year-on-year improvements
3. Sustained multi-season productivity and consistency
4. Productivity combined with reliable availability

---

# Findings by business question

## Question 1 — Which players recorded the highest goals per 90 minutes?

The `player_season_productivity.csv` output ranks eligible player-club-season records by goals per 90 after applying the 900-minute threshold and excluding goalkeepers.

The Tableau leaderboard includes a **Productivity Metric** selector. Choosing **Goals per 90** recalculates the top ten for the selected season, league and position.

### Interpretation

Per-90 scoring identifies efficient finishers, but it should be read alongside:

- total goals
- minutes played
- club and league context
- position

A player with a high scoring rate over 900–1,200 minutes may not provide the same full-season value as a player sustaining a slightly lower rate over 2,500–3,000 minutes.

---

## Question 2 — Which players recorded the highest assists per 90 minutes?

The same productivity output ranks eligible records by assists per 90 when **Assists per 90** is selected in the dashboard.

### Interpretation

Assist rates are useful for identifying creative output, but they remain dependent on teammate finishing and the source dataset’s assist definitions. Total assists and minutes should therefore be retained in tooltips and supporting tables.

---

## Question 3 — Which players generated the highest combined goal contributions per 90?

### 2024–25 top ten

| Rank | Player–club | Goal contributions per 90 |
|---:|---|---:|
| 1 | Omar Marmoush — Eintracht Frankfurt | 1.545 |
| 2 | Ousmane Dembélé — Paris Saint-Germain | 1.503 |
| 3 | Harry Kane — Bayern Munich | 1.355 |
| 4 | Ferran Torres — FC Barcelona | 1.308 |
| 5 | Alexander Sørloth — Atlético de Madrid | 1.268 |
| 6 | Mohamed Salah — Liverpool | 1.251 |
| 7 | Mateo Retegui — Atalanta | 1.235 |
| 8 | Patrik Schick — Bayer Leverkusen | 1.174 |
| 9 | Michael Olise — Bayern Munich | 1.150 |
| 10 | Amine Gouiri — Olympique de Marseille | 1.112 |

![Top player-club productivity](../images/theme_2/player_productivity.png)

**Key finding:** Marmoush produced the strongest qualified 2024–25 player-club rate, while Dembélé followed closely. The top ten was dominated by attacking players, which reinforces the need for position-specific comparison elsewhere in the analysis.

---

## Question 4 — Which players contributed the greatest share of their club’s total goals or goal contributions?

The `club_goal_involvement.csv` output calculates:

- player goals as a share of club goals
- player assists as a share of club goals
- combined goal involvement as a share of club goals

### Interpretation

This metric identifies players on whom a club’s attack was particularly dependent. A high involvement share can indicate:

- elite individual influence
- limited alternative attacking sources
- a highly centralised attacking structure

Combined involvement should not be interpreted as a mutually exclusive share of goals because the same club goal may include both a scorer and an assister.

---

## Question 5 — Which players ranked highest within their position?

The position-ranking output compares players within broad positions rather than treating defenders, midfielders and attackers identically.

For outfield players, the primary attacking ranking uses goal contributions per 90. Goalkeepers are not ranked by goals or assists; their output is treated separately using availability.

### Interpretation

Position-level comparison reduces the structural bias that would otherwise place almost every defender below attacking players. It is still important to recognise that goals and assists do not capture many defensive, progression or goalkeeper actions absent from this dataset.

---

## Question 6 — Which players showed the greatest year-on-year improvement?

### Largest improvements into 2024–25

| Rank | Player | Previous GC/90 | Current GC/90 | Change |
|---:|---|---:|---:|---:|
| 1 | Mateo Retegui | 0.364 | 1.235 | +0.871 |
| 2 | Ousmane Dembélé | 0.716 | 1.503 | +0.787 |
| 3 | Nick Woltemade | 0.152 | 0.778 | +0.626 |
| 4 | Ayoze Pérez | 0.390 | 0.956 | +0.566 |
| 5 | Ferran Torres | 0.748 | 1.308 | +0.560 |
| 6 | Yacine Adli | 0.191 | 0.745 | +0.554 |
| 7 | Assane Diao | 0.171 | 0.705 | +0.534 |
| 8 | Dwight McNeil | 0.280 | 0.788 | +0.508 |
| 9 | Isco | 0.500 | 0.986 | +0.486 |
| 10 | Ulisses Garcia | 0.000 | 0.484 | +0.484 |

![Year-on-year player improvement](../images/theme_2/player_improvement.png)

**Key finding:** Retegui recorded the largest increase, followed by Dembélé. Several players combined substantial improvement with top-ten 2024–25 productivity, showing that the change was not merely from a very low base to an average level.

### Limitation

Year-on-year change does not establish why performance improved. Possible explanations include:

- tactical role changes
- transfers
- increased minutes
- injuries in the comparison season
- changes in teammate quality
- normal finishing variation

---

## Question 7 — Which players maintained strong performance across several seasons?

The sustained-performance analysis includes players with at least three seasons of 900 or more minutes.

- **Y-axis:** average goal contributions per 90
- **X-axis:** standard deviation of season-level goal contributions per 90
- **Lower x-values:** greater consistency

![Sustained player performance](../images/theme_2/sustained_performance.png)

### Selected standouts

- **Kylian Mbappé** combined the highest labelled average output with relatively low variation.
- **Erling Haaland** also maintained exceptionally high average productivity, with somewhat greater seasonal variation.
- **Mohamed Salah** combined output above 1.0 per 90 with variation close to the median.
- **Harry Kane** and **Robert Lewandowski** remained among the strongest sustained producers, although both appeared farther to the right than Mbappé, indicating greater variation.

### Interpretation

The preferred region is the **upper-left quadrant**:

- high average productivity
- low season-to-season variation

The upper-right quadrant still contains elite players, but their output varied more across qualified seasons.

---

## Question 8 — Which under-23 players accumulated the most meaningful league minutes?

The `under_23_minutes.csv` output ranks players aged 22 or younger at season end by league minutes, both overall and within position.

### Interpretation

Minutes are treated as evidence of senior-level trust and exposure rather than proof of quality. The strongest development candidates are those combining:

- substantial minutes
- young age
- productive or position-relevant output
- repeated involvement across seasons

This output is best presented as a supporting recruitment table or a separate youth-focused visual rather than forcing it into the main four-chart dashboard.

---

## Question 9 — Which players produced strong results despite playing for lower-performing clubs?

The `lower_performing_club_players.csv` output defines lower-performing clubs as the bottom half of each league-season by points per match. Eligible players are then ranked by goal contributions per 90, total contributions and share of club goals.

### Interpretation

This analysis is useful for identifying potential transfer targets whose production may be understated by team context. Strong output at a lower-performing club can signal:

- individual attacking quality
- high responsibility within the team
- resilience despite fewer chances or weaker supporting players

It does not automatically mean the player will reproduce the same role or output at a stronger club.

---

## Question 10 — Which players combined high productivity with reliable availability?

The final scatterplot uses position- and league-adjusted percentile scores:

- **X-axis:** availability percentile
- **Y-axis:** productivity percentile
- **Reference lines:** 50th percentile

![Productivity and availability](../images/theme_2/productivity_and_availability.png)

### Quadrant interpretation

| Quadrant | Interpretation |
|---|---|
| Top right | Above-median productivity and availability |
| Top left | Above-median productivity, lower availability |
| Bottom right | Above-median availability, lower productivity |
| Bottom left | Below median on both measures |

**Key finding:** The chart contains a substantial group in the top-right quadrant, showing that high productivity and reliable availability are not mutually exclusive. The labelled leaders are selected using the combined league-season ranking, while the full distribution remains visible to avoid showing only preselected high performers.

---

# Methodology

## Per-90 calculations

For each player-club-season:

```text
Goals per 90 = goals × 90 ÷ minutes played
Assists per 90 = assists × 90 ÷ minutes played
Goal contributions per 90 = (goals + assists) × 90 ÷ minutes played
```

A minimum of 900 minutes is used to reduce small-sample distortion.

## Year-on-year comparison

Player records are aggregated across club spells within a season before comparing consecutive seasons. Both seasons must contain at least 900 minutes.

## Sustained performance

A season qualifies when the player records at least 900 minutes. Players require at least three qualified seasons. Consistency is measured using the sample standard deviation of season-level goal contributions per 90.

## Availability

Availability is estimated as:

```text
Player minutes ÷ (club league matches × 90)
```

The productivity-and-availability analysis requires at least 1,800 minutes. Percentile scores are calculated within position, league and season before being combined with equal weights.

---

# Main limitations

1. Goals and assists do not capture the full contribution of defenders, midfielders or goalkeepers.
2. Assist records depend on the data provider’s event definitions.
3. Per-90 rates can still be affected by role, substitution patterns and game state.
4. Availability percentage does not distinguish injury, suspension, tactical omission or registration status.
5. Club strength and opponent difficulty are not directly controlled in the attacking rankings.
6. Year-on-year improvement is descriptive and does not identify causal drivers.
7. Broad position categories can hide meaningful differences between sub-positions.
8. Historical analysis is limited to the five selected leagues and five completed seasons.

---

# Files used

## SQL

```text
sql/07_player_performance.sql
sql/07a_theme_2_export_queries.sql
```

## Data outputs

```text
outputs/theme_2/player_season_productivity.csv
outputs/theme_2/club_goal_involvement.csv
outputs/theme_2/position_rankings.csv
outputs/theme_2/year_on_year_improvement.csv
outputs/theme_2/sustained_player_performance.csv
outputs/theme_2/under_23_minutes.csv
outputs/theme_2/lower_performing_club_players.csv
outputs/theme_2/productivity_availability.csv
```

## Visuals

```text
images/theme_2/theme_2_dashboard.png
images/theme_2/player_productivity.png
images/theme_2/player_improvement.png
images/theme_2/sustained_performance.png
images/theme_2/productivity_and_availability.png
```

---

# Skills demonstrated

- PostgreSQL common table expressions
- Window functions and ranking
- Per-90 normalisation
- Minimum-minute eligibility rules
- Historical club-season joins
- Consecutive-season comparisons with `LAG`
- Multi-season aggregation and standard deviation
- Position-specific benchmarking
- Percentile scoring
- Tableau parameters, filters, dumbbell charts and scatterplots
- Translating SQL outputs into business-facing findings
