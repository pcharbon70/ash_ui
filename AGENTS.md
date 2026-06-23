# ash_ui

> Resource-backed UI framework on Ash: Screen/Element/Binding Ash resources (via `AshUI.Resource.DSL.*`) are the authoritative authoring units, compiled to a canonical IUR that renders across LiveView / Elm / desktop. Co-maintained with Pascal (jallum). Plan/spec: [`.spec/specs/package.spec.md`](.spec/specs/package.spec.md).

<!-- Reviewed 2026-06-22. No phase numbers / PR ranges / status - link live sources. -->

## Stack

Elixir 1.19.5-otp-28 / Erlang 28.3.1 (`.tool-versions`). Ash `~> 3.0`, AshPostgres `~> 2.0`, Phoenix LiveView `~> 1.0`, telemetry. Vendored path-dep packages: `packages/{unified_ui,unified_iur,live_ui,elm_ui,desktop_ui}`.

## Setup

```bash
mix deps.get        # resolves vendored packages/ path-deps
mix compile
```

## Build / test / lint

```bash
mix compile
mix test                                   # full suite
mix test test/foo_test.exs                 # single file
mix test test/foo_test.exs:42              # single test by line
mix format --check-formatted
mix credo --strict
mix dialyzer                               # uses .dialyzer_ignore.exs

# Done = run this gate:
mix format --check-formatted && mix credo --strict && mix dialyzer && mix test
```

Example suite: `mix ash_ui.examples.{list,validate,report}`, `mix ash_ui.examples.preview <dir>`, `mix ash_ui.examples.start <dir> --dry-run`. Governance: `bash ./scripts/validate_specs_governance.sh`. Coverage threshold 90%.

## Layout

- `lib/ash_ui/{resource,compiler,rendering,navigation,authorization,runtime,telemetry}` — core pipeline.
- `lib/ash_ui/authoring/` — legacy builder/document, migration-only.
- `packages/` — vendored unified_ui sibling packages (renderer + widget grammar).
- `examples/<dir>/` — standalone Mix apps; names mirror `unified_ui/examples`.
- `.spec/` — current-truth spec workspace; read `.spec/AGENTS.md` before editing it.

## Dependencies & boundaries (MANDATORY)

- **Upstream:** Ash / AshPostgres / Phoenix LiveView + its own vendored `packages/` path-deps. No Metagraph-engine dependency.
- **Downstream:** `ariston-ui` path-deps `:ash_ui` (renderer packages come transitively). Contract = the `AshUI.Resource.DSL.*` authoring API + canonical `%UnifiedIUR.Element{}` IUR.
- **Renderer seam:** internal `AshUI.Compilation.IUR` is private; public contract is canonical `%UnifiedIUR.Element{}` via `AshUI.Rendering.IURAdapter`.
- **Navigation = semantic only:** symbolic screens/destinations/modals/params/payload-maps/binding-refs. NEVER route/path/URL/helper/module/runtime-stack fields — host owns routes.
- **Styling = semantic only:** class hooks, variants, renderer-read props, dynamic inline values. Host owns theme tokens/CSS/shell/layout.

## Conventions / boundaries

- Resource-first authoring is authoritative; do NOT hand-author runtime `unified_dsl` snapshots when `AshUI.Resource.Authority` can derive them.
- Legacy builder/document payloads are migration-only — do NOT reopen as runtime compiler inputs.
- Keep storage boundaries configurable via `AshUI.Config`; do NOT hard-code default domain/resources/repo.
- Return structured errors (auth/compilation/binding/rendering/LiveView); do NOT crash sessions.
- Spec-led: update the matching `.spec/specs/*.spec.md` when behavior changes; `.spec` is current-state, not a changelog.
- Branch `codex/<topic>`; commit body = WHY; trailer `Co-Authored-By: Codex`. One reviewable arc per PR.

## Codex

- Review/self-check with `codex exec --profile deep-review`; sandbox + approval per `~/.codex/config.toml`.
- Never touch or echo secrets.
- `spec.*` tasks (from `spec_led_ex`) may not be wired in every checkout (only `format` is in `mix.exs` aliases). If unavailable, note it and run the targeted `mix test ...` from the relevant spec's verification block.

## Pointers

- Spec/ADRs: `.spec/specs/package.spec.md`, `.spec/decisions/`; public shape: `README.md`; examples: `examples/README.md`.
- Open work: `gh pr list --repo The-Metagraph/ash_ui`.
- Workspace core: `~/.codex/AGENTS.md`.
