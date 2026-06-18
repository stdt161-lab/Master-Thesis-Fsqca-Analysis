# =============================================================================
# 05_plots.R  --  Comparison graphs for the fsQCA analysis
# =============================================================================
# Produces publication-quality figures (300 dpi PNG) saved to output/figures:
#   A. XY plots for each sufficient configuration (path)   -> set relation vs OUT
#   B. XY plots for necessary conditions                    -> X vs OUT
#   C. Bar chart comparing consistency & coverage of paths  -> "best path" view
#   D. Comparison of the three solution types               -> complex/pars/interm
#   E. Truth-table heatmap                                  -> configuration map
#   G. Venn diagram of sufficient paths vs the outcome      -> set overlap / coverage
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
# G. Venn diagram: crisp set membership in each sufficient path vs the outcome.
#    A case is counted in a path if its fuzzy membership in that path's
#    prime-implicant score exceeds 0.5, and in the outcome set if its outcome
#    membership exceeds 0.5. The overlaps make coverage and the joint
#    explanatory reach of the configurations visible at a glance.
# ----------------------------------------------------------------------------
plot_solution_venn <- function(sol, outcome_vec, config, prefix = "OUT") {
  if (!requireNamespace("venn", quietly = TRUE)) {
    message("Package 'venn' not available - skipping Venn diagram for ", prefix)
    return(invisible(NULL))
  }
  pims <- sol$pims
  if (is.null(pims) || ncol(pims) == 0) return(invisible(NULL))

  ids   <- seq_len(nrow(pims))
  exprs <- colnames(pims)
  sets  <- list()
  for (j in seq_len(ncol(pims)))
    sets[[ sprintf("Path %d", j) ]] <- ids[pims[, j] > 0.5]

  # Keep the set name short so it does not run off the canvas; the full outcome
  # meaning goes in the subtitle below.
  out_lab <- if (prefix == "OUT") "Outcome" else "~Outcome"
  sets[[out_lab]] <- ids[outcome_vec > 0.5]

  # venn supports up to 7 sets; cap defensively.
  if (length(sets) > 7) sets <- sets[seq_len(7)]

  out_desc <- if (prefix == "OUT")
    config$labels[[config$outcome]]
  else
    paste0("NOT ", config$labels[[config$outcome]])

  fname <- file.path(config$fig_dir, sprintf("G_venn_%s.png", prefix))
  .png_open(fname, w = 8, h = 8, dpi = config$fig_dpi)
  op <- graphics::par(mar = c(7, 3, 4, 3))
  on.exit({ graphics::par(op); grDevices::dev.off() }, add = TRUE)
  venn::venn(sets, ilabels = "counts", zcolor = "style",
             box = FALSE, opacity = 0.4, ggplot = FALSE, cexsn = 1.0, cexil = 1.1)
  graphics::title(
    main = sprintf("Set overlap of sufficient paths and outcome (%s)", prefix))
  # Decode the short set labels and state the outcome / case count beneath the
  # figure, on separate lines so they do not overlap.
  legend_lines <- paste0("Path ", seq_along(exprs), " = ", exprs)
  graphics::mtext(paste(legend_lines, collapse = "      "),
                  side = 1, line = 3.5, cex = 0.85)
  graphics::mtext(sprintf("Outcome = %s.  Counts = cases per region with fuzzy membership > 0.5;  n = %d",
                          out_desc, nrow(pims)),
                  side = 1, line = 5.0, cex = 0.8)
  invisible(sets)
}

# ----------------------------------------------------------------------------
# H. Configuration chart in Fiss (2011) notation -- the canonical fsQCA results
#    figure. Conditions are rows, sufficient paths are columns. A condition that
#    is PRESENT in a path is a filled circle; ABSENT is a crossed circle; a
#    blank means the condition does not appear ("don't care"). A condition is
#    CORE (large symbol) if it also survives in the parsimonious solution, and
#    PERIPHERAL (small symbol) if it appears only in the intermediate solution
#    (Ragin & Fiss, 2008). Per-path consistency and coverage are printed beneath.
# ----------------------------------------------------------------------------
.parse_literals <- function(terms) {
  # Return a data frame: term index, condition, sign (1 present / 0 absent).
  terms <- terms[!is.na(terms) & nzchar(terms)]
  if (length(terms) == 0) return(NULL)
  do.call(rbind, lapply(seq_along(terms), function(i) {
    lits <- strsplit(terms[i], "\\*")[[1]]
    do.call(rbind, lapply(lits, function(l) {
      neg <- startsWith(l, "~")
      data.frame(term = i, condition = sub("^~", "", l),
                 present = ifelse(neg, 0L, 1L), stringsAsFactors = FALSE)
    }))
  }))
}

# The QCA intermediate object stores the reduced (parsimonious) expression at the
# top level; the actual INTERMEDIATE expression and its fit live in $i.sol. Pull
# the intermediate terms and per-path fit from there, falling back gracefully.
.intermediate_terms <- function(sol) {
  if (!is.null(sol$i.sol) && length(sol$i.sol) >= 1) {
    sub <- sol$i.sol[[1]]
    ic  <- tryCatch(as.data.frame(sub$IC$incl.cov), error = function(e) NULL)
    terms <- if (!is.null(ic) && nrow(ic) > 0) rownames(ic) else
      tryCatch(unlist(sub$solution), error = function(e) NULL)
    if (!is.null(terms) && length(terms) > 0) return(list(terms = terms, ic = ic))
  }
  ic <- tryCatch(as.data.frame(sol$IC$incl.cov), error = function(e) NULL)
  terms <- if (!is.null(ic) && nrow(ic) > 0) rownames(ic) else
    tryCatch(sol$solution[[1]], error = function(e) NULL)
  list(terms = terms, ic = ic)
}

