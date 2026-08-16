# Theme 4 — Recruitment and Potentially Undervalued Talent

## Business objective

Build an evidence-based recruitment shortlist by combining age, position-adjusted sporting performance, playing time, recent development, consistency and estimated market value.

This theme differs from the earlier descriptive themes because its primary purpose is **decision support**: identifying recruitment opportunities rather than simply describing who performed best.

---

## Analytical scope

- **Primary recruitment season:** 2024–25
- **Historical context:** 2020–21 to 2024–25
- **Competitions:** Premier League, La Liga, Bundesliga, Serie A and Ligue 1
- **Base performance threshold:** at least 900 league minutes
- **Meaningful playing-time threshold:** 1,800 league minutes
- **Under-23 definition:** age 22 or younger at season end
- **Young recruitment pool:** generally age 23 or younger
- **Position-adjusted performance:** percentile ranking within league, season and position
- **Value benchmark:** market-value percentile and median within position and age group
- **Elite club definition:** top 20% of estimated squad value within each league-season
- **Goalkeeper caveat:** goalkeeper-specific performance statistics were not available, so availability is used as the main goalkeeper performance proxy

> Market values are estimates, not transfer fees. The outputs identify statistically interesting recruitment profiles rather than definitive transfer recommendations.

---

## Recruitment methodology

### Position-adjusted performance

Outfield players are compared using goal contributions per 90 **within their position and league-season**, rather than comparing attackers directly with defenders.

Goalkeepers are ranked using availability because the dataset does not include saves, save percentage, post-shot expected goals, clean sheets or other goalkeeper-specific indicators.

### Value benchmark

Players are compared with others in the same:

- season
- position
- age group

This reduces the risk of labelling a young player “expensive” simply because attackers or prime-age players generally command higher values.

### Recruitment score

The master shortlist score uses:

- **50% current position-adjusted performance**
- **20% availability**
- **15% affordability**
- **15% recent development**

The score is designed to remain transparent rather than behave like a black-box scouting model.

### Default position-specific value limits

| Position | Default maximum estimated value |
|---|---:|
| Goalkeeper | €30m |
| Defender | €40m |
| Midfield | €50m |
| Attack | €60m |

### Opportunity classifications

| Classification | Rule |
|---|---|
| **High-upside candidate** | Age ≤23, performance ≥70th percentile, positive YoY development, value percentile ≤60 |
| **Potential value opportunity** | Performance ≥75th percentile and value percentile ≤40 |
| **Consistent performer** | ≥3 qualified seasons, historical average performance ≥65th percentile, performance SD ≤15 |
| **Emerging talent** | Age ≤21 and performance ≥60th percentile |
| **Established value** | Performance ≥80th percentile and ≥1,800 minutes |
| **Recruitment watchlist** | Meets the base shortlist criteria but none of the stronger classifications |

The final 2024–25 shortlist contains **211 candidates**:
- **Recruitment watchlist:** 75
- **Potential value opportunity:** 55
- **Established value:** 25
- **Consistent performer:** 24
- **High-upside candidate:** 20
- **Emerging talent:** 12


---

# Findings by business question

## Question 1 — Which under-23 players produced above-average position-adjusted performance?

The exported `undervalued_young_players.csv` applies a stricter requirement than “above average”: every player in this file is **under 23, at least 70th percentile in position-adjusted performance, and below the market-value median for their position-age group**.

Therefore, these players are not the complete population of all above-average U23 performers; they are the strongest exported subset that also satisfies the value-opportunity condition.

### Leading exported U23 value opportunities

