#!/usr/bin/env bash
set -euo pipefail

ROOT="${RFC_GOVERNANCE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

failures=0
VALID_STATUSES='Draft|Review|Discussion|Accepted|Rejected|Implementation|Implemented|Active|Deprecated'

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

echo "Checking RFC index and README stay in sync..."
while IFS= read -r rfc_id; do
  [[ -z "$rfc_id" ]] && continue

  if ! rg -q "$rfc_id" rfcs/index.md; then
    fail "RFC missing from rfcs/index.md: $rfc_id"
  fi

  if ! rg -q "$rfc_id" rfcs/README.md; then
    fail "RFC missing from rfcs/README.md: $rfc_id"
  fi
done < <(
  find rfcs -maxdepth 1 -type f -name 'RFC-*.md' -exec basename {} .md \; |
    sed -E 's/^(RFC-[0-9]+).*/\1/' |
    sort -u
)

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
    ((RFC_COUNT += 1))
    rfc_name="$(basename "$rfc")"
    echo "  Found: $rfc_name"

    required_fields=(
      '\*\*Status\*\*:'
      '\*\*Phase\*\*:'
      '\*\*Authors\*\*:'
      '\*\*Created\*\*:'
      '\*\*Modified\*\*:'
    )

    for field in "${required_fields[@]}"; do
      if ! rg -q "$field" "$rfc"; then
        fail "RFC missing required metadata field ($field): $rfc_name"
      fi
    done

    required_sections=(
      '^## Summary$'
      '^## Motivation$'
      '^## Proposed Design$'
      '^## Governance Mapping$'
      '^## Spec Creation Plan$'
      '^## Alternatives$'
      '^## Implementation Plan$'
      '^## References$'
    )

    for section in "${required_sections[@]}"; do
      if ! rg -q "$section" "$rfc"; then
        fail "RFC missing required section ($section): $rfc_name"
      fi
    done

    if ! rg -q "\\*\\*Status\\*\\*: (${VALID_STATUSES})" "$rfc"; then
      fail "RFC has invalid status value: $rfc_name"
    fi

    if ! rg -q '\*\*Created\*\*: [0-9]{4}-[0-9]{2}-[0-9]{2}' "$rfc"; then
      fail "RFC missing valid Created date: $rfc_name"
    fi

    if ! rg -q '\*\*Modified\*\*: [0-9]{4}-[0-9]{2}-[0-9]{2}' "$rfc"; then
      fail "RFC missing valid Modified date: $rfc_name"
    fi

  fi
done

if [[ "$RFC_COUNT" -eq 0 ]]; then
  echo "  No RFC files found (except template)"
fi

if [[ "$failures" -ne 0 ]]; then
  echo "RFC governance validation failed."
  exit 1
fi

echo "RFC governance validation passed."
exit 0
