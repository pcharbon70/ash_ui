# Ash UI Guides

This directory contains user and developer documentation for the Ash UI framework.

## Guide Structure

```
guides/
├── user/                    # User guides (UG-XXXX)
├── developer/              # Developer guides (DG-XXXX)
├── contracts/              # Guide documentation contracts
├── conformance/            # Guide conformance tracking
└── templates/              # Guide templates
```

## User Guides (UG-*)

User guides are written for framework users who build applications with Ash UI.

| Guide ID | Title | Audience | Status |
|---|---|---|---|
| [UG-0001](user/UG-0001-getting-started.md) | Getting Started | Application Developers | Active |

## Developer Guides (DG-*)

Developer guides are written for contributors to the Ash UI framework itself.

| Guide ID | Title | Audience | Status |
|---|---|---|---|
| [DG-0001](developer/DG-0001-architecture-overview.md) | Architecture Overview | Framework Developers | Active |

## Guide Contracts

See [contracts/](contracts/) for documentation standards and requirements.

## Conformance

See [conformance/](conformance/) for guide conformance tracking.

## Contributing

When creating new guides:

1. Copy the appropriate template from [templates/](templates/)
2. Follow the guide contract requirements
3. Link to relevant REQ-* and SCN-* entries
4. Update the appropriate index

## Related Documentation

- [../specs/](../specs/) - Technical specifications
- [../rfcs/](../rfcs/) - Design proposals
