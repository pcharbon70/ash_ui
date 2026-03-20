# Rollback Plan

This document defines when and how to roll back an Ash UI release candidate.

## Rollback Criteria

Initiate rollback when any of the following are true after release:

- repeated screen mount failures appear in telemetry
- authorization failures spike unexpectedly for known-good paths
- renderer output is broken across a supported integration path
- the published package cannot be installed or compiled cleanly
- critical regressions are confirmed with no safe hotfix available immediately

## Rollback Steps

1. Pause rollout and stop promoting the new version.
2. Confirm the affected version, commit SHA, and distribution channel.
3. Notify stakeholders using `release/templates/rollback-communication.md`.
4. Revert consumers to the previous known-good version or tag.
5. If a GitHub release was published, mark it as superseded in the release notes.
6. If Hex publication already happened:
   - prefer shipping a corrective patch release when unpublish is not appropriate
   - only unpublish if it is permitted and operationally safe
7. Capture the triggering signals in `release/KNOWN_ISSUES.md`.
8. Open follow-up work for the root cause and the safe re-release path.

## Rollback Owner Checklist

- [ ] previous known-good version identified
- [ ] consumer rollback instructions ready
- [ ] communication sent
- [ ] telemetry stabilized after rollback
- [ ] follow-up issue or patch plan created

## Validation

Run:

```bash
./scripts/test_rollback_procedure.sh
```

This validates that the rollback artifacts and required sections are present.
