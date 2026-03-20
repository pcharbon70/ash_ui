defmodule AshUI.Rendering.DesktopUIAdapter do
  @moduledoc """
  Adapter for DesktopUI renderer package.

  This module provides integration with the desktop_ui package for rendering
  to native desktop UI instructions. When the desktop_ui package is not
  available, this module provides stub implementations.

  ## DesktopUI-Specific Features

  This adapter supports:
  - SDL2 window properties configuration
  - Native menu bar generation
  - Platform-specific features (Windows, macOS, Linux)
  - Desktop event handling

  If DesktopUI.Renderer is available, delegates to it. Otherwise, provides
  fallback implementation using the IURAdapter.
  """

  alias AshUI.Rendering.IURAdapter
  alias AshUI.Compilation.IUR
  alias AshUI.Telemetry

  @doc """
  Renders a canonical IUR to desktop UI instructions.

  ## Parameters
    * `canonical_iur` - Canonical IUR map from IURAdapter
    * `opts` - Rendering options

  ## Options
    * `:window_width` - Window width in pixels (default: 1280)
    * `:window_height` - Window height in pixels (default: 720)
    * `:window_resizable` - Allow window resizing (default: true)
    * `:window_title` - Window title (default: from IUR)
    * `:native_menu_bar` - Include native menu bar (default: true)
    * `:platform` - Target platform (:auto, :windows, :macos, :linux)

  ## Returns
    * `{:ok, instructions}` - Desktop UI instruction map
    * `{:error, reason}` - Rendering failed
  """
  @spec render(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def render(canonical_iur, opts \\ []) when is_map(canonical_iur) do
    started_at = System.monotonic_time()
    metadata = render_metadata(canonical_iur, :desktop_ui)
    Telemetry.emit(:render, :start, %{count: 1}, metadata)

    result =
      if Code.ensure_loaded?(DesktopUI.Renderer) do
        call_desktop_ui_renderer(canonical_iur, opts)
      else
        render_fallback(canonical_iur, opts)
      end

    emit_render_telemetry(result, started_at, metadata)
  end

  @doc """
  Checks if DesktopUI renderer is available.

  ## Returns
    * `true` - DesktopUI.Renderer is available
    * `false` - DesktopUI.Renderer is not available
  """
  @spec available?() :: boolean()
  def available? do
    Code.ensure_loaded?(desktop_ui_renderer_module())
  end

  @doc """
  Converts an Ash IUR to DesktopUI-compatible format and renders.

  ## Parameters
    * `ash_iur` - Ash IUR structure
    * `opts` - Rendering options

  ## Returns
    * `{:ok, instructions}` - Desktop UI instruction map
    * `{:error, reason}` - Rendering failed
  """
  @spec render_ash_iur(IUR.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def render_ash_iur(%IUR{} = ash_iur, opts \\ []) do
    with {:ok, canonical_iur} <- IURAdapter.to_canonical(ash_iur, opts),
         {:ok, instructions} <- render(canonical_iur, opts) do
      {:ok, instructions}
    else
      error -> error
    end
  end

  @doc """
  Configures SDL2 window properties.

  ## Parameters
    * `canonical_iur` - Canonical IUR map
    * `opts` - Options

  ## Returns
    * Window configuration map
  """
  @spec configure_window(map(), keyword()) :: map()
  def configure_window(%{"type" => "screen"} = iur, opts \\ []) do
    width = Keyword.get(opts, :window_width, 1280)
    height = Keyword.get(opts, :window_height, 720)
    resizable = Keyword.get(opts, :window_resizable, true)
    title = Keyword.get(opts, :window_title, Map.get(iur, "name", "AshUI App"))
    fullscreen = Keyword.get(opts, :fullscreen, false)
    borderless = Keyword.get(opts, :borderless, false)

    %{
      width: width,
      height: height,
      resizable: resizable,
      title: title,
      fullscreen: fullscreen,
      borderless: borderless,
      position: Keyword.get(opts, :window_position, :center),
      minimum_size: Keyword.get(opts, :minimum_size, nil),
      maximum_size: Keyword.get(opts, :maximum_size, nil)
    }
  end

  @doc """
  Configures native menu bar.

  ## Parameters
    * `canonical_iur` - Canonical IUR map
    * `opts` - Options

  ## Returns
    * Menu bar configuration
  """
  @spec configure_menu_bar(map(), keyword()) :: map()
  def configure_menu_bar(%{"type" => "screen"} = _iur, opts \\ []) do
    enabled = Keyword.get(opts, :native_menu_bar, true)
    custom_items = Keyword.get(opts, :menu_items, [])

    default_items =
      if enabled do
        [
          %{
            label: "File",
            items: [
              %{label: "New", action: "file_new", shortcut: "CmdOrCtrl+N"},
              %{label: "Open", action: "file_open", shortcut: "CmdOrCtrl+O"},
              :separator,
              %{label: "Save", action: "file_save", shortcut: "CmdOrCtrl+S"},
              %{label: "Save As", action: "file_save_as", shortcut: "CmdOrCtrl+Shift+S"},
              :separator,
              %{label: "Quit", action: "app_quit", shortcut: "CmdOrCtrl+Q"}
            ]
          },
          %{
            label: "Edit",
            items: [
              %{label: "Undo", action: "edit_undo", shortcut: "CmdOrCtrl+Z"},
              %{label: "Redo", action: "edit_redo", shortcut: "CmdOrCtrl+Shift+Z"},
              :separator,
              %{label: "Cut", action: "edit_cut", shortcut: "CmdOrCtrl+X"},
              %{label: "Copy", action: "edit_copy", shortcut: "CmdOrCtrl+C"},
              %{label: "Paste", action: "edit_paste", shortcut: "CmdOrCtrl+V"},
              :separator,
              %{label: "Select All", action: "edit_select_all", shortcut: "CmdOrCtrl+A"}
            ]
          },
          %{
            label: "View",
            items: [
              %{label: "Reload", action: "view_reload", shortcut: "F5"},
              %{label: "Toggle Fullscreen", action: "view_fullscreen", shortcut: "F11"},
              :separator,
              %{label: "Developer Tools", action: "view_devtools", shortcut: "CmdOrCtrl+Shift+I"}
            ]
          }
        ]
      else
        []
      end

    %{
      enabled: enabled,
      items: default_items ++ custom_items
    }
  end

  @doc """
  Configures platform-specific features.

  ## Parameters
    * `canonical_iur` - Canonical IUR map
    * `opts` - Options

  ## Returns
    * Platform configuration
  """
  @spec configure_platform(map(), keyword()) :: map()
  def configure_platform(%{"type" => "screen"} = _iur, opts \\ []) do
    platform = Keyword.get(opts, :platform, :auto)

    %{
      target: detect_platform(platform),
      features: platform_features(platform),
      native_integration: Keyword.get(opts, :native_integration, true)
    }
  end

  @doc """
  Configures desktop event handling.

  ## Parameters
    * `canonical_iur` - Canonical IUR map
    * `opts` - Options

  ## Returns
    * Event handling configuration
  """
  @spec configure_events(map(), keyword()) :: map()
  def configure_events(%{"type" => "screen"} = iur, opts \\ []) do
    bindings = Map.get(iur, "bindings", [])

    event_handlers =
      bindings
      |> Enum.filter(fn binding -> Map.get(binding, "type") == "event" end)
      |> Enum.map(fn binding ->
        %{
          event: Map.get(binding, "target"),
          action: get_in(binding, ["source", "action"]),
          element_id: Map.get(binding, "element_id")
        }
      end)

    %{
      handlers: event_handlers,
      enable_shortcuts: Keyword.get(opts, :enable_shortcuts, true),
      enable_drag_drop: Keyword.get(opts, :enable_drag_drop, false)
    }
  end

  # Private Functions

  defp desktop_ui_renderer_module do
    Module.concat(DesktopUI, Renderer)
  end

  # Call actual DesktopUI.Renderer if available
  defp call_desktop_ui_renderer(canonical_iur, opts) do
    renderer_module = desktop_ui_renderer_module()

    try do
      case apply(renderer_module, :render, [canonical_iur, opts]) do
        {:ok, instructions} -> {:ok, instructions}
        {:error, reason} -> {:error, {:desktop_ui_error, reason}}
        other -> {:error, {:unexpected_response, other}}
      end
    rescue
      error -> {:error, {:desktop_ui_exception, error}}
    end
  end

  # Fallback renderer when DesktopUI is not available
  defp render_fallback(canonical_iur, opts) do
    instructions = generate_instructions(canonical_iur, opts)
    {:ok, instructions}
  end

  # Generate desktop UI instructions from canonical IUR
  defp generate_instructions(%{"type" => "screen"} = iur, opts) do
    window = configure_window(iur, opts)
    menu_bar = configure_menu_bar(iur, opts)
    platform = configure_platform(iur, opts)
    events = configure_events(iur, opts)

    %{
      "type" => "desktop_screen",
      "id" => iur["id"],
      "name" => iur["name"],
      "window" => window,
      "menu_bar" => menu_bar,
      "platform" => platform,
      "events" => events,
      "content" => generate_content(iur["children"])
    }
  end

  defp generate_instructions(widget, _opts) do
    # Handle non-screen widgets (row, text, button, etc.)
    generate_widget(widget)
  end

  defp generate_content(nil), do: []
  defp generate_content([]), do: []

  defp generate_content(children) when is_list(children) do
    Enum.map(children, &generate_widget/1)
  end

  defp generate_widget(%{"type" => "row"} = widget) do
    %{
      "type" => "hbox",
      "id" => widget["id"],
      "spacing" => Map.get(widget["props"] || %{}, "spacing", 8),
      "align" => Map.get(widget["props"] || %{}, "align", :start),
      "children" => generate_content(widget["children"])
    }
  end

  defp generate_widget(%{"type" => "column"} = widget) do
    %{
      "type" => "vbox",
      "id" => widget["id"],
      "spacing" => Map.get(widget["props"] || %{}, "spacing", 8),
      "align" => Map.get(widget["props"] || %{}, "align", :start),
      "children" => generate_content(widget["children"])
    }
  end

  defp generate_widget(%{"type" => "text"} = widget) do
    content = Map.get(widget["props"] || %{}, "content", "")
    size = Map.get(widget["props"] || %{}, "size", 14)
    weight = Map.get(widget["props"] || %{}, "weight", :normal)

    %{
      "type" => "label",
      "id" => widget["id"],
      "text" => content,
      "font_size" => size,
      "font_weight" => weight
    }
  end

  defp generate_widget(%{"type" => "button"} = widget) do
    label = Map.get(widget["props"] || %{}, "label", "Button")
    on_click = Map.get(widget["props"] || %{}, "on_click", nil)

    %{
      "type" => "button",
      "id" => widget["id"],
      "label" => label,
      "on_click" => on_click,
      "variant" => Map.get(widget["props"] || %{}, "variant", :primary)
    }
  end

  defp generate_widget(%{"type" => "input"} = widget) do
    name = Map.get(widget["props"] || %{}, "name", "input")
    placeholder = Map.get(widget["props"] || %{}, "placeholder", "")

    %{
      "type" => "text_input",
      "id" => widget["id"],
      "name" => name,
      "placeholder" => placeholder
    }
  end

  defp generate_widget(%{"type" => "checkbox"} = widget) do
    name = Map.get(widget["props"] || %{}, "name", "checkbox")

    %{
      "type" => "checkbox",
      "id" => widget["id"],
      "name" => name
    }
  end

  defp generate_widget(%{"type" => "select"} = widget) do
    name = Map.get(widget["props"] || %{}, "name", "select")
    options = Map.get(widget["props"] || %{}, "options", [])

    %{
      "type" => "dropdown",
      "id" => widget["id"],
      "name" => name,
      "options" => options
    }
  end

  defp generate_widget(widget) do
    %{
      "type" => "container",
      "id" => widget["id"],
      "widget_type" => widget["type"],
      "children" => generate_content(widget["children"])
    }
  end

  # Platform detection
  defp detect_platform(:auto), do: :os.type() |> elem(1) |> detect_platform_from_os()
  defp detect_platform(platform) when is_atom(platform), do: platform

  defp detect_platform_from_os(:darwin), do: :macos
  defp detect_platform_from_os(:nt), do: :windows
  defp detect_platform_from_os(:linux), do: :linux
  defp detect_platform_from_os(_), do: :linux

  defp platform_features(platform) do
    case platform do
      :macos ->
        %{
          touch_bar: true,
          native_titlebar: true,
          unified_toolbar: true
        }

      :windows ->
        %{
          window_controls_overlay: true,
          mica_material: true,
          snap_layouts: true
        }

      :linux ->
        %{
          app_menu: true,
          native_decorations: true
        }

      _ ->
        %{}
    end
  end

  defp emit_render_telemetry(result, started_at, metadata) do
    duration = System.monotonic_time() - started_at

    case result do
      {:ok, _rendered} = success ->
        Telemetry.emit(
          :render,
          :complete,
          %{count: 1, duration: duration},
          Map.put(metadata, :status, :ok)
        )

        success

      {:error, reason} = error ->
        error_metadata = Map.merge(metadata, %{status: :error, error: inspect(reason)})
        Telemetry.emit(:render, :error, %{count: 1, duration: duration}, error_metadata)
        error
    end
  end

  defp render_metadata(canonical_iur, renderer) do
    %{
      renderer: renderer,
      resource_id: Map.get(canonical_iur, "id"),
      resource_type: :screen,
      screen_id: Map.get(canonical_iur, "id")
    }
  end
end
