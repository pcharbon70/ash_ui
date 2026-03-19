#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner --jq '.nameWithOwner')}"
BRANCH="${2:-main}"

read -r -d '' PAYLOAD <<'JSON' || true
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Specs Governance / validate",
      "Conformance / Conformance"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null
}
JSON

if ! gh api \
  --method PUT \
  "repos/${REPO}/branches/${BRANCH}/protection" \
  -H "Accept: application/vnd.github+json" \
  --input - <<<"$PAYLOAD"; then
  echo "Failed to update branch protection for ${REPO}:${BRANCH}." >&2
  echo "GitHub admin permission on the repository is required." >&2
  exit 1
fi

echo "Branch protection updated for ${REPO}:${BRANCH}."
echo "Required checks: Specs Governance / validate, Conformance / Conformance"
