# =============================================================================
# 08_tables.R  --  Publication-quality results tables (Markdown + LaTeX + CSV)
# =============================================================================
# fsQCA findings are conventionally read off a configuration table (Ragin 2008;
# Fiss 2011). This module builds, for the primary model:
#   * the configuration solution table  (conditions x configurations, in Fiss
#     notation: core/peripheral, present/absent/don't-care, with fit rows)
#   * the calibration justification table (every condition: method + anchors)
#   * the salient-conditions table (necessity in kind + in degree + sufficiency role)
#   * the sector breakdown of each sufficient configuration (tech vs financial)
# Outputs go to <tab_dir> as .md (paste-ready), .tex (booktabs), and .csv.
# Relies on helpers .intermediate_terms() and .parse_literals() from 05_plots.R.
# =============================================================================

# Fiss notation symbols (Unicode; a legend is printed with every table).
.sym <- function(present, core) {
  if (is.na(present)) return("")                 # don't care
  if (present == 1)  return(if (core) "●" else "•")   # ● core / • periph (present)
  if (present == 0)  return(if (core) "⊗" else "⊘")   # ⊗ core / ⊘ periph (absent)
  ""
}
.legend <- paste(
  "Legend: ● core present  • peripheral present",
  "⊗ core absent  ⊘ peripheral absent  (blank) = don't care.",
  "Core = also in the parsimonious solution (Fiss, 2011).")

# Fuzzy AND (min) membership in a conjunctive term, e.g. "AI_CAP*~DYN".
.term_pim <- function(term, cal) {
  lits <- strsplit(term, "\\*")[[1]]
  cols <- lapply(lits, function(l) {
    neg <- startsWith(l, "~"); base <- sub("^~", "", l)
    v <- as.numeric(cal[[base]]); if (neg) 1 - v else v
  })
  apply(do.call(cbind, cols), 1, min)
}

# First model's terms for a (possibly model-ambiguous) solution.
.first_model_terms <- function(sol) {
  pick <- function(ss) if (is.list(ss)) ss[[1]] else ss
  if (!is.null(sol$i.sol) && length(sol$i.sol) >= 1) {
    t <- tryCatch(pick(sol$i.sol[[1]]$solution), error = function(e) NULL)
    if (!is.null(t) && length(t) > 0) return(t)
  }
  tryCatch(pick(sol$solution), error = function(e) NULL)
}

.n_models <- function(sol) {
  max(tryCatch(length(sol$i.sol[[1]]$solution), error = function(e) 1L),
      tryCatch(length(sol$solution), error = function(e) 1L), 1L)
}

# Per-path description with fit computed DIRECTLY from the calibrated data
# (standard fuzzy consistency/coverage), so it is robust to model ambiguity and
# QCA's nested IC layout. `y` is the (possibly negated) calibrated outcome.
.solution_paths <- function(sol, parsim, config, y, cal) {
  terms <- .first_model_terms(sol)
  if (is.null(terms) || length(terms) == 0) return(NULL)
  plit <- .parse_literals(.first_model_terms(parsim))
  core_key <- if (is.null(plit)) character(0) else paste(plit$condition, plit$present)
  ilit <- .parse_literals(terms)

  pim_mat <- vapply(terms, function(t) .term_pim(t, cal), numeric(nrow(cal)))
  if (is.null(dim(pim_mat))) pim_mat <- matrix(pim_mat, ncol = 1)
  sol_or <- apply(pim_mat, 1, max)
  sy <- sum(y)
  cov_all  <- sum(pmin(sol_or, y)) / sy
  incl_all <- sum(pmin(sol_or, y)) / sum(sol_or)

  paths <- lapply(seq_along(terms), function(j) {
    lj <- ilit[ilit$term == j, ]
    states <- setNames(rep(NA_integer_, length(config$conditions)), config$conditions)
    cores  <- setNames(rep(FALSE, length(config$conditions)), config$conditions)
    for (k in seq_len(nrow(lj))) {
      states[lj$condition[k]] <- lj$present[k]
      cores[lj$condition[k]]  <- paste(lj$condition[k], lj$present[k]) %in% core_key
    }
    pim <- pim_mat[, j]
    covU <- if (ncol(pim_mat) == 1) NA_real_ else {
      others <- apply(pim_mat[, -j, drop = FALSE], 1, max)
      cov_all - sum(pmin(others, y)) / sy
    }
    list(expr = terms[j], states = states, cores = cores,
         inclS = sum(pmin(pim, y)) / sum(pim),
         covS  = sum(pmin(pim, y)) / sy, covU = covU, pim = pim)
  })
  list(paths = paths, overall_incl = incl_all, overall_cov = cov_all,
       n_models = .n_models(sol), pim_mat = pim_mat)
}

