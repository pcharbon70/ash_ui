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

[ ] 7 Phase 7 - Renderer Package Integration
  Integrate with external unified renderer packages (live_ui, web_ui, desktop_ui) for final output generation.

  [ ] 7.1 Section - Package Dependencies
    Add and configure unified renderer packages as dependencies.

    [ ] 7.1.1 Task - Add renderer packages to mix.exs
    Include renderer packages as optional dependencies.

      [ ] 7.1.1.1 Subtask - Add `unified_iur` to deps
      [ ] 7.1.1.2 Subtask - Add `live_ui` as optional dependency
      [ ] 7.1.1.3 Subtask - Add `web_ui` as optional dependency
      [ ] 7.1.1.4 Subtask - Add `desktop_ui` as optional dependency

    [ ] 7.1.2 Task - Create renderer configuration
    Configure which renderer package to use.

      [ ] 7.1.2.1 Subtask - Add `:renderer` config to application config
      [ ] 7.1.2.2 Subtask - Support `:liveview`, `:html`, `:desktop` options
      [ ] 7.1.2.3 Subtask - Validate selected renderer is available
      [ ] 7.1.2.4 Subtask - Provide default renderer selection

    [ ] 7.1.3 Task - Implement renderer registry
    Track available renderer packages.

      [ ] 7.1.3.1 Subtask - Implement `AshUI.Rendering.Registry`
      [ ] 7.1.3.2 Subtask - Register available renderers at startup
      [ ] 7.1.3.3 Subtask - Provide `list_renderers/0` function
      [ ] 7.1.3.4 Subtask - Provide `get_renderer/1` lookup function

  [ ] 7.2 Section - LiveUI Integration
    Integrate with live_ui renderer for LiveView output.

    [ ] 7.2.1 Task - Implement LiveUI renderer adapter
    Create adapter for calling LiveUI renderer.

      [ ] 7.2.1.1 Subtask - Implement `AshUI.Rendering.LiveUIAdapter`
      [ ] 7.2.1.2 Subtask - Accept canonical IUR and options
      [ ] 7.2.1.3 Subtask - Call `LiveUI.Renderer.render/2`
      [ ] 7.2.1.4 Subtask - Return HEEx template string

    [ ] 7.2.2 Task - Handle LiveUI-specific features
    Support LiveUI-specific rendering features.

      [ ] 7.2.2.1 Subtask - Configure LiveView event bindings
      [ ] 7.2.2.2 Subtask - Configure LiveView hooks
      [ ] 7.2.2.3 Subtask - Handle LiveView assigns for reactivity
      [ ] 7.2.2.4 Subtask - Support LiveView patch optimizations

  [ ] 7.3 Section - WebUI Integration
    Integrate with web_ui renderer for static HTML output.

    [ ] 7.3.1 Task - Implement WebUI renderer adapter
    Create adapter for calling WebUI renderer.

      [ ] 7.3.1.1 Subtask - Implement `AshUI.Rendering.WebUIAdapter`
      [ ] 7.3.1.2 Subtask - Accept canonical IUR and options
      [ ] 7.3.1.3 Subtask - Call `WebUI.Renderer.render/2`
      [ ] 7.3.1.4 Subtask - Return static HTML string

    [ ] 7.3.2 Task - Handle WebUI-specific features
    Support WebUI-specific rendering features.

      [ ] 7.3.2.1 Subtask - Configure Elm client integration
      [ ] 7.3.2.2 Subtask - Configure asset references
      [ ] 7.3.2.3 Subtask - Handle SEO meta tags
      [ ] 7.3.2.4 Subtask - Support static site generation

  [ ] 7.4 Section - DesktopUI Integration
    Integrate with desktop_ui renderer for native desktop output.

    [ ] 7.4.1 Task - Implement DesktopUI renderer adapter
    Create adapter for calling DesktopUI renderer.

      [ ] 7.4.1.1 Subtask - Implement `AshUI.Rendering.DesktopUIAdapter`
      [ ] 7.4.1.2 Subtask - Accept canonical IUR and options
      [ ] 7.4.1.3 Subtask - Call `DesktopUI.Renderer.render/2`
      [ ] 7.4.1.4 Subtask - Return native desktop UI instructions

    [ ] 7.4.2 Task - Handle DesktopUI-specific features
    Support DesktopUI-specific rendering features.

      [ ] 7.4.2.1 Subtask - Configure SDL2 window properties
      [ ] 7.4.2.2 Subtask - Configure native menu bar
      [ ] 7.4.2.3 Subtask - Handle platform-specific features
      [ ] 7.4.2.4 Subtask - Support desktop event handling

  [ ] 7.5 Section - Renderer Selection
    Implement automatic renderer selection based on context.

    [ ] 7.5.1 Task - Implement runtime renderer selection
    Select renderer based on request context.

      [ ] 7.5.1.1 Subtask - Detect LiveView request → use live_ui
      [ ] 7.5.1.2 Subtask - Detect HTTP request → use web_ui
      [ ] 7.5.1.3 Subtask - Support explicit renderer override
      [ ] 7.5.1.4 Subtask - Handle unavailable renderer gracefully

    [ ] 7.5.2 Task - Implement renderer fallback
    Provide fallback when selected renderer is unavailable.

      [ ] 7.5.2.1 Subtask - Fallback to alternative renderer if configured
      [ ] 7.5.2.2 Subtask - Display error if no fallback available
      [ ] 7.5.2.3 Subtask - Log fallback events for monitoring
      [ ] 7.5.2.4 Subtask - Support per-environment renderer selection

  [ ] 7.6 Section - Phase 7 Integration Tests
    Validate renderer package integration end-to-end.

    [ ] 7.6.1 Task - LiveUI integration scenarios
    Verify live_ui renderer works correctly.

      [ ] 7.6.1.1 Subtask - Verify canonical IUR renders to valid HEEx
      [ ] 7.6.1.2 Subtask - Verify events are wired correctly
      [ ] 7.6.1.3 Subtask - Verify reactive updates work
      [ ] 7.6.1.4 Subtask - Verify LiveView patches work

    [ ] 7.6.2 Task - WebUI integration scenarios
    Verify web_ui renderer works correctly.

      [ ] 7.6.2.1 Subtask - Verify canonical IUR renders to valid HTML
      [ ] 7.6.2.2 Subtask - Verify Elm client integration works
      [ ] 7.6.2.3 Subtask - Verify static assets are referenced correctly
      [ ] 7.6.2.4 Subtask - Verify SEO tags are present

    [ ] 7.6.3 Task - Renderer selection scenarios
    Verify renderer selection works correctly.

      [ ] 7.6.3.1 Subtask - Verify LiveView request uses live_ui
      [ ] 7.6.3.2 Subtask - Verify HTTP request uses web_ui
      [ ] 7.6.3.3 Subtask - Verify explicit override is respected
      [ ] 7.6.3.4 Subtask - Verify unavailable renderer shows error

    [ ] 7.6.4 Task - Cross-renderer scenarios
    Verify UI works across different renderers.

      [ ] 7.6.4.1 Subtask - Verify same IUR renders on all renderers
      [ ] 7.6.4.2 Subtask - Verify renderer-specific features are isolated
      [ ] 7.6.4.3 Subtask - Verify fallback behavior works
      [ ] 7.6.4.4 Subtask - Verify renderer switching works
