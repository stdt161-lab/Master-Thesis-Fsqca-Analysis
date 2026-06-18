# =============================================================================
# 06_sensitivity.R  --  Robustness / sensitivity analysis (stress test)
# =============================================================================
# fsQCA results depend on three analyst choices: the raw-consistency threshold
# (incl.cut), the frequency threshold (n.cut), and the calibration anchors.
# This module re-runs the WHOLE sufficiency analysis across a grid of those
# choices and reports, for each setting:
#   * the intermediate-solution paths (the configurations recovered)
#   * the overall solution consistency and coverage
#   * how much each result differs from the baseline solution (robustness)
#
# Two complementary stress tests are produced:
#   1. Threshold sensitivity : grid over incl.cut x n.cut
#   2. Calibration sensitivity: shift every crossover anchor by a fraction of
#                               its (full_in - crossover) span
# Outputs: tidy data frames + a robustness heatmap figure.
# =============================================================================

suppressWarnings(suppressMessages({
  library(QCA)
  library(ggplot2)
}))

# Overall consistency/coverage of a solution via the fuzzy-OR of its paths.
.overall_fit <- function(sol, outcome_vec) {
  if (is.null(sol$pims) || ncol(sol$pims) == 0)
    return(c(consistency = NA, coverage = NA, n_paths = 0))
  sm <- apply(sol$pims, 1, max)
  pf <- QCA::pof(sm, outcome_vec, relation = "sufficiency")$incl.cov
  c(consistency = unname(pf$inclS[1]),
    coverage    = unname(pf$covS[1]),
    n_paths     = ncol(sol$pims))
}

# Canonical string of a solution's paths (sorted) for comparison across runs.
.solution_string <- function(sol) {
  terms <- tryCatch(sol$solution[[1]], error = function(e) NA)
  if (length(terms) == 0 || all(is.na(terms))) return("<none>")
  paste(sort(terms), collapse = " + ")
}

# Jaccard similarity of two path sets (1 = identical, 0 = disjoint).
.path_jaccard <- function(a, b) {
  if (a == "<none>" || b == "<none>") return(NA_real_)
  A <- strsplit(a, " \\+ ")[[1]]; B <- strsplit(b, " \\+ ")[[1]]
  length(intersect(A, B)) / length(union(A, B))
}

# Try to minimise; return NULL gracefully if a setting explains nothing.
.safe_intermediate <- function(cal, config, incl_cut, n_cut, outcome = config$outcome) {
  tt <- tryCatch(
    QCA::truthTable(cal, outcome = outcome, conditions = config$conditions,
                    incl.cut = incl_cut, pri.cut = config$pri_cut, n.cut = n_cut,
                    sort.by = "OUT, n", complete = FALSE),
    error = function(e) NULL)
  if (is.null(tt)) return(NULL)
  tryCatch(
    QCA::minimize(tt, include = "?", dir.exp = config$directional_expectations,
                  details = TRUE),
    error = function(e) NULL)
}

# ----------------------------------------------------------------------------
# 1. Threshold sensitivity: grid over incl.cut x n.cut
# ----------------------------------------------------------------------------
sensitivity_thresholds <- function(cal, config) {
  outcome_vec <- cal[[config$outcome]]
  baseline <- .safe_intermediate(cal, config, config$incl_cut, config$n_cut)
  base_str <- if (is.null(baseline)) "<none>" else .solution_string(baseline)

  grid <- expand.grid(incl_cut = config$sensitivity$incl_cut_range,
                      n_cut    = config$sensitivity$n_cut_range,
                      KEEP.OUT.ATTRS = FALSE)
  res <- lapply(seq_len(nrow(grid)), function(i) {
    ic <- grid$incl_cut[i]; nc <- grid$n_cut[i]
    sol <- .safe_intermediate(cal, config, ic, nc)
    if (is.null(sol)) {
      data.frame(incl_cut = ic, n_cut = nc, n_paths = 0,
                 consistency = NA, coverage = NA,
                 solution = "<none>", jaccard_vs_baseline = NA,
                 identical_to_baseline = FALSE, stringsAsFactors = FALSE)
    } else {
      fit <- .overall_fit(sol, outcome_vec)
      sstr <- .solution_string(sol)
      data.frame(incl_cut = ic, n_cut = nc, n_paths = unname(fit["n_paths"]),
                 consistency = round(unname(fit["consistency"]), 3),
                 coverage    = round(unname(fit["coverage"]), 3),
                 solution    = sstr,
                 jaccard_vs_baseline = round(.path_jaccard(sstr, base_str), 3),
                 identical_to_baseline = identical(sstr, base_str),
                 stringsAsFactors = FALSE)
    }
  })
  out <- do.call(rbind, res)
  attr(out, "baseline") <- base_str
  out
}

