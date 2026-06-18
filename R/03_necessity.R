# =============================================================================
# 03_necessity.R  --  Analysis of necessary conditions
# =============================================================================
# In QCA, necessity is tested SEPARATELY from sufficiency and BEFORE it.
# A condition X is necessary for outcome Y if Y is a subset of X, i.e.
# consistency(X <- Y) is high (conventionally >= 0.90) with non-trivial
# coverage. We test each condition and its negation, for the outcome and
# (optionally) its negation.
# =============================================================================

suppressWarnings(suppressMessages(library(QCA)))

# Test every condition and ~condition as a potential necessary condition.
necessity_table <- function(cal, outcome_vec, conditions) {
  rows <- list()
  for (cond in conditions) {
    for (neg in c(FALSE, TRUE)) {
      x   <- if (neg) 1 - cal[[cond]] else cal[[cond]]
      lab <- if (neg) paste0("~", cond) else cond
      p   <- QCA::pof(x, outcome_vec, relation = "necessity")
      inc <- p$incl.cov$inclN[1]   # consistency (inclusion) for necessity
      cov <- p$incl.cov$covN[1]    # coverage
      rov <- p$incl.cov$covN[1]    # (kept for clarity; RoN reported below)
      ron <- tryCatch(p$incl.cov$RoN[1], error = function(e) NA_real_)
      rows[[lab]] <- data.frame(
        condition   = lab,
        consistency = round(inc, 3),
        coverage    = round(cov, 3),
        RoN         = round(ron, 3),
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  out <- out[order(-out$consistency), ]
  rownames(out) <- NULL
  out
}

# Flag conditions that pass the necessity thresholds set in config.
flag_necessary <- function(nec_tbl, config) {
  nec_tbl$necessary <- nec_tbl$consistency >= config$necessity_consistency_cut &
                       nec_tbl$coverage    >= config$necessity_coverage_cut
  nec_tbl
}

run_necessity <- function(cal, config) {
  res <- list()
  res$outcome <- flag_necessary(
    necessity_table(cal, cal[[config$outcome]], config$conditions), config)
  if (isTRUE(config$analyse_negation)) {
    res$negated <- flag_necessary(
      necessity_table(cal, 1 - cal[[config$outcome]], config$conditions), config)
  }
  res
}
