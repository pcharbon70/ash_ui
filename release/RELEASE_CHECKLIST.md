# Release Checklist

Use this checklist before cutting an Ash UI release.

## Release Criteria

- [ ] All conformance tests pass via `./scripts/run_conformance.sh`
- [ ] All governance workflows pass:
  - `ci.yml`
  - `conformance.yml`
  - `specs-governance.yml`
  - `guides-governance.yml`
  - `rfc-governance.yml`
  - `release.yml` dry run
- [ ] Code coverage meets or exceeds the release threshold of `70%`
- [ ] `release/KNOWN_ISSUES.md` lists no critical bugs
- [ ] Root README, guides, and release assets are current
- [ ] Telemetry dashboards are available and recent signals look healthy

## Release Inputs

- current version from `mix.exs`
- generated changelog draft from `./scripts/generate_changelog.sh`
- current branch and commit SHA
- release dry-run result from `.github/workflows/release.yml`

## Cut Procedure

### 1. Update version numbers

- update `version` in `mix.exs`
- review any version references in guides, examples, and release notes

### 2. Validate readiness

Run:

```bash
./scripts/validate_release_readiness.sh
```

For full release gating in CI, the release workflow runs the script with heavy checks enabled:

- conformance
- coverage threshold
- rollback validation

### 3. Generate changelog draft

Run:

```bash
./scripts/generate_changelog.sh vX.Y.Z
```

Review the generated draft and merge the important items into `CHANGELOG.md`.

### 4. Dry-run the release workflow

Use `.github/workflows/release.yml` with:

- `dry_run=true`
- empty `tag_name`

The dry run should complete without failures before any tag is created.

### 5. Create and publish the tag

Use the release workflow with:

- `dry_run=false`
- `tag_name=vX.Y.Z`

The workflow creates the git tag if needed and creates the GitHub release entry.

### 6. Publish to Hex if enabled

If `HEX_API_KEY` is configured in GitHub Actions secrets, the workflow will publish to Hex automatically after the GitHub release step.

## Sign-Off

- [ ] Engineering sign-off
- [ ] Docs sign-off
- [ ] Observability sign-off
- [ ] Rollback owner assigned