plot_config_chart <- function(suf, config, prefix = "OUT") {
  solset <- if (prefix == "OUT") suf$solutions else suf$solutions_neg
  if (is.null(solset)) return(invisible(NULL))
  interm <- solset[["intermediate"]]
  parsim <- solset[["parsimonious"]]

  ext    <- .intermediate_terms(interm)
  iterms <- ext$terms
  ic     <- ext$ic
  if (is.null(iterms) || length(iterms) == 0) return(invisible(NULL))
  ilit <- .parse_literals(iterms)

  # Core literals = those that also appear in the parsimonious solution.
  pterms <- tryCatch(parsim$solution[[1]], error = function(e) character(0))
  plit <- .parse_literals(pterms)
  core_key <- if (is.null(plit)) character(0) else paste(plit$condition, plit$present)

  conds <- config$conditions
  grid <- expand.grid(condition = conds, term = seq_along(iterms),
                      KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  grid <- merge(grid, ilit, by = c("condition", "term"), all.x = TRUE)
  grid$state <- ifelse(is.na(grid$present), "blank",
                 ifelse(grid$present == 1, "present", "absent"))
  grid$core  <- mapply(function(cd, pr) {
    if (is.na(pr)) return(FALSE)
    paste(cd, pr) %in% core_key
  }, grid$condition, grid$present)
  grid$size_lab <- ifelse(grid$core, "core", "peripheral")

  # Column labels carry per-path fit.
  if (!is.null(ic) && nrow(ic) >= length(iterms)) {
    collab <- sprintf("Path %d\ncons %.2f\ncov %.2f",
                      seq_along(iterms), ic$inclS[seq_along(iterms)],
                      ic$covS[seq_along(iterms)])
  } else {
    collab <- sprintf("Path %d", seq_along(iterms))
  }
  grid$term_lab <- factor(grid$term, levels = seq_along(iterms), labels = collab)
  grid$condition <- factor(grid$condition, levels = rev(conds))

  pts <- grid[grid$state != "blank", , drop = FALSE]
  overall <- tryCatch(interm$i.sol[[1]]$IC$sol.incl.cov, error = function(e) NULL)
  if (is.null(overall)) overall <- tryCatch(interm$IC$sol.incl.cov, error = function(e) NULL)
  sub <- if (!is.null(overall) && is.data.frame(overall) && nrow(overall) >= 1)
    sprintf("Intermediate solution: overall consistency %.2f, coverage %.2f",
            overall$inclS[1], overall$covS[1])
  else "Intermediate solution"

  # Present = solid circle (shape 19, colour-driven); Absent = circle-with-cross
  # (shape 13). Symbol size encodes core (large) vs peripheral (small).
  p <- ggplot(pts, aes(x = term_lab, y = condition)) +
    geom_point(aes(shape = state, size = size_lab, color = state)) +
    scale_shape_manual(values = c(present = 19, absent = 13),
                       labels = c(present = "present", absent = "absent (negated)")) +
    scale_size_manual(values = c(core = 9, peripheral = 5),
                      labels = c(core = "core (also in parsimonious)",
                                 peripheral = "peripheral (intermediate only)")) +
    scale_color_manual(values = c(present = "black", absent = "grey25"), guide = "none") +
    scale_y_discrete(drop = FALSE) +
    labs(title = paste0("Sufficient configurations for ", prefix),
         subtitle = sub,
         x = NULL, y = NULL, shape = NULL, size = NULL,
         caption = "Blank cell = condition does not appear in the path (\"don't care\").") +
    theme_minimal(base_size = 12) +
    theme(legend.position = "right",
          panel.grid.minor = element_blank(),
          plot.subtitle = element_text(size = 10),
          plot.caption = element_text(hjust = 0, size = 9),
          plot.margin = margin(10, 12, 10, 14),
          axis.text.x = element_text(size = 9)) +
    guides(size  = guide_legend(order = 1, override.aes = list(shape = 19, color = "black")),
           shape = guide_legend(order = 2, override.aes = list(size = 5, color = "black")))
  ggsave(file.path(config$fig_dir, sprintf("H_config_chart_%s.png", prefix)),
         p, width = max(7, 3.5 + 1.6 * length(iterms)), height = 5, dpi = config$fig_dpi)
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
  plot_solution_venn(suf$solutions[[headline]], out_vec, config, prefix = "OUT")
  plot_config_chart(suf, config, prefix = "OUT")

  # Outcome negated
  if (isTRUE(config$analyse_negation) && !is.null(suf$solutions_neg)) {
    neg_vec <- 1 - out_vec
    plot_sufficiency_xy(suf$solutions_neg[[headline]], neg_vec, config, prefix = "~OUT")
    plot_path_comparison(suf$solutions_neg[[headline]], config, prefix = "~OUT")
    plot_solution_types(suf$solutions_neg, neg_vec, config, prefix = "~OUT")
    plot_truth_table_heatmap(suf$truth_table_neg, config, prefix = "~OUT")
    plot_solution_venn(suf$solutions_neg[[headline]], neg_vec, config, prefix = "~OUT")
    plot_config_chart(suf, config, prefix = "~OUT")
  }
  cat("Figures written to", config$fig_dir, "\n")
}
