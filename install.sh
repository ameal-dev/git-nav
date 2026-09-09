#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  install.sh — Symlink git-nav onto your PATH and check for optional tools.
#
#  Usage:
#    ./install.sh                    # installs to ~/.local/bin
#    ./install.sh --prefix DIR       # installs to DIR instead
#    ./install.sh --uninstall        # removes the symlink
#
#  Env override: GIT_NAV_PREFIX=DIR ./install.sh
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

COLOR_RESET="\033[0m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_CYAN="\033[1;36m"
COLOR_RED="\033[1;31m"
COLOR_BOLD="\033[1m"
COLOR_DIM="\033[2m"

# Resolve the repo root from this script's own location, so it works
# regardless of the caller's cwd.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PREFIX="${GIT_NAV_PREFIX:-$HOME/.local/bin}"
UNINSTALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      PREFIX="$2"
      shift 2
      ;;
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    -h|--help)
      echo "Usage: ./install.sh [--prefix DIR] [--uninstall]"
      exit 0
      ;;
    *)
      echo -e "${COLOR_RED}Unknown option: $1${COLOR_RESET}" >&2
      exit 1
      ;;
  esac
done

LINK_TARGET="$PREFIX/git-nav"

if $UNINSTALL; then
  if [[ -L "$LINK_TARGET" ]]; then
    rm -f "$LINK_TARGET"
    echo -e "${COLOR_GREEN}✓ Removed ${LINK_TARGET}${COLOR_RESET}"
  else
    echo -e "${COLOR_YELLOW}Nothing to remove at ${LINK_TARGET}${COLOR_RESET}"
  fi
  exit 0
fi

echo -e "${COLOR_BOLD}Installing git-nav${COLOR_RESET}"
echo ""

# ── Required tools ───────────────────────────────────────────────────────────
missing_required=()
for tool in git bash; do
  command -v "$tool" &>/dev/null || missing_required+=("$tool")
done

if [[ ${#missing_required[@]} -gt 0 ]]; then
  echo -e "${COLOR_RED}Missing required tools: ${missing_required[*]}${COLOR_RESET}" >&2
  exit 1
fi
echo -e "${COLOR_GREEN}✓${COLOR_RESET} git, bash found"

# ── Symlink onto PATH ────────────────────────────────────────────────────────
mkdir -p "$PREFIX"
ln -sfn "$ROOT_DIR/bin/git-nav" "$LINK_TARGET"
echo -e "${COLOR_GREEN}✓${COLOR_RESET} Linked ${COLOR_BOLD}${LINK_TARGET}${COLOR_RESET} → ${ROOT_DIR}/bin/git-nav"

echo ""

# ── Optional tools ───────────────────────────────────────────────────────────
echo -e "${COLOR_BOLD}Optional tools:${COLOR_RESET}"

if command -v delta &>/dev/null; then
  echo -e "${COLOR_GREEN}✓${COLOR_RESET} git-delta found (used by ${COLOR_BOLD}git-nav diff${COLOR_RESET})"
  if ! delta --list-syntax-themes 2>/dev/null | grep -qi "Catppuccin Macchiato"; then
    echo -e "  ${COLOR_YELLOW}git-nav diff's default theme (Catppuccin Macchiato) isn't in your delta's theme list.${COLOR_RESET}"
    echo -e "  ${COLOR_DIM}Pick one from \`delta --list-syntax-themes\` and set:${COLOR_RESET}"
    echo -e "  ${COLOR_DIM}  export GIT_NAV_DIFF_THEME=\"<theme name>\"${COLOR_RESET}"
  fi
else
  echo -e "${COLOR_YELLOW}✗${COLOR_RESET} git-delta not found — ${COLOR_DIM}git-nav diff${COLOR_RESET} will tell you to install it or use --plain"
  echo -e "  ${COLOR_DIM}brew install git-delta${COLOR_RESET}"
fi

if command -v gh &>/dev/null; then
  echo -e "${COLOR_GREEN}✓${COLOR_RESET} gh CLI found (used by ${COLOR_BOLD}git-nav pr${COLOR_RESET} and PR numbers in ${COLOR_BOLD}git-nav status${COLOR_RESET})"
else
  echo -e "${COLOR_YELLOW}✗${COLOR_RESET} gh CLI not found — ${COLOR_DIM}git-nav pr${COLOR_RESET} requires it; ${COLOR_DIM}git-nav status${COLOR_RESET} works without it"
  echo -e "  ${COLOR_DIM}https://cli.github.com${COLOR_RESET}"
fi

if command -v pbcopy &>/dev/null || command -v xclip &>/dev/null || command -v wl-copy &>/dev/null; then
  echo -e "${COLOR_GREEN}✓${COLOR_RESET} clipboard tool found (used by ${COLOR_BOLD}git-nav copy${COLOR_RESET})"
else
  echo -e "${COLOR_YELLOW}✗${COLOR_RESET} no clipboard tool found (pbcopy/xclip/wl-copy) — ${COLOR_DIM}git-nav copy${COLOR_RESET} will warn instead of copying"
fi

echo ""

# ── PATH check ───────────────────────────────────────────────────────────────
case ":$PATH:" in
  *":$PREFIX:"*)
    ;;
  *)
    echo -e "${COLOR_YELLOW}${PREFIX} is not on your PATH.${COLOR_RESET} Add this to your ~/.zshrc or ~/.bashrc:"
    echo ""
    echo -e "  ${COLOR_DIM}export PATH=\"${PREFIX}:\$PATH\"${COLOR_RESET}"
    echo ""
    ;;
esac

# ── Next steps ───────────────────────────────────────────────────────────────
echo -e "${COLOR_BOLD}Next steps:${COLOR_RESET}"
echo -e "  1. ${COLOR_DIM}source ${ROOT_DIR}/share/git-nav.aliases.sh${COLOR_RESET}  (add to your shell rc to keep it)"
echo -e "  2. ${COLOR_CYAN}git-nav tutorial${COLOR_RESET}  — a hands-on walkthrough of every command"
