#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

export MIX_ENV="${MIX_ENV:-test}"

./scripts/validate_specs_governance.sh
./scripts/validate_guides_governance.sh
./scripts/validate_rfc_governance.sh
./scripts/validate_code_docs.sh
mix test --only conformance
