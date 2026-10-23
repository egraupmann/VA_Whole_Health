# Acupuncture Utilization Analysis — Chart Repository

Reference documentation for the set of data visualizations built for the VA acupuncture
utilization deck/report. Each chart is a self-contained React (recharts + custom SVG)
component. This file documents what each chart shows, the data behind it, the design
conventions, methodology, and known caveats.

**Data source:** VHA Corporate Data Warehouse (CDW), accessed via VINCI. Use "VHA CDW"
(not "VA CDW"); include the extract/pull date since CDW refreshes continuously.
**Fiscal-year coverage:** historical data FY2021–FY2026; projections FY2027–FY2036.

---

## Source data files

| File | Feeds chart(s) | Notes |
|---|---|---|
| (inline) utilization table | Utilization Trends | Total / VAMC / Community Care unique users by FY |
| (inline) referrals/encounters table | Referrals & Encounters | Totals by FY |
| (inline) demographic tables | Age / Race / Gender dumbbells | acupuncture %, likely-to-use %, enrolled %, counts |
| (inline) condition table | Gender-by-condition, Pareto | diagnosis totals, distinct patients, gender splits, future users |
| (inline) evidence-group table | Evidence Scale | user % / enrolled % / counts per group |
| `annual_uptake_scenarios.csv` | Uptake Projections, Setting Projections | scenario × FY × (setting) projections; pop 5,231,037 |
| `county_rurality_summary.csv` | Rurality Use Rate | pooled use rate by RUCC |
| (inline) VA/CC rurality table | VA vs. CC by Rurality | VA & CC patient counts by RUCC |
| `evidence_group_odds_ratios.csv` | Each Added Condition | adjusted OR per added condition, by evidence group |
| `adjusted_odds_ratios.csv` | Adjusted Odds by Demographic | OR vs. reference for age/rucc/gender (race null here) |
| `model_coefficients_age_buckets.csv` | Race odds (derived) | ridge log-odds coefficients; race OR = exp(coef − White coef) |
| `condition_odds_ratios_with_evidence.csv` | Condition Odds Ratios | adjusted OR (with vs. without condition), 98 conditions |

---

## Chart inventory

| # | Artifact ID | Title | Type |
|---|---|---|---|
| 1 | `acupuncture-chart` | Acupuncture Utilization Trends | line/bar toggle |
| 2 | `referrals-encounters-chart` | Acupuncture Referrals & Encounters | line/bar toggle |
| 3 | `age-acupuncture` | Acupuncture Use by Age | dual-baseline dumbbell |
| 4 | `race-acupuncture` | Acupuncture Use by Race | dual-baseline dumbbell |
| 5 | `gender-acupuncture` | Acupuncture Use by Gender | dual-baseline dumbbell |
| 6 | `gender-condition-delta` | Which Conditions Skew Male vs. Female | diverging bar |
| 7 | `benefit-group-dist` | Where Acupuncture Users Fall on the Evidence Scale | grouped bars + index toggle |
| 8 | `condition-pareto` | A Few Conditions Drive Almost All Demand | Pareto |
| 9 | `uptake-projections` | Projected Acupuncture Users (FY36) | scenario lines |
| 10 | `uptake-projections-fy31` | Projected Acupuncture Users (dup, FY36) | scenario lines |
| 11 | `odds-ratio-trend` | Acupuncture Use Rate: Growth Slowing | actual + fitted trend lines |
| 12 | `rurality-use-rate` | Use Rate by County Rurality | horizontal bars |
| 13 | `rurality-va-cc` | VA vs. Community Care by Rurality | stacked bars, volume/share toggle |
| 14 | `setting-projections` | Projected Users by Care Setting | uncertainty-fan projections |
| 15 | `evidence-odds-ratios` | Each Added Condition Raises Odds | horizontal OR bars |
| 16 | `adjusted-odds-groups` | Adjusted Odds Ratios by Demographic | OR bars, 4-way toggle |
| 17 | `condition-odds-ratios` | Conditions That Drive Acupuncture Use | OR bars, drivers/suppressors toggle |

