# ash_ui

Ash UI is a resource-backed UI framework for Elixir built on Ash: Screen, Element, and Binding Ash resources (via `AshUI.Resource.DSL.*`) are the authoritative authoring units, compiled to a canonical IUR that renders across LiveView / Elm / desktop targets. Canonical spec: [`.spec/specs/package.spec.md`](.spec/specs/package.spec.md); public shape: [`README.md`](README.md).

<!-- Last reviewed 2026-06-22 - link live state, do not inline status. -->

## Quick start

```bash
mix deps.get                                # resolves path-dep packages under packages/
mix compile

mix test                                    # full suite
mix test test/path/to/some_test.exs         # one file
mix test test/path/to/some_test.exs:42      # one test by line

# quality gate (what mix.exs actually wires)
mix format --check-formatted
mix credo --strict
mix dialyzer                                 # uses .dialyzer_ignore.exs
mix test
```

Coverage threshold is 90% (`MIX_TEST_COVERAGE_THRESHOLD` overrides). Example-suite tasks: `mix ash_ui.examples.list`, `mix ash_ui.examples.preview <dir>`, `mix ash_ui.examples.start <dir> --dry-run`, `mix ash_ui.examples.validate`, `mix ash_ui.examples.report`. Governance check: `bash ./scripts/validate_specs_governance.sh`.

## Architecture

ash_ui is the **declarative UI layer** in the Metagraph dependency tree. It has no upstream Metagraph dependency — it stands on Ash 3.x / AshPostgres / Phoenix LiveView. It **vendors `unified_ui` packages internally** as path-deps (`packages/{unified_ui,unified_iur,live_ui,elm_ui,desktop_ui}`) which own the shared widget/layout grammar and multi-target renderers. Downstream, `ariston-ui` path-deps `:ash_ui` (only `:ash_ui` is declared in its `mix.exs`; the renderer packages come transitively).

Authoring → runtime pipeline:

- Ash resources using `AshUI.Resource.DSL.Screen` / `.Element` are the authoring surface; relationships + `ui_relationships` define composition; `ui_bindings` / `ui_actions` define runtime behavior.
- `AshUI.Resource.Authority` derives and persists the `Screen.unified_dsl` snapshot from the resource graph.
- `AshUI.Compiler` compiles persisted screens + authority payloads to `AshUI.Compilation.IUR`.
- `AshUI.Rendering.IURAdapter` converts internal IUR to `%UnifiedIUR.Element{}` canonical renderer-facing IUR.
- LiveView mount/event/update helpers + runtime authorization policies drive the live surface.

Non-obvious dirs: `packages/` (vendored unified_ui sibling packages — own grammar, do not duplicate in `lib/`); `examples/` (standalone Mix apps, directory names mirror `unified_ui/examples` for catalog-stable review); `lib/ash_ui/{compiler,rendering,navigation,authorization,telemetry}`; `lib/ash_ui/authoring/` (legacy builder/document — migration-only).

## Dependencies & boundaries (MANDATORY)

- **Consumes (upstream):** Ash `~> 3.0`, AshPostgres `~> 2.0`, Phoenix LiveView `~> 1.0`, plus its own vendored path-dep packages `packages/{unified_ui,unified_iur,live_ui,elm_ui,desktop_ui}`. No Metagraph-engine dependency.
- **Consumed by (downstream):** `ariston-ui` path-deps `:ash_ui` as its canonical UI layer. The contract is the **Ash `AshUI.Resource.DSL.*` authoring API + the canonical `%UnifiedIUR.Element{}` IUR** produced by the compiler/adapter. Breaking either ripples into ariston-ui.
- **Contract at the renderer seam:** internal `AshUI.Compilation.IUR` is private; the **public renderer-facing contract is canonical `%UnifiedIUR.Element{}`** via `AshUI.Rendering.IURAdapter`. Renderer packages consume canonical IUR, not internal IUR.
- **Navigation is semantic/host-independent:** resource `navigation` may use symbolic screens, destinations, modals, params, payload mappings, binding refs — but **never route/path/URL/helper/module/runtime-stack fields**. Host apps own concrete routes.
- **Styling is semantic:** resources declare class hooks, variants, renderer-read props, dynamic inline style values; host apps own concrete theme tokens, CSS, shell, responsive layout.

## Hard rules (reverted if violated)

