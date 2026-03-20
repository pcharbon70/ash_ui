#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

REPORT_DIR="${ROLLBACK_REPORT_DIR:-reports/release}"
mkdir -p "$REPORT_DIR"

failures=0

fail() {
  echo "FAIL: $1"
  failures=1
}

required_files=(
  "release/ROLLBACK_PLAN.md"
  "release/templates/rollback-communication.md"
  "release/KNOWN_ISSUES.md"
)

echo "Checking rollback files..."
for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    fail "missing rollback artifact: $file"
  fi
done

echo "Checking rollback plan structure..."
required_sections=(
  '^## Rollback Criteria$'
  '^## Rollback Steps$'
  '^## Rollback Owner Checklist$'
  '^## Validation$'
)

for section in "${required_sections[@]}"; do
  if ! rg -q "$section" release/ROLLBACK_PLAN.md; then
    fail "rollback plan missing section: $section"
  fi
done

echo "Checking rollback communication template..."
template_markers=(
  '<version>'
  '<timestamp>'
  '<owner>'
  '<signal>'
  '<impact>'
  '<action>'
  '<eta>'
)

for marker in "${template_markers[@]}"; do
  if ! rg -q "$marker" release/templates/rollback-communication.md; then
    fail "rollback communication template missing marker: $marker"
  fi
done

GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
cat > "$REPORT_DIR/rollback-test.md" <<EOF
# Rollback Procedure Validation

- Generated at: $GENERATED_AT
- Branch: $(git branch --show-current)
- Revision: $(git rev-parse --short HEAD)
- Result: $(if [[ "$failures" -eq 0 ]]; then echo "passed"; else echo "failed"; fi)
EOF

if [[ "$failures" -ne 0 ]]; then
  echo "Rollback procedure validation failed."
  exit 1
fi

echo "Rollback procedure validation passed."
