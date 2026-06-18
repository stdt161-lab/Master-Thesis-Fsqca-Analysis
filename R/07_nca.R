# =============================================================================
# 07_nca.R  --  Necessary Condition Analysis (NCA, Dul 2016) -- from scratch
# =============================================================================
# The NCA package cannot be installed in this environment (CRAN is blocked), so
# this module implements NCA's core directly. For "condition X is necessary for
# outcome Y" the empty space is the UPPER-LEFT corner (high Y requires high X).
# Two ceiling lines are computed, exactly as in Dul (2016):
#   * CE-FDH : ceiling envelopment, free disposal hull -> a non-decreasing STEP
#              ceiling, f(x) = max{ Y_i : X_i <= x } (all points lie on/below it)
#   * CR-FDH : ceiling regression on the CE-FDH peers -> an OLS line through the
#              points that define the step, clamped to the scope
# The effect size is d = C / S, where S is the scope (observed XY rectangle) and
# C is the empty ceiling zone above the line. d >= 0.10 flags a meaningful
# necessary condition (Dul, 2016). Computed on the RAW (continuous) measures, as
# NCA assesses "necessity in degree along a continuous measure": calibration
# compresses the tails and flattens the ceiling, so it is run pre-calibration.
# This complements the set-theoretic (in-kind) necessity in 03_necessity.R; a
# condition can be necessary in degree without being necessary in kind, and
# reporting both is expected practice (Vis & Dul, 2018).
#
# NOTE: this is an independent implementation; cross-check against the official
# NCA package once it can be installed. The CE-FDH effect size is the primary
# one reported (it is the more conservative, distribution-free ceiling). STRUCT
# and CULT take only three ordinal levels, so their NCA is indicative only — the
# continuous conditions (AI_CAP, SIZE, DYN) are the proper in-degree candidates.
# =============================================================================

suppressWarnings(suppressMessages(library(ggplot2)))

# Numerically integrate the empty area above a ceiling function over the scope.
.ceiling_effect <- function(x, y, ceiling_fun, n_grid = 2000) {
  xmin <- min(x); xmax <- max(x); ymin <- min(y); ymax <- max(y)
  if (xmax <= xmin || ymax <= ymin) return(NA_real_)        # no scope -> undefined
  S  <- (xmax - xmin) * (ymax - ymin)
  gx <- seq(xmin, xmax, length.out = n_grid)
  fy <- pmin(pmax(ceiling_fun(gx), ymin), ymax)             # clamp ceiling to scope
  C  <- mean(ymax - fy) * (xmax - xmin)                      # empty upper-left area
  as.numeric(C / S)
}

# CE-FDH step ceiling: running maximum of Y ordered by X.
.ce_fdh_fun <- function(x, y) {
  ord <- order(x)
  xs <- x[ord]; ys <- cummax(y[ord])
  function(gx) {
    idx <- findInterval(gx, xs)            # last sample with X <= gx
    idx[idx < 1] <- 1
    ys[idx]
  }
}

# CR-FDH peers = the points where the running max increases (the step corners).
.cr_fdh_line <- function(x, y) {
  ord <- order(x)
  xs <- x[ord]; ys <- y[ord]
  rm <- cummax(ys)
  peer <- ys >= rm - 1e-12 & ys == rm     # points achieving the running max
  px <- xs[peer]; py <- ys[peer]
  if (length(unique(px)) < 2) return(NULL)
  b <- stats::cov(px, py) / stats::var(px)
  a <- mean(py) - b * mean(px)
  c(intercept = a, slope = b)
}

# Effect size + ceiling data for a single (X necessary for Y) test.
nca_one <- function(x, y) {
  keep <- is.finite(x) & is.finite(y); x <- x[keep]; y <- y[keep]
  ce_fun <- .ce_fdh_fun(x, y)
  d_ce <- .ceiling_effect(x, y, ce_fun)
  cr <- .cr_fdh_line(x, y)
  d_cr <- if (is.null(cr)) NA_real_ else
    .ceiling_effect(x, y, function(gx) cr["intercept"] + cr["slope"] * gx)
  list(d_ce = d_ce, d_cr = d_cr, cr = cr,
       xmin = min(x), xmax = max(x), ymin = min(y), ymax = max(y))
}