# ----------------------------------------------------------------------------
# 2. Calibration sensitivity: shift crossover anchors of the raw variables
# ----------------------------------------------------------------------------
# For each shift s in config$sensitivity$crossover_shifts, every raw variable's
# crossover is moved by s * (full_in - crossover), then the data is recalibrated
# and the baseline analysis re-run. Pre-calibrated variables are untouched.
sensitivity_calibration <- function(data, config) {
  shifts <- config$sensitivity$crossover_shifts
  base_anchors <- config$anchors

  baseline_cal <- calibrate_data(data, config, anchors = base_anchors)
  base_sol <- .safe_intermediate(baseline_cal, config, config$incl_cut, config$n_cut)
  base_str <- if (is.null(base_sol)) "<none>" else .solution_string(base_sol)

  res <- lapply(shifts, function(s) {
    anchors <- base_anchors
    for (v in names(anchors)) {
      a <- anchors[[v]]
      span <- a["full_in"] - a["crossover"]
      a["crossover"] <- a["crossover"] + s * span
      anchors[[v]] <- a
    }
    cal <- calibrate_data(data, config, anchors = anchors)
    sol <- .safe_intermediate(cal, config, config$incl_cut, config$n_cut)
    outcome_vec <- cal[[config$outcome]]
    if (is.null(sol)) {
      data.frame(crossover_shift = s, n_paths = 0, consistency = NA,
                 coverage = NA, solution = "<none>",
                 jaccard_vs_baseline = NA, identical_to_baseline = FALSE,
                 stringsAsFactors = FALSE)
    } else {
      fit <- .overall_fit(sol, outcome_vec); sstr <- .solution_string(sol)
      data.frame(crossover_shift = s, n_paths = unname(fit["n_paths"]),
                 consistency = round(unname(fit["consistency"]), 3),
                 coverage    = round(unname(fit["coverage"]), 3),
                 solution    = sstr,
                 jaccard_vs_baseline = round(.path_jaccard(sstr, base_str), 3),
                 identical_to_baseline = identical(sstr, base_str),
                 stringsAsFactors = FALSE)
    }
  })
  out <- do.call(rbind, res)
  attr(out, "baseline") <- base_str
  out
}

# ----------------------------------------------------------------------------
# Robustness heatmap: consistency across the incl.cut x n.cut grid, annotated
# with how many paths and whether the solution matches baseline.
# ----------------------------------------------------------------------------
plot_robustness_heatmap <- function(thr_tbl, config) {
  df <- thr_tbl
  df$label <- ifelse(is.na(df$consistency), "none",
                     sprintf("%.2f\n(%d paths)%s",
                             df$consistency, df$n_paths,
                             ifelse(df$identical_to_baseline, "*", "")))
  p <- ggplot(df, aes(x = factor(incl_cut), y = factor(n_cut),
                      fill = consistency)) +
    geom_tile(color = "white") +
    geom_text(aes(label = label), size = 3) +
    scale_fill_gradient(low = "#fee8c8", high = "#e34a33", na.value = "grey85",
                        limits = c(0.6, 1)) +
    labs(title = "Threshold robustness of the intermediate solution",
         subtitle = "Overall consistency by raw-consistency cut x frequency cut. * = same paths as baseline.",
         x = "Raw consistency cut (incl.cut)", y = "Frequency cut (n.cut)",
         fill = "Solution\nconsistency") +
    theme_minimal(base_size = 12)
  ggsave(file.path(config$fig_dir, "F_robustness_thresholds.png"),
         p, width = 9, height = 5, dpi = config$fig_dpi)
}

run_sensitivity <- function(data, cal, config) {
  dir.create(config$fig_dir, recursive = TRUE, showWarnings = FALSE)
  thr <- sensitivity_thresholds(cal, config)
  cal_sens <- sensitivity_calibration(data, config)
  plot_robustness_heatmap(thr, config)
  list(thresholds = thr, calibration = cal_sens)
}