| Rank | Player | Age | Position | Club | League | Performance percentile | Est. value | Position-age median | Discount |
|---:|---|---:|---|---|---|---:|---:|---:|---:|
| 1 | Juanlu Sánchez | 21 | Defender | Sevilla FC | laliga | 100.0 | €12.0m | €12.5m | 4.0% |
| 2 | Tom Rothe | 20 | Defender | 1.FC Union Berlin | bundesliga | 96.4 | €10.0m | €12.5m | 20.0% |
| 3 | Lucas Stassin | 20 | Attack | AS Saint-Étienne | ligue-1 | 90.3 | €18.0m | €29.0m | 37.9% |
| 4 | Frans Krätzig | 22 | Defender | 1. Fußballclub Heidenheim 1846 | bundesliga | 80.9 | €3.5m | €12.5m | 72.0% |
| 5 | Adam Obert | 22 | Defender | Cagliari Calcio | serie-a | 80.5 | €3.0m | €12.5m | 76.0% |
| 6 | Giovanni Fabbian | 22 | Midfield | Bologna Football Club 1909 | serie-a | 80.0 | €12.0m | €17.0m | 29.4% |
| 7 | Félix Lemaréchal | 21 | Midfield | RC Strasbourg Alsace | ligue-1 | 79.0 | €10.0m | €17.0m | 41.2% |
| 8 | Farès Chaïbi | 22 | Midfield | Eintracht Frankfurt | bundesliga | 79.0 | €9.0m | €17.0m | 47.1% |
| 9 | Arnau Martínez | 22 | Defender | Girona FC | laliga | 77.2 | €10.0m | €12.5m | 20.0% |
| 10 | Nicolò Savona | 22 | Defender | Juventus FC | serie-a | 75.9 | €12.0m | €12.5m | 4.0% |


**Key finding:** the exported U23 opportunity set contains **14 players**. Juanlu Sánchez ranked first overall, combining a **100th-percentile** position-adjusted performance score with an estimated value of **€12.0m**, slightly below the €12.5m benchmark for his position-age group. Lucas Stassin stood out among attackers, with a **90.3rd-percentile** performance score and an estimated value of **€18.0m** versus a €29.0m benchmark.

---

## Question 2 — Which high-performing players remained below the market-value median for their position and age group?

The same U23 opportunity export directly answers the young-player version of this question.

The strongest discounts among the leading candidates include:

- **Nhoa Sangui:** approximately 80% below the relevant benchmark
- **Adam Obert:** approximately 76% below benchmark
- **Frans Krätzig:** approximately 72% below benchmark
- **Luca Netz:** approximately 52% below benchmark
- **Farès Chaïbi:** approximately 47% below benchmark

**Key finding:** a low value relative to peers does not automatically make a player attractive. The strongest recruitment cases are those that combine the discount with a high performance percentile and meaningful playing time.

---

## Question 3 — Which players produced the highest sporting output per €1 million of estimated market value?

### Top ten efficiency scores

| Rank | Player | Age | Position | Club | Performance percentile | Est. value | Performance percentile per €1m |
|---:|---|---:|---|---|---:|---:|---:|
| 1 | Cristhian Stuani | 38 | Attack | Girona FC | 97.9 | €1.0m | 97.94 |
| 2 | Pedro | 37 | Attack | Società Sportiva Lazio S.p.A. | 97.3 | €1.0m | 97.30 |
| 3 | Álex Muñoz | 30 | Defender | UD Las Palmas | 87.8 | €1.0m | 87.80 |
| 4 | Antoine Hainaut | 23 | Defender | Parma Calcio 1913 | 72.9 | €1.0m | 72.93 |
| 5 | Nicolas Viola | 35 | Midfield | Cagliari Calcio | 68.2 | €1.0m | 68.18 |
| 6 | Charalampos Lykogiannis | 31 | Defender | Bologna Football Club 1909 | 95.5 | €1.5m | 63.66 |
| 7 | Óscar de Marcos | 36 | Defender | Athletic Bilbao | 94.3 | €1.5m | 62.87 |
| 8 | Lukas Kübler | 32 | Defender | SC Freiburg | 90.9 | €1.5m | 60.61 |
| 9 | Donovan Léon | 32 | Goalkeeper | AJ Auxerre | 57.1 | €1.0m | 57.14 |
| 10 | Hernani | 31 | Midfield | Parma Calcio 1913 | 89.1 | €1.6m | 55.68 |