# Full NCA over all conditions against the (raw) outcome. `data` is the raw,
# pre-calibration analysis data frame. The negated outcome is handled by
# reflecting the outcome within its scope (max + min - y) so that "high X
# necessary for the absence of growth" is tested in the same upper-left frame.
run_nca <- function(data, config, outcome = config$outcome, negate_outcome = FALSE) {
  y <- as.numeric(data[[outcome]])
  if (negate_outcome) y <- max(y, na.rm = TRUE) + min(y, na.rm = TRUE) - y
  rows <- list(); plotdat <- list()
  for (cond in config$conditions) {
    x   <- as.numeric(data[[cond]])
    r   <- nca_one(x, y)
    n_lv <- length(unique(x[is.finite(x)]))
    rows[[cond]] <- data.frame(
      condition = cond,
      levels    = n_lv,
      d_ce_fdh  = round(r$d_ce, 3),
      d_cr_fdh  = round(r$d_cr, 3),
      necessary_in_degree =
        ifelse(!is.na(r$d_ce) & r$d_ce >= 0.10, "yes (d>=0.10)", "no"),
      stringsAsFactors = FALSE)
    plotdat[[cond]] <- list(x = x, y = y, fit = r)
  }
  tbl <- do.call(rbind, rows)
  tbl <- tbl[order(-tbl$d_ce_fdh), ]; rownames(tbl) <- NULL
  list(table = tbl, plotdat = plotdat, outcome = outcome, negated = negate_outcome)
}

# Faceted ceiling plot: one panel per condition, points + CE-FDH step + CR-FDH.
plot_nca <- function(nca, config, prefix = "OUT") {
  pd <- nca$plotdat; if (length(pd) == 0) return(invisible(NULL))
  pts <- do.call(rbind, lapply(names(pd), function(cn) {
    data.frame(condition = config$labels[[cn]], x = pd[[cn]]$x, y = pd[[cn]]$y)
  }))
  # CR-FDH line segments + CE-FDH step, per panel.
  crlines <- do.call(rbind, lapply(names(pd), function(cn) {
    f <- pd[[cn]]$fit; if (is.null(f$cr)) return(NULL)
    gx <- seq(f$xmin, f$xmax, length.out = 50)
    gy <- pmin(pmax(f$cr["intercept"] + f$cr["slope"] * gx, f$ymin), f$ymax)
    data.frame(condition = config$labels[[cn]], x = gx, y = gy)
  }))
  steps <- do.call(rbind, lapply(names(pd), function(cn) {
    f <- pd[[cn]]$fit; cf <- .ce_fdh_fun(pd[[cn]]$x, pd[[cn]]$y)
    gx <- seq(f$xmin, f$xmax, length.out = 400)
    data.frame(condition = config$labels[[cn]], x = gx,
               y = pmin(pmax(cf(gx), f$ymin), f$ymax))
  }))
  labs_df <- do.call(rbind, lapply(names(pd), function(cn) {
    f <- pd[[cn]]$fit
    data.frame(condition = config$labels[[cn]], x = f$xmin, y = f$ymax,
               lab = sprintf("d(CE-FDH) = %.2f", f$d_ce))
  }))
  ylab <- paste0(config$labels[[config$outcome]],
                 if (prefix != "OUT") " (reflected: absence)" else "")
  p <- ggplot(pts, aes(x, y)) +
    geom_point(alpha = 0.5, size = 1.6, color = "grey35") +
    geom_line(data = steps, aes(x, y), color = "#2c7fb8", linewidth = 0.7) +
    geom_line(data = crlines, aes(x, y), color = "#e34a33", linewidth = 0.8, linetype = "dashed") +
    geom_label(data = labs_df, aes(x, y, label = lab), hjust = 0, vjust = 1,
               size = 3.4, fontface = "bold", label.size = 0, fill = "white", alpha = 0.7) +
    facet_wrap(~condition, scales = "free_x") +
    labs(title = paste0("NCA ceiling lines for ", prefix,
                        " (", config$labels[[config$outcome]], ")"),
         subtitle = "Raw measures. Blue step = CE-FDH ceiling; red dashed = CR-FDH. Empty upper-left corner = necessity in degree.",
         x = "Condition (raw value)", y = ylab,
         caption = "Effect size d >= 0.10 indicates a meaningful necessary condition (Dul, 2016). STRUCT/CULT are 3-level (indicative).") +
    theme_minimal(base_size = 12) +
    theme(plot.caption = element_text(hjust = 0),
          strip.text = element_text(face = "bold"),
          panel.grid.minor = element_blank())
  ggsave(file.path(config$fig_dir, sprintf("I_nca_ceiling_%s.png", prefix)),
         p, width = 10, height = 6.5, dpi = config$fig_dpi, bg = "white")
}
