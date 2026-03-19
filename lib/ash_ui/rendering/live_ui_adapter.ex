defmodule AshUI.Rendering.LiveUIAdapter do
  @moduledoc """
  Adapter for LiveUI renderer package.

  This module provides integration with the live_ui package for rendering
  to Phoenix LiveView HEEx templates. When the live_ui package is not
  available, this module provides stub implementations.

  If LiveUI.Renderer is available, delegates to it. Otherwise, provides
  fallback implementation using the IURAdapter.
  """

  alias AshUI.Rendering.IURAdapter
  alias AshUI.Compilation.IUR

  @doc """
  Renders a canonical IUR to HEEx template string.

  ## Parameters
    * `canonical_iur` - Canonical IUR map from IURAdapter
    * `opts` - Rendering options

  ## Options
    * `:optimize_patches` - Enable LiveView patch optimizations (default: true)
    * `:assigns` - LiveView assigns for reactivity (default: %{})
    * `:socket` - LiveView socket for event binding (default: nil)

  ## Returns
    * `{:ok, heex_string}` - HEEx template string
    * `{:error, reason}` - Rendering failed
  """
  @spec render(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render(canonical_iur, opts \\ []) when is_map(canonical_iur) do
    if Code.ensure_loaded?(LiveUI.Renderer) do
      call_live_ui_renderer(canonical_iur, opts)
    else
      render_fallback(canonical_iur, opts)
    end
  end

  @doc """
  Checks if LiveUI renderer is available.

  ## Returns
    * `true` - LiveUI.Renderer is available
    * `false` - LiveUI.Renderer is not available
  """
  @spec available?() :: boolean()
  def available? do
    Code.ensure_loaded?(LiveUI.Renderer)
  end

  @doc """
  Converts an Ash IUR to LiveUI-compatible format and renders.

  ## Parameters
    * `ash_iur` - Ash IUR structure
    * `opts` - Rendering options

  ## Returns
    * `{:ok, heex_string}` - HEEx template string
    * `{:error, reason}` - Rendering failed
  """
  @spec render_ash_iur(IUR.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render_ash_iur(%IUR{} = ash_iur, opts \\ []) do
    with {:ok, canonical_iur} <- IURAdapter.to_canonical(ash_iur, opts),
         {:ok, heex} <- render(canonical_iur, opts) do
      {:ok, heex}
    else
      error -> error
    end
  end

  # Private Functions

  # Call actual LiveUI.Renderer if available
  defp call_live_ui_renderer(canonical_iur, opts) do
    try do
      case LiveUI.Renderer.render(canonical_iur, opts) do
        {:ok, heex} -> {:ok, heex}
        {:error, reason} -> {:error, {:live_ui_error, reason}}
        other -> {:error, {:unexpected_response, other}}
      end
    rescue
      error -> {:error, {:live_ui_exception, error}}
    end
  end

  # Fallback renderer when LiveUI is not available
  defp render_fallback(canonical_iur, _opts) do
    # Basic HEEx generation from canonical IUR
    heex = generate_heex(canonical_iur)
    {:ok, heex}
  end

  # Generate basic HEEx from canonical IUR
  defp generate_heex(%{"type" => "screen"} = iur) do
    """
    <div class="ash-screen ash-screen-#{iur["name"]}" data-screen-id="#{iur["id"]}">
      #{generate_children(iur["children"])}
    </div>
    """
  end

  defp generate_heex(%{"type" => "row"} = iur) do
    """
    <div class="ash-row">
      #{generate_children(iur["children"])}
    </div>
    """
  end

  defp generate_heex(%{"type" => "column"} = iur) do
    """
    <div class="ash-column">
      #{generate_children(iur["children"])}
    </div>
    """
  end

  defp generate_heex(%{"type" => "text"} = iur) do
    content = Map.get(iur["props"] || %{}, "content", "")
    """
    <span class="ash-text">#{content}</span>
    """
  end

  defp generate_heex(%{"type" => "button"} = iur) do
    label = Map.get(iur["props"] || %{}, "label", "Button")
    """
    <button class="ash-button" phx-click="ash_click" data-target="#{iur["id"]}">#{label}</button>
    """
  end

  defp generate_heex(%{"type" => "input"} = iur) do
    name = Map.get(iur["props"] || %{}, "name", "input")
    """
    <input class="ash-input" name="#{name}" phx-blur="ash_blur" phx-change="ash_change" data-target="#{iur["id"]}" />
    """
  end

  defp generate_heex(iur) do
    """
    <div class="ash-widget ash-widget-#{iur["type"]}" data-widget-id="#{iur["id"]}">
      #{generate_children(iur["children"])}
    </div>
    """
  end

  defp generate_children(nil), do: ""
  defp generate_children([]), do: ""
  defp generate_children(children) when is_list(children) do
    Enum.map_join(children, &generate_heex/1)
  end
end
