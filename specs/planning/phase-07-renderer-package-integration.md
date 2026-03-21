# Phase 7 - Renderer Package Integration

Back to index: [README](./README.md)

## Relevant Shared APIs / Interfaces
- `AshUI.Rendering.IURAdapter`
- `LiveUI.Renderer` (live_ui package)
- `WebUI.Renderer` (web_ui package)
- `DesktopUI.Renderer` (desktop_ui package)
- `UnifiedIUR` (unified_iur package)

## Relevant Assumptions / Defaults
- Renderer packages are external dependencies
- Application selects which renderer to use
- Canonical IUR is passed to selected renderer
- Renderers produce platform-specific output

## Current Status Note
- Ash UI now completes renderer selection, fallback handling, and integration coverage in-repo.
- External packages (`live_ui`, `web_ui`, `desktop_ui`, `unified_iur`) are still optional and not yet wired as hard dependencies in `mix.exs`.
- Until those upstream packages and APIs are stable, Ash UI relies on adapter fallback implementations for local rendering and test coverage.

[ ] 7 Phase 7 - Renderer Package Integration
  Integrate with external unified renderer packages (live_ui, web_ui, desktop_ui) for final output generation.

  [X] 7.1 Section - Package Dependencies
    Add and configure unified renderer packages as dependencies.

    Add and configure unified renderer packages as dependencies - Add renderer packages to mix.exs
    Include renderer packages as optional dependencies.

      [X] - Add `unified_iur` to deps
      [X] - Add `live_ui` as optional dependency
      [X] - Add `web_ui` as optional dependency
      [X] - Add `desktop_ui` as optional dependency

    [X] - Create renderer configuration
    Configure which renderer package to use.

      [X] - Add `:renderer` config to application config
      [X] - Support `:liveview`, `:html`, `:desktop` options
      [X] - Validate selected renderer is available
      [X] - Provide default renderer selection

    [X] - Implement renderer registry
    Track available renderer packages.

      [X] - Implement `AshUI.Rendering.Registry`
      [X] - Register available renderers at startup
      [X] - Provide `list_renderers/0` function
      [X] - Provide `get_renderer/1` lookup function

  [X] 7.2 Section - LiveUI Integration
    Integrate with live_ui renderer for LiveView output.

    [X] - Implement LiveUI renderer adapter
    Create adapter for calling LiveUI renderer.

      [X] - Implement `AshUI.Rendering.LiveUIAdapter`
      [X] - Accept canonical IUR and options
      [X] - Call `LiveUI.Renderer.render/2`
      [X] - Return HEEx template string

    [X] - Handle LiveUI-specific features
    Support LiveUI-specific rendering features.

      [X] - Configure LiveView event bindings
      [X] - Configure LiveView hooks
      [X] - Handle LiveView assigns for reactivity
      [X] - Support LiveView patch optimizations

  [X] 7.3 Section - WebUI Integration
    Integrate with web_ui renderer for static HTML output.

    [X] - Implement WebUI renderer adapter
    Create adapter for calling WebUI renderer.

      [X] - Implement `AshUI.Rendering.WebUIAdapter`
      [X] - Accept canonical IUR and options
      [X] - Call `WebUI.Renderer.render/2`
      [X] - Return static HTML string

    [X] - Handle WebUI-specific features
    Support WebUI-specific rendering features.

      [X] - Configure Elm client integration
      [X] - Configure asset references
      [X] - Handle SEO meta tags
      [X] - Support static site generation

  [X] 7.4 Section - DesktopUI Integration
    Integrate with desktop_ui renderer for native desktop output.

    [X] - Implement DesktopUI renderer adapter
    Create adapter for calling DesktopUI renderer.

      [X] - Implement `AshUI.Rendering.DesktopUIAdapter`
      [X] - Accept canonical IUR and options
      [X] - Call `DesktopUI.Renderer.render/2`
      [X] - Return native desktop UI instructions

    [X] - Handle DesktopUI-specific features
    Support DesktopUI-specific rendering features.

      [X] - Configure SDL2 window properties
      [X] - Configure native menu bar
      [X] - Handle platform-specific features
      [X] - Support desktop event handling

  [X] 7.5 Section - Renderer Selection
    Implement automatic renderer selection based on context.

    [X] 7.5.1 Task - Implement runtime renderer selection
    Select renderer based on request context.

      [X] 7.5.1.1 Subtask - Detect LiveView request → use live_ui
      [X] 7.5.1.2 Subtask - Detect HTTP request → use web_ui
      [X] 7.5.1.3 Subtask - Support explicit renderer override
      [X] 7.5.1.4 Subtask - Handle unavailable renderer gracefully

    [X] 7.5.2 Task - Implement renderer fallback
    Provide fallback when selected renderer is unavailable.

      [X] 7.5.2.1 Subtask - Fallback to alternative renderer if configured
      [X] 7.5.2.2 Subtask - Display error if no fallback available
      [X] 7.5.2.3 Subtask - Log fallback events for monitoring
      [X] 7.5.2.4 Subtask - Support per-environment renderer selection

  [X] 7.6 Section - Phase 7 Integration Tests
    Validate renderer package integration end-to-end.

    [X] 7.6.1 Task - LiveUI integration scenarios
    Verify live_ui renderer works correctly.

      [X] 7.6.1.1 Subtask - Verify canonical IUR renders to valid HEEx
      [X] 7.6.1.2 Subtask - Verify events are wired correctly
      [X] 7.6.1.3 Subtask - Verify reactive updates work
      [X] 7.6.1.4 Subtask - Verify LiveView patches work

    [X] 7.6.2 Task - WebUI integration scenarios
    Verify web_ui renderer works correctly.

      [X] 7.6.2.1 Subtask - Verify canonical IUR renders to valid HTML
      [X] 7.6.2.2 Subtask - Verify Elm client integration works
      [X] 7.6.2.3 Subtask - Verify static assets are referenced correctly
      [X] 7.6.2.4 Subtask - Verify SEO tags are present

    [X] 7.6.3 Task - Renderer selection scenarios
    Verify renderer selection works correctly.

      [X] 7.6.3.1 Subtask - Verify LiveView request uses live_ui
      [X] 7.6.3.2 Subtask - Verify HTTP request uses web_ui
      [X] 7.6.3.3 Subtask - Verify explicit override is respected
      [X] 7.6.3.4 Subtask - Verify unavailable renderer shows error

    [X] 7.6.4 Task - Cross-renderer scenarios
    Verify UI works across different renderers.

      [X] 7.6.4.1 Subtask - Verify same IUR renders on all renderers
      [X] 7.6.4.2 Subtask - Verify renderer-specific features are isolated
      [X] 7.6.4.3 Subtask - Verify fallback behavior works
      [X] 7.6.4.4 Subtask - Verify renderer switching works
