# =============================================================================
# 05_plots.R  --  Comparison graphs for the fsQCA analysis
# =============================================================================
# Produces publication-quality figures (300 dpi PNG) saved to output/figures:
#   A. XY plots for each sufficient configuration (path)   -> set relation vs OUT
#   B. XY plots for necessary conditions                    -> X vs OUT
#   C. Bar chart comparing consistency & coverage of paths  -> "best path" view
#   D. Comparison of the three solution types               -> complex/pars/interm
#   E. Truth-table heatmap                                  -> configuration map
# All numbers come straight from the QCA objects so the graphs match the tables.
# =============================================================================

suppressWarnings(suppressMessages({
  library(QCA)
  library(ggplot2)
}))

.png_open <- function(path, w = 7, h = 6, dpi = 300) {
  grDevices::png(path, width = w, height = h, units = "in", res = dpi)
}

# Fuzzy OR over the prime-implicant membership scores = overall solution score.
solution_membership <- function(sol) {
  if (is.null(sol$pims) || ncol(sol$pims) == 0) return(NULL)
  apply(sol$pims, 1, max)
}

# ----------------------------------------------------------------------------
# A. XY plots: each sufficient path vs the outcome (sufficiency = upper triangle)
# ----------------------------------------------------------------------------
plot_sufficiency_xy <- function(sol, outcome_vec, config, prefix = "OUT") {
  pims <- sol$pims
  if (is.null(pims)) return(invisible(NULL))
  for (j in seq_len(ncol(pims))) {
    term <- colnames(pims)[j]
    fname <- file.path(config$fig_dir,
                       sprintf("A_suff_xy_%s_path%d.png", prefix, j))
    .png_open(fname, dpi = config$fig_dpi)
    QCA::XYplot(pims[, j], outcome_vec,
                xlab = paste0("Membership in: ", term),
                ylab = paste0("Membership in outcome (", config$labels[[config$outcome]], ")"),
                main = sprintf("Sufficiency XY plot - %s path %d", prefix, j),
                jitter = TRUE, relation = "sufficiency")
    grDevices::dev.off()
  }
}

# ----------------------------------------------------------------------------
# B. XY plots: candidate necessary conditions vs outcome (necessity = lower tri)
# ----------------------------------------------------------------------------
plot_necessity_xy <- function(cal, config, nec_tbl) {
  nec_conds <- nec_tbl$condition[nec_tbl$consistency >=
                                 config$necessity_consistency_cut]
  if (length(nec_conds) == 0) nec_conds <- nec_tbl$condition[1]  # plot top one
  outcome_vec <- cal[[config$outcome]]
  for (cond in nec_conds) {
    neg <- startsWith(cond, "~")
    base <- sub("^~", "", cond)
    x <- if (neg) 1 - cal[[base]] else cal[[base]]
    fname <- file.path(config$fig_dir,
                       sprintf("B_nec_xy_%s.png", gsub("[^A-Za-z0-9]", "", cond)))
    .png_open(fname, dpi = config$fig_dpi)
    QCA::XYplot(x, outcome_vec,
                xlab = paste0("Membership in: ", cond),
                ylab = paste0("Membership in outcome (", config$labels[[config$outcome]], ")"),
                main = paste0("Necessity XY plot - ", cond),
                jitter = TRUE, relation = "necessity")
    grDevices::dev.off()
  }
}

# ----------------------------------------------------------------------------
# C. Bar chart: per-path consistency, raw & unique coverage ("best path" view)
# ----------------------------------------------------------------------------
plot_path_comparison <- function(sol, config, prefix = "OUT") {
  ic <- as.data.frame(sol$IC$incl.cov)
  if (nrow(ic) == 0) return(invisible(NULL))
  ic$path <- rownames(ic)
  long <- data.frame(
    path   = rep(ic$path, 3),
    metric = rep(c("Consistency (inclS)", "Raw coverage (covS)",
                   "Unique coverage (covU)"), each = nrow(ic)),
    value  = c(ic$inclS, ic$covS, ic$covU)
  )
  p <- ggplot(long, aes(x = path, y = value, fill = metric)) +
    geom_col(position = position_dodge(width = 0.8), width = 0.7) +
    geom_text(aes(label = sprintf("%.2f", value)),
              position = position_dodge(width = 0.8), vjust = -0.3, size = 3) +
    scale_y_continuous(limits = c(0, 1), expand = expansion(mult = c(0, .1))) +
    labs(title = paste0("Configuration comparison - ", prefix),
         subtitle = "Higher consistency = more sufficient; higher coverage = more cases explained",
         x = NULL, y = NULL, fill = NULL) +
    coord_flip() +
    theme_minimal(base_size = 12) +
    theme(legend.position = "top")
  ggsave(file.path(config$fig_dir, sprintf("C_path_comparison_%s.png", prefix)),
         p, width = 9, height = 5, dpi = config$fig_dpi)
}

