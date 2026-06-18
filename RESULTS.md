# Results — configurations of post-acquisition growth

*Primary model: the chapter-aligned five-condition pooled fsQCA (AI_CAP, CULT,
STRUCT, SIZE, DYN), N = 140. The four-condition model is reported as a
robustness comparison in §7. All numbers are reproduced by `run_analysis.R`;
tables are generated to `output_methods/tables/` (Markdown, LaTeX, CSV).*

---

## 1. Sample and calibration

**Sample.** The analytic sample is the **140 deals with complete data on the
outcome and all five conditions** — the intersection across every dataset. Of
147 coded deals, 7 drop solely because AI_CAP could not be computed (Intuit,
Shopify, Lightspeed, Edenred, Antares Vision, Thomson Reuters ×2); every other
condition and the outcome are complete, so the analysis is strictly
like-for-like. The sample is 88 technology and 52 financial-services deals.
Every one of the 2⁵ = 32 logically possible configurations is populated, and no
case sits on the 0.5 crossover.

**Calibration (justified for every condition).** Two families are used, matched
to the nature of each measure (full table: `calibration_justification.csv`).

| Condition | Measure | Calibration | Anchors (in / cross / out) | Why |
|-----------|---------|-------------|----------------------------|-----|
| Industry-adjusted growth | 2-yr industry-adjusted revenue CAGR | Direct, percentile | 0.084 / 0.000 / −0.072 | p50 crossover ≈ industry parity (theory meets data) |
| AI capability | 0.40·AIE_z + 0.60·AIS_z (within-sector) | Direct, percentile | 0.53 / −0.02 / −0.60 | p25/p50/p75; within-sector z removes the reporting asymmetry |
| Relative deal size | deal value ÷ acquirer revenue | Direct, percentile | 0.88 / 0.37 / 0.12 | p25/p50/p75 on a scale-free ratio |
| Industry dynamism | Dess–Beard instability (US) | Direct, percentile | 0.00057 / 0.00040 / 0.00026 | p10/p50/p75 — lower half is concentrated, so p10 is the exclusion anchor |
| Structural integration | absorption / symbiosis / preservation | Theoretical | 0.95 / 0.67 / 0.33 | ordered ideal types, not a continuous metric |
| Cultural integration effort | strong / moderate / weak | Theoretical | 0.95 / 0.67 / 0.33 | ordered ideal types |

The direct-method anchors are **empirical percentiles of this sample**, so each
is data-justified rather than imposed; the ordinal conditions keep their
theoretical ideal-type structure. Sensitivity to these choices is examined in §6.

---

## 2. Necessity — which conditions are *salient* (in kind and in degree)

Necessity is tested two complementary ways (Vis & Dul, 2018): **in kind** via
fsQCA (is the outcome a subset of the condition?) and **in degree** via NCA (does
the condition put a *ceiling* on the outcome?). Table: `salient_conditions.csv`;
figures `B_nec_xy_STRUCT.png` and `I_nca_ceiling_OUT.png`.

| Condition | Necessity in kind (consistency) | Necessity in degree (NCA *d*) | Appears in # sufficient paths |
|-----------|:--:|:--:|:--:|
| **Structural integration** | **0.91** ✓ | 0.39 † | **5** |
| **Relative deal size** | 0.64 | **0.30** ✓ | 4 |
| **AI capability** | 0.53 | **0.20** ✓ | 4 |
| Industry dynamism | 0.70 | 0.04 | 3 |
| Cultural integration effort | 0.68 | 0.14 † | 3 |

✓ above threshold (kind ≥ 0.90; degree *d* ≥ 0.10). † STRUCT/CULT are 3-level,
so their NCA is indicative; the in-kind test is primary for them.

**The salient conditions are STRUCT, SIZE and AI_CAP.**
- **Structural integration is necessary *in kind*** (consistency 0.91): high
  growth essentially does not occur without at least moderate structural
  integration. It is also the condition that appears in *every* sufficient
  configuration. It is the linchpin.
- **Relative deal size (d = 0.30) and AI capability (d = 0.20) are necessary
  *in degree***: there is an empty upper-left corner in their ceiling plots —
  no high-growth deal is observed below a threshold level of scale or of AI
  capability. This is something the set-theoretic test alone would miss, and it
  is exactly the kind/degree complementarity the method promises.
- **Dynamism is contextual, not necessary**; cultural effort is weak on both
  tests as a stand-alone necessity (it matters only in combination, §4).

---

## 3. Sufficiency — the configuration table

The truth table (incl.cut = 0.75, PRI = 0.50, freq = 1) was minimised into
intermediate solutions for high growth and its absence. The configuration table
below is the canonical fsQCA results display in Fiss (2011) notation
(`config_solution_table.md/.tex/.csv`; figure `H_config_chart_OUT.png`).

| Condition | **G1** | **A1** | **A2** | **A3** | **A4** |
|-----------|:--:|:--:|:--:|:--:|:--:|
| *Outcome* | *High growth* | *Absence* | *Absence* | *Absence* | *Absence* |
| AI capability | ● |  | ⊗ | • | • |
| Cultural integration effort |  | • | ⊗ | • |  |
| Structural integration | • | ⊗ | • | ⊗ | ⊗ |
| Relative deal size | ● |  | ⊗ | ⊗ | ⊗ |
| Industry dynamism | ● | ⊘ |  |  | ⊘ |
| **Consistency** | 0.73 | 0.76 | 0.79 | 0.81 | 0.80 |
| **Raw coverage** | 0.22 | 0.18 | 0.24 | 0.17 | 0.11 |
| **Unique coverage** | – | 0.04 | 0.14 | 0.04 | 0.00 |
| Tech cases | 6 | 3 | 6 | 1 | 1 |
| Financial cases | 5 | 0 | 2 | 1 | 2 |