**Key finding:** this raw efficiency metric strongly favours very low-valued players. Cristhian Stuani and Pedro ranked first and second because both carried €1m valuations while retaining very high current performance percentiles.

This is useful for identifying inexpensive output, but it should **not** be treated as the final shortlist by itself. Age, resale value, availability and future development remain important recruitment considerations.

---

## Question 4 — Which players outside elite clubs produced results comparable to players at higher-valued clubs?

The non-elite opportunity analysis compares players outside the top 20% of squad values with the median position-adjusted performance of players at elite clubs in the same league.

### Leading examples by position

| Position | Player | Club | Performance percentile | Elite-club median | Above elite median | Est. value |
|---|---|---|---:|---:|---:|---:|
| Attack | Alexander Isak | Newcastle United | 98.7 | 61.8 | +36.8 | €120.0m |
| Attack | Riccardo Orsolini | Bologna Football Club 1909 | 98.7 | 79.7 | +18.9 | €25.0m |
| Defender | Mats Wieffer | Brighton & Hove Albion | 100.0 | 61.3 | +38.7 | €25.0m |
| Defender | Juanlu Sánchez | Sevilla FC | 100.0 | 66.7 | +33.3 | €12.0m |
| Midfield | James Maddison | Tottenham Hotspur | 100.0 | 73.4 | +26.6 | €42.0m |
| Midfield | Yacine Adli | ACF Fiorentina | 100.0 | 75.5 | +24.6 | €11.0m |
| Goalkeeper | David Soria | Getafe CF | 95.8 | 45.8 | +50.0 | €3.0m |
| Goalkeeper | Joan García | RCD Espanyol Barcelona | 95.8 | 45.8 | +50.0 | €25.0m |


**Key finding:** several players at non-elite-value clubs produced performance well above elite-club positional medians. Examples include Juanlu Sánchez, Mats Wieffer, Yacine Adli, Rayan Cherki and Joan García. These cases are especially interesting because they combine strong output with a club context that may receive less attention than the highest-valued squads.

---

## Question 5 — Which players combined strong current performance with positive year-on-year development?

### Highest exported YoY improvements

| Rank | Player | Age | Position | Club | Previous percentile | Current percentile | Change |
|---:|---|---:|---|---|---:|---:|---:|
| 1 | Ulisses Garcia | 29 | Defender | Olympique Marseille | 0.0 | 98.2 | +98.2 |
| 2 | Ramy Bensebaini | 30 | Defender | Borussia Dortmund | 0.0 | 92.7 | +92.7 |
| 3 | Iñigo Martínez | 34 | Defender | FC Barcelona | 0.0 | 86.2 | +86.2 |
| 4 | Arouna Sangante | 23 | Defender | Le Havre AC | 0.0 | 86.1 | +86.1 |
| 5 | Ashley Young | 39 | Defender | Everton FC | 0.0 | 85.7 | +85.7 |
| 6 | Nikola Milenković | 27 | Defender | Nottingham Forest | 0.0 | 84.0 | +84.0 |
| 7 | Mile Svilar | 25 | Goalkeeper | Associazione Sportiva Roma | 12.5 | 95.8 | +83.3 |
| 8 | Adam Masina | 31 | Defender | Torino FC | 0.0 | 82.7 | +82.7 |
| 9 | Adam Obert | 22 | Defender | Cagliari Calcio | 0.0 | 80.5 | +80.5 |
| 10 | Dani Vivian | 25 | Defender | Athletic Bilbao | 0.0 | 78.9 | +78.9 |
| 11 | Dwight McNeil | 25 | Attack | Everton FC | 15.5 | 92.1 | +76.6 |
| 12 | Willi Orbán | 32 | Defender | RB Leipzig | 0.0 | 76.4 | +76.4 |


