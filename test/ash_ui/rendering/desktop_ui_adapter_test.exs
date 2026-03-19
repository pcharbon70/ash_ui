defmodule AshUI.Rendering.DesktopUIAdapterTest do
  use ExUnit.Case, async: true

  alias AshUI.Rendering.DesktopUIAdapter
  alias AshUI.Compilation.IUR

  describe "Section 7.4.1 - DesktopUI Renderer Adapter" do
    test "render/2 returns desktop UI instructions for screen IUR" do
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

      assert {:ok, instructions} = DesktopUIAdapter.render(canonical_iur)
      assert is_map(instructions)
      assert instructions["type"] == "desktop_screen"
      assert instructions["id"] == "screen-1"
      assert instructions["name"] == "test_screen"
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

      assert {:ok, instructions} = DesktopUIAdapter.render(canonical_iur, window_width: 1920)
      # The window key should exist for screen types
      window = Map.get(instructions, "window") || Map.get(instructions, :window)
      assert window != nil, "Expected window to be present, got: #{inspect(instructions)}"
      assert Map.get(window, "width") || Map.get(window, :width) == 1920
    end

    test "available?/0 returns boolean" do
      result = DesktopUIAdapter.available?()
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

      assert {:ok, instructions} = DesktopUIAdapter.render_ash_iur(ash_iur)
      assert is_map(instructions)
      assert instructions["type"] == "desktop_screen"
    end
  end

  describe "Section 7.4.2 - DesktopUI-specific Features" do
    setup do
      {:ok, canonical_iur: %{
        "type" => "screen",
        "id" => "screen-1",
        "name" => "main_app",
        "layout" => "column",
        "children" => [
          %{
            "type" => "button",
            "id" => "button-1",
            "props" => %{"label" => "Click Me", "variant" => :primary},
            "children" => [],
            "metadata" => %{}
          },
          %{
            "type" => "input",
            "id" => "input-1",
            "props" => %{"name" => "username", "placeholder" => "Enter username"},
            "children" => [],
            "metadata" => %{}
          }
        ],
        "bindings" => [
          %{
            "id" => "binding-1",
            "type" => "event",
            "target" => "save_action",
            "source" => %{"action" => "save"},
            "element_id" => "button-1",
            "metadata" => %{}
          }
        ],
        "metadata" => %{}
      }}
    end

    test "configure_window/2 generates window configuration" do
      config = DesktopUIAdapter.configure_window(%{
        "type" => "screen",
        "id" => "s1",
        "name" => "test",
        "layout" => "column",
        "children" => [],
        "bindings" => [],
        "metadata" => %{}
      })

      assert config.width == 1280
      assert config.height == 720
      assert config.resizable == true
      assert config.title == "test"
      assert config.position == :center
    end

    test "configure_window/2 respects custom options" do
      config = DesktopUIAdapter.configure_window(%{
        "type" => "screen",
        "id" => "s1",
        "name" => "test",
        "layout" => "column",
        "children" => [],
        "bindings" => [],
        "metadata" => %{}
      }, window_width: 1920, window_height: 1080, window_resizable: false)

      assert config.width == 1920
      assert config.height == 1080
      assert config.resizable == false
    end

    test "configure_menu_bar/2 generates menu bar configuration" do
      config = DesktopUIAdapter.configure_menu_bar(%{
        "type" => "screen",
        "id" => "s1",
        "name" => "test",
        "layout" => "column",
        "children" => [],
        "bindings" => [],
        "metadata" => %{}
      })

      assert config.enabled == true
      assert is_list(config.items)
      assert length(config.items) > 0

      file_menu = Enum.find(config.items, fn item ->
        is_map(item) and Map.get(item, :label) == "File"
      end)

      assert file_menu != nil
      assert is_list(file_menu[:items])
    end

    test "configure_menu_bar/2 can be disabled" do
      config = DesktopUIAdapter.configure_menu_bar(%{
        "type" => "screen",
        "id" => "s1",
        "name" => "test",
        "layout" => "column",
        "children" => [],
        "bindings" => [],
        "metadata" => %{}
      }, native_menu_bar: false)

      assert config.enabled == false
      assert config.items == []
    end

    test "configure_menu_bar/2 includes default menu items" do
      config = DesktopUIAdapter.configure_menu_bar(%{
        "type" => "screen",
        "id" => "s1",
        "name" => "test",
        "layout" => "column",
        "children" => [],
        "bindings" => [],
        "metadata" => %{}
      })

      file_menu = Enum.find(config.items, fn item -> Map.get(item, :label) == "File" end)
      edit_menu = Enum.find(config.items, fn item -> Map.get(item, :label) == "Edit" end)
      view_menu = Enum.find(config.items, fn item -> Map.get(item, :label) == "View" end)

      assert file_menu != nil
      assert edit_menu != nil
      assert view_menu != nil

      # Check File menu has Quit
      quit_item = Enum.find(file_menu[:items], fn item ->
        is_map(item) and Map.get(item, :action) == "app_quit"
      end)
      assert quit_item != nil
    end

    test "configure_platform/2 detects platform" do
      config = DesktopUIAdapter.configure_platform(%{
        "type" => "screen",
        "id" => "s1",
        "name" => "test",
        "layout" => "column",
        "children" => [],
        "bindings" => [],
        "metadata" => %{}
      })

      assert is_atom(config.target)
      assert config.target in [:macos, :windows, :linux]
      assert is_map(config.features)
    end

    test "configure_platform/2 respects explicit platform" do
      config = DesktopUIAdapter.configure_platform(%{
        "type" => "screen",
        "id" => "s1",
        "name" => "test",
        "layout" => "column",
        "children" => [],
        "bindings" => [],
        "metadata" => %{}
      }, platform: :windows)

      assert config.target == :windows
      assert Map.has_key?(config.features, :snap_layouts)
    end

    test "configure_events/2 extracts event handlers from bindings", %{canonical_iur: iur} do
      config = DesktopUIAdapter.configure_events(iur)

      assert is_list(config.handlers)
      assert length(config.handlers) > 0

      handler = hd(config.handlers)
      assert handler.event == "save_action"
      assert handler.action == "save"
      assert handler.element_id == "button-1"
    end

    test "configure_events/2 enables shortcuts by default" do
      config = DesktopUIAdapter.configure_events(%{
        "type" => "screen",
        "id" => "s1",
        "name" => "test",
        "layout" => "column",
        "children" => [],
        "bindings" => [],
        "metadata" => %{}
      })

      assert config.enable_shortcuts == true
      assert config.enable_drag_drop == false
    end
  end

  describe "Section 7.4.1 - Widget Generation" do
    test "generates hbox from row widget" do
      iur = %{
        "type" => "row",
        "id" => "row-1",
        "props" => %{"spacing" => 16, "align" => :center},
        "children" => [],
        "metadata" => %{}
      }

      {:ok, instructions} = DesktopUIAdapter.render(iur)
      assert instructions["type"] == "hbox"
      assert instructions["spacing"] == 16
      assert instructions["align"] == :center
    end

    test "generates vbox from column widget" do
      iur = %{
        "type" => "column",
        "id" => "col-1",
        "props" => %{"spacing" => 24},
        "children" => [],
        "metadata" => %{}
      }

      {:ok, instructions} = DesktopUIAdapter.render(iur)
      assert instructions["type"] == "vbox"
      assert instructions["spacing"] == 24
    end

    test "generates label from text widget" do
      iur = %{
        "type" => "text",
        "id" => "text-1",
        "props" => %{"content" => "Hello World", "size" => 18, "weight" => :bold},
        "children" => [],
        "metadata" => %{}
      }

      {:ok, instructions} = DesktopUIAdapter.render(iur)
      assert instructions["type"] == "label"
      assert instructions["text"] == "Hello World"
      assert instructions["font_size"] == 18
      assert instructions["font_weight"] == :bold
    end

    test "generates button widget" do
      iur = %{
        "type" => "button",
        "id" => "btn-1",
        "props" => %{"label" => "Submit", "variant" => :primary},
        "children" => [],
        "metadata" => %{}
      }

      {:ok, instructions} = DesktopUIAdapter.render(iur)
      assert instructions["type"] == "button"
      assert instructions["label"] == "Submit"
      assert instructions["variant"] == :primary
    end

    test "generates text_input from input widget" do
      iur = %{
        "type" => "input",
        "id" => "input-1",
        "props" => %{"name" => "email", "placeholder" => "Enter email"},
        "children" => [],
        "metadata" => %{}
      }

      {:ok, instructions} = DesktopUIAdapter.render(iur)
      assert instructions["type"] == "text_input"
      assert instructions["name"] == "email"
      assert instructions["placeholder"] == "Enter email"
    end

    test "generates checkbox widget" do
      iur = %{
        "type" => "checkbox",
        "id" => "check-1",
        "props" => %{"name" => "agree"},
        "children" => [],
        "metadata" => %{}
      }

      {:ok, instructions} = DesktopUIAdapter.render(iur)
      assert instructions["type"] == "checkbox"
      assert instructions["name"] == "agree"
    end

    test "generates dropdown from select widget" do
      iur = %{
        "type" => "select",
        "id" => "select-1",
        "props" => %{"name" => "country", "options" => ["USA", "Canada"]},
        "children" => [],
        "metadata" => %{}
      }

      {:ok, instructions} = DesktopUIAdapter.render(iur)
      assert instructions["type"] == "dropdown"
      assert instructions["name"] == "country"
      assert instructions["options"] == ["USA", "Canada"]
    end

    test "generates container for unknown widget types" do
      iur = %{
        "type" => "custom_widget",
        "id" => "custom-1",
        "props" => %{},
        "children" => [],
        "metadata" => %{}
      }

      {:ok, instructions} = DesktopUIAdapter.render(iur)
      assert instructions["type"] == "container"
      assert instructions["widget_type"] == "custom_widget"
    end
  end

  describe "Section 7.4.2 - Platform-Specific Features" do
    test "macOS platform includes touch bar feature" do
      config = DesktopUIAdapter.configure_platform(%{
        "type" => "screen",
        "id" => "s1",
        "name" => "test",
        "layout" => "column",
        "children" => [],
        "bindings" => [],
        "metadata" => %{}
      }, platform: :macos)

      assert config.target == :macos
      assert config.features.touch_bar == true
      assert config.features.native_titlebar == true
    end

    test "Windows platform includes mica material feature" do
      config = DesktopUIAdapter.configure_platform(%{
        "type" => "screen",
        "id" => "s1",
        "name" => "test",
        "layout" => "column",
        "children" => [],
        "bindings" => [],
        "metadata" => %{}
      }, platform: :windows)

      assert config.target == :windows
      assert config.features.mica_material == true
      assert config.features.snap_layouts == true
    end

    test "Linux platform includes app menu feature" do
      config = DesktopUIAdapter.configure_platform(%{
        "type" => "screen",
        "id" => "s1",
        "name" => "test",
        "layout" => "column",
        "children" => [],
        "bindings" => [],
        "metadata" => %{}
      }, platform: :linux)

      assert config.target == :linux
      assert config.features.app_menu == true
    end
  end
end