---

## Design conventions

- **Palette:** VAMC / users / "higher" = dark blue `#1b3a6b`; Community Care / enrolled /
  "lower" = orange `#e67e22`; secondary blue `#2e86c1`; magenta (full/historical trend,
  female-skew) `#b5338a`; reference/neutral gray `#95a5a6`; reference line / cumulative red
  `#c0392b`; uncertainty-fan purple `#6b4a8a`. Colorblind-safe blue `#0072B2` where noted.
- **Likelihood index:** a group's share among users ÷ its share of a baseline population.
  1.0× = proportional; >1.0× more likely, <1.0× less likely.
- **Odds ratio charts:** anchored at a 1.0× reference line; include a plain-language
  "How to read this chart" box. Remember OR acts on *odds*, not probability directly:
  new_odds = base_odds × OR^n; convert via p = odds/(1+odds).
- **Layout order:** chart → key → explanation → summary cards → footnote.
- **Rurality:** USDA Rural-Urban Continuum Codes (RUCC 1–9). Three display tiers: Metro (1–3),
  Large town (4–5), Rural (6–9). "Adjacent" = borders a metro county; "remote" = nonadjacent.
- Charts are custom SVG where fine label control was needed (dumbbells, diverging/OR bars,
  Pareto, rurality, fans); recharts for simple line/bar trends and projections.
- Most charts have had fonts enlarged for report/screenshot legibility.

---

## 1. Utilization Trends (`acupuncture-chart`)

Unique acupuncture users over time by care setting; line/bar toggle; growth cards.

| FY | Total | VAMC | Community Care |
|---|---|---|---|
| 2021 | 118,409 | 58,614 | 66,105 |
| 2022 | 140,958 | 74,092 | 75,342 |
| 2023 | 167,586 | 92,721 | 85,723 |
| 2024 | 190,788 | 112,522 | 89,925 |
| 2025 | 197,536 | 119,900 | 89,718 |
| 2026 | 210,941 | 118,600 | 106,052 |

Legend labels: "VAMC Users", "Community Care Referrals". **Findings:** total +78%, VAMC +102%
(peaks FY25 then dips), CC +60%. Lines not stacked (settings overlap).

## 2. Referrals & Encounters (`referrals-encounters-chart`)

| FY | Referrals | Encounters |
|---|---|---|
| 2021 | 100,400 | 221,181 |
| 2022 | 112,993 | 291,907 |
| 2023 | 124,437 | 381,742 |
| 2024 | 130,831 | 478,119 |
| 2025 | 128,875 | 527,920 |
| 2026 | 157,309 | 536,492 |

**Findings:** encounters +143%, referrals +57%; encounters per referral 2.2→3.4.

## 3–5. Demographic dumbbells (`age-`, `race-`, `gender-acupuncture`)

Two dots per row: orange = likelihood vs. "All enrolled patients"; blue = vs. "Veterans with
Acupuncture Classification Condition". Connector length = baseline divergence. Each has a
Likelihood-Index and Raw-Shares view. X-axis caps: **Age 1.4×, Race 1.6×, Gender 1.8×**
(per-chart, not shared).

**Age** [acu%, cond%, enrolled%, count]: <35 [7.0, 8.5, 8.9, 45130]; 35–44 [16.0, 13.6, 15.0,
103208]; 45–54 [17.6, 13.5, 13.6, 113794]; 55–64 [21.2, 18.1, 16.7, 137092]; 65–74 [18.2, 18.9,
17.5, 117376]; 75+ [20.0, 27.4, 28.3, 129019]. Most likely 45–54/55–64 (~1.3×); least 75+ (~0.71×).

