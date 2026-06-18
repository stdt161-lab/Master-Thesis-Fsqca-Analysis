# =============================================================================
# 04_sufficiency.R  --  Truth table + sufficiency (the configurational solutions)
# =============================================================================
# Builds the truth table from the calibrated data and minimises it into the
# three standard QCA solution types:
#   * complex (conservative): no logical remainders used
#   * parsimonious: all remainders used freely
#   * intermediate: only "easy" remainders consistent with directional expectations
# Works for both the outcome and its negation.
# =============================================================================

suppressWarnings(suppressMessages(library(QCA)))

# Build a truth table for `outcome` ("OUT" or "~OUT" for negation).
build_truth_table <- function(cal, config, outcome = config$outcome,
                              incl_cut = config$incl_cut,
                              n_cut    = config$n_cut,
                              pri_cut  = config$pri_cut) {
  QCA::truthTable(
    data       = cal,
    outcome    = outcome,
    conditions = config$conditions,
    incl.cut   = incl_cut,
    pri.cut    = pri_cut,
    n.cut      = n_cut,
    sort.by    = "OUT, n",
    complete   = FALSE,
    show.cases = TRUE
  )
}

# Minimise a truth table into all three solution types.
minimise_all <- function(tt, config, negate = FALSE) {
  dir <- config$directional_expectations

  complex <- QCA::minimize(tt, details = TRUE, show.cases = TRUE)
  parsim  <- QCA::minimize(tt, include = "?", details = TRUE, show.cases = TRUE)
  interm  <- QCA::minimize(tt, include = "?", dir.exp = dir,
                           details = TRUE, show.cases = TRUE)

  list(complex = complex, parsimonious = parsim, intermediate = interm)
}

# Convenience: tidy the solution terms + fit measures into a data frame.
solution_summary <- function(sol) {
  ic <- sol$IC$overall$sol.incl.cov           # may be NULL in some versions
  terms <- tryCatch(sol$solution[[1]], error = function(e) NA)
  pims  <- tryCatch(sol$IC$incl.cov, error = function(e) NULL)
  list(
    terms    = terms,
    fit      = pims,             # per-term consistency / raw & unique coverage
    overall  = sol$IC$overall    # overall solution consistency / coverage
  )
}

run_sufficiency <- function(cal, config) {
  res <- list()

  tt_pos <- build_truth_table(cal, config, outcome = config$outcome)
  res$truth_table <- tt_pos
  res$solutions   <- minimise_all(tt_pos, config)

  if (isTRUE(config$analyse_negation)) {
    neg_out <- paste0("~", config$outcome)
    tt_neg  <- build_truth_table(cal, config, outcome = neg_out)
    res$truth_table_neg <- tt_neg
    res$solutions_neg   <- minimise_all(tt_neg, config, negate = TRUE)
  }
  res
}
