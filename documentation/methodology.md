# Methodology

## 1. Project Scope

This project analyses club performance, player productivity, market-value development, recruitment opportunities, and transfer outcomes across Europe’s five major domestic leagues:

- Premier League
- La Liga
- Bundesliga
- Serie A
- Ligue 1

The core analytical period covers the **2020–21 to 2024–25 seasons**. The main analysis focuses on domestic league activity and excludes domestic cups, league cups, super cups, UEFA club competitions, national-team matches, international tournaments and qualifiers, incomplete 2025–26 competitions, and ongoing 2026 World Cup data.

PostgreSQL is the primary analytical environment. The workflow uses relational database modelling, validation and cleaning, reusable views, joins, aggregations, common table expressions, window functions, percentile calculations and theme-specific analytical queries. Selected SQL outputs are exported as CSV files and visualised in Tableau.

---

## 2. Data Preparation and Quality Control

The source data covers competitions, clubs, matches, player appearances, player information, historical market valuations and transfer records.

Before analysis, the project applies structured data-quality checks covering:

- duplicate records;
- missing values;
- invalid or inconsistent dates;
- ID and relationship integrity;
- season mapping;
- appearance and minute totals;
- transfer-fee formats;
- club and player history; and
- consistency of fields used in joins and analytical views.

Cleaning and standardisation decisions are implemented in SQL rather than manually altering analytical outputs. Reusable views are created after cleaning so that league, season and historical club-membership logic can be applied consistently across themes.

Missing values are not automatically treated as zero. Their interpretation depends on the field and analytical context.

---

## 3. Competition, Season and Historical Membership Rules

The main analytical population consists of clubs and players participating in the five selected leagues during the 2020–21 to 2024–25 period.

Historical analysis uses the relevant **club-season membership** rather than a player’s current club whenever possible.

Promoted and relegated clubs remain eligible for season-level analysis. However, Theme 1 five-season comparisons use only clubs appearing in **all five seasons**, producing a consistent comparison group of **63 clubs**.

---

## 4. Player Age and Position Definitions

Players are grouped into four broad positions:

- Goalkeeper
- Defender
- Midfield
- Attack

Broad position groups are used because the source data does not consistently support role-specific evaluation at a finer level.

For Theme 2 and Theme 3, **under-23** means a player is **22 or younger at season end**. Theme 4 also uses a broader young-recruitment condition of **age 23 or younger** for selected shortlist rules.

Goalkeepers are excluded from attacking-productivity rankings because goals and assists are not meaningful primary performance measures for that position. In recruitment analysis, goalkeeper availability is used as the main performance proxy because goalkeeper-specific metrics such as saves, save percentage and goals prevented are unavailable.

---

# Theme-Specific Methodology

## 5. Theme 1 — Club and League Performance

### Match and club-season population

Theme 1 covers **8,982 domestic league matches** and **486 club-season records**.

Seasonal club rankings use **win percentage** as the primary result measure, with **points per match (PPM)** and goal difference used as supporting indicators.

Five-season aggregate comparisons are restricted to clubs that appeared in all five seasons.

### Home and away performance

Home and away win percentages are calculated separately from domestic league matches and compared over the selected period.

### Year-on-year change

Club improvement and decline are primarily measured through changes in **points per match** between consecutive seasons, with changes in win percentage included as supporting context.

### Attacking and defensive performance

Club attacking and defensive strength are compared using:

- goals scored per match; and
- goals conceded per match.

### League scoring comparison

League attacking environments are compared using total domestic-league goals divided by total matches.

### Multi-season consistency

Consistency is evaluated using the variation in season-level points per match. Standard deviation is interpreted together with average performance because a consistently low-performing club should not be described as a strong performer merely because its results are stable.

### Market-value efficiency

Theme 1 measures value-adjusted club performance as the difference between **actual PPM** and **expected PPM** within each league-season.

Expected performance is estimated from the **natural logarithm of participating-player market value**.

```text
Performance residual = Actual PPM − Expected PPM
```

Positive residuals indicate that a club achieved more points per match than expected from its estimated player-value level.

Club-seasons require:

- at least **80% valuation coverage**; and
- player valuations no more than **180 days old**.

This measure represents relative sporting outperformance, not financial profitability or causal efficiency.

---

## 6. Theme 2 — Player Performance and Consistency

### Participation thresholds

Theme 2 uses:

- **900 league minutes** as the standard minimum for per-90 player rankings;
- **1,800 league minutes** for the productivity-and-availability analysis; and
- at least **three qualified seasons** for sustained-performance analysis.

These thresholds reduce small-sample distortion.

### Per-90 calculations

For each player-club-season:

```text
Goals per 90 = Goals × 90 ÷ Minutes played
Assists per 90 = Assists × 90 ÷ Minutes played
Goal contributions per 90 = (Goals + Assists) × 90 ÷ Minutes played
```

Goals, assists and goal contributions are interpreted as attacking-output measures rather than complete measures of player quality.

### Year-on-year improvement

Player records are aggregated across club spells within a season before consecutive seasons are compared.

