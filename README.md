# fsQCA Analysis — Master Thesis

Fuzzy-set Qualitative Comparative Analysis (fsQCA) of M&A deal performance,
with comparison graphs and a full sensitivity / robustness analysis. Written in
**R** using the [`QCA`](https://cran.r-project.org/package=QCA) package.

## Research design (as implemented)

| Role | Variable | Source file | Meaning | Calibration |
|------|----------|-------------|---------|-------------|
| **Outcome** | `OUT` (`IAG_Primary_2y`) | `Outcome_Size.csv` | Industry-adjusted revenue growth, 2 years post-deal | direct, raw → fuzzy |
| Condition | `AI_CAP` | `AI_CAP_composite.csv` (by ticker) | Acquirer AI capability (sector z-score) | direct (−1 / 0 / +1) |
| Condition | `CULT` | `CULT_by_deal.csv` | Cultural fit | already calibrated |
| Condition | `STRUCT` | `STRUCT_by_deal.csv` | Integration structure (absorption) | already calibrated |
| Condition | `DYN` | `DYN_by_deal.csv` | Environmental dynamism | direct (percentile anchors) |

The six raw files are merged on `Deal_ID` (and `Ticker` for AI capability) into a
single deal-level dataset of **140 complete cases**.

> These role assignments and calibration anchors are **defensible defaults**, not
> the only possible design. Everything is controlled from `config.R` — change the
> outcome, the condition set, the anchors, or the thresholds there and re-run.

## How to run

```r
# From the project root, in R or RStudio:
source("run_analysis.R")
```
or from a terminal:
```bash
Rscript run_analysis.R
```

### Requirements
- R (>= 3.6)
- Packages: `QCA`, `ggplot2` (and their dependencies `admisc`, `declared`, `venn`)

```r
install.packages(c("QCA", "ggplot2"))
```

## Project structure

```
config.R                 # <-- the ONLY file you normally edit
run_analysis.R           # master script: runs the whole pipeline
R/
  01_data_prep.R         # merge the 6 raw files -> data/analysis_data.csv
  02_calibration.R       # direct-method calibration into fuzzy sets + diagnostics
  03_necessity.R         # necessary-condition analysis (outcome & negation)
  04_sufficiency.R       # truth table + complex/parsimonious/intermediate solutions
  05_plots.R             # comparison graphs (XY plots, bar charts, heatmaps, Venn)
  06_sensitivity.R       # robustness: threshold grid + calibration shifts
data/
  raw/                   # the six source CSVs
  analysis_data.csv      # merged, complete-case dataset (generated)
  calibrated_data.csv    # fuzzy scores (generated)
output/
  tables/                # all results as CSV + full solution printouts (TXT)
  figures/               # all graphs (300 dpi PNG)
  report.txt             # human-readable summary of every step
```

## What the pipeline produces

**Tables** (`output/tables/`)
- `calibration_diagnostics.csv` — checks no case is stranded at fuzzy 0.5
- `necessity_outcome.csv`, `necessity_negated.csv` — consistency, coverage, RoN
- `truth_table_outcome.csv` — every configuration with consistency & PRI
- `solution_{complex,parsimonious,intermediate}_{OUT,NEGOUT}.{csv,txt}`
- `sensitivity_thresholds.csv`, `sensitivity_calibration.csv`

**Figures** (`output/figures/`)
- `A_suff_xy_*` — sufficiency XY plots (one per path; points above the diagonal support sufficiency)
- `B_nec_xy_*` — necessity XY plots (points below the diagonal support necessity)
- `C_path_comparison_*` — consistency vs raw vs unique coverage per configuration
- `D_solution_types_*` — complex vs parsimonious vs intermediate fit
- `E_truthtable_heatmap_*` — configuration map coloured by membership
- `F_robustness_thresholds.png` — solution stability across `incl.cut` × `n.cut`
- `G_venn_*` — Venn/set-overlap diagram of the sufficient paths vs the outcome (cases per region, fuzzy membership > 0.5)

## Headline results (with the default settings)

**Necessity.** `STRUCT` (integration structure) is the only condition passing the
necessity threshold (consistency ≈ 0.95), but its Relevance of Necessity (RoN) is
low — i.e. it is necessary largely because it is near-constant in the sample, so it
should be read as *trivially* necessary.

**Sufficiency (intermediate solution for high growth).** Two paths:
1. `AI_CAP · CULT · STRUCT · ~DYN` — AI capability + cultural fit + absorption in
   *stable* environments
2. `~AI_CAP · CULT · STRUCT · DYN` — cultural fit + absorption in *dynamic*
   environments, *without* high AI capability

Overall solution consistency ≈ 0.74, coverage ≈ 0.60. Both paths share
`CULT · STRUCT`; AI capability matters conditionally on environmental dynamism.

**Robustness — read this before drawing strong conclusions.** The solution is
**sensitive** to analyst choices:
- It only appears at a raw-consistency cut of ≤ 0.75; at `incl.cut` ≥ 0.78 *no*
  configuration is sufficiently consistent (consistencies cluster at 0.73–0.81).
- Raising the frequency cut (`n.cut`) drops `STRUCT` from the paths.
- Shifting calibration crossovers changes the solution.

This fragility is a genuine empirical finding (PRI values are modest throughout)
and is documented quantitatively in the sensitivity tables and `F_robustness_thresholds.png`.

## Adapting for the thesis write-up
- Justify each calibration anchor theoretically in `config.R` (the defaults are
  data-driven percentiles / z-score anchors).
- Decide and defend your `incl.cut` / `pri.cut` / `n.cut`; report the sensitivity
  table to show you stress-tested them.
- Report necessity and sufficiency separately, and present both the outcome and
  its negation (asymmetry is a core fsQCA principle).
