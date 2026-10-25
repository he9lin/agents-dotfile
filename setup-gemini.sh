#!/usr/bin/env bash
#
# Wire ~/.agents (AGENTS.md and skills/) into Google Antigravity / Gemini's
# global configuration (~/.gemini/).
#
# Safe to re-run: existing links are refreshed and any real file in the way is
# backed up rather than overwritten.
#
set -euo pipefail

AGENTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANONICAL_RULES="$AGENTS_DIR/AGENTS.md"
CANONICAL_SKILLS="$AGENTS_DIR/skills"

if [[ ! -f "$CANONICAL_RULES" ]]; then
  echo "error: $CANONICAL_RULES not found" >&2
  exit 1
fi

# Replace <target> with a symlink to <source> (backing up any real file).
link() {
  local source="$1" target="$2" dir
  dir="$(dirname "$target")"
  mkdir -p "$dir"

  if [[ -L "$target" ]]; then
    if [[ "$(readlink "$target")" == "$source" ]]; then
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

  ln -s "$source" "$target"
}

# 1. Global rules for Antigravity / Gemini
link "$CANONICAL_RULES" "$HOME/.gemini/GEMINI.md"
link "$CANONICAL_RULES" "$HOME/.gemini/config/rules/AGENTS.md"

# 2. Global skills registration (~/.gemini/config/skills.json)
SKILLS_JSON="$HOME/.gemini/config/skills.json"
mkdir -p "$(dirname "$SKILLS_JSON")"
cat > "$SKILLS_JSON" <<EOF
{
  "entries": [
    { "path": "$CANONICAL_SKILLS" }
  ]
}
EOF
echo "write   $SKILLS_JSON (points to $CANONICAL_SKILLS)"

echo
echo "Done. Restart Antigravity / Gemini session for changes to take effect."
