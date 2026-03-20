# Release Assets

This directory contains the operational files used for Phase 8 release readiness.

## Contents

- `RELEASE_CHECKLIST.md`: release criteria and cut procedure
- `ROLLBACK_PLAN.md`: rollback triggers and execution steps
- `KNOWN_ISSUES.md`: current release blocker inventory
- `templates/rollback-communication.md`: communication template for rollback or pause

## Validation Scripts

- `./scripts/validate_release_readiness.sh`
- `./scripts/generate_changelog.sh`
- `./scripts/test_rollback_procedure.sh`

## Typical Sequence

1. update the version in `mix.exs`
2. run `./scripts/validate_release_readiness.sh`
3. generate release notes with `./scripts/generate_changelog.sh vX.Y.Z`
4. review `release/KNOWN_ISSUES.md`
5. use `.github/workflows/release.yml` for dry run or release execution