- **Resource-first authoring.** Screen/element Ash resources are authoritative; do not ask apps to hand-author runtime `unified_dsl` snapshots when `AshUI.Resource.Authority` can derive them.
- **Legacy builder/document support is migration-only.** Do not reopen builder-first or document-first payloads as supported runtime compiler inputs (`lib/ash_ui/authoring/`).
- **No route/path/renderer-specific fields on resources.** Navigation transport goes through `AshUI.Navigation.Intent`, `AshUI.Rendering.CanonicalIUR`, `AshUI.Runtime.Navigation`.
- **Storage boundaries stay configurable** through `AshUI.Config` — do not hard-code the default domain, resources, repo, or runtime domain into shared logic.
- **Runtime is actor-aware.** Binding evaluation, LiveView events, screen mounts, and resource access pass through authorization/policy surfaces; return structured errors rather than crashing sessions.
- **Co-maintained repo.** This is jointly maintained with Pascal (pcharbon70) as architect. Breaking-change discipline, release notes, and issue-triage obligations apply; respect existing `.spec/` and README conventions.
- **Renderer selection: package availability != fallback renderability.** The registry distinguishes external package availability from adapter-fallback renderability and exposes the resolved module + mode per renderer type — preserve that distinction (`AshUI.Rendering.{Selector,Registry}`).

## Conventions

- Branch `claude/<topic>` (Claude) or `codex/<topic>` (Codex). One reviewable arc per PR.
- Commit subject is descriptive; the body explains WHY, not WHAT.
- **Spec-led.** `.spec/` is current-truth. Update the matching `.spec/specs/*.spec.md` subject when behavior changes. `.spec` files are current-state documents — use git history/PRs for the change log.
- Emit/preserve canonical `ash_ui` telemetry events for authoring, screen, binding, compilation, rendering, authorization, and migration flows when those paths change.
- Prefer existing `AshUI.Resource.DSL.*`, `AshUI.Resource.Info`, `AshUI.Resource.Authority`, `AshUI.Config`, compiler/rendering/runtime/telemetry modules over new parallel abstractions.

## Claude Code specifics

- **Spec-led loop:** `mix spec.prime --base HEAD` at session start, `mix spec.next` after changes, `mix spec.check --base HEAD` when ready. NOTE: the `spec.*` tasks come from `spec_led_ex` and may not be wired in every checkout (only `format` is in `mix.exs` aliases). If a spec task is unavailable, record that in the handoff and run the closest targeted `mix test ...` from the relevant spec's verification block instead.
- **`widget` skill** applies when adding/reviewing widgets for AshUI / Unified UI / Live UI / Elm UI / Desktop UI, and when deciding canonical-widget vs `custom:*` application extension. Load it for any widget work.
- **Orchestration:** in cross-repo waves, the umbrella session runs orchestrator-conductor; sub-agents implement. For ariston-ui-adjacent ash_ui work the default split is Codex implements / Opus reviews.
- First read: `.spec/README.md`, then `.spec/AGENTS.md` before editing `.spec/`, then the subject specs matching your files, then `README.md`. For example work: `examples/README.md`, `examples/scaffold_contract.md`, `examples/ash_hq_theme_baseline.md`.

## Gotchas

- `packages/` are real path-deps vendored in-repo; `mix deps.get` resolves them locally. Changes there are renderer/grammar changes — review the seam contract.
- Example apps under `examples/<dir>/` are **standalone Mix projects**; treat their `_build/`, `deps/`, and reports as unrelated unless the task targets them.
- Canonical type normalization in the example suite intentionally diverges from upstream authoring (`text_input -> input`, `radio_group -> radio`, `toggle -> switch`, `separator -> divider`); directory parity with `unified_ui/examples` is stable even when the canonical subject is normalized.
- Worktree + Phoenix `priv/` build-time path resolution: a worktree's rebuilt assets can be served stale by a server running from the main checkout (`_build/` symlink). Rebuild against the merged checkout to preview.

## Pointers (live, NOT inlined)

- Canonical spec: [`.spec/specs/package.spec.md`](.spec/specs/package.spec.md); ADRs: [`.spec/decisions/`](.spec/decisions/); public shape: [`README.md`](README.md).
- Example suite: [`examples/README.md`](examples/README.md).
- Open work: `gh pr list --repo The-Metagraph/ash_ui`.
- Workspace conventions and the full dependency tree: [`../CLAUDE.md`](../CLAUDE.md).
