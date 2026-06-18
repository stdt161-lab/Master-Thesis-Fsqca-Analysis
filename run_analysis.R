# =============================================================================
# run_analysis.R  --  Master script: runs the full fsQCA pipeline end to end
# =============================================================================
# Usage:
#   From the project root, in R / RStudio:   source("run_analysis.R")
#   Or from a terminal:                      Rscript run_analysis.R
#
# Produces:
#   data/analysis_data.csv          merged, complete-case analysis dataset
#   data/calibrated_data.csv        fuzzy-calibrated conditions + outcome
#   output/tables/*.csv             calibration, necessity, sufficiency, sensitivity
#   output/figures/*.png           comparison graphs + robustness heatmap
#   output/report.txt               human-readable summary of all results
# =============================================================================

options(stringsAsFactors = FALSE)

# --- Load configuration and modules -----------------------------------------
# The config file can be overridden (e.g. to run the chapter-aligned
# 5-condition model) via the CONFIG_FILE environment variable; default config.R.
config_file <- Sys.getenv("CONFIG_FILE", unset = "config.R")
source(config_file)
source("R/01_data_prep.R")
source("R/02_calibration.R")
source("R/03_necessity.R")
source("R/04_sufficiency.R")
source("R/05_plots.R")
source("R/06_sensitivity.R")

set.seed(config$seed)
dir.create(config$tab_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(config$fig_dir, recursive = TRUE, showWarnings = FALSE)

# Capture a plain-text report alongside console output.
report_lines <- c()
say <- function(...) {
  line <- paste0(...)
  cat(line, "\n")
  report_lines[[length(report_lines) + 1]] <<- line
}
hr <- function(title) say("\n", strrep("=", 78), "\n", title, "\n", strrep("=", 78))

# ============================================================================
hr("STEP 1  -  DATA PREPARATION")
# ============================================================================
dat <- prepare_analysis_data(config)
say(sprintf("Cases analysed: %d   Conditions: %s   Outcome: %s",
            nrow(dat), paste(config$conditions, collapse = ", "), config$outcome))

# ============================================================================
hr("STEP 2  -  CALIBRATION")
# ============================================================================
cal <- calibrate_data(dat, config)
# Calibrated-data path tracks the config's data_file so each model writes its own
# (e.g. calibrated_data.csv vs calibrated_data_methods.csv) rather than clobbering.
cal_file <- sub("analysis_data", "calibrated_data", config$data_file)
write.csv(cbind(Deal_ID = dat[[config$id_col]], cal), cal_file, row.names = FALSE)
diag <- calibration_diagnostics(cal, config)
write.csv(diag, file.path(config$tab_dir, "calibration_diagnostics.csv"), row.names = FALSE)
say("Calibration diagnostics (prop_at_0.5 must be ~0):")
say(paste(capture.output(print(diag)), collapse = "\n"))

# ============================================================================
hr("STEP 3  -  NECESSITY ANALYSIS")
# ============================================================================
nec <- run_necessity(cal, config)
write.csv(nec$outcome, file.path(config$tab_dir, "necessity_outcome.csv"), row.names = FALSE)
say("Necessary-condition test for the OUTCOME (consistency >= ",
    config$necessity_consistency_cut, " flagged):")
say(paste(capture.output(print(nec$outcome)), collapse = "\n"))
if (!is.null(nec$negated)) {
  write.csv(nec$negated, file.path(config$tab_dir, "necessity_negated.csv"), row.names = FALSE)
  say("\nNecessary-condition test for the NEGATED outcome:")
  say(paste(capture.output(print(nec$negated)), collapse = "\n"))
}

# ============================================================================
hr("STEP 4  -  SUFFICIENCY (TRUTH TABLE + SOLUTIONS)")
# ============================================================================
suf <- run_sufficiency(cal, config)

# Save the truth table.
tt_df <- as.data.frame(suf$truth_table$tt)
write.csv(tt_df, file.path(config$tab_dir, "truth_table_outcome.csv"), row.names = TRUE)
say("Truth table (outcome):")
say(paste(capture.output(print(suf$truth_table)), collapse = "\n"))

# Robustly persist a solution: always save the full printout (txt), plus a
# structured CSV of the per-path fit when it is available. Handles model
# ambiguity (multiple equally-good models), where the top-level IC is NULL.
write_solution <- function(sol, st, tag) {
  txt <- file.path(config$tab_dir, sprintf("solution_%s_%s.txt", st, tag))
  writeLines(capture.output(print(sol)), txt)

  ic <- tryCatch(as.data.frame(sol$IC$incl.cov), error = function(e) NULL)
  if (!is.null(ic) && nrow(ic) > 0) {
    ic$path <- rownames(ic)
    write.csv(ic, file.path(config$tab_dir, sprintf("solution_%s_%s.csv", st, tag)),
              row.names = FALSE)
  } else {
    # Model ambiguity: list each model's paths instead of a single fit table.
    models <- tryCatch(sol$solution, error = function(e) list())
    md <- do.call(rbind, lapply(seq_along(models), function(m)
      data.frame(model = paste0("M", m),
                 paths = paste(models[[m]], collapse = " + "))))
    if (!is.null(md))
      write.csv(md, file.path(config$tab_dir, sprintf("solution_%s_%s.csv", st, tag)),
                row.names = FALSE)
  }
  n_models <- length(tryCatch(sol$solution, error = function(e) list()))
  if (n_models > 1)
    say(sprintf("   [note] %s solution (%s) shows MODEL AMBIGUITY: %d equally-valid models.",
                st, tag, n_models))
}

# Save and report each solution type for the outcome.
for (st in names(suf$solutions)) {
  sol <- suf$solutions[[st]]
  say(sprintf("\n----- %s solution (OUT) -----", toupper(st)))
  say(paste(capture.output(print(sol)), collapse = "\n"))
  write_solution(sol, st, "OUT")
}

# Negated outcome.
if (!is.null(suf$solutions_neg)) {
  for (st in names(suf$solutions_neg)) {
    sol <- suf$solutions_neg[[st]]
    say(sprintf("\n----- %s solution (~OUT) -----", toupper(st)))
    say(paste(capture.output(print(sol)), collapse = "\n"))
    write_solution(sol, st, "NEGOUT")
  }
}

# ============================================================================
hr("STEP 5  -  COMPARISON GRAPHS")
# ============================================================================
make_all_plots(cal, suf, nec, config)
say("Figures saved to ", config$fig_dir)

# ============================================================================
hr("STEP 6  -  SENSITIVITY / ROBUSTNESS")
# ============================================================================
sens <- run_sensitivity(dat, cal, config)
write.csv(sens$thresholds,  file.path(config$tab_dir, "sensitivity_thresholds.csv"), row.names = FALSE)
write.csv(sens$calibration, file.path(config$tab_dir, "sensitivity_calibration.csv"), row.names = FALSE)
say("Threshold sensitivity (baseline paths: ", attr(sens$thresholds, "baseline"), "):")
say(paste(capture.output(print(sens$thresholds)), collapse = "\n"))
say("\nCalibration sensitivity (crossover shifts):")
say(paste(capture.output(print(sens$calibration)), collapse = "\n"))

share_stable <- mean(sens$thresholds$identical_to_baseline, na.rm = TRUE)
say(sprintf("\nRobustness summary: %.0f%% of threshold settings reproduce the exact baseline paths.",
            100 * share_stable))

# ============================================================================
hr("DONE")
# ============================================================================
writeLines(unlist(report_lines), file.path(config$output_dir, "report.txt"))
say("Full report written to ", file.path(config$output_dir, "report.txt"))
