# =============================================================================
# config_methods.R  --  CHAPTER-ALIGNED configuration (faithful to Chapter 3)
# =============================================================================
# This config implements the analysis exactly as the Methods chapter specifies,
# for side-by-side comparison with the current 4-condition config.R. Differences
# from config.R are flagged with [ALIGNED]:
#   [ALIGNED] FIVE conditions, adding relative deal size (SIZE)  -> 2^5 = 32 rows
#   [ALIGNED] DYN drawn from the US-only aggregates (primary measure)
#   [ALIGNED] continuous conditions + outcome calibrated by the DIRECT method on
#             empirical percentiles (p25/p50/p75; p10/p50/p75 for DYN)
#   [ALIGNED] sensitivity consistency thresholds 0.75 / 0.80 / 0.85
# Everything is written to output_methods/ so it never clobbers output/.
# =============================================================================

config <- list(

  # ---------------------------------------------------------------------------
  # 1. DATA
  # ---------------------------------------------------------------------------
  data_file = "data/analysis_data_methods.csv",
  sep       = ",",
  decimal   = ".",
  id_col    = "Deal_ID",
  dyn_source = "US_only",                  # [ALIGNED] primary DYN measure

  # ---------------------------------------------------------------------------
  # 2. OUTCOME AND CONDITIONS
  # ---------------------------------------------------------------------------
  outcome    = "OUT",                              # = GROWTH (IAG_Primary_2y)
  conditions = c("AI_CAP", "CULT", "STRUCT", "SIZE", "DYN"),   # [ALIGNED] +SIZE

  labels = c(
    AI_CAP = "AI capability",
    CULT   = "Cultural integration effort",
    STRUCT = "Structural integration",
    SIZE   = "Relative deal size",
    DYN    = "Industry dynamism",
    OUT    = "Industry-adjusted growth"
  ),

  # ---------------------------------------------------------------------------
  # 3. CALIBRATION
  # ---------------------------------------------------------------------------
  # STRUCT and CULT arrive theoretically calibrated (0.33 / 0.67 / 0.95) and are
  # passed through unchanged.
  pre_calibrated = c("CULT", "STRUCT"),

  # [ALIGNED] Direct method on empirical percentiles, computed from the analytic
  # sample (Ragin, 2008). full_out / crossover / full_in -> fuzzy 0.05/0.50/0.95.
  # AI_CAP, SIZE, OUT use p25/p50/p75. DYN uses p10/p50/p75 because its lower
  # half is concentrated (the 25th and 50th percentiles nearly coincide), so the
  # 10th percentile gives a well-behaved exclusion anchor.
  anchor_pct = list(
    AI_CAP = c(0.25, 0.50, 0.75),
    SIZE   = c(0.25, 0.50, 0.75),
    OUT    = c(0.25, 0.50, 0.75),
    DYN    = c(0.10, 0.50, 0.75)
  ),
  anchors = list(),   # no fixed anchors; all direct-method vars use percentiles

  # ---------------------------------------------------------------------------
  # 4. TRUTH TABLE / SUFFICIENCY PARAMETERS
  # ---------------------------------------------------------------------------
  incl_cut          = 0.75,   # baseline raw-consistency threshold (chapter floor)
  pri_cut           = 0.50,
  n_cut             = 1,
  headline_solution = "intermediate",

  # Theory-based directional expectations for the INTERMEDIATE solution.
  # AI_CAP / CULT / STRUCT: presence expected to contribute to growth
  # (capability, integration effort, integration depth). SIZE and DYN are
  # contextual conditions the chapter expects to shape WHICH recipe works rather
  # than to exert a uniform main effect, so they carry no directional
  # expectation ("-"). Adjust here if your theory section argues a direction.
  directional_expectations = c(AI_CAP = "1", CULT = "1", STRUCT = "1",
                               SIZE = "-", DYN = "-"),

  analyse_negation = TRUE,

  # ---------------------------------------------------------------------------
  # 5. NECESSITY
  # ---------------------------------------------------------------------------
  necessity_consistency_cut = 0.90,
  necessity_coverage_cut    = 0.50,
  run_nca                   = TRUE,   # [ALIGNED] also run Necessary Condition Analysis

  # ---------------------------------------------------------------------------
  # 6. SENSITIVITY / ROBUSTNESS RANGES
  # ---------------------------------------------------------------------------
  sensitivity = list(
    incl_cut_range   = c(0.75, 0.80, 0.85),   # [ALIGNED] chapter thresholds
    n_cut_range      = c(1, 2, 3),
    crossover_shifts = c(-0.5, 0, 0.5)
  ),

  # ---------------------------------------------------------------------------
  # 7. OUTPUT  (separate tree so it never overwrites the 4-condition results)
  # ---------------------------------------------------------------------------
  output_dir = "output_methods",
  fig_dir    = "output_methods/figures",
  tab_dir    = "output_methods/tables",
  fig_dpi    = 300,
  seed       = 1234
)
