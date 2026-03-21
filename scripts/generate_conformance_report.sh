#!/usr/bin/env bash
set -euo pipefail

ROOT="${CONFORMANCE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

REPORT_DIR="${1:-reports/conformance}"
mkdir -p "$REPORT_DIR"

STATUS="${CONFORMANCE_STATUS:-unknown}"
GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
REQ_COUNT="$(rg -c '^\| REQ-' specs/conformance/spec_conformance_matrix.md || echo 0)"
SCN_MATRIX_COUNT="$(rg -o 'SCN-[0-9A-Z]+' specs/conformance/spec_conformance_matrix.md | sort -u | wc -l | tr -d ' ')"
SCN_CATALOG_COUNT="$(rg -o 'SCN-[0-9A-Z]+' specs/conformance/scenario_catalog.md | sort -u | wc -l | tr -d ' ')"
SCN_TRACE_COUNT="$(rg -c '^\| SCN-' specs/conformance/scenario_test_matrix.md || echo 0)"
CONFORMANCE_TEST_FILES="$(rg -l '@(module)?tag.*conformance' test || true)"
if [[ -n "$CONFORMANCE_TEST_FILES" ]]; then
  TEST_FILE_COUNT="$(printf '%s\n' "$CONFORMANCE_TEST_FILES" | sed '/^$/d' | wc -l | tr -d ' ')"
else
  TEST_FILE_COUNT="0"
fi

if [[ "$SCN_CATALOG_COUNT" -gt 0 ]]; then
  SCN_TRACE_COVERAGE="$((SCN_TRACE_COUNT * 100 / SCN_CATALOG_COUNT))"
else
  SCN_TRACE_COVERAGE="0"
fi

cat > "$REPORT_DIR/report.md" <<EOF
# Conformance Report

- Generated at: $GENERATED_AT
- Git branch: $(git branch --show-current)
- Git revision: $(git rev-parse --short HEAD)
- Overall status: $STATUS
- Requirements in matrix: $REQ_COUNT
- Scenarios referenced by matrix: $SCN_MATRIX_COUNT
- Scenarios defined in catalog: $SCN_CATALOG_COUNT
- Scenarios with explicit test mappings: $SCN_TRACE_COUNT
- Scenario traceability coverage: $SCN_TRACE_COVERAGE%
- Conformance-tagged test files: $TEST_FILE_COUNT

## Inputs

- [Spec Conformance Matrix](../../specs/conformance/spec_conformance_matrix.md)
- [Scenario Catalog](../../specs/conformance/scenario_catalog.md)
- [Scenario Test Matrix](../../specs/conformance/scenario_test_matrix.md)

## Tagged Test Files

EOF

if [[ -n "$CONFORMANCE_TEST_FILES" ]]; then
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    echo "- $file" >> "$REPORT_DIR/report.md"
  done <<<"$CONFORMANCE_TEST_FILES"
else
  echo "- None" >> "$REPORT_DIR/report.md"
fi

cat > "$REPORT_DIR/report.json" <<EOF
{
  "generated_at": "$GENERATED_AT",
  "branch": "$(git branch --show-current)",
  "revision": "$(git rev-parse --short HEAD)",
  "status": "$STATUS",
  "requirements_in_matrix": $REQ_COUNT,
  "scenarios_in_matrix": $SCN_MATRIX_COUNT,
  "scenarios_in_catalog": $SCN_CATALOG_COUNT,
  "scenarios_with_test_mappings": $SCN_TRACE_COUNT,
  "scenario_traceability_coverage": $SCN_TRACE_COVERAGE,
  "conformance_test_files": $TEST_FILE_COUNT
}
EOF

echo "Conformance report written to $REPORT_DIR"