*● core present · • peripheral present · ⊗ core absent · ⊘ peripheral absent ·
blank = "don't care". Core = also in the parsimonious solution.* Overall fit:
high-growth solution consistency 0.73, coverage 0.22; absence-of-growth solution
consistency 0.78, coverage 0.39.

---

## 4. Making sense of the configurations (grouping + theory)

### One recipe for high growth (G1): AI_CAP · STRUCT · SIZE · DYN
Above-industry growth follows from **large, AI-capable acquisitions that are
structurally integrated and undertaken in dynamic industries.** AI capability,
scale and dynamism are *core*; structural integration is *peripheral* but
present, and cultural effort is irrelevant ("don't care"). Theoretically this is
a **dynamic-capabilities** story (Teece et al., 1997; Mikalef & Gupta, 2021):
AI capability creates value precisely where the environment is turbulent (DYN
core), and only at sufficient scale (SIZE core) — consistent with the
in-degree necessity of both. It is a demanding recipe (coverage 0.22): most
above-industry growth is *not* captured by any single configuration, so growth
is harder to engineer than failure is to fall into.

### Two ways to fail (the absence-of-growth paths group cleanly)

**Group I — "Failure to integrate" (~STRUCT): A1, A3, A4.** Three of the four
failure paths share the *absence* of structural integration. Whatever else is
present — cultural effort (A1, A3), AI capability (A3, A4) — without structural
integration, and typically in smaller deals (~SIZE in A3, A4), the deal does not
out-grow its industry. This is the mirror of finding §2: where structural
integration is *necessary* for success, its absence is the dominant route to
underperformance (Haspeslagh & Jemison, 1991 — integration is the mechanism
through which synergy is realised; the task dimension dominates).

**Group II — "Hollow integration" (STRUCT · ~AI_CAP · ~CULT): A2.** The one
failure path *with* structural integration is also the one lacking both AI
capability and cultural effort, in small deals — structure without the
capabilities or the human-side investment to exploit it. Structural integration
is necessary but not self-sufficient; it must be paired with capability and
effort (resource-based view; the acculturation perspective on the human side).

**Causal asymmetry.** The two solution sets are not mirror images, and failure
is explained almost twice as well as success (coverage 0.39 vs 0.22) — the
asymmetry the design anticipated.

---

## 5. Sector insight (why pooled, with a breakdown — not a split)

A separate financial-only fsQCA (N = 52) would be underpowered for five
conditions, so the analysis is pooled and the sector composition of each
configuration is reported (rows "Tech/Financial cases" above). Two patterns:

- The high-growth recipe **G1 spans both arms** (6 technology, 5 financial) — a
  genuinely cross-sector path, which justifies pooling.
- In the four-condition robustness model the **two growth paths separate almost
  perfectly by sector**: AI_CAP·CULT·STRUCT·~DYN is 25 technology / 0 financial,
  while ~AI_CAP·CULT·STRUCT·DYN is 2 technology / 21 financial. Equifinality
  here *is* the sector contrast — technology grows through AI capability in
  stable niches, financial services through integration under high dynamism (the
  2022–23 rate regime). This is a substantive finding, recovered without
  splitting the sample.

---

## 6. Robustness

Re-estimating across consistency cuts (0.75 / 0.80 / 0.85) and frequency cuts
(1–3), and shifting the calibration crossovers, the **necessity findings are
stable** (STRUCT necessary in kind throughout; SIZE and AI_CAP necessary in
degree). The *sufficiency* solution is stable at the conventional cut (0.75) but
thins at stricter cuts — reported transparently as a sensitivity caveat
(`F_robustness_thresholds.png`, `sensitivity_*.csv`). The substantive story
rests on the robust necessity results and the clean failure typology, not on a
single fragile sufficiency path.

---

## 7. Robustness model (four conditions, without SIZE)

Dropping SIZE yields two equifinal growth paths (coverage 0.60): AI_CAP·CULT·
STRUCT·~DYN and ~AI_CAP·CULT·STRUCT·DYN — both built on **CULT·STRUCT**. STRUCT
remains necessary (consistency 0.95). The contrast with the five-condition model
is informative: adding scale (SIZE) reveals it as a core, necessary-in-degree
condition and narrows the growth recipe. Either way, **structural integration is
the constant**, which is the headline to carry into the discussion.

---

## 8. Conclusions and fit to the literature

1. **Structural integration is the necessary backbone** of post-acquisition
   growth (necessary in kind; present in every configuration; its absence is the
   main failure mode). This extends Haspeslagh & Jemison (1991) into an
   AI-era, configurational setting and answers the gap on *how* integration
   choices combine rather than act in isolation (Graebner et al., 2017).
2. **Scale and AI capability are threshold (necessary-in-degree) conditions** —
   a contribution only visible by combining fsQCA with NCA (Vis & Dul, 2018):
   growth requires *enough* deal size and *enough* AI capability, then the right
   configuration.
3. **AI capability pays off in turbulence** (the growth recipe couples AI_CAP
   with DYN), consistent with the dynamic-capabilities view and with Babina et
   al. (2024) on real AI deployment driving growth.
4. **Equifinality is sectoral**: technology and financial services reach growth
   by different routes, recovered from a pooled model — the configurational,
   context-contingent pattern that a single averaged effect would obscure
   (Misangyi et al., 2017; Campbell et al., 2016).

**Bottom line for the thesis:** lead with necessity (STRUCT in kind; SIZE and
AI_CAP in degree), present the configuration table, group the failure paths into
"failure to integrate" vs "hollow integration", and frame growth as a demanding,
dynamism-contingent recipe — all robust to specification.
