# Acupuncture Utilization Analysis — Visualizations

Interactive charts analyzing veteran acupuncture utilization, demographics, condition
patterns, and multi-year uptake projections, built for a VA reporting deck. Each chart is a
self-contained React component (recharts + custom SVG).

> **Data source:** VHA Corporate Data Warehouse (CDW), accessed via VINCI.
> **Coverage:** historical FY2021–FY2026; projections through FY2036.

---

## What's here

Seventeen charts across five themes:

- **Utilization over time** — user trends, referrals & encounters, use-rate growth (and its slowdown).
- **Who uses acupuncture** — likelihood by age, race, and gender vs. population baselines.
- **What they use it for** — condition concentration (Pareto), gender skew by condition, and the
  conditions that most drive use.
- **Evidence alignment** — how users distribute across the MITRE evidence-group scale, and how each
  added condition shifts the odds of use.
- **Where care happens + what's next** — VA facility vs. community care by rurality, and
  scenario-based uptake projections with uncertainty fans.

See [`CHARTS.md`](./CHARTS.md) for full per-chart documentation: data tables, findings, and caveats.

---

## Repository structure

```
.
├── README.md                 # this file
├── CHARTS.md                 # detailed per-chart reference (data, findings, methodology)
├── data/                     # source CSVs
│   ├── annual_uptake_scenarios.csv
│   ├── county_rurality_summary.csv
│   ├── evidence_group_odds_ratios.csv
│   ├── adjusted_odds_ratios.csv
│   ├── model_coefficients_age_buckets.csv
│   └── condition_odds_ratios_with_evidence.csv
└── src/                      # one React component per chart
    ├── UtilizationTrends.jsx
    ├── ReferralsEncounters.jsx
    ├── AgeLikelihood.jsx
    ├── RaceLikelihood.jsx
    ├── GenderLikelihood.jsx
    ├── GenderConditionDelta.jsx
    ├── EvidenceGroupDistribution.jsx
    ├── ConditionPareto.jsx
    ├── UptakeProjections.jsx
    ├── UseRateTrend.jsx
    ├── RuralityUseRate.jsx
    ├── RuralityVaCc.jsx
    ├── SettingProjections.jsx
    ├── EvidenceOddsRatios.jsx
    ├── AdjustedOddsByDemographic.jsx
    └── ConditionOddsRatios.jsx
```

> Note: some data is embedded directly in the components (the historical utilization, demographic,
> condition, and evidence-group tables); the files in `data/` are the CSVs that were loaded or
> derived from. Values are duplicated into the components for portability.

---

## Running the charts

The components are standard React function components with default exports. They depend on
`react`, `recharts`, and Tailwind CSS utility classes for layout.

```bash
npm install react recharts
# Tailwind: configure per https://tailwindcss.com/docs/installation
```

Import and render any chart:

```jsx
import UtilizationTrends from "./src/UtilizationTrends";

export default function App() {
  return <UtilizationTrends />;
}
```

Each component is self-contained (no required props) and manages its own toggles/state. There is
no shared data layer — update the data arrays at the top of a component to refresh its figures.

---

## Dependencies

- **React** (hooks: `useState`)
- **recharts** — line/bar/area charts (charts 1, 2, 9–11, 14 use it; others are hand-rolled SVG)
- **Tailwind CSS** — layout, cards, buttons, legends
- No browser storage, no network calls, no build-time data loading.

---

## Conventions (quick reference)

- **Colors:** dark blue `#1b3a6b` (VAMC / users / higher), orange `#e67e22` (community care /
  enrolled / lower), magenta `#b5338a` (historical/full trend, female-skew), red `#c0392b`
  (reference/cumulative line), purple `#6b4a8a` (uncertainty fan), gray `#95a5a6` (neutral/reference).
- **Likelihood index:** group share among users ÷ group share of a baseline. 1.0× = proportional.
- **Odds ratios:** anchored at a 1.0× line; OR multiplies *odds*, not probability
  (`p = o/(1+o)`, `o = p0/(1−p0) × OR^n`).
- **Rurality:** USDA RUCC 1–9, grouped Metro (1–3) / Large town (4–5) / Rural (6–9).

---

## Caveats

- Figures reflect the CDW extract used for this analysis; re-pull dates will shift values.
- Race adjusted odds ratios are derived from ridge-regression coefficients (shrinkage may pull
  toward 1.0×; ranking/direction reliable).
- Projections apply scenario odds multipliers to a fixed enrolled population (5,231,037) and are
  illustrative, not forecasts.
- Two uptake-projection components are near-duplicates pending consolidation.

Full methodology and known cleanup items are in [`CHARTS.md`](./CHARTS.md).