**Key finding:** some of the largest improvements arise from a previous-season percentile of zero, especially among defenders. This can legitimately reflect movement from no attacking contribution to meaningful contribution, but it can also make the change statistic look dramatic. For recruitment use, the development ranking should therefore be read alongside current performance, minutes and positional context.

Among younger players, **Milos Kerkez**, **Assane Diao** and **Adam Obert** stand out as strong development cases.

---

## Question 6 — Which players demonstrated both strong output and meaningful playing time?

Within the master shortlist, **75 players** recorded at least **1,800 minutes** and ranked at or above the **75th performance percentile**.

Examples include:

| Player | Position | Age | Club | Minutes | Performance percentile | Est. value |
|---|---|---:|---|---:|---:|---:|
| Mateo Retegui | Attack | 26 | Atalanta BC | 2,404 | 100.0 | €45.0m |
| Rayan Cherki | Midfield | 21 | Olympique Lyon | 2,048 | 100.0 | €45.0m |
| Nathaniel Brown | Defender | 22 | Eintracht Frankfurt | 1,952 | 100.0 | €22.0m |
| Justin Kluivert | Midfield | 26 | AFC Bournemouth | 2,356 | 99.0 | €35.0m |
| Rayan Aït-Nouri | Defender | 24 | Wolverhampton Wanderers | 3,128 | 97.5 | €35.0m |
| Antonee Robinson | Defender | 27 | Fulham FC | 3,167 | 96.6 | €35.0m |
| Mile Svilar | Goalkeeper | 25 | AS Roma | 3,420 | 95.8 | €25.0m |
| Joan García | Goalkeeper | 24 | Espanyol | 3,420 | 95.8 | €25.0m |

**Key finding:** this group is useful for distinguishing proven current-season contributors from players whose high per-90 output came in smaller samples.

---

## Question 7 — Which leagues contained the largest number of affordable, productive young players?

| Rank | League | Candidates | Avg. age | Avg. performance percentile | Median value | Total value |
|---:|---|---:|---:|---:|---:|---:|
| 1 | serie-a | 8 | 22.4 | 75.2 | €12.0m | €71.0m |
| 2 | laliga | 6 | 21.7 | 82.6 | €11.0m | €73.0m |
| 3 | bundesliga | 6 | 22.0 | 81.6 | €4.8m | €31.5m |
| 4 | ligue-1 | 6 | 20.8 | 75.8 | €10.0m | €63.5m |


**Key finding:** Serie A led with **8** affordable productive young players. La Liga, Bundesliga and Ligue 1 each produced **6**.

The Bundesliga had the lowest median estimated value at approximately **€4.75m**, suggesting the deepest low-cost pool among the qualifying leagues.

The Premier League does not appear in this export because **no player met all four criteria simultaneously**: age ≤23, performance ≥65th percentile, and value at or below the position-age median within the exported methodology.

---

## Question 8 — Which players should be shortlisted for each position under selected market-value limits?

The master recruitment dataset applies the default value limits and produces a position-specific recruitment score.

### Goalkeepers — top five

| Rank | Player | Age | Club | Minutes | Performance pct. | Est. value | Score | Classification |
|---:|---|---:|---|---:|---:|---:|---:|---|
| 1 | Mile Svilar | 25 | Associazione Sportiva Roma | 3,420 | 95.8 | €25.0m | 89.3 | Established value |
| 2 | Joan García | 24 | RCD Espanyol Barcelona | 3,420 | 95.8 | €25.0m | 81.8 | Established value |
| 3 | Marcin Bulka | 25 | OGC Nice | 3,060 | 85.7 | €20.0m | 78.4 | Potential value opportunity |
| 4 | Zion Suzuki | 22 | Parma Calcio 1913 | 3,315 | 87.5 | €20.0m | 74.4 | Established value |
| 5 | Bart Verbruggen | 22 | Brighton & Hove Albion | 3,240 | 76.0 | €30.0m | 71.0 | Recruitment watchlist |

