#!/usr/bin/env bash
#
# Wire this repo's AGENTS.md into the global config of each coding agent, so a
# single file (~/.agents/AGENTS.md) drives opencode, Claude Code, and Cursor.
#
# Safe to re-run: existing links are refreshed and any real file in the way is
# backed up rather than overwritten.
#
set -euo pipefail

AGENTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANONICAL="$AGENTS_DIR/AGENTS.md"

if [[ ! -f "$CANONICAL" ]]; then
  echo "error: $CANONICAL not found" >&2
  exit 1
fi

# Replace <target> with a symlink to the canonical file (backing up any real file).
link() {
  local target="$1" dir
  dir="$(dirname "$target")"
  mkdir -p "$dir"

  if [[ -L "$target" ]]; then
    if [[ "$(readlink "$target")" == "$CANONICAL" ]]; then
      echo "ok      $target (already linked)"
      return
    fi
    echo "relink  $target (was -> $(readlink "$target"))"
    rm "$target"
  elif [[ -e "$target" ]]; then
    local backup="$target.bak.$(date +%Y%m%d%H%M%S)"
    echo "backup  $target -> $backup"
    mv "$target" "$backup"
  else
    echo "link    $target"
  fi

  ln -s "$CANONICAL" "$target"
}

# opencode — global rules auto-discovered at this path
link "$HOME/.config/opencode/AGENTS.md"

# Claude Code — global rules
link "$HOME/.claude/CLAUDE.md"

# Cursor — machine-local user rule that includes the canonical file.
# (Generated; edit ~/.agents/AGENTS.md, not this file.)
CURSOR_RULE="$HOME/.cursor/rules/agent-rules.mdc"
mkdir -p "$(dirname "$CURSOR_RULE")"
cat > "$CURSOR_RULE" <<EOF
---
description: Global agent rules (functional design, planning/review, git, verification)
alwaysApply: true
---

@$CANONICAL
EOF
echo "write   $CURSOR_RULE (includes $CANONICAL)"

echo
echo "Done. Restart opencode for changes to take effect."
