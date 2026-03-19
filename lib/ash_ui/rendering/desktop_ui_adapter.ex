defmodule AshUI.Rendering.DesktopUIAdapter do
  @moduledoc """
  Adapter for DesktopUI renderer package.

  This module provides integration with the desktop_ui package for rendering
  to native desktop UI instructions. When the desktop_ui package is not
  available, this module provides stub implementations.

  If DesktopUI.Renderer is available, delegates to it. Otherwise, provides
  fallback implementation using the IURAdapter.
  """

  alias AshUI.Rendering.IURAdapter
  alias AshUI.Compilation.IUR

  @doc """
  Renders a canonical IUR to desktop UI instructions.

  ## Parameters
    * `canonical_iur` - Canonical IUR map from IURAdapter
    * `opts` - Rendering options

  ## Options
    * `:window_width` - Window width in pixels (default: 1280)
    * `:window_height` - Window height in pixels (default: 720)
    * `:window_resizable` - Allow window resizing (default: true)
    * `:native_menu_bar` - Include native menu bar (default: true)

  ## Returns
    * `{:ok, instructions}` - Desktop UI instruction map
    * `{:error, reason}` - Rendering failed
  """
  @spec render(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def render(canonical_iur, opts \\ []) when is_map(canonical_iur) do
    if Code.ensure_loaded?(DesktopUI.Renderer) do
      call_desktop_ui_renderer(canonical_iur, opts)
    else
      render_fallback(canonical_iur, opts)
    end
  end

  @doc """
  Checks if DesktopUI renderer is available.

  ## Returns
    * `true` - DesktopUI.Renderer is available
    * `false` - DesktopUI.Renderer is not available
  """
  @spec available?() :: boolean()
  def available? do
    Code.ensure_loaded?(DesktopUI.Renderer)
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

  # Private Functions

  # Call actual DesktopUI.Renderer if available
  defp call_desktop_ui_renderer(canonical_iur, opts) do
    try do
      case DesktopUI.Renderer.render(canonical_iur, opts) do
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
    window_width = Keyword.get(opts, :window_width, 1280)
    window_height = Keyword.get(opts, :window_height, 720)
    window_resizable = Keyword.get(opts, :window_resizable, true)
    native_menu_bar = Keyword.get(opts, :native_menu_bar, true)

    %{
      "type" => "desktop_screen",
      "id" => iur["id"],
      "name" => iur["name"],
      "window" => %{
        "width" => window_width,
        "height" => window_height,
        "resizable" => window_resizable
      },
      "menu_bar" => %{
        "enabled" => native_menu_bar,
        "items" => generate_menu_items(iur)
      },
      "content" => generate_content(iur["children"])
    }
  end

  defp generate_menu_items(_iur) do
    [
      %{"label" => "File", "items" => [
        %{"label" => "Quit", "action" => "quit"}
      ]},
      %{"label" => "Edit", "items" => [
        %{"label" => "Undo", "action" => "undo"},
        %{"label" => "Redo", "action" => "redo"}
      ]}
    ]
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
      "children" => generate_content(widget["children"])
    }
  end

  defp generate_widget(%{"type" => "column"} = widget) do
    %{
      "type" => "vbox",
      "id" => widget["id"],
      "spacing" => Map.get(widget["props"] || %{}, "spacing", 8),
      "children" => generate_content(widget["children"])
    }
  end

  defp generate_widget(%{"type" => "text"} = widget) do
    content = Map.get(widget["props"] || %{}, "content", "")
    size = Map.get(widget["props"] || %{}, "size", 14)

    %{
      "type" => "label",
      "id" => widget["id"],
      "text" => content,
      "font_size" => size
    }
  end

  defp generate_widget(%{"type" => "button"} = widget) do
    label = Map.get(widget["props"] || %{}, "label", "Button")
    on_click = Map.get(widget["props"] || %{}, "on_click", nil)

    %{
      "type" => "button",
      "id" => widget["id"],
      "label" => label,
      "on_click" => on_click
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

  defp generate_widget(widget) do
    %{
      "type" => "container",
      "id" => widget["id"],
      "widget_type" => widget["type"],
      "children" => generate_content(widget["children"])
    }
  end
end