Both the previous and current seasons must contain at least **900 minutes**.

Year-on-year improvement is descriptive and does not identify why output changed.

### Sustained performance and consistency

A season qualifies when the player records at least **900 minutes**.

Players require at least **three qualified seasons**.

Consistency is measured using the **sample standard deviation of season-level goal contributions per 90**.

Higher average productivity with lower standard deviation represents the preferred high-output, lower-variation profile.

### Availability

Availability is estimated as:

```text
Availability = Player league minutes ÷ (Club league matches × 90)
```

The productivity-and-availability analysis requires at least **1,800 minutes**.

Productivity and availability percentile scores are calculated **within position, league and season** before being combined with equal weighting for the dashboard comparison.

### Lower-performing club context

Lower-performing clubs are defined as the **bottom half of each league-season by points per match**. Eligible players at these clubs are evaluated using productivity, total goal contributions and contribution share.

---

## 7. Theme 3 — Market Value and Player Development

### Valuation window

Theme 3 uses historical valuations between **1 July 2020 and 30 June 2025**.

Market values are estimates rather than realised transfer prices and are interpreted as changes in perceived market value.

### Full-window player growth

For overall player growth, the earliest and latest eligible valuations in the project window are compared.

```text
Absolute growth = Ending value − Starting value

Percentage growth =
(Ending value − Starting value) ÷ Starting value × 100
```

Percentage-growth rankings require a **starting market value of at least €1 million** to reduce extreme low-base distortion.

### Player-season valuation mapping

Valuations are mapped to football seasons as follows:

- July–December → season beginning in that calendar year;
- January–June → previous season-start year.

The first and last recorded valuation within a season are used for player-season growth analysis.

### Club development attribution

Club-level development analysis includes only **single-club player-seasons**. Multi-club player-seasons are excluded where attribution of value development to one club would be ambiguous.

Club summaries distinguish:

- net value growth;
- gross positive growth;
- gross decline; and
- number of high-growth players.

A high-growth player-season requires:

- starting value of at least **€1 million**;
- absolute increase of at least **€10 million**; and
- percentage increase of at least **50%**.

### Positional value comparison

Median market values are used for position-level comparisons because elite-value outliers can materially distort averages.

### Peak-value age

For each player, the highest recorded valuation in the project window is identified.

Where the same peak value appears more than once, the **earliest peak date** is used.

Players require:

- at least **three valuation observations**; and
- a peak value of at least **€1 million**.

Peak-value age therefore represents the peak observed **within the project window**, not necessarily the player’s lifetime peak.

### Performance and value comparison

Consecutive seasons are compared using:

- change in ending market value;
- change in league minutes; and
- change in goal contributions per 90.

Both performance seasons require at least **900 league minutes**.

These comparisons are observational and do not establish that changes in performance caused changes in market value.

---

## 8. Theme 4 — Recruitment and Potentially Undervalued Talent

### Analytical season and player pool

The primary recruitment season is **2024–25**, with 2020–21 to 2024–25 used for historical development and consistency.

The base performance threshold is **900 league minutes**, while **1,800 minutes** is treated as meaningful playing time for selected classifications.

### Position-adjusted performance

Outfield players are ranked using goal contributions per 90 **within league, season and position**.

Goalkeepers use availability as the primary proxy because goalkeeper-specific performance statistics are unavailable.

### Value benchmarking

Market-value comparisons are made within:

- season;
- position; and
- age group.

Both value percentile and the position-age median are used.

This reduces structural bias arising from different market-value distributions across ages and positions.

### Elite-club definition

An elite club is defined as a club in the **top 20% of estimated squad value within its league-season**.

This benchmark is used to identify players at lower-valued clubs whose position-adjusted output is comparable to players at elite-value clubs.

### Recruitment score

The master recruitment score is intentionally transparent:

```text
50%  Current position-adjusted performance
20%  Availability
15%  Affordability
15%  Recent development
```

The weighting is heuristic rather than empirically optimised.

### Default position-specific value limits

| Position | Maximum estimated value |
|---|---:|
| Goalkeeper | €30m |
| Defender | €40m |
| Midfield | €50m |
| Attack | €60m |

### Recruitment classifications

| Classification | Rule |
|---|---|
| **High-upside candidate** | Age ≤23, performance ≥70th percentile, positive YoY development, value percentile ≤60 |
| **Potential value opportunity** | Performance ≥75th percentile and value percentile ≤40 |
| **Consistent performer** | ≥3 qualified seasons, historical average performance ≥65th percentile, performance SD ≤15 |
| **Emerging talent** | Age ≤21 and performance ≥60th percentile |
| **Established value** | Performance ≥80th percentile and ≥1,800 minutes |
| **Recruitment watchlist** | Meets base shortlist criteria but none of the stronger classifications |

The final shortlist is a **screening tool**, not a definitive scouting recommendation. Tactical fit, injury history, wages, contract status, personality and other scouting information are outside the dataset.

---

## 9. Theme 5 — Transfers and Post-Transfer Outcomes

### Transfer-fee treatment

