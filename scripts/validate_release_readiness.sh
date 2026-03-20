#!/usr/bin/env bash
set -euo pipefail

ROOT="${RELEASE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

REPORT_DIR="${RELEASE_REPORT_DIR:-reports/release}"
mkdir -p "$REPORT_DIR"

failures=0
notes=()

fail() {
  echo "FAIL: $1"
  failures=1
}

note() {
  echo "INFO: $1"
  notes+=("$1")
}

extract_section_items() {
  local file="$1"
  local heading="$2"

  awk -v heading="$heading" '
    $0 == heading {capture=1; next}
    /^## / && capture {exit}
    capture {print}
  ' "$file" | sed '/^[[:space:]]*$/d'
}

echo "Checking required release assets..."
required_files=(
  "CHANGELOG.md"
  "release/README.md"
  "release/RELEASE_CHECKLIST.md"
  "release/ROLLBACK_PLAN.md"
  "release/KNOWN_ISSUES.md"
  "release/templates/rollback-communication.md"
  "scripts/generate_changelog.sh"
  "scripts/test_rollback_procedure.sh"
  ".github/workflows/ci.yml"
  ".github/workflows/conformance.yml"
  ".github/workflows/specs-governance.yml"
  ".github/workflows/guides-governance.yml"
  ".github/workflows/rfc-governance.yml"
  ".github/workflows/release.yml"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    fail "missing required release file: $file"
  fi
done

echo "Checking changelog structure..."
if ! rg -q '^## Unreleased$' CHANGELOG.md; then
  fail "CHANGELOG.md is missing an Unreleased section"
fi

echo "Checking mix project version..."
PROJECT_VERSION="$(sed -n 's/.*version: "\([^"]*\)".*/\1/p' mix.exs | head -n1)"
if [[ -z "$PROJECT_VERSION" ]]; then
  fail "unable to determine version from mix.exs"
else
  note "mix.exs version: $PROJECT_VERSION"
fi

echo "Checking known issues..."
critical_items="$(extract_section_items release/KNOWN_ISSUES.md "## Critical" | grep '^- ' || true)"
if [[ -z "$critical_items" ]]; then
  fail "release/KNOWN_ISSUES.md must declare the Critical section status"
else
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" != "- None" ]]; then
      fail "critical issue remains open: $line"
    fi
  done <<<"$critical_items"
fi

if [[ "${RELEASE_RUN_GOVERNANCE:-true}" == "true" ]]; then
  echo "Running governance validators..."
  if [[ "${RELEASE_RUN_SPECS_GOVERNANCE:-true}" == "true" ]]; then
    ./scripts/validate_specs_governance.sh || fail "specs governance validation failed"
  else
    note "specs governance skipped"
  fi

  if [[ "${RELEASE_RUN_GUIDES_GOVERNANCE:-true}" == "true" ]]; then
    ./scripts/validate_guides_governance.sh || fail "guides governance validation failed"
  else
    note "guides governance skipped"
  fi

  if [[ "${RELEASE_RUN_RFC_GOVERNANCE:-true}" == "true" ]]; then
    ./scripts/validate_rfc_governance.sh || fail "RFC governance validation failed"
  else
    note "RFC governance skipped"
  fi

  if [[ "${RELEASE_RUN_CODE_DOCS:-true}" == "true" ]]; then
    ./scripts/validate_code_docs.sh || fail "code docs validation failed"
  else
    note "code docs validation skipped"
  fi
fi

if [[ "${RELEASE_RUN_CONFORMANCE:-false}" == "true" ]]; then
  echo "Running conformance harness..."
  ./scripts/run_conformance.sh || fail "conformance run failed"
else
  note "conformance run skipped (set RELEASE_RUN_CONFORMANCE=true to enforce)"
fi

if [[ "${RELEASE_RUN_COVERAGE:-false}" == "true" ]]; then
  threshold="${RELEASE_COVERAGE_THRESHOLD:-70}"
  echo "Running coverage check with threshold ${threshold}%..."
  set +e
  mix test --cover --min-coverage "$threshold" 2>&1 | tee "$REPORT_DIR/coverage.txt"
  coverage_status=${PIPESTATUS[0]}
  set -e

  if [[ "$coverage_status" -ne 0 ]]; then
    fail "coverage check failed for threshold ${threshold}%"
  fi
else
  note "coverage run skipped (set RELEASE_RUN_COVERAGE=true to enforce)"
fi

echo "Testing rollback procedure..."
./scripts/test_rollback_procedure.sh || fail "rollback procedure validation failed"

GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
cat > "$REPORT_DIR/release-readiness.md" <<EOF
# Release Readiness Report

- Generated at: $GENERATED_AT
- Branch: $(git branch --show-current)
- Revision: $(git rev-parse --short HEAD)
- Version: ${PROJECT_VERSION:-unknown}
- Result: $(if [[ "$failures" -eq 0 ]]; then echo "passed"; else echo "failed"; fi)

## Notes
EOF

if [[ "${#notes[@]}" -eq 0 ]]; then
  echo "- None" >> "$REPORT_DIR/release-readiness.md"
else
  for item in "${notes[@]}"; do
    echo "- $item" >> "$REPORT_DIR/release-readiness.md"
  done
fi

if [[ "$failures" -ne 0 ]]; then
  echo "Release readiness validation failed."
  exit 1
fi

echo "Release readiness validation passed."