**Race** (Unknown removed): White [58.8, 61.1, 60.1, 380286]; Black [18.4, 18.8, 15.6, 118885];
Hispanic [10.2, 8.9, 12.1, 65857]; Asian [2.4, 1.6, 1.6, 15304]; Multiracial [1.2, 1.1, 1.0, 7932];
NH/PI [1.1, 0.8, 0.8, 7122]; AI/AN [0.8, 0.7, 0.7, 4873]. Asian highest (~1.5×); White lowest.
Hispanic flips by baseline (0.84× enrolled vs 1.15× condition).

**Gender:** Female [20.7, 12.7, 11.7, 133728]; Male [79.3, 87.3, 88.3, 511893]. Female ~1.77×
enrolled / ~1.63× condition — the sharpest demographic effect.

## 6. Conditions skewing male vs. female (`gender-condition-delta`)

Diverging bar, top 20 conditions by diagnosis volume, distinct-user gender split vs. the
79% M / 21% F user baseline. Symmetric axis ±55; male-skew blue `#2e6da4`, female-skew magenta
`#b5338a`; diagnosis count under each label. **Most female:** Fibromyalgia (67% F, +46), Migraine
(48% F, +27), Anxiety, Tension headache, Depression. **Most male:** Diabetic periph. neuropathy
(95% M, −16), autonomic & other neuropathy (91% M). Women over-index on pain+neuro/mental-health;
men on neuropathies.

## 7. Evidence-group distribution (`benefit-group-dist`)

Grouped bars (FY26 Acupuncture users vs. FY26 VA enrolled Veterans) + Likelihood-Index toggle.
Includes a bold "Group A — All Evidence Levels" subtotal row.

| Group | User % | User ct | Enrolled % | Enrolled ct | Index |
|---|---|---|---|---|---|
| A High/Strong | 23.4 | 50,881 | 10.2 | 539,723 | 2.29× |
| A Moderate | 43.3 | 94,394 | 27.1 | 1,439,261 | 1.60× |
| A Low/Very Low | 28.2 | 61,326 | 32.4 | 1,723,192 | 0.87× |
| **A All Levels** | **94.9** | **206,601** | **69.7** | **3,702,176** | **1.36×** |
| B | 1.5 | 3,280 | 7.7 | 409,236 | 0.19× |
| C | 2.9 | 6,311 | 17.4 | 926,170 | 0.17× |
| D | 0.7 | 1,569 | 5.2 | 277,708 | 0.13× |

**Findings:** 95% of users in Group A vs 70% enrolled; A High/Strong 2.3× over-represented;
Groups B–D only 5% of users vs 30% enrolled.

## 8. Condition concentration — Pareto (`condition-pareto`)

Ranked bars + cumulative % line (vs. all-99-condition total). Toggle: "Acupuncture users since
FY21" vs "Possible future users". Top-10 bars; fixed y-max 360K (users) / 700K (future).
All-condition totals: 918,257 current patients; 905,257 future users.
**Current top 5 = 77%** of users (Low back pain alone 38%). **Future top 5 = 97%** (Low back
pain 76%).

## 9–10. Uptake projections (`uptake-projections`, `uptake-projections-fy31`)

Scenario fan lines, FY27–FY36 (both now full horizon — **duplicates; consolidate to one**).
Reference line dropped from plot. Pop 5,231,037. Labels: "Increased odds of use",
"Change in Usage Odds from FY21–FY26", "…FY24–FY26". Y-axis "Possible user growth", cap 400K.

| Scenario | FY27 | FY36 |
|---|---|---|
| Reference (flat) | 206,963 | 206,963 |
| FY24–FY26 odds | 210,406 | 243,787 |
| FY21–FY26 odds | 216,881 | 327,120 |
| Increased odds | 219,720 | 370,016 |

## 11. Use rate — growth slowing (`odds-ratio-trend`)

Solid actual use rate FY21–FY26 + two exponential least-squares trend fits (FY21–FY26 window and
FY24–FY26 window) projected to FY28. Full-window fit faint until FY25. Relabeled from "Odds Ratio"
to "Use rate".

| FY | Use rate |
|---|---|
| 2021 | 2.295% |
| 2022 | 2.749% |
| 2023 | 3.248% |
| 2024 | 3.661% |
| 2025 | 3.775% |
| 2026 | 3.956% |