### Defenders — top five

| Rank | Player | Age | Club | Minutes | Performance pct. | Est. value | Score | Classification |
|---:|---|---:|---|---:|---:|---:|---:|---|
| 1 | Sergi Cardona | 25 | Villarreal CF | 2,955 | 95.1 | €10.0m | 89.1 | Potential value opportunity |
| 2 | Liberato Cacace | 24 | FC Empoli | 2,231 | 91.0 | €3.0m | 86.4 | Potential value opportunity |
| 3 | Rayan Aït-Nouri | 24 | Wolverhampton Wanderers | 3,128 | 97.5 | €35.0m | 85.3 | Established value |
| 4 | Nadir Zortea | 26 | Cagliari Calcio | 2,727 | 94.0 | €5.0m | 82.6 | Potential value opportunity |
| 5 | Antonee Robinson | 27 | Fulham FC | 3,167 | 96.6 | €35.0m | 82.5 | Established value |

### Midfielders — top five

| Rank | Player | Age | Club | Minutes | Performance pct. | Est. value | Score | Classification |
|---:|---|---:|---|---:|---:|---:|---:|---|
| 1 | Ludovic Blas | 27 | Stade Rennais FC | 2,302 | 97.5 | €18.0m | 82.9 | Potential value opportunity |
| 2 | Aimar Oroz | 23 | CA Osasuna | 2,983 | 75.0 | €15.0m | 81.5 | High-upside candidate |
| 3 | Luis Henrique | 23 | Olympique Marseille | 2,622 | 93.8 | €25.0m | 80.9 | Established value |
| 4 | Justin Kluivert | 26 | AFC Bournemouth | 2,356 | 99.0 | €35.0m | 80.1 | Consistent performer |
| 5 | Yacine Adli | 24 | ACF Fiorentina | 1,208 | 100.0 | €11.0m | 80.0 | Potential value opportunity |

### Forwards — top five

| Rank | Player | Age | Club | Minutes | Performance pct. | Est. value | Score | Classification |
|---:|---|---:|---|---:|---:|---:|---:|---|
| 1 | Mateo Retegui | 26 | Atalanta BC | 2,404 | 100.0 | €45.0m | 87.5 | Established value |
| 2 | Mason Greenwood | 23 | Olympique Marseille | 2,818 | 91.7 | €40.0m | 85.2 | High-upside candidate |
| 3 | Amine Gouiri | 25 | Olympique Marseille | 2,089 | 88.9 | €30.0m | 81.0 | Established value |
| 4 | Jonathan Burkardt | 24 | 1.FSV Mainz 05 | 2,125 | 91.3 | €35.0m | 80.2 | Established value |
| 5 | Evann Guessand | 23 | OGC Nice | 2,575 | 83.3 | €25.0m | 80.1 | High-upside candidate |


**Key finding:** the highest-ranked shortlist candidates were:

- **Goalkeeper:** Mile Svilar
- **Defender:** Sergi Cardona
- **Midfielder:** Ludovic Blas
- **Forward:** Mateo Retegui

The rankings are budget-sensitive. Changing the market-value limits in a future Tableau dashboard would change the eligible shortlist and is therefore a useful interactive recruitment feature.

---

## Question 9 — Which shortlist candidates appear lower-risk because they performed consistently across multiple seasons?

### Top ten lower-risk profiles

