# Findings — fsQCA of post-acquisition growth

This note reports what the analysis shows, written to be adaptable into the
Results chapter. Because the code and the Methods chapter had diverged, two
models were run side by side (the user chose "build both, compare first"):

| Model | Conditions | DYN source | Calibration of continuous vars | Output folder |
|-------|-----------|-----------|--------------------------------|---------------|
| **A — current code** | 4 (AI_CAP, CULT, STRUCT, DYN) | combined US+EU | fixed/manual anchors | `output/` |
| **B — chapter-aligned** | 5 (adds **SIZE**) | **US-only** (primary) | **direct method, empirical percentiles** | `output_methods/` |

Model **B is faithful to Chapter 3** (five conditions, US-only DYN, p25/p50/p75
anchors — p10/p50/p75 for DYN, parity nudge for exact-zero growth). Model A is
retained as a robustness comparison. STRUCT and CULT are theoretically
calibrated (0.33/0.67/0.95) in both.

**Sample.** Both models analyse the **identical 140 deals** — the complete-case
intersection across all datasets. Of 147 merged deals, **7 are dropped solely
because AI_CAP could not be computed** (Intuit, Shopify, Lightspeed, Edenred,
Antares Vision, and Thomson Reuters ×2); every other condition and the outcome
are complete. So the comparison is strictly like-for-like on the same companies.
In Model B every one of the 32 logically possible configurations is populated and
no case lands on the 0.5 crossover, so the chapter's calibration design is clean.

---

## 1. Headline findings (robust across both models)

1. **Structural integration depth (STRUCT) is necessary for above-industry
   growth (necessity *in kind*), and relative deal size and AI capability are
   necessary *in degree*.** STRUCT clears the set-theoretic necessity threshold
   (consistency 0.95 in Model A, 0.91 in Model B; coverage ≈ 0.55). The NCA
   (necessity-in-degree) test on the raw continuous measures adds that **SIZE
   (effect size d = 0.30) and AI_CAP (d = 0.20)** impose ceilings on growth —
   high growth is not reached without a sufficient level of each — while DYN does
   not (d = 0.04). This in-kind/in-degree combination is the most defensible
   result and exactly the complementarity Vis & Dul (2018) describe.

2. **Sufficiency for *high* growth is weak and specification-dependent.** No
   configuration combines high consistency with broad coverage. Adding SIZE
   (Model B) collapses the solution from two paths to one and cuts coverage
   from 0.60 to 0.22.

3. **Causal asymmetry holds: the *absence* of growth is explained better than
   its presence, and the two solutions are not mirror images.** In Model B the
   absence-of-growth solution reaches coverage 0.39 (vs 0.22 for growth) and in
   Model A 0.78 (vs 0.60); the recurring ingredient in the failure paths is
   **~STRUCT** (shallow structural integration). This directly substantiates the
   asymmetry premise set out in Section 3.1.

---

## 2. Necessity (fsQCA, necessity-in-kind, threshold 0.90)

| Condition | Model A consistency | Model B consistency | Necessary? |
|-----------|--------------------:|--------------------:|:----------:|
| **STRUCT** | **0.947** | **0.908** | **Yes (both)** |
| CULT | 0.769 | 0.682 | No |
| DYN | 0.513 | 0.702 | No |
| AI_CAP | 0.607 | 0.531 | No |
| SIZE | — | 0.644 | No |

*Note:* DYN's consistency rises markedly from A to B (0.51 → 0.70) because the
primary DYN series changes from combined to US-only and is recalibrated on
percentiles. This is exactly why the DYN source must match the chapter — the two
series tell different stories about dynamism.

### Necessity in degree (NCA, Dul 2016) — on the raw continuous measures

NCA tests whether a condition imposes a *ceiling* on the outcome (an empty
upper-left corner: high growth is impossible below some level of the condition).
Effect size *d* ≥ 0.10 is meaningful. Run on the **raw** measures, because
calibration compresses the tails and flattens the ceiling (on calibrated scores
every *d* ≈ 0). Model B (5 conditions):