Transfer records are separated into three main fee categories:

- **positive known fee**;
- **recorded zero fee**; and
- **missing or undisclosed fee**.

Missing or undisclosed fees are **never treated as zero**.

Financial outputs therefore represent:

- known transfer expenditure;
- known transfer income; and
- known-fee net balances.

They should not be interpreted as complete audited transfer-market accounts.

### League mapping

Historical club-season league mappings are used where available, with current-club competition information used as a fallback.

Because mapping coverage is incomplete—particularly for origin-club league assignments—league-flow and transfer-route findings are explicitly described as **mapped transfers** rather than the complete transfer universe.

Same-league transfers are excluded from the external league-flow analysis.

### Transfer-fee profiles

Age- and position-level transfer-fee comparisons use **positive known-fee transactions only**.

Median fees are emphasised because transaction-fee distributions contain high-value outliers that can pull averages upward.

### Summer-transfer cohort

Post-transfer analysis is restricted to transfers occurring from **July through September**.

This creates cleaner before/after season comparisons and avoids many winter transfers where a player can accumulate domestic-league minutes for both clubs in the same season.

### Post-transfer valuation analysis

Post-transfer market-value analysis requires matched pre-transfer and post-transfer season-end valuations for the clean summer-transfer cohort.

Absolute and percentage changes are kept separate because percentage increases are highly sensitive to low starting valuations.

### Sporting outcome threshold

Sporting-outcome comparisons require at least **450 league minutes in both the pre-transfer and post-transfer seasons**.

For non-goalkeepers, the comparison uses:

- change in league minutes; and
- change in goal contributions per 90.

Goalkeepers are interpreted primarily through changes in playing time.

Outcome labels describe changes **following** a transfer; they do not imply that the transfer caused those changes.

### Young acquisition development

Young-player club development analysis is restricted to:

- summer acquisitions;
- players aged **23 or younger**; and
- cases with matched pre- and post-transfer valuations.

Clubs require at least **two eligible young acquisitions** for the young-acquisition development comparison.

### Development efficiency relative to spending

The spending-efficiency analysis uses:

- summer acquisitions;
- **positive known transfer fees**;
- matched pre/post valuations; and
- at least **three eligible acquisitions per club**.

The principal efficiency measure is:

```text
Development efficiency =
Net post-transfer market-value growth ÷ Known acquisition spending
```

For example, a value of `1.00` means €1 of net estimated market-value growth for every €1 of known spending in the eligible sample.

Because fee coverage is incomplete and market values are estimates, this is an analytical indicator rather than an accounting return on investment.

### Source-transfer anomalies

Some source transfer records appear reciprocal, duplicated-looking or structurally unusual. Records are retained unless clearly invalid rather than manually overwritten. Individual player-level cases should therefore be checked before making strong claims.

---

## 10. Interpretation of Market Value and Financial Measures

Throughout the project, market value and transfer fee are treated as distinct concepts.

**Market value** represents an estimated valuation and may be influenced by age, performance, contract duration, reputation, nationality, club context and wider market conditions.

**Transfer fee** represents a recorded transaction amount where a usable fee is available.

Accordingly:

- market-value growth does not equal realised profit;
- estimated market value does not equal acquisition cost;
- missing transfer fees are not treated as free transfers; and
- financial efficiency measures are not presented as audited financial returns.

---

## 11. Main Analytical Limitations

The project has several limitations that affect interpretation:

1. Market values are estimates rather than realised transaction prices.
2. Transfer-fee coverage is incomplete and some fees are undisclosed.
3. Goals and assists do not capture the full contribution of defenders, midfielders or goalkeepers.
4. Goalkeeper-specific performance statistics are unavailable.
5. Broad position groups hide differences between specialised roles.
6. Per-90 measures can be affected by role, substitution patterns and game state.
7. Availability cannot distinguish injury, suspension, tactical omission or registration status.
8. League strength is not explicitly adjusted with a cross-league strength coefficient.
9. Promoted and relegated clubs do not have equal observation periods in all analyses.
10. Valuation timing does not always align exactly with season boundaries or transfer dates.
11. Club-level development does not establish that the club caused a player’s value change.
12. Post-transfer changes do not establish transfer causation.
13. Injury history, wages, contract terms and tactical fit are unavailable.
14. Currency values are analysed in nominal euros without inflation adjustment.
15. Some source transfer records contain unusual or duplicated-looking structures.

These limitations are considered when wording conclusions and recruitment recommendations.

---

## 12. Reproducibility and Analytical Workflow

The public repository separates the project into the following stages:

1. database setup;
2. source-table creation;
3. CSV import;
4. data-quality checks;
5. cleaning and standardisation;
6. reusable analytical views and indexes;
7. five theme-specific SQL analyses;
8. theme-specific export queries;
9. dashboard-ready CSV outputs;
10. Tableau visualisations; and
11. written findings and methodology documentation.

The raw source dataset is documented separately and does not need to be redistributed through the repository. The SQL scripts, methodology, selected outputs and Tableau visuals provide the reproducible analytical trail from source data to final findings.
