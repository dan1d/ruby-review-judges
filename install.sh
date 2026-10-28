#!/usr/bin/env bash
# Install the planning skill, the four-judge review skills, the judge agents and
# the /plan command — into one repo, or globally for every repo on this machine.
#
# Usage:
#   ./install.sh --global                              # ~/.claude: skills + agents + commands
#   ./install.sh /path/to/repo                         # <repo>/.claude: skills + agents + commands
#   ./install.sh /path/to/repo --with-rubocop          # + custom cop + CI script
#   ./install.sh /path/to/repo --claude-md             # + append the Approach Rule to <repo>/CLAUDE.md
#   flags can be combined: ./install.sh /path/to/repo --with-rubocop --claude-md
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET=""
WITH_RUBOCOP=0
CLAUDE_MD=0
GLOBAL=0

for arg in "$@"; do
  case "$arg" in
    --global) GLOBAL=1 ;;
    --with-rubocop) WITH_RUBOCOP=1 ;;
    --claude-md) CLAUDE_MD=1 ;;
    -h|--help) sed -n 2,10p "$0"; exit 0 ;;
    *) TARGET="$arg" ;;
  esac
done

if [ "$GLOBAL" = 1 ]; then
  DEST="$HOME/.claude"
elif [ -n "$TARGET" ]; then
  [ -d "$TARGET" ] || { echo "not a directory: $TARGET" >&2; exit 1; }
  DEST="$TARGET/.claude"
else
  echo "usage: install.sh --global | install.sh <target-repo> [--with-rubocop] [--claude-md]" >&2
  exit 1
fi

mkdir -p "$DEST/skills" "$DEST/agents" "$DEST/commands"
cp -R "$HERE/skills/ruby-approach-plan" "$HERE/skills/ruby-code-review" "$HERE/skills/ruby-pr-review" "$HERE/skills/_shared" "$DEST/skills/"
cp "$HERE"/agents/*.md "$DEST/agents/"
cp "$HERE"/commands/*.md "$DEST/commands/"
echo "skills   -> $DEST/skills/{ruby-approach-plan,ruby-code-review,ruby-pr-review,_shared}"
echo "agents   -> $DEST/agents/{$(ls "$HERE/agents" | sed 's/\.md$//' | paste -sd, -)}"
echo "commands -> $DEST/commands/{$(ls "$HERE/commands" | sed 's/\.md$//' | paste -sd, -)}"

if [ "$WITH_RUBOCOP" = 1 ] && [ -n "$TARGET" ]; then
  mkdir -p "$TARGET/lib/rubocop/cop/review" "$TARGET/bin"
  cp "$HERE/rubocop/lib/rubocop/cop/review/single_use_trivial_method.rb" "$TARGET/lib/rubocop/cop/review/"
  cp "$HERE/bin/rubocop_diff_check" "$TARGET/bin/"
  chmod +x "$TARGET/bin/rubocop_diff_check"
  echo "cop      -> $TARGET/lib/rubocop/cop/review/single_use_trivial_method.rb"
  echo "script   -> $TARGET/bin/rubocop_diff_check"
  echo "now merge rubocop/rubocop.yml.example into $TARGET/.rubocop.yml"
fi

if [ "$CLAUDE_MD" = 1 ] && [ -n "$TARGET" ]; then
  if grep -q "^## Approach Rule" "$TARGET/CLAUDE.md" 2>/dev/null; then
    echo "CLAUDE.md already has the Approach Rule, left as is"
  else
    { [ -f "$TARGET/CLAUDE.md" ] && printf "\n"; cat "$HERE/templates/CLAUDE.md.snippet"; } >> "$TARGET/CLAUDE.md"
    echo "CLAUDE.md -> appended the Approach Rule"
  fi
fi

echo
echo "Next: point Phase B at your conventions (CONVENTIONS_PATH or docs/conventions/),"
echo "open Claude Code and say: plan <ticket>  |  review this  |  review PR #123"
[ "$GLOBAL" = 1 ] && echo "Agents and commands load at session start: restart Claude Code once."
exit 0