| Rank | Player | Position | Qualified seasons | Current pct. | Historical avg. pct. | Performance SD | Est. value |
|---:|---|---|---:|---:|---:|---:|---:|
| 1 | Kylian Mbappé | Attack | 5 | 96.9 | 99.4 | 1.38 | N/A |
| 2 | Denzel Dumfries | Defender | 4 | 98.5 | 99.0 | 1.18 | €35.0m |
| 3 | Jonathan Clauss | Defender | 5 | 99.1 | 98.6 | 1.74 | €5.0m |
| 4 | Achraf Hakimi | Defender | 5 | 100.0 | 98.6 | 1.29 | €80.0m |
| 5 | Federico Dimarco | Defender | 5 | 100.0 | 98.5 | 1.54 | €50.0m |
| 6 | Erling Haaland | Attack | 5 | 93.4 | 98.1 | 2.73 | €180.0m |
| 7 | Jamal Musiala | Midfield | 4 | 98.7 | 97.8 | 2.86 | €140.0m |
| 8 | Trent Alexander-Arnold | Defender | 5 | 99.2 | 97.7 | 1.98 | €75.0m |
| 9 | Mohamed Salah | Attack | 5 | 100.0 | 97.2 | 2.65 | €50.0m |
| 10 | Robert Lewandowski | Attack | 5 | 95.9 | 97.0 | 2.12 | N/A |


**Key finding:** the lower-risk export contains **93 players**. Denzel Dumfries, Jonathan Clauss, Achraf Hakimi and Federico Dimarco combined extremely high historical performance with very low year-to-year variation.

Some elite players such as Kylian Mbappé appear despite missing a usable current market value in the export. They are valuable consistency benchmarks, but would not be suitable for a budget-constrained shortlist until a reliable valuation is available.

---

## Question 10 — Which players represent high-upside candidates based on age, recent improvement and current valuation?

### High-upside ranking

| Rank | Player | Age | Position | Club | Current pct. | YoY improvement | Est. value | Value percentile | Upside score |
|---:|---|---:|---|---|---:|---:|---:|---:|---:|
| 1 | Hákon Arnar Haraldsson | 22 | Midfield | LOSC Lille | 84.0 | +43.5 | €18.0m | 32.0 | 82.8 |
| 2 | Nicola Zalewski | 23 | Midfield | Associazione Sportiva Roma | 67.3 | +44.3 | €12.0m | 17.5 | 79.2 |
| 3 | Quentin Merlin | 23 | Defender | Olympique Marseille | 87.0 | +31.3 | €15.0m | 40.2 | 78.5 |
| 4 | Aimar Oroz | 23 | Midfield | CA Osasuna | 75.0 | +37.1 | €15.0m | 25.8 | 78.4 |
| 5 | Mason Greenwood | 23 | Attack | Olympique Marseille | 91.7 | +36.6 | €40.0m | 57.3 | 77.9 |
| 6 | Rayan Cherki | 21 | Midfield | Olympique Lyon | 100.0 | +15.7 | €45.0m | 49.5 | 77.3 |
| 7 | Lamine Camara | 21 | Midfield | AS Monaco | 82.7 | +24.3 | €22.0m | 35.0 | 75.8 |
| 8 | Evann Guessand | 23 | Attack | OGC Nice | 83.3 | +27.4 | €25.0m | 40.0 | 75.7 |
| 9 | Nick Woltemade | 23 | Attack | VfB Stuttgart | 73.9 | +70.9 | €30.0m | 50.7 | 75.6 |
| 10 | Habib Diarra | 21 | Midfield | RC Strasbourg Alsace | 77.8 | +27.2 | €20.0m | 34.0 | 74.7 |
| 11 | Emmanuel Emegha | 22 | Attack | RC Strasbourg Alsace | 75.0 | +32.4 | €25.0m | 40.0 | 73.5 |
| 12 | Arnaud Kalimuendo | 23 | Attack | Stade Rennais FC | 81.9 | +12.8 | €22.0m | 38.7 | 71.0 |
| 13 | Enzo Millot | 22 | Midfield | VfB Stuttgart | 90.8 | +4.1 | €35.0m | 45.4 | 70.8 |
| 14 | Arnau Martínez | 22 | Defender | Girona FC | 77.2 | +1.1 | €10.0m | 28.3 | 68.0 |
| 15 | Anthony Elanga | 23 | Attack | Nottingham Forest | 67.1 | +18.3 | €42.0m | 60.0 | 60.7 |


