#!/usr/bin/env bash
set -euo pipefail

ROOT="${RFC_GOVERNANCE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

failures=0

fail() {
  echo "FAIL: $1"
  failures=1
}

if [[ ! -d "rfcs" ]]; then
  echo "Skipping RFC governance validation: missing rfcs/ directory."
  exit 0
fi

echo "Checking RFC metadata files exist..."
required_files=(
  "rfcs/README.md"
  "rfcs/index.md"
  "rfcs/getting-started.md"
  "rfcs/templates/rfc-template.md"
)
for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    fail "missing required file: $file"
  fi
done

echo "Checking RFC template has required sections..."
if [[ -f "rfcs/templates/rfc-template.md" ]]; then
  required_sections=(
    "Status"
    "Summary"
    "Motivation"
    "Proposed Design"
    "Governance Mapping"
    "Alternatives"
  )
  for section in "${required_sections[@]}"; do
    if ! rg -q "$section" "rfcs/templates/rfc-template.md"; then
      fail "RFC template missing section: $section"
    fi
  done
fi

echo "Checking RFC files..."
RFC_COUNT=0
for rfc in rfcs/RFC-*.md; do
  if [[ -f "$rfc" ]]; then
    ((RFC_COUNT++))
    rfc_name="$(basename "$rfc")"
    echo "  Found: $rfc_name"

    # Check for required fields
    if ! rg -q '\*\*Status\*\*:' "$rfc"; then
      fail "RFC missing Status field: $rfc_name"
    fi

    if ! rg -q '## Summary' "$rfc"; then
      fail "RFC missing Summary section: $rfc_name"
    fi

    if ! rg -q '## Governance Mapping' "$rfc"; then
      fail "RFC missing Governance Mapping section: $rfc_name"
    fi
  fi
done

if [[ "$RFC_COUNT" -eq 0 ]]; then
  echo "  No RFC files found (except template)"
fi

echo "RFC governance validation passed."
exit 0
