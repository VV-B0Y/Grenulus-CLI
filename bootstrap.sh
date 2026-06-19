#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║              DRONECOIL BOOTSTRAP — one-command install              ║
# ║                                                                  ║
# ║   curl -fsSL https://raw.githubusercontent.com/the-priest/dronecoil/main/bootstrap.sh | bash
# ║                                                                  ║
# ║   Clones (or updates) the repo, then runs install.sh.            ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

REPO_URL="${DRONECOIL_REPO:-https://github.com/the-priest/dronecoil.git}"
BRANCH="${DRONECOIL_BRANCH:-main}"
DEST="${DRONECOIL_HOME:-$HOME/dronecoil}"
INSTALL_ARGS=("$@")

# ── colours ────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    MAG=$'\033[35m'; GRN=$'\033[32m'; YEL=$'\033[33m'
    RED=$'\033[31m'; DIM=$'\033[90m'; RST=$'\033[0m'
else
    MAG= GRN= YEL= RED= DIM= RST=
fi
err() { printf '%s\n' "${RED}[x]${RST} $*" >&2; exit 1; }

cat <<EOF
${MAG}
  ┌─ DRONECOIL bootstrap ──────────────────────────────────┐
  │  repo:   ${REPO_URL}
  │  branch: ${BRANCH}
  │  dest:   ${DEST}
  └─────────────────────────────────────────────────────┘${RST}
EOF

# ── 1. ensure git ──────────────────────────────────────────────────
if ! command -v git >/dev/null 2>&1; then
    echo "${YEL}[!]${RST} git missing — installing"
    if command -v apt-get >/dev/null 2>&1; then
        if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
            sudo apt-get update -qq && sudo apt-get install -y git
        else
            apt-get update -qq && apt-get install -y git
        fi
    else
        err "git not installed and apt-get unavailable — install git manually"
    fi
fi

# ── 2. clone or update ─────────────────────────────────────────────
if [[ -d "$DEST/.git" ]]; then
    echo "${GRN}[ok]${RST} repo exists — pulling latest"
    git -C "$DEST" fetch --quiet origin "$BRANCH"
    git -C "$DEST" reset --hard "origin/$BRANCH" --quiet
else
    if [[ -e "$DEST" ]]; then
        err "$DEST exists and isn't a git checkout — move it or set DRONECOIL_HOME"
    fi
    echo "${GRN}[ok]${RST} cloning $REPO_URL → $DEST"
    git clone --depth=1 --branch "$BRANCH" --quiet "$REPO_URL" "$DEST"
fi

# ── 3. run installer ───────────────────────────────────────────────
echo "${GRN}[ok]${RST} handing off to install.sh"
echo ""
cd "$DEST"
chmod +x install.sh dronecoil.py dronecoil_gui.py dronecoil-gui 2>/dev/null || true
exec bash install.sh "${INSTALL_ARGS[@]}"
