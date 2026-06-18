# =============================================================================
# 01_data_prep.R  --  Merge the raw source files into one analysis dataset
# =============================================================================
# The thesis data arrives as six separate files. This script joins them into a
# single deal-level table (one row per M&A deal) containing the outcome and the
# four causal conditions, then writes data/analysis_data.csv.
#
#   Deal-level files (keyed by Deal_ID):
#     - CULT_by_deal.csv      -> CULT_calibrated     (already fuzzy 0..1)
#     - STRUCT_by_deal.csv    -> STRUCT_calibrated   (already fuzzy 0..1)
#     - DYN_by_deal.csv       -> DYN_raw_combined    (raw, to be calibrated)
#     - Outcome_Size.csv      -> IAG_Primary_2y      (raw outcome) + Ticker
#   Firm-level file (keyed by ticker), joined to deals via the acquiror Ticker:
#     - AI_CAP_composite.csv  -> AI_CAP              (raw z-score, to calibrate)
#
#   AIS_a_component.csv is an upstream component already folded into AI_CAP and
#   is retained only for provenance; it is not used in the merge.
# =============================================================================

suppressWarnings(suppressMessages({
  # base R only -- no external packages needed for data prep
}))

prepare_analysis_data <- function(config) {

  rd <- function(name) {
    path <- file.path("data", "raw", name)
    if (!file.exists(path)) stop("Missing raw file: ", path)
    read.csv(path, stringsAsFactors = FALSE,
             sep = config$sep, dec = config$decimal, check.names = TRUE)
  }

  cult   <- rd("CULT_by_deal.csv")
  struct <- rd("STRUCT_by_deal.csv")
  dyn    <- rd("DYN_by_deal.csv")
  out    <- rd("Outcome_Size.csv")
  aicap  <- rd("AI_CAP_composite.csv")

  # --- Start from the outcome table (it carries Deal_ID, Ticker, outcome) ----
  df <- out[, c("Deal_ID", "Ticker", "Acquiror_Name",
                "IAG_Primary_2y", "SIZE_rel_DealOverRev", "Deal_Value_M")]

  # --- Join the deal-level conditions on Deal_ID -----------------------------
  df <- merge(df, cult[,   c("Deal_ID", "CULT_calibrated")],   by = "Deal_ID", all.x = TRUE)
  df <- merge(df, struct[, c("Deal_ID", "STRUCT_calibrated")], by = "Deal_ID", all.x = TRUE)
  df <- merge(df, dyn[,    c("Deal_ID", "DYN_raw_combined", "DYN_raw_US_only")],
              by = "Deal_ID", all.x = TRUE)

  # --- Join AI capability on the acquiror ticker -----------------------------
  ai <- aicap[, c("ticker", "AI_CAP")]
  names(ai)[names(ai) == "ticker"] <- "Ticker"
  df <- merge(df, ai, by = "Ticker", all.x = TRUE)

  # --- Tidy and report -------------------------------------------------------
  # Rename to the clean names used throughout the pipeline.
  df$CULT  <- df$CULT_calibrated
  df$STRUCT <- df$STRUCT_calibrated
  df$OUT   <- df$IAG_Primary_2y
  df$SIZE  <- df$SIZE_rel_DealOverRev

  # Industry dynamism has two source series: US-only aggregates (the thesis's
  # primary measure) and a combined US+European aggregate (a robustness
  # variant). config$dyn_source selects which one feeds DYN; default combined
  # for backward compatibility.
  dyn_col <- if (identical(config$dyn_source, "US_only"))
    "DYN_raw_US_only" else "DYN_raw_combined"
  df$DYN <- df[[dyn_col]]

  keep <- c("Deal_ID", "Ticker", "Acquiror_Name",
            "AI_CAP", "CULT", "STRUCT", "DYN", "SIZE", "OUT")
  df <- df[, keep]

  n_total <- nrow(df)
  # Completeness is judged on the conditions actually used in this run.
  core    <- c(config$conditions, config$outcome)
  complete <- df[stats::complete.cases(df[, core]), ]
  n_complete <- nrow(complete)

  cat(sprintf("Data prep: %d deals merged; %d complete on outcome + %d conditions (%s); DYN source = %s.\n",
              n_total, n_complete, length(config$conditions),
              paste(config$conditions, collapse = ", "), dyn_col))
  missing_report <- sapply(df[, core], function(x) sum(is.na(x)))
  cat("Missing per core variable:\n"); print(missing_report)

  dir.create("data", showWarnings = FALSE)
  data_file <- if (!is.null(config$data_file)) config$data_file else "data/analysis_data.csv"
  all_file  <- sub("\\.csv$", "_all.csv", data_file)
  write.csv(df,       all_file,  row.names = FALSE)
  write.csv(complete, data_file, row.names = FALSE)
  cat(sprintf("Wrote %s (complete cases) and %s (all).\n\n", data_file, all_file))

  invisible(complete)
}
