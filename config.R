# =============================================================================
# config.R  --  Central configuration for the fsQCA analysis
# =============================================================================
# This is the ONLY file you normally need to edit. Everything downstream
# (calibration, truth table, sufficiency, graphs, sensitivity) reads from the
# `config` object defined here.
#
# The defaults below are filled in for THIS thesis dataset:
#   Outcome    : industry-adjusted revenue growth 2y after the deal (IAG_Primary_2y)
#   Conditions : AI capability (AI_CAP), cultural fit (CULT),
#                integration structure (STRUCT), environmental dynamism (DYN)
# Read the comments on each block before changing anything for your write-up.
# =============================================================================

config <- list(

  # ---------------------------------------------------------------------------
  # 1. DATA
  # ---------------------------------------------------------------------------
  data_file = "data/analysis_data.csv",   # produced by R/01_data_prep.R
  sep       = ",",
  decimal   = ".",
  id_col    = "Deal_ID",                   # case identifier
  dyn_source = "combined",                 # DYN series: "combined" (US+EU) or "US_only"

  # ---------------------------------------------------------------------------
  # 2. OUTCOME AND CONDITIONS  (clean names created in 01_data_prep.R)
  # ---------------------------------------------------------------------------
  outcome    = "OUT",                              # = IAG_Primary_2y
  conditions = c("AI_CAP", "CULT", "STRUCT", "DYN"),

  # Human-readable labels used in figures and tables.
  labels = c(
    AI_CAP = "AI capability",
    CULT   = "Cultural fit",
    STRUCT = "Integration structure",
    DYN    = "Environmental dynamism",
    OUT    = "Industry-adjusted growth"
  ),

  # ---------------------------------------------------------------------------
  # 3. CALIBRATION
  # ---------------------------------------------------------------------------
  # CULT and STRUCT arrive ALREADY calibrated (fuzzy 0..1) from the source
  # workbooks, so they are passed through unchanged. AI_CAP, DYN and the
  # OUTCOME are raw and are calibrated with the direct method below.
  #
  # `pre_calibrated` lists variables that are already fuzzy and must NOT be
  # re-calibrated.
  pre_calibrated = c("CULT", "STRUCT"),

  # Direct-method anchors for the raw variables:
  #   full_out  -> fuzzy 0.05 (full non-membership)
  #   crossover -> fuzzy 0.50 (point of maximum ambiguity)
  #   full_in   -> fuzzy 0.95 (full membership)
  #
  # AI_CAP is a sector-standardised z-score, so theory-driven anchors at
  # -1 / 0 / +1 SD are natural and transparent.
  # DYN is a small, right-skewed industry-level measure; anchors are set at the
  # sample 10th / 50th / 90th percentiles of the complete cases.
  # OUT is industry-adjusted growth: the crossover sits at 0 (matching the
  # industry benchmark), with full membership/ non-membership at the 90th/10th
  # percentiles. Adjust these to your theoretical justification in the thesis.
  # NOTE on DYN: it is an industry-level measure with only ~13 distinct values,
  # and its modal value (0.000340) sits exactly at the median. Placing the
  # crossover there would strand ~28% of cases at fuzzy 0.5 (which fsQCA cannot
  # use). The crossover is therefore set in the empirical gap between the low
  # cluster (<=0.000340) and the high cluster (>=0.000550), separating
  # low- from high-dynamism industries without any case landing on 0.5.
  # NOTE on OUT: the crossover is just above 0 (the industry benchmark) so the
  # handful of exactly-zero-growth deals do not land on fuzzy 0.5.
  anchors = list(
    AI_CAP = c(full_out = -1.000000, crossover =  0.000000, full_in =  1.000000),
    DYN    = c(full_out =  0.000250, crossover =  0.000445, full_in =  0.001500),
    OUT    = c(full_out = -0.143766, crossover =  0.000500, full_in =  0.204935)
  ),

  # ---------------------------------------------------------------------------
  # 4. TRUTH TABLE / SUFFICIENCY PARAMETERS
  # ---------------------------------------------------------------------------
  # NOTE: in this dataset row consistencies cluster tightly between ~0.73 and
  # ~0.81 and PRI values are modest, so sufficiency is weak and the solution is
  # sensitive to this cut. 0.75 is a defensible, commonly used raw-consistency
  # threshold that yields a non-empty solution; the sensitivity analysis
  # (R/06) deliberately stress-tests this choice. Review against your standards.
  incl_cut          = 0.75,   # raw consistency threshold for sufficiency
  pri_cut           = 0.50,   # PRI consistency threshold
  n_cut             = 1,      # minimum cases for a row to count as observed
  headline_solution = "intermediate",  # "complex" | "parsimonious" | "intermediate"

  # Directional expectations for the INTERMEDIATE solution (one per condition).
  # "1" = presence expected to help the outcome, "0" = absence, "-" = either.
  # Hypothesised here: more AI capability, better cultural fit, deeper
  # integration structure, and higher dynamism each favour growth.
  directional_expectations = c(AI_CAP = "1", CULT = "1", STRUCT = "1", DYN = "1"),

  analyse_negation = TRUE,    # also analyse the negated outcome (~OUT)

  # ---------------------------------------------------------------------------
  # 5. NECESSITY
  # ---------------------------------------------------------------------------
  necessity_consistency_cut = 0.90,
  necessity_coverage_cut    = 0.50,
  run_nca                   = TRUE,   # also run Necessary Condition Analysis (in degree)

  # ---------------------------------------------------------------------------
  # 6. SENSITIVITY / ROBUSTNESS RANGES
  # ---------------------------------------------------------------------------
  sensitivity = list(
    incl_cut_range   = c(0.72, 0.75, 0.78, 0.80),   # consistency thresholds
    n_cut_range      = c(1, 2, 3),                   # frequency thresholds
    crossover_shifts = c(-0.5, 0, 0.5)              # fraction of the
                                                     # (full_in - crossover) span
                                                     # by which each calibrated
                                                     # crossover is shifted
  ),

  # ---------------------------------------------------------------------------
  # 7. OUTPUT
  # ---------------------------------------------------------------------------
  output_dir = "output",
  fig_dir    = "output/figures",
  tab_dir    = "output/tables",
  fig_dpi    = 300,
  seed       = 1234
)