| Condition | NCA *d* (CE-FDH) | Necessary in degree? | Note |
|-----------|----------------:|:--------------------:|------|
| **STRUCT** | 0.39 | Yes | 3-level — indicative |
| **SIZE** | **0.30** | **Yes** | continuous |
| **AI_CAP** | **0.20** | **Yes** | continuous |
| CULT | 0.14 | Yes | 3-level — indicative |
| DYN | 0.04 | No | continuous |

The continuous conditions are the proper in-degree candidates: **SIZE and AI_CAP
each put a floor under growth** — you do not see high-growth deals at low deal
size or low AI capability (visible as the empty corners in the ceiling plot).
STRUCT/CULT take only three levels, so their NCA is indicative and the in-kind
test above is the primary evidence for them. This is an independent
implementation of NCA's CE-FDH/CR-FDH ceilings (the `NCA` package cannot be
installed here — see §7); cross-check against the package before final
submission.

Figures: `B_nec_xy_STRUCT.png` (set-theoretic necessity XY plot);
`I_nca_ceiling_OUT.png` (NCA ceiling plot — all conditions, both ceilings).

Figure: `B_nec_xy_STRUCT.png` (necessity XY plot — points cluster below the
diagonal, the necessity signature).

---

## 3. Sufficiency for high growth (intermediate solution)

**Model A (4 conditions) — two equifinal paths, coverage 0.60**

| Path | Configuration | Consistency | Raw cov. | Unique cov. |
|------|---------------|:-----------:|:--------:|:-----------:|
| A1 | AI_CAP·CULT·STRUCT·~DYN | 0.76 | 0.42 | 0.23 |
| A2 | ~AI_CAP·CULT·STRUCT·DYN | 0.77 | 0.37 | 0.19 |
| | **Solution** | **0.74** | **0.60** | |

Both paths share **CULT·STRUCT**: high growth goes with deep structural
integration *plus* sustained socio-cultural effort, with AI capability and
dynamism trading off (high AI in stable settings, or high dynamism without high
AI). All terms are core.

**Model B (5 conditions, chapter-aligned) — one narrow path, coverage 0.22**

| Path | Configuration | Consistency | Coverage |
|------|---------------|:-----------:|:--------:|
| B1 | AI_CAP·STRUCT·SIZE·DYN | 0.73 | 0.22 |
| | **Solution** | **0.73** | **0.22** |

Core = AI_CAP, SIZE, DYN; **STRUCT is peripheral**; **CULT drops out**. Read
substantively: in the chapter-faithful model, the only sufficient recipe for
high growth is large, AI-capable acquisitions in dynamic industries with at
least moderate structural integration — but it covers only ~22% of high-growth
cases, so most above-industry performance is **not** captured by any single
configuration.

Figures: `H_config_chart_OUT.png` (Fiss notation — the headline results
figure), `A_suff_xy_OUT_path*.png`, `G_venn_OUT.png`.

---

## 4. Sufficiency for the absence of growth (~OUT)

**Model B — four paths, coverage 0.39, consistency 0.78**

| Path | Configuration | Consistency | Raw cov. |
|------|---------------|:-----------:|:--------:|
| 1 | CULT·~STRUCT·~DYN | 0.76 | 0.18 |
| 2 | ~AI_CAP·~CULT·STRUCT·~SIZE | 0.79 | 0.24 |
| 3 | AI_CAP·CULT·~STRUCT·~SIZE | 0.81 | 0.17 |
| 4 | AI_CAP·~STRUCT·~SIZE·~DYN | 0.80 | 0.11 |

(Raw coverages sum to more than 0.39 because the paths overlap on shared cases;
0.39 is the coverage of their union.)