# ---- Sector arm per case (Technology vs Financial), aligned to the cal rows ---
.case_arm <- function(dat) {
  o <- tryCatch(read.csv(file.path("data", "raw", "DYN_by_deal.csv"),
                         stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(o)) return(rep(NA_character_, nrow(dat)))
  ig <- o$Industry_Group[match(dat$Deal_ID, o$Deal_ID)]
  ifelse(grepl("Software|Communications|Media|Hardware", ig), "Technology", "Financial")
}

# ----------------------------------------------------------------------------
# Build the configuration solution table across OUT and ~OUT.
# ----------------------------------------------------------------------------
build_config_table <- function(suf, config, dat, cal) {
  y <- as.numeric(cal[[config$outcome]])
  blocks <- list()
  blocks$OUT <- .solution_paths(suf$solutions[["intermediate"]],
                                suf$solutions[["parsimonious"]], config, y, cal)
  if (!is.null(suf$solutions_neg))
    blocks$NEGOUT <- .solution_paths(suf$solutions_neg[["intermediate"]],
                                     suf$solutions_neg[["parsimonious"]], config, 1 - y, cal)

  arm <- .case_arm(dat)

  cols <- list(); amb <- c()
  for (bn in names(blocks)) {
    b <- blocks[[bn]]; if (is.null(b)) next
    if (b$n_models > 1) amb <- c(amb, sprintf("%s (%d models)",
                                  ifelse(bn == "OUT", "High growth", "Absence of growth"), b$n_models))
    for (j in seq_along(b$paths)) {
      p <- b$paths[[j]]
      mem <- p$pim > 0.5
      cols[[length(cols) + 1]] <- list(
        outcome = ifelse(bn == "OUT", "High growth", "Absence of growth"),
        name = sprintf("%s%d", ifelse(bn == "OUT", "G", "A"), j),
        states = p$states, cores = p$cores,
        inclS = p$inclS, covS = p$covS, covU = p$covU,
        tech = sum(mem & arm == "Technology", na.rm = TRUE),
        fin  = sum(mem & arm == "Financial",  na.rm = TRUE),
        overall_incl = b$overall_incl, overall_cov = b$overall_cov)
    }
  }
  list(cols = cols, conditions = config$conditions, labels = config$labels,
       ambiguity = amb)
}

# ---- Render the configuration table to Markdown ----------------------------
render_config_md <- function(ct) {
  cn <- vapply(ct$cols, function(c) c$name, "")
  out <- vapply(ct$cols, function(c) c$outcome, "")
  header <- paste0("| Condition | ", paste(cn, collapse = " | "), " |")
  sep    <- paste0("|", paste(rep("---", length(cn) + 1), collapse = "|"), "|")
  subhdr <- paste0("| *Outcome* | ", paste0("*", out, "*", collapse = " | "), " |")
  rows <- vapply(ct$conditions, function(cd) {
    cells <- vapply(ct$cols, function(c) .sym(c$states[[cd]], c$cores[[cd]]), "")
    paste0("| ", ct$labels[[cd]], " | ", paste(cells, collapse = " | "), " |")
  }, "")
  fitrow <- function(lab, f, dig = 2) {
    v <- vapply(ct$cols, function(c) {
      x <- c[[f]]; if (length(x) != 1 || is.na(x)) "–" else formatC(x, format = "f", digits = dig)
    }, "")
    paste0("| **", lab, "** | ", paste(v, collapse = " | "), " |")
  }
  countrow <- function(lab, f) {
    v <- vapply(ct$cols, function(c) { x <- c[[f]]; if (is.na(x)) "–" else as.character(x) }, "")
    paste0("| ", lab, " | ", paste(v, collapse = " | "), " |")
  }
  ambnote <- if (length(ct$ambiguity))
    paste0("*Model ambiguity (first model shown): ",
           paste(ct$ambiguity, collapse = "; "), ".*") else NULL
  c(header, sep, subhdr,
    rows,
    fitrow("Consistency", "inclS"),
    fitrow("Raw coverage", "covS"),
    fitrow("Unique coverage", "covU"),
    countrow("Tech cases (mem>0.5)", "tech"),
    countrow("Financial cases (mem>0.5)", "fin"),
    "", paste0("*", .legend, "*"), ambnote)
}

# ---- Render the configuration table to LaTeX (booktabs) ---------------------
render_config_tex <- function(ct) {
  cn <- vapply(ct$cols, function(c) c$name, "")
  ncol <- length(cn)
  esc <- function(s) gsub("~", "$\\\\sim$", s)
  texsym <- function(present, core) {
    if (is.na(present)) return("")
    if (present == 1) return(if (core) "$\\CIRCLE$" else "$\\bullet$")
    if (present == 0) return(if (core) "$\\otimes$" else "$\\oslash$")
    ""
  }
  lines <- c(
    "% Requires \\usepackage{wasysym} (for \\CIRCLE) and \\usepackage{booktabs}.",
    "\\begin{table}[htbp]\\centering",
    "\\caption{Configurations for high growth and its absence (intermediate solution).}",
    paste0("\\begin{tabular}{l", paste(rep("c", ncol), collapse = ""), "}"),
    "\\toprule",
    paste0("Condition & ", paste(cn, collapse = " & "), " \\\\"),
    "\\midrule")
  for (cd in ct$conditions) {
    cells <- vapply(ct$cols, function(c) texsym(c$states[[cd]], c$cores[[cd]]), "")
    lines <- c(lines, paste0(esc(ct$labels[[cd]]), " & ", paste(cells, collapse = " & "), " \\\\"))
  }
  fit <- function(lab, f, dig = 2) {
    v <- vapply(ct$cols, function(c) { x <- c[[f]]; if (length(x) != 1 || is.na(x)) "--" else formatC(x, format="f", digits=dig) }, "")
    paste0(lab, " & ", paste(v, collapse = " & "), " \\\\")
  }
  lines <- c(lines, "\\midrule",
             fit("Consistency", "inclS"), fit("Raw coverage", "covS"),
             fit("Unique coverage", "covU"),
             "\\bottomrule", "\\end{tabular}",
             "\\\\[2pt]\\footnotesize $\\CIRCLE$ core present, $\\bullet$ peripheral present, $\\otimes$ core absent, $\\oslash$ peripheral absent; blank = don't care.",
             "\\end{table}")
  lines
}

# ----------------------------------------------------------------------------
# Calibration justification table (every condition + the outcome).
# ----------------------------------------------------------------------------
build_calibration_table <- function(dat, config) {
  anc <- resolve_anchors(dat, config)
  meta <- list(
    OUT    = c("Industry-adjusted 2y revenue CAGR", "Direct (percentile)"),
    AI_CAP = c("0.40*AIE_z + 0.60*AIS_z, within-sector", "Direct (percentile)"),
    SIZE   = c("Deal value / acquirer revenue (Y0)", "Direct (percentile)"),
    DYN    = c("Dess-Beard instability index (US)", "Direct (percentile, p10/50/75)"),
    STRUCT = c("Absorption/symbiosis/preservation", "Theoretical (0.95/0.67/0.33)"),
    CULT   = c("Strong/moderate/weak effort", "Theoretical (0.95/0.67/0.33)"))
  vars <- c(config$outcome, config$conditions)
  rows <- lapply(vars, function(v) {
    if (v %in% config$pre_calibrated) {
      anchors <- "0.95 / 0.67 / 0.33"
    } else {
      a <- anc[[v]]
      anchors <- if (is.null(a)) "–" else
        paste(formatC(c(a["full_in"], a["crossover"], a["full_out"]),
                      format = "g", digits = 3), collapse = " / ")
    }
    m <- meta[[v]]; if (is.null(m)) m <- c("–", "–")
    data.frame(Condition = config$labels[[v]], Measure = m[1],
               Calibration = m[2],
               `Anchors (in/cross/out)` = anchors,
               check.names = FALSE, stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

# ----------------------------------------------------------------------------
# Salient-conditions table: necessity in kind + in degree + sufficiency role.
# ----------------------------------------------------------------------------
build_salient_table <- function(nec, nca, suf, config) {
  ck <- setNames(nec$outcome$consistency[match(config$conditions, nec$outcome$condition)],
                 config$conditions)
  nd <- if (!is.null(nca)) setNames(nca$table$d_ce_fdh[match(config$conditions, nca$table$condition)],
                                    config$conditions) else setNames(rep(NA, length(config$conditions)), config$conditions)
  # Count appearances (present) across all sufficient paths (OUT + ~OUT).
  count_present <- function(solset) {
    if (is.null(solset)) return(setNames(rep(0L, length(config$conditions)), config$conditions))
    ext <- .intermediate_terms(solset[["intermediate"]])
    lit <- .parse_literals(ext$terms)
    sapply(config$conditions, function(cd)
      if (is.null(lit)) 0L else sum(lit$condition == cd))
  }
  appear <- count_present(suf$solutions) + count_present(suf$solutions_neg)
  data.frame(
    Condition = vapply(config$conditions, function(c) config$labels[[c]], ""),
    `Necessity in kind (consistency)` = round(ck, 3),
    `Necessity in degree (NCA d)` = round(nd, 3),
    `Appears in # sufficient paths` = as.integer(appear),
    check.names = FALSE, row.names = NULL, stringsAsFactors = FALSE)
}

# ---- Orchestrator ----------------------------------------------------------
build_all_tables <- function(suf, nec, nca, cal, dat, config) {
  td <- config$tab_dir; dir.create(td, recursive = TRUE, showWarnings = FALSE)

  ct <- build_config_table(suf, config, dat, cal)
  writeLines(render_config_md(ct),  file.path(td, "config_solution_table.md"))
  writeLines(render_config_tex(ct), file.path(td, "config_solution_table.tex"))
  # Flat CSV of the configuration table.
  csv <- do.call(rbind, lapply(ct$cols, function(c) {
    s <- sapply(ct$conditions, function(cd) .sym(c$states[[cd]], c$cores[[cd]]))
    data.frame(configuration = c$name, outcome = c$outcome,
               t(setNames(s, ct$conditions)),
               consistency = round(c$inclS, 3), raw_coverage = round(c$covS, 3),
               unique_coverage = round(c$covU, 3), tech_cases = c$tech,
               financial_cases = c$fin, check.names = FALSE)
  }))
  write.csv(csv, file.path(td, "config_solution_table.csv"), row.names = FALSE)

  cal_tab <- build_calibration_table(dat, config)
  write.csv(cal_tab, file.path(td, "calibration_justification.csv"), row.names = FALSE)

  sal <- build_salient_table(nec, nca, suf, config)
  write.csv(sal, file.path(td, "salient_conditions.csv"), row.names = FALSE)

  cat("Tables written to", td, "\n")
  invisible(list(config = ct, calibration = cal_tab, salient = sal))
}
