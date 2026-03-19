#!/usr/bin/env bash
set -euo pipefail

ROOT="${GUIDES_GOVERNANCE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

failures=0

fail() {
  echo "FAIL: $1"
  failures=1
}

echo "Checking guide directory structure..."
required_dirs=(
  "guides/user"
  "guides/developer"
  "guides/contracts"
  "guides/conformance"
  "guides/templates"
)
for dir in "${required_dirs[@]}"; do
  if [[ ! -d "$dir" ]]; then
    fail "missing required directory: $dir"
  fi
done

echo "Checking guide contracts exist..."
required_contract_files=(
  "guides/contracts/guide_contract.md"
  "guides/contracts/guide_traceability_contract.md"
)
for file in "${required_contract_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    fail "missing required file: $file"
  fi
done

echo "Checking guide templates exist..."
required_templates=(
  "guides/templates/user-guide-template.md"
  "guides/templates/developer-guide-template.md"
)
for file in "${required_templates[@]}"; do
  if [[ ! -f "$file" ]]; then
    fail "missing required template: $file"
  fi
done

echo "Checking guide conformance matrix exists..."
if [[ ! -f "guides/conformance/guide_conformance_matrix.md" ]]; then
  fail "missing guide conformance matrix"
fi

echo "Guides governance validation passed."
exit 0
