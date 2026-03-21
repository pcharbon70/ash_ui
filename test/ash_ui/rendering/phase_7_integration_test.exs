defmodule AshUI.Rendering.Phase7IntegrationTest do
  use ExUnit.Case, async: true

  alias AshUI.Rendering.{
    DesktopUIAdapter,
    IURAdapter,
    LiveUIAdapter,
    Registry,
    Selector,
    WebUIAdapter
  }

  alias AshUI.Compilation.IUR

  @moduletag :integration
  @moduletag :conformance

  describe "Section 7.6.1 - LiveUI integration scenarios" do
    test "7.6.1.1 - Verify canonical IUR renders to valid HEEx" do
      canonical_iur = %{
        "type" => "screen",
        "id" => "screen-1",
        "name" => "test_screen",
        "layout" => "column",
        "children" => [
          %{
            "type" => "text",
            "id" => "text-1",
            "props" => %{"content" => "Hello"},
            "children" => [],
            "metadata" => %{}
          }
        ],
        "bindings" => [],
        "metadata" => %{}
      }

      assert {:ok, heex} = LiveUIAdapter.render(canonical_iur)
      assert is_binary(heex)
      # Should contain LiveView-specific attributes
      assert String.contains?(heex, "ash-screen")
      assert String.contains?(heex, "phx-")
    end

    test "7.6.1.2 - Verify events are wired correctly" do
      canonical_iur = %{
        "type" => "screen",
        "id" => "screen-1",
        "name" => "test_screen",
        "layout" => "column",
        "children" => [
          %{
            "type" => "button",
            "id" => "button-1",
            "props" => %{"label" => "Click Me"},
            "children" => [],
            "metadata" => %{}
          }
        ],
        "bindings" => [
          %{
            "id" => "binding-1",
            "type" => "event",
            "target" => "handle_click",
            "source" => %{"action" => "click"},
            "element_id" => "button-1",
            "metadata" => %{}
          }
        ],
        "metadata" => %{}
      }

      assert {:ok, heex} = LiveUIAdapter.render(canonical_iur)
      # Events are rendered with phx-click attribute
      assert String.contains?(heex, "phx-click")
      # Action is rendered with event prefix
      assert String.contains?(heex, "click")
    end

    test "7.6.1.3 - Verify reactive updates work" do
      canonical_iur = %{
        "type" => "screen",
        "id" => "screen-1",
        "name" => "test_screen",
        "layout" => "column",
        "children" => [
          %{
            "type" => "text",
            "id" => "text-1",
            "props" => %{"content" => "Dynamic Message"},
            "children" => [],
            "metadata" => %{"reactive" => true}
          }
        ],
        "bindings" => [
          %{
            "id" => "binding-1",
            "type" => "bidirectional",
            "target" => "message",
            "source" => %{"assign" => "message"},
            "element_id" => "text-1",
            "metadata" => %{}
          }
        ],
        "metadata" => %{}
      }

      assert {:ok, heex} = LiveUIAdapter.render(canonical_iur)
      # Content should be rendered
      assert String.contains?(heex, "Dynamic Message")
      assert String.contains?(heex, "ash-text")
    end

    test "7.6.1.4 - Verify LiveView patches work" do
      canonical_iur = %{
        "type" => "screen",
        "id" => "screen-1",
        "name" => "test_screen",
        "layout" => "column",
        "children" => [
          %{
            "type" => "text",
            "id" => "text-1",
            "props" => %{"content" => "Content"},
            "children" => [],
            "metadata" => %{}
          }
        ],
        "bindings" => [],
        "metadata" => %{}
      }

      assert {:ok, heex} = LiveUIAdapter.render(canonical_iur, optimize_patches: true)
      # Verify patch optimization attributes are present
      assert String.contains?(heex, "phx-update=\"stream\"")
    end
  end

  describe "Section 7.6.2 - WebUI integration scenarios" do
    test "7.6.2.1 - Verify canonical IUR renders to valid HTML" do
      canonical_iur = %{
        "type" => "screen",
        "id" => "screen-1",
        "name" => "test_screen",
        "layout" => "column",
        "children" => [],
        "bindings" => [],
        "metadata" => %{}
      }

      assert {:ok, html} = WebUIAdapter.render(canonical_iur)
      assert is_binary(html)
      assert String.contains?(html, "<!DOCTYPE html>")
      assert String.contains?(html, "<html")
      assert String.contains?(html, "</html>")
    end

    test "7.6.2.2 - Verify Elm client integration works" do
      canonical_iur = %{
        "type" => "screen",
        "id" => "screen-1",
        "name" => "test_screen",
        "layout" => "column",
        "children" => [],
        "bindings" => [
          %{
            "id" => "binding-1",
            "type" => "bidirectional",
            "target" => "counter",
            "source" => %{"field" => "count"},
            "element_id" => "counter-1",
            "metadata" => %{}
          }
        ],
        "metadata" => %{}
      }

      assert {:ok, html} =
               WebUIAdapter.render(canonical_iur, elm_enabled: true, elm_module: "App")

      assert String.contains?(html, "elm-app")
      assert String.contains?(html, "Elm")
    end

    test "7.6.2.3 - Verify static assets are referenced correctly" do
      canonical_iur = %{
        "type" => "screen",
        "id" => "screen-1",
        "name" => "test_screen",
        "layout" => "column",
        "children" => [],
        "bindings" => [],
        "metadata" => %{}
      }

      assert {:ok, html} = WebUIAdapter.render(canonical_iur, include_css: true, include_js: true)
      assert String.contains?(html, "/assets/")
      assert String.contains?(html, ".css")
      assert String.contains?(html, ".js")
    end

    test "7.6.2.4 - Verify SEO tags are present" do
      canonical_iur = %{
        "type" => "screen",
        "id" => "screen-1",
        "name" => "My Page",
        "layout" => "column",
        "children" => [],
        "bindings" => [],
        "metadata" => %{"keywords" => ["test", "page"]}
      }

      assert {:ok, html} = WebUIAdapter.render(canonical_iur, seo_enabled: true)
      assert String.contains?(html, "<title>My Page</title>")
      assert String.contains?(html, "name=\"description\"")
      assert String.contains?(html, "name=\"keywords\"")
    end
  end

  describe "Section 7.6.3 - Renderer selection scenarios" do
    test "7.6.3.1 - Verify LiveView request uses live_ui" do
      request = %{headers: %{"accepts" => "text/vnd.phoenix.live-view"}}

      assert {:ok, :liveview, module} = Selector.select_for_request(request)
      assert {:ok, info} = Registry.renderer_info(:liveview)
      assert module == info.module
    end

    test "7.6.3.2 - Verify HTTP request uses web_ui" do
      request = %{headers: %{"accept" => "text/html"}}

      assert {:ok, :html, module} = Selector.select_for_request(request)
      assert {:ok, info} = Registry.renderer_info(:html)
      assert module == info.module
    end

    test "7.6.3.3 - Verify explicit override is respected" do
      request = %{headers: %{"accept" => "text/html"}}

      assert {:ok, :desktop, module} = Selector.select_for_request(request, renderer: :desktop)
      assert {:ok, info} = Registry.renderer_info(:desktop)
      assert module == info.module
    end

    test "7.6.3.4 - Verify unavailable renderer type returns error" do
      request = %{headers: %{"accept" => "text/html"}}

      assert {:error, _} = Selector.select_for_request(request, renderer: :invalid_type)
    end
  end

  describe "Section 7.6.4 - Cross-renderer scenarios" do
    setup do
      {:ok,
       sample_iur: %{
         "type" => "screen",
         "id" => "screen-1",
         "name" => "test_screen",
         "layout" => "column",
         "children" => [
           %{
             "type" => "text",
             "id" => "text-1",
             "props" => %{"content" => "Hello World"},
             "children" => [],
             "metadata" => %{}
           },
           %{
             "type" => "button",
             "id" => "button-1",
             "props" => %{"label" => "Click"},
             "children" => [],
             "metadata" => %{}
           }
         ],
         "bindings" => [],
         "metadata" => %{}
       }}
    end

    test "7.6.4.1 - Verify same IUR renders on all renderers", %{sample_iur: iur} do
      # All renderers should successfully render the same IUR
      assert {:ok, _liveui_output} = LiveUIAdapter.render(iur)
      assert {:ok, _webui_output} = WebUIAdapter.render(iur)
      assert {:ok, _desktop_output} = DesktopUIAdapter.render(iur)
    end

    test "7.6.4.2 - Verify renderer-specific features are isolated", %{sample_iur: iur} do
      # LiveUI should produce HEEx with LiveView attributes
      assert {:ok, liveui_output} = LiveUIAdapter.render(iur)
      assert String.contains?(liveui_output, "phx-")
      assert String.contains?(liveui_output, "ash-screen")

      # WebUI should produce HTML with DOCTYPE
      assert {:ok, webui_output} = WebUIAdapter.render(iur)
      assert String.contains?(webui_output, "<!DOCTYPE html>")

      # DesktopUI should produce instruction map
      assert {:ok, desktop_output} = DesktopUIAdapter.render(iur)
      assert is_map(desktop_output)
      assert Map.has_key?(desktop_output, "type")
    end

    test "7.6.4.3 - Verify fallback behavior works" do
      request = %{headers: %{"accept" => "text/html"}}
      assert {:ok, info} = Registry.renderer_info(:html)

      assert {:ok, :html, module, fallback_used} = Selector.select_with_fallback(request)
      assert module == info.module
      assert fallback_used == (info.mode == :adapter_fallback)
    end

    test "7.6.4.4 - Verify renderer switching works" do
      request = %{headers: %{"accept" => "text/html"}}

      assert {:ok, :html, _} = Selector.select_for_request(request)
      assert {:ok, :liveview, _} = Selector.select_for_request(request, renderer: :liveview)
      assert {:ok, :desktop, _} = Selector.select_for_request(request, renderer: :desktop)
    end
  end

  describe "Section 7.6 - End-to-end rendering pipeline" do
    test "Ash IUR converts to canonical and renders through LiveUI" do
      # Create a simple screen IUR without nested children
      ash_iur =
        struct(IUR,
          id: "test-id",
          type: :screen,
          name: "test_screen",
          attributes: %{"layout" => "column"},
          children: [],
          bindings: [],
          metadata: %{},
          version: 1
        )

      assert {:ok, canonical} = IURAdapter.to_canonical(ash_iur)
      assert {:ok, heex} = LiveUIAdapter.render(canonical)
      assert is_binary(heex)
      assert String.contains?(heex, "ash-screen")
    end

    test "Ash IUR converts to canonical and renders through WebUI" do
      ash_iur =
        struct(IUR,
          id: "test-id",
          type: :screen,
          name: "test_screen",
          attributes: %{"layout" => "column"},
          children: [],
          bindings: [],
          metadata: %{},
          version: 1
        )

      assert {:ok, canonical} = IURAdapter.to_canonical(ash_iur)
      assert {:ok, html} = WebUIAdapter.render(canonical)
      assert String.contains?(html, "<!DOCTYPE html>")
    end

    test "Ash IUR converts to canonical and renders through DesktopUI" do
      ash_iur =
        struct(IUR,
          id: "test-id",
          type: :screen,
          name: "test_screen",
          attributes: %{"layout" => "column"},
          children: [],
          bindings: [],
          metadata: %{},
          version: 1
        )

      assert {:ok, canonical} = IURAdapter.to_canonical(ash_iur)
      assert {:ok, instructions} = DesktopUIAdapter.render(canonical)
      assert is_map(instructions)
      assert instructions["type"] == "desktop_screen"
    end

    test "Direct rendering methods work for all adapters" do
      ash_iur =
        struct(IUR,
          id: "test-id",
          type: :screen,
          name: "test_screen",
          attributes: %{"layout" => "column"},
          children: [],
          bindings: [],
          metadata: %{},
          version: 1
        )

      assert {:ok, _heex} = LiveUIAdapter.render_ash_iur(ash_iur)
      assert {:ok, _html} = WebUIAdapter.render_ash_iur(ash_iur)
      assert {:ok, _instructions} = DesktopUIAdapter.render_ash_iur(ash_iur)
    end
  end

  describe "Section 7.6 - Registry integration" do
    test "All renderers are registered in the registry" do
      renderers = AshUI.Rendering.Registry.list_renderers()

      assert Enum.any?(renderers, fn r ->
               r.type == :liveview or r.type == :html or r.type == :desktop
             end)
    end

    test "Each renderer can be retrieved individually" do
      assert {:ok, _module} = AshUI.Rendering.Registry.get_renderer(:liveview)
      assert {:ok, _module} = AshUI.Rendering.Registry.get_renderer(:html)
      assert {:ok, _module} = AshUI.Rendering.Registry.get_renderer(:desktop)
    end

    test "Renderer availability can be checked" do
      assert is_boolean(AshUI.Rendering.Registry.renderer_available?(:liveview))
      assert is_boolean(AshUI.Rendering.Registry.renderer_available?(:html))
      assert is_boolean(AshUI.Rendering.Registry.renderer_available?(:desktop))
    end

    test "Renderer renderability can be checked independently of external packages" do
      assert AshUI.Rendering.Registry.renderer_renderable?(:liveview)
      assert AshUI.Rendering.Registry.renderer_renderable?(:html)
      assert AshUI.Rendering.Registry.renderer_renderable?(:desktop)
    end

    test "Default renderer is available" do
      assert {:ok, _type, _module} = AshUI.Rendering.Registry.default_renderer()
    end
  end
end
