#!/bin/bash
# =============================================================================
# SessionStart hook: install R + the QCA stack for the fsQCA analysis.
#
# The remote (Claude Code on the web) container is ephemeral, so R must be
# reinstalled each session. CRAN is blocked by the network policy in this
# environment, so the QCA package and its dependencies are built from the
# package author's GitHub mirrors instead. ggplot2 + admisc come from apt.
#
# Idempotent: if R and QCA already load, it exits immediately.
# Web-only: does nothing in a local environment.
# =============================================================================
set -euo pipefail

# Only run in the remote (web) environment.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  echo "Not a remote session - skipping R setup."
  exit 0
fi

# sudo only if we are not already root.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

log() { echo "[session-start] $*"; }

# --- Fast path: already installed? ------------------------------------------
if command -v Rscript >/dev/null 2>&1 && \
   Rscript -e 'q(status = !all(c("QCA","ggplot2") %in% rownames(installed.packages())))' >/dev/null 2>&1; then
  log "R, QCA and ggplot2 already present - nothing to do."
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive

# --- 1. Base R + apt-provided R packages ------------------------------------
log "Installing R base and apt R packages..."
# Some base images carry third-party PPAs that the network policy blocks (403);
# those failures are unrelated to R, so do not let them abort the hook. The
# Ubuntu archive (where r-base lives) still refreshes successfully.
$SUDO apt-get update -q || log "apt-get update reported errors (likely blocked PPAs) - continuing."
# --no-install-recommends keeps the install lean (ggplot2 otherwise drags in
# the entire r-recommended set - hundreds of packages we do not need).
$SUDO apt-get install -y -q --no-install-recommends r-base-core r-cran-ggplot2

# --- 2. Build the QCA dependency chain from GitHub source -------------------
# QCA (>0.39 admisc) imports admisc, declared, venn. Default branches differ,
# so each download tries main then master.
WORKDIR="$(mktemp -d)"
fetch_pkg() {
  local repo="$1"
  local dest="$WORKDIR/${repo}-src"
  local br
  for br in main master; do
    local url="https://codeload.github.com/dusadrian/${repo}/tar.gz/refs/heads/${br}"
    if curl -fsSL -o "$WORKDIR/${repo}.tar.gz" --max-time 120 "$url" 2>/dev/null; then
      tar xzf "$WORKDIR/${repo}.tar.gz" -C "$WORKDIR"
      # extracted dir is "<repo>-<branch>"; rename it to "<repo>-src"
      rm -rf "$dest"
      mv "$WORKDIR/${repo}-${br}" "$dest"
      log "fetched ${repo} (${br})"
      return 0
    fi
  done
  log "ERROR: could not download ${repo} from GitHub"
  return 1
}

# Remove the too-old apt admisc if present, so the GitHub build is used.
$SUDO apt-get remove -y -q r-cran-admisc >/dev/null 2>&1 || true

for repo in admisc declared venn QCA; do
  fetch_pkg "$repo"
done

# Install in dependency order.
log "installing admisc...";   $SUDO R CMD INSTALL "$WORKDIR/admisc-src"
log "installing declared..."; $SUDO R CMD INSTALL "$WORKDIR/declared-src"
log "installing venn...";     $SUDO R CMD INSTALL "$WORKDIR/venn-src"
log "installing QCA (compiles C - may take a minute)..."; $SUDO R CMD INSTALL "$WORKDIR/QCA-src"

rm -rf "$WORKDIR"

# --- 3. Verify ---------------------------------------------------------------
log "verifying installation..."
Rscript -e 'for (p in c("admisc","declared","venn","QCA","ggplot2")) cat(sprintf("  %-9s %s\n", p, requireNamespace(p, quietly=TRUE)))'
log "R setup complete. Run the analysis with:  Rscript run_analysis.R"
