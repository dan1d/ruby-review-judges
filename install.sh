#!/usr/bin/env bash
# Install the three-judge review skills (and optionally the RuboCop cop + CI
# script) into a target Ruby repo.
#
# Usage:
#   ./install.sh /path/to/your-ruby-repo            # skills only
#   ./install.sh /path/to/your-ruby-repo --with-rubocop
set -euo pipefail

TARGET="${1:?usage: install.sh <target-repo> [--with-rubocop]}"
WITH_RUBOCOP="${2:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -d "$TARGET" ] || { echo "not a directory: $TARGET" >&2; exit 1; }

mkdir -p "$TARGET/.claude/skills"
cp -R "$HERE/skills/ruby-code-review" "$HERE/skills/ruby-pr-review" "$HERE/skills/_shared" "$TARGET/.claude/skills/"
echo "installed skills -> $TARGET/.claude/skills/{ruby-code-review,ruby-pr-review,_shared}"

if [ "$WITH_RUBOCOP" = "--with-rubocop" ]; then
  mkdir -p "$TARGET/lib/rubocop/cop/review" "$TARGET/bin"
  cp "$HERE/rubocop/lib/rubocop/cop/review/single_use_trivial_method.rb" "$TARGET/lib/rubocop/cop/review/"
  cp "$HERE/bin/rubocop_diff_check" "$TARGET/bin/"
  chmod +x "$TARGET/bin/rubocop_diff_check"
  echo "installed cop     -> $TARGET/lib/rubocop/cop/review/single_use_trivial_method.rb"
  echo "installed script  -> $TARGET/bin/rubocop_diff_check"
  echo
  echo "Now add the entries from rubocop/rubocop.yml.example to $TARGET/.rubocop.yml"
fi
