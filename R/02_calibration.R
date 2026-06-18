# =============================================================================
# 02_calibration.R  --  Direct-method calibration of raw measures into fuzzy sets
# =============================================================================
# Turns each raw condition / outcome into a fuzzy-set membership score in [0,1]
# using QCA::calibrate() with the three anchors defined in config.R. Variables
# listed in config$pre_calibrated are already fuzzy and are passed through.
#
# Returns a data frame of calibrated scores (conditions + outcome) and writes
# data/calibrated_data.csv plus a calibration-diagnostics table.
# =============================================================================

suppressWarnings(suppressMessages(library(QCA)))

calibrate_data <- function(data, config, anchors = config$anchors) {

  vars <- c(config$conditions, config$outcome)
  cal  <- data.frame(row.names = seq_len(nrow(data)))

  for (v in vars) {
    if (v %in% config$pre_calibrated) {
      # Already a fuzzy 0..1 set: pass through, but clamp to be safe.
      x <- as.numeric(data[[v]])
      cal[[v]] <- pmin(pmax(x, 0), 1)
    } else {
      a <- anchors[[v]]
      if (is.null(a)) stop("No calibration anchors defined for '", v, "' in config$anchors.")
      cal[[v]] <- QCA::calibrate(
        as.numeric(data[[v]]),
        type       = "fuzzy",
        thresholds = c(a["full_out"], a["crossover"], a["full_in"])
      )
    }
  }

  # Carry the case id through for labelling plots/tables.
  if (!is.na(config$id_col) && config$id_col %in% names(data)) {
    rownames(cal) <- make.unique(as.character(data[[config$id_col]]))
  }
  cal
}

# --- Diagnostics: how well-behaved is each calibrated set? --------------------
calibration_diagnostics <- function(cal, config) {
  diag <- data.frame(
    variable      = names(cal),
    min           = sapply(cal, min),
    mean          = sapply(cal, mean),
    max           = sapply(cal, max),
    # Share of cases sitting essentially "in" / "out" of the set.
    prop_in_0.95  = sapply(cal, function(x) mean(x >= 0.95)),
    prop_out_0.05 = sapply(cal, function(x) mean(x <= 0.05)),
    # Cases exactly at 0.5 are problematic (drop out of the truth table).
    prop_at_0.5   = sapply(cal, function(x) mean(abs(x - 0.5) < 1e-9)),
    row.names     = NULL
  )
  diag[, -1] <- round(diag[, -1], 3)
  diag
}