**Key finding:** **Hákon Arnar Haraldsson** ranked first in the high-upside model, followed by Nicola Zalewski, Quentin Merlin and Aimar Oroz. The model rewards players who are young, improving, already productive and not yet at the top of their position-age value distribution.

Ligue 1 contributes a particularly large share of the high-upside list, including Haraldsson, Quentin Merlin, Mason Greenwood, Rayan Cherki, Lamine Camara, Evann Guessand, Habib Diarra, Emmanuel Emegha and Arnaud Kalimuendo.

---

# Recruitment shortlist summary

The master dataset contains **211 position-specific candidates** under the default value limits:

| Classification | Candidates |
|---|---:|
| Recruitment watchlist | 75 |
| Potential value opportunity | 55 |
| Established value | 25 |
| Consistent performer | 24 |
| High-upside candidate | 20 |
| Emerging talent | 12 |


This distribution is useful for separating different recruitment strategies:

- **Established value** for teams prioritising immediate performance
- **Consistent performer** for lower-risk recruitment
- **Emerging talent** for younger developmental signings
- **High-upside candidate** for growth-oriented recruitment
- **Potential value opportunity** for strong output relative to current estimated value
- **Recruitment watchlist** for players who pass the base screen but need deeper scouting

---

# Main limitations

1. **Goalkeeper analysis is limited.** Availability is not a sufficient substitute for save percentage, goals prevented, cross claiming or distribution.
2. **Defender evaluation is attacking-output biased.** Goal contributions do not capture tackling, interceptions, aerial ability, ball progression or defensive positioning.
3. **Market value is not transfer cost.** Contract length, salary, release clauses and negotiating leverage are not included.
4. **The recruitment score is heuristic.** The 50/20/15/15 weighting is transparent but not empirically optimised.
5. **Position groups remain broad.** A centre-back and attacking full-back can have very different role requirements despite both being classified as defenders.
6. **League strength is not explicitly adjusted.** Percentiles are calculated within league and position, but no cross-league strength coefficient is applied.
7. **Injury history is unavailable.** Minutes and availability partly capture reliability but cannot distinguish injury from selection decisions.
8. **Development changes can be exaggerated from low previous percentiles**, particularly for players moving from zero attacking contribution.
9. **Current club context may differ from transfer feasibility.**
10. **No wage data is included**, so affordability refers only to estimated market value.
11. The `undervalued_young_players.csv` export is a **stricter subset** of Question 1 because it additionally requires performance ≥70th percentile and value below the position-age median.

---

# Data outputs

```text
outputs/theme_4/recruitment_candidate_master.csv
outputs/theme_4/undervalued_young_players.csv
outputs/theme_4/performance_value_efficiency.csv
outputs/theme_4/non_elite_club_opportunities.csv
outputs/theme_4/development_candidates.csv
outputs/theme_4/league_affordable_young_talent.csv
outputs/theme_4/lower_risk_candidates.csv
outputs/theme_4/high_upside_candidates.csv
```

# SQL files

```text
sql/09_recruitment_undervalued_talent.sql
sql/09a_theme_4_export_queries.sql
```

# Skills demonstrated

- Multi-factor recruitment screening in PostgreSQL
- Position-adjusted percentile ranking
- Age-position market-value benchmarking
- Value-efficiency analysis
- Club-context adjustment
- Year-on-year development analysis using `LAG`
- Historical consistency measurement with standard deviation
- Market-value limits by position
- Transparent weighted scoring
- Rule-based candidate classification
- Recruitment shortlist construction
- Translation of analytical outputs into business-facing scouting recommendations

---

## Interpretation note

The recruitment model should be treated as a **screening tool**. Its purpose is to reduce a large player universe to a manageable evidence-based shortlist. Final recruitment decisions would still require video scouting, tactical-role analysis, injury history, contract information, wage expectations, personality and club-specific requirements.