FY28 fits: FY21–FY26 → 5.25%; FY24–FY26 → 4.26% (gap ~1.0 pt). Actual +72% but flattening.

## 12. Use rate by rurality (`rurality-use-rate`)

Horizontal bars, RUCC 1–9 most-urban→most-rural, all-county reference line 4.1%. Tiers:
Metro / Large town / Rural (graduated blue). RUCC codes shown in labels.

| RUCC | Use rate | Veterans |
|---|---|---|
| 1 Large metro | 4.68% | 2,346,877 |
| 2 Mid metro | 3.98% | 1,314,031 |
| 3 Small metro | 3.76% | 618,044 |
| 4 Lg town, adjacent | 3.47% | 280,920 |
| 5 Lg town, remote | 4.00% | 85,349 |
| 6 Sm town, adjacent | 2.94% | 228,067 |
| 7 Sm town, remote | 3.03% | 120,822 |
| 8 Rural, adjacent | 2.87% | 132,182 |
| 9 Rural, remote | 2.87% | 89,654 |

**Findings:** urban→rural gradient, large metro (4.7%) ~1.6× the most rural (2.9%). Remote
large-town (4.0%) bucks trend (small N).

## 13. VA vs. Community Care by rurality (`rurality-va-cc`)

Stacked bars, Patient-Volume and Share-of-Care toggle (50% ref line). RUCC labels.

| RUCC | VA | CC | % CC |
|---|---|---|---|
| 1 | 61,928 | 50,791 | 45% |
| 2 | 25,136 | 26,897 | 52% |
| 3 | 11,918 | 11,049 | 48% |
| 4 | 5,430 | 4,295 | 44% |
| 5 | 1,780 | 1,911 | 52% |
| 6 | 3,410 | 3,212 | 49% |
| 7 | 2,099 | 1,475 | 41% |
| 8 | 2,115 | 1,662 | 44% |
| 9 | 1,508 | 1,106 | 42% |

**Findings:** CC share flat (41–52%) across rurality — no rural shift; ~47% overall CC. Story is
consistency, not gradient.

## 14. Projected users by care setting (`setting-projections`)

Three-way view toggle (VA Facility / Community Care / Both Settings) + 5-Year/10-Year horizon
toggle. Two trend lines per setting; shaded fan between = uncertainty. Combined view: blue=VAMC,
orange=CC; solid=FY21–FY26 odds, dashed=FY24–FY26 odds; matrix legend. Pop 5,231,037. FY26
baselines: VAMC 116,318, CC 104,011. Combined 5-yr y-axis zoomed 90K–210K.

| Series | FY27 | FY36 |
|---|---|---|
| VAMC FY21–FY26 odds | 129,686 | 330,500 |
| VAMC FY24–FY26 odds | 115,547 | 108,823 |
| CC FY21–FY26 odds | 109,300 | 169,531 |
| CC FY24–FY26 odds | 108,981 | 164,792 |

**Findings — key point:** all uncertainty is on VA-facility side. VAMC FY36 fan ±222K (109K–331K:
historical +184%, recent −6%). CC fan only ±5K (165K–170K, stable). Recent slowdown concentrated
in VA-facility care; CC climbs regardless.

## 15. Each added condition raises odds (`evidence-odds-ratios`)

Horizontal OR bars; adjusted OR of acupuncture use per *one additional* condition in each evidence
group. Blue raises / orange lowers; 1.0× reference; "how to read" box.

| Group | OR | Patients |
|---|---|---|
| A High/Strong | 1.64 | 513,161 |
| A Low/Very Low | 1.56 | 2,937,219 |
| A Moderate | 1.33 | 1,646,369 |
| D | 1.15 | 1,824,221 |
| C | 1.04 | 3,093,891 |
| B | 0.93 | 2,154,959 |