# ----------------------------------------------------------------------------
# D. Compare the three solution types (complex / parsimonious / intermediate)
#    by overall consistency and coverage. The caller supplies the outcome vec.
# ----------------------------------------------------------------------------
plot_solution_types <- function(solutions, outcome_vec, config, prefix = "OUT") {
  rows <- lapply(names(solutions), function(st) {
    sm <- solution_membership(solutions[[st]]); if (is.null(sm)) return(NULL)
    pf <- QCA::pof(sm, outcome_vec, relation = "sufficiency")$incl.cov
    data.frame(solution = st,
               n_paths = ncol(solutions[[st]]$pims),
               Consistency = round(pf$inclS[1], 3),
               Coverage    = round(pf$covS[1], 3))
  })
  df <- do.call(rbind, rows)
  if (is.null(df)) return(invisible(NULL))
  long <- data.frame(
    solution = rep(df$solution, 2),
    metric   = rep(c("Consistency", "Coverage"), each = nrow(df)),
    value    = c(df$Consistency, df$Coverage),
    npaths   = rep(df$n_paths, 2)
  )
  p <- ggplot(long, aes(x = solution, y = value, fill = metric)) +
    geom_col(position = position_dodge(0.8), width = 0.7) +
    geom_text(aes(label = sprintf("%.2f", value)),
              position = position_dodge(0.8), vjust = -0.3, size = 3.2) +
    scale_y_continuous(limits = c(0, 1), expand = expansion(mult = c(0, .12))) +
    labs(title = paste0("Solution-type comparison - ", prefix),
         subtitle = "Complex / parsimonious / intermediate overall fit",
         x = NULL, y = NULL, fill = NULL) +
    theme_minimal(base_size = 12) + theme(legend.position = "top")
  ggsave(file.path(config$fig_dir, sprintf("D_solution_types_%s.png", prefix)),
         p, width = 8, height = 5, dpi = config$fig_dpi)
  df
}

# ----------------------------------------------------------------------------
# E. Truth-table heatmap: configurations x conditions, coloured by consistency
# ----------------------------------------------------------------------------
plot_truth_table_heatmap <- function(tt, config, prefix = "OUT") {
  tb <- as.data.frame(tt$tt)
  conds <- config$conditions
  # Keep only observed rows (n > 0).
  tb <- tb[as.numeric(as.character(tb$n)) > 0, , drop = FALSE]
  if (nrow(tb) == 0) return(invisible(NULL))
  tb$config_id <- rownames(tb)
  tb$incl <- suppressWarnings(as.numeric(as.character(tb$incl)))
  tb$n    <- suppressWarnings(as.numeric(as.character(tb$n)))
  # Order rows by consistency for readability.
  ord <- order(-tb$incl)
  tb  <- tb[ord, ]
  tb$row <- factor(seq_len(nrow(tb)),
                   labels = sprintf("cfg %s (n=%d, incl=%.2f)",
                                    tb$config_id, tb$n, tb$incl))
  long <- do.call(rbind, lapply(conds, function(cc) {
    data.frame(row = tb$row, condition = cc,
               present = as.numeric(as.character(tb[[cc]])),
               incl = tb$incl)
  }))
  long$present_lab <- ifelse(long$present == 1, "present", "absent")
  p <- ggplot(long, aes(x = condition, y = row, fill = present_lab)) +
    geom_tile(color = "grey80") +
    scale_fill_manual(values = c(present = "#2c7fb8", absent = "#f0f0f0")) +
    labs(title = paste0("Truth table configurations - ", prefix),
         subtitle = "Rows ordered by sufficiency consistency (incl)",
         x = NULL, y = NULL, fill = NULL) +
    theme_minimal(base_size = 11) +
    theme(axis.text.x = element_text(angle = 30, hjust = 1),
          legend.position = "top")
  ggsave(file.path(config$fig_dir, sprintf("E_truthtable_heatmap_%s.png", prefix)),
         p, width = 8, height = max(4, 0.35 * nrow(tb)), dpi = config$fig_dpi)
}

# ----------------------------------------------------------------------------
# Orchestrator for all graphs.
# ----------------------------------------------------------------------------
make_all_plots <- function(cal, suf, nec, config) {
  dir.create(config$fig_dir, recursive = TRUE, showWarnings = FALSE)
  headline <- config$headline_solution
  out_vec  <- cal[[config$outcome]]

  # Outcome present
  plot_sufficiency_xy(suf$solutions[[headline]], out_vec, config, prefix = "OUT")
  plot_necessity_xy(cal, config, nec$outcome)
  plot_path_comparison(suf$solutions[[headline]], config, prefix = "OUT")
  plot_solution_types(suf$solutions, out_vec, config, prefix = "OUT")
  plot_truth_table_heatmap(suf$truth_table, config, prefix = "OUT")

  # Outcome negated
  if (isTRUE(config$analyse_negation) && !is.null(suf$solutions_neg)) {
    neg_vec <- 1 - out_vec
    plot_sufficiency_xy(suf$solutions_neg[[headline]], neg_vec, config, prefix = "~OUT")
    plot_path_comparison(suf$solutions_neg[[headline]], config, prefix = "~OUT")
    plot_solution_types(suf$solutions_neg, neg_vec, config, prefix = "~OUT")
    plot_truth_table_heatmap(suf$truth_table_neg, config, prefix = "~OUT")
  }
  cat("Figures written to", config$fig_dir, "\n")
}
