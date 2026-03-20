#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

VERSION="${1:-}"
OUTPUT_FILE="${2:-}"

if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <version-tag> [output-file]"
  exit 1
fi

if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="reports/release/changelog-${VERSION}.md"
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

DATE="$(date -u +%F)"
PREVIOUS_TAG="$(git tag --list 'v*' --sort=-creatordate | grep -Fxv "$VERSION" | head -n1 || true)"

if [[ -n "$PREVIOUS_TAG" ]]; then
  RANGE="${PREVIOUS_TAG}..HEAD"
  RANGE_LABEL="${PREVIOUS_TAG}..HEAD"
else
  RANGE="HEAD"
  RANGE_LABEL="initial-history"
fi

COMMITS="$(git log --no-merges --pretty='- %h %s' "$RANGE")"
if [[ -z "$COMMITS" ]]; then
  COMMITS="- No commits found"
fi

cat > "$OUTPUT_FILE" <<EOF
# Changelog Draft for ${VERSION}

- Generated at: ${DATE}
- Git range: ${RANGE_LABEL}
- Revision: $(git rev-parse --short HEAD)

## [${VERSION}] - ${DATE}

### Highlights

- Review the commit list below and promote the user-visible items into CHANGELOG.md.

### Commits

${COMMITS}
EOF

echo "Changelog draft written to $OUTPUT_FILE"
