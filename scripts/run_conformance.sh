#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

export MIX_ENV="${MIX_ENV:-test}"
REPORT_DIR="${CONFORMANCE_REPORT_DIR:-reports/conformance}"
mkdir -p "$REPORT_DIR"

./scripts/validate_specs_governance.sh
./scripts/validate_guides_governance.sh
./scripts/validate_rfc_governance.sh
./scripts/validate_code_docs.sh

set +e
mix test --only conformance 2>&1 | tee "$REPORT_DIR/test-output.txt"
TEST_STATUS=${PIPESTATUS[0]}
set -e

if [[ "$TEST_STATUS" -eq 0 ]]; then
  export CONFORMANCE_STATUS="passed"
else
  export CONFORMANCE_STATUS="failed"
fi

./scripts/generate_conformance_report.sh "$REPORT_DIR"

exit "$TEST_STATUS"