**Findings:** Group A tiers drive odds most; Group B the lone <1.0× (each added B condition slightly
lowers odds). Worked example: base 4% + 3 Group-A-High conditions → odds 0.042×1.64³ ≈ 0.184 → **15.5%**.

## 16. Adjusted odds ratios by demographic (`adjusted-odds-groups`)

OR bars vs. a reference group; 4-way toggle. Blue higher / orange lower; gray dot = reference.

- **Age** (ref <35): 45–54 1.40× (highest), 55–64 1.37×, 65–74 1.26×, 35–44 1.24×, 75+ 1.03×.
- **Rurality** (ref RUCC 6): RUCC 1 1.33×, RUCC 5 1.32×; RUCC 8 0.93× & RUCC 9 0.97× below ref.
- **Gender** (ref male): Female 1.56×.
- **Race** (ref White, derived from ridge coefficients, Unknown removed, sorted A→Z):
  American Indian/AK Native 1.14×, Asian 1.71×, Black 0.88×, Hispanic 1.14×, Multiracial 1.10×,
  NH/PI 1.30×, White 1.00×. **Summary:** Asian highest (~71% higher than White); Black the only
  group below White (~12% lower); others modestly above.

## 17. Conditions that drive acupuncture use (`condition-odds-ratios`)

Horizontal OR bars; adjusted OR of use for patients WITH vs. WITHOUT each condition. Toggle: Top
Drivers (x to 4.0×) / Lowest Odds (0.7–1.1×). Evidence group spelled out + patient count per row.
**Top drivers:** Low back pain 3.95×, Chronic neck pain 1.98×, Other MSK pain 1.92×, Segmental
dysfunction 1.75×, Fibromyalgia 1.73×. **Lowest:** Tobacco use disorder 0.77×, Dyslipidemia 0.79×,
GERD 0.81×, Schizophrenia 0.82×, COPD 0.85×.

---

## Methodology & caveats

- **Two baselines in demographic charts:** "all enrolled patients" (general propensity) and
  "Veterans with Acupuncture Classification Condition" (propensity given clinical relevance,
  originally "likely to benefit"). The underlying MITRE source column is "likely to benefit".
- **Likely-to-benefit list:** MITRE-developed ICD-10 condition list; Group A subdivided by evidence
  strength (High/Strong, Moderate, Low/Very Low); Groups B–D have no assigned evidence level.
- **Distinct users vs. diagnoses:** condition-level patient counts sum to more than unique users
  because a patient with multiple conditions is counted under each.
- **Gender baselines:** diagnosis-level ≈ 77% M / 23% F; distinct-user ≈ 79% M / 21% F. Chart 6
  uses the distinct-user baseline.
- **Odds ratios:** OR multiplies *odds*, not probability. For a predicted probability use
  p = o/(1+o) where o = [p0/(1−p0)] × OR^n.
- **Race ORs (chart 16):** derived from ridge-regression log-odds coefficients as
  exp(group − White). Ridge shrinkage may pull estimates slightly toward 1.0×; ranking/direction
  reliable. The pre-computed `adjusted_odds_ratios.csv` returned null for race, hence the
  coefficient-based derivation.
- **Projections:** apply scenario odds multipliers to a fixed enrolled population (5,231,037).
  "Reference" holds FY26 rate flat; trend scenarios extrapolate FY21-onward or FY24-onward change
  in odds of use.
- **Source table dedup:** the condition table had duplicate rows at the bottom (Hyperemesis
  gravidarum, Premenstrual syndrome, ART/embryo transfer) removed before computing totals.
- **Use-rate series** labeled "odds ratio" in source but formatted as % and matches use rates.

## Known cleanup items

- Charts 9 and 10 (`uptake-projections`, `uptake-projections-fy31`) are duplicate full-horizon
  copies — consolidate to one.
- Per-chart x-axis scales on the three demographic dumbbells differ (1.4× / 1.6× / 1.8×) — not
  directly comparable side-by-side; standardize if needed.
- Summary-card headers and footnotes in a few charts still use shorter legacy wording.