Three of the four failure paths contain **~STRUCT** (shallow integration), and
~SIZE recurs (small deals). The mirror image of finding 1: where structural
integration is necessary for success, its absence is the common route to
underperformance. (Model A tells the same story with model ambiguity — two
equally-good models, both built on ~STRUCT / mismatched STRUCT-CULT pairings,
coverage ≈ 0.78.)

Figures: `H_config_chart_~OUT.png`, `G_venn_~OUT.png`.

---

## 5. Robustness

Threshold sensitivity (consistency × frequency grid) reproduces the exact
baseline paths in **17%** of settings (Model A) and **33%** (Model B). Both
solutions are stable at the standard consistency cut (0.75) but empty out at
stricter cuts (≥0.78–0.80), reflecting the tightly clustered row consistencies
the chapter already flags. Report this honestly as a sensitivity caveat rather
than presenting any single solution as definitive.

Figure: `F_robustness_thresholds.png`. Tables: `sensitivity_thresholds.csv`,
`sensitivity_calibration.csv`.

---

## 6. What makes most sense for the analysis (recommendation)

1. **Lead with necessity.** STRUCT-necessary-for-growth is the robust,
   well-covered, theory-consistent result. Put it first.
2. **Frame sufficiency through causal asymmetry.** The absence-of-growth model
   is empirically stronger (coverage 0.39 vs 0.22 in Model B; 0.78 vs 0.60 in
   Model A) and has a clean reading (~STRUCT-centred failure). The chapter
   already motivates asymmetry, so this is a natural spine for the Results
   chapter.
3. **Use Model B as primary** (it matches Chapter 3) but **report its low
   positive-outcome coverage transparently**, and present Model A as a
   robustness comparison showing the growth solution depends on whether SIZE is
   included. The side-by-side is a strength, not a weakness.
4. **Discuss the conditions-to-cases ratio.** Five conditions over 140 cases
   spread thinly across 32 configurations; the narrow Model-B growth solution is
   partly a diversity effect. This is a legitimate limitation to raise (cf.
   Greckhamer et al., 2018) and a reason the asymmetric/necessity framing is
   safer than leaning on the positive-outcome sufficiency solution.

### Recommended figures (grounded in field practice)
Conventions confirmed against Fiss (2011), Pappas & Woodside (2021) and the
Campbell et al. (2016) precedent: the configuration chart with large/small
circles (core/peripheral), ⊗ for absent and blank for "don't care" is the
standard headline display.
- **Headline:** `H_config_chart_*` (Fiss notation), `I_nca_ceiling_OUT`
  (NCA — necessity in degree), `B_nec_xy_STRUCT` (set-theoretic necessity),
  `G_venn_*` (coverage / equifinality), `F_robustness_thresholds` (sensitivity).
- **Support:** `A_suff_xy_*` (per-path sufficiency).
- **Appendix only:** `C_path_comparison_*`, `D_solution_types_*`,
  `E_truthtable_heatmap_*`.

---

## 7. Outstanding items before final write-up

- **NCA — now implemented "around" the package.** Chapter 3.5 specifies NCA
  (ce_fdh/cr_fdh ceilings, effect size d ≥ 0.10). The `NCA` package cannot be
  installed here (CRAN blocked; sandbox declined a mirror fetch), so
  `R/07_nca.R` computes the CE-FDH and CR-FDH ceilings and effect sizes
  directly. Results are in `necessity_nca.csv` and `I_nca_ceiling_*`.
  **Cross-check against the official `NCA` package before submission** — the
  numbers should match, but this is an independent implementation.
- **Choice of primary model (4 vs 5 conditions).** This determines every number
  in the Results chapter; the comparison above is the input to that decision.
- **Directional expectations for SIZE/DYN.** Model B treats both contextual
  conditions as "either" ("-"), consistent with the chapter's framing of them
  as moderators. If the theory section argues a direction, it is one line to
  change in `config_methods.R`.
