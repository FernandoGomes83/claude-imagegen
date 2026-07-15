#!/usr/bin/env bash
# Install the imagegen skill into Claude Code by symlinking it into ~/.claude/skills.
# Undo with: rm ~/.claude/skills/imagegen

set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SRC="$REPO_DIR/skills/imagegen"
DEST_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
DEST="$DEST_DIR/imagegen"

info() { printf '  %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

[ -d "$SRC" ] || { printf 'error: %s not found — run this from a full clone of the repo\n' "$SRC" >&2; exit 1; }

mkdir -p "$DEST_DIR"

if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  current=$(readlink "$DEST" 2>/dev/null || echo "")
  if [ "$current" = "$SRC" ]; then
    info "already installed: $DEST"
  else
    printf '%s already exists.\n' "$DEST" >&2
    printf 'Remove it first if you want to replace it:\n  rm -rf "%s"\n' "$DEST" >&2
    exit 1
  fi
else
  ln -s "$SRC" "$DEST"
  info "installed: $DEST -> $SRC"
fi

chmod +x "$SRC/scripts/codex-image.sh" 2>/dev/null || true

echo
if ! command -v codex >/dev/null 2>&1; then
  warn "the 'codex' command was not found in PATH."
  info "Install it, then log in:"
  info "  brew install --cask codex     # or: npm install -g @openai/codex"
  info "  codex login"
  exit 0
fi

info "codex found: $(codex --version 2>/dev/null || echo unknown)"

if codex login status >/dev/null 2>&1; then
  info "codex is logged in."
  echo
  info "Done. Open Claude Code and ask it to generate an image."
else
  warn "codex is installed but not logged in."
  info "Run:  codex login     (opens your browser; needs a paid ChatGPT plan)"
fi
