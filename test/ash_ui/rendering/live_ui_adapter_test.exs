defmodule AshUI.Rendering.LiveUIAdapterTest do
  use ExUnit.Case, async: true

  alias AshUI.Rendering.LiveUIAdapter
  alias AshUI.Compilation.IUR

  describe "Section 7.2.1 - LiveUI Renderer Adapter" do
    test "render/2 returns HEEx for screen IUR" do
      canonical_iur = %{
        "type" => "screen",
        "id" => "screen-1",
        "name" => "test_screen",
        "layout" => "column",
        "children" => [
          %{"type" => "text", "id" => "text-1", "props" => %{"content" => "Hello"}, "children" => [], "metadata" => %{}}
        ],
        "bindings" => [],
        "metadata" => %{}
      }

      assert {:ok, heex} = LiveUIAdapter.render(canonical_iur)
      assert is_binary(heex)
      assert String.contains?(heex, "ash-screen")
      assert String.contains?(heex, "test_screen")
    end

    test "render/2 accepts options" do
      canonical_iur = %{
        "type" => "screen",
        "id" => "screen-1",
        "name" => "test_screen",
        "layout" => "column",
        "children" => [],
        "bindings" => [],
        "metadata" => %{}
      }

      assert {:ok, heex} = LiveUIAdapter.render(canonical_iur, optimize_patches: false)
      assert is_binary(heex)
      assert String.contains?(heex, "ash-screen")
    end

    test "available?/0 returns boolean" do
      result = LiveUIAdapter.available?()
      assert is_boolean(result)
    end

    test "render_ash_iur/2 converts and renders Ash IUR" do
      ash_iur = struct(IUR,
        id: "test-id",
        type: :screen,
        name: "test_screen",
        attributes: %{"layout" => :row},
        children: [],
        bindings: [],
        metadata: %{},
        version: 1
      )

      assert {:ok, heex} = LiveUIAdapter.render_ash_iur(ash_iur)
      assert is_binary(heex)
      assert String.contains?(heex, "ash-screen")
    end
  end

  describe "Section 7.2.2 - LiveUI-specific Features" do
    setup do
      {:ok, canonical_iur: %{
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
          },
          %{
            "type" => "input",
            "id" => "input-1",
            "props" => %{"name" => "username"},
            "children" => [],
            "metadata" => %{}
          }
        ],
        "bindings" => [
          %{
            "id" => "binding-1",
            "type" => "bidirectional",
            "target" => "username",
            "source" => %{"resource" => "User", "field" => "name"},
            "element_id" => "input-1",
            "metadata" => %{}
          }
        ],
        "metadata" => %{}
      }}
    end

    test "configure_event_bindings/2 extracts click events", %{canonical_iur: iur} do
      config = LiveUIAdapter.configure_event_bindings(iur, event_prefix: "ash")

      assert is_list(config.events)
      assert config.event_prefix == "ash"

      click_events = Enum.filter(config.events, fn e ->
        String.contains?(e.event, "click")
      end)

      assert length(click_events) > 0
    end

    test "configure_event_bindings/2 extracts blur and change events", %{canonical_iur: iur} do
      config = LiveUIAdapter.configure_event_bindings(iur)

      blur_events = Enum.filter(config.events, fn e ->
        String.contains?(e.event, "blur")
      end)

      change_events = Enum.filter(config.events, fn e ->
        String.contains?(e.event, "change")
      end)

      assert length(blur_events) > 0
      assert length(change_events) > 0
    end

    test "configure_hooks/2 returns default hooks", %{canonical_iur: iur} do
      hooks = LiveUIAdapter.configure_hooks(iur)

      assert is_list(hooks)

      lifecycle_hook = Enum.find(hooks, fn h -> h.name == :ash_ui_lifecycle end)
      assert lifecycle_hook != nil
      assert lifecycle_hook.on_mount == {AshUI.LiveView.Hooks, :on_mount_ash_ui}
    end

    test "configure_hooks/2 includes patch hooks when optimize_patches is true", %{canonical_iur: iur} do
      hooks = LiveUIAdapter.configure_hooks(iur, optimize_patches: true)

      patch_hook = Enum.find(hooks, fn h -> h.name == :ash_ui_patches end)
      assert patch_hook != nil
    end

    test "configure_hooks/2 excludes patch hooks when optimize_patches is false", %{canonical_iur: iur} do
      hooks = LiveUIAdapter.configure_hooks(iur, optimize_patches: false)

      patch_hook = Enum.find(hooks, fn h -> h.name == :ash_ui_patches end)
      assert patch_hook == nil
    end

    test "configure_assigns/2 extracts binding assigns", %{canonical_iur: iur} do
      assigns = LiveUIAdapter.configure_assigns(iur)

      assert is_map(assigns)
      assert Map.has_key?(assigns, "username")
    end

    test "configure_assigns/2 merges initial assigns", %{canonical_iur: iur} do
      assigns = LiveUIAdapter.configure_assigns(iur, assigns: %{custom: "value"})

      assert assigns.custom == "value"
      assert Map.has_key?(assigns, "username")
    end

    test "configure_patch_optimization/2 returns optimization config", %{canonical_iur: iur} do
      config = LiveUIAdapter.configure_patch_optimization(iur)

      assert config.enabled == true
      assert is_list(config.static_ids)
      assert is_list(config.dynamic_streams)
    end

    test "configure_patch_optimization/2 respects optimize_patches option", %{canonical_iur: iur} do
      config = LiveUIAdapter.configure_patch_optimization(iur, optimize_patches: false)

      assert config.enabled == false
    end
  end

  describe "Section 7.2.2 - HEEx Generation" do
    test "generates button with phx-click attribute" do
      iur = %{
        "type" => "button",
        "id" => "btn-1",
        "props" => %{"label" => "Submit"},
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur)
      assert String.contains?(heex, "phx-click")
      assert String.contains?(heex, "Submit")
    end

    test "generates input with phx-blur and phx-change attributes" do
      iur = %{
        "type" => "input",
        "id" => "input-1",
        "props" => %{"name" => "email"},
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur)
      assert String.contains?(heex, "phx-blur")
      assert String.contains?(heex, "phx-change")
      assert String.contains?(heex, "name=\"email\"")
    end

    test "generates checkbox with phx-click attribute" do
      iur = %{
        "type" => "checkbox",
        "id" => "check-1",
        "props" => %{"name" => "agree"},
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur)
      assert String.contains?(heex, "type=\"checkbox\"")
      assert String.contains?(heex, "phx-click")
    end

    test "generates select with options" do
      iur = %{
        "type" => "select",
        "id" => "select-1",
        "props" => %{"name" => "country", "options" => ["USA", "Canada", "Mexico"]},
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur)
      assert String.contains?(heex, "<select")
      assert String.contains?(heex, "USA")
      assert String.contains?(heex, "Canada")
      assert String.contains?(heex, "Mexico")
    end

    test "generates row with gap style" do
      iur = %{
        "type" => "row",
        "id" => "row-1",
        "props" => %{"spacing" => 16},
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur)
      assert String.contains?(heex, "ash-row")
      assert String.contains?(heex, "gap: 16px")
    end

    test "generates column with gap style" do
      iur = %{
        "type" => "column",
        "id" => "col-1",
        "props" => %{"spacing" => 24},
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur)
      assert String.contains?(heex, "ash-column")
      assert String.contains?(heex, "gap: 24px")
    end

    test "generates text with font size and color" do
      iur = %{
        "type" => "text",
        "id" => "text-1",
        "props" => %{"content" => "Hello World", "size" => 18, "color" => "blue"},
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur)
      assert String.contains?(heex, "Hello World")
      assert String.contains?(heex, "font-size: 18px")
      assert String.contains?(heex, "color: blue")
    end
  end

  describe "Section 7.2.1 - Event Binding Configuration" do
    test "build_event_handlers creates handler maps" do
      iur = %{
        "type" => "screen",
        "id" => "screen-1",
        "name" => "test",
        "layout" => "column",
        "children" => [
          %{
            "type" => "button",
            "id" => "btn-1",
            "props" => %{},
            "children" => [],
            "metadata" => %{}
          }
        ],
        "bindings" => [],
        "metadata" => %{}
      }

      config = LiveUIAdapter.configure_event_bindings(iur)

      assert is_list(config.events)
      assert is_list(config.handlers)

      if length(config.handlers) > 0 do
        handler = hd(config.handlers)
        assert Map.has_key?(handler, :event)
        assert Map.has_key?(handler, :handler)
        assert Map.has_key?(handler, :target)
      end
    end
  end
end
