defmodule AshUI.Rendering.LiveUIAdapter do
  @moduledoc """
  Adapter for LiveUI renderer package.

  This module provides integration with the live_ui package for rendering
  to Phoenix LiveView HEEx templates. When the live_ui package is not
  available, this module provides stub implementations.

  ## LiveView-Specific Features

  This adapter supports:
  - Event bindings (phx-click, phx-blur, phx-change)
  - LiveView hooks attachment
  - Reactive assigns for data binding
  - Patch optimizations for efficient updates

  If LiveUI.Renderer is available, delegates to it. Otherwise, provides
  fallback implementation using the IURAdapter.
  """

  alias AshUI.Rendering.IURAdapter
  alias AshUI.Compilation.IUR
  alias AshUI.Telemetry

  @doc """
  Renders a canonical IUR to HEEx template string.

  ## Parameters
    * `canonical_iur` - Canonical IUR map from IURAdapter
    * `opts` - Rendering options

  ## Options
    * `:optimize_patches` - Enable LiveView patch optimizations (default: true)
    * `:assigns` - LiveView assigns for reactivity (default: %{})
    * `:socket` - LiveView socket for event binding (default: nil)
    * `:hooks` - LiveView hooks to attach (default: [])
    *: `:event_prefix` - Prefix for event names (default: "ash")

  ## Returns
    * `{:ok, heex_string}` - HEEx template string
    * `{:error, reason}` - Rendering failed
  """
  @spec render(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render(canonical_iur, opts \\ []) when is_map(canonical_iur) do
    started_at = System.monotonic_time()
    metadata = render_metadata(canonical_iur, :live_ui)
    Telemetry.emit(:render, :start, %{count: 1}, metadata)

    result =
      if Code.ensure_loaded?(LiveUI.Renderer) do
        call_live_ui_renderer(canonical_iur, opts)
      else
        render_fallback(canonical_iur, opts)
      end

    emit_render_telemetry(result, started_at, metadata)
  end

  @doc """
  Checks if LiveUI renderer is available.

  ## Returns
    * `true` - LiveUI.Renderer is available
    * `false` - LiveUI.Renderer is not available
  """
  @spec available?() :: boolean()
  def available? do
    Code.ensure_loaded?(live_ui_renderer_module())
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

  @doc """
  Configures LiveView event bindings for a screen.

  ## Parameters
    * `canonical_iur` - Canonical IUR map
    * `opts` - Options

  ## Returns
    * Event binding configuration map
  """
  @spec configure_event_bindings(map(), keyword()) :: map()
  def configure_event_bindings(%{"type" => "screen"} = iur, opts \\ []) do
    event_prefix = Keyword.get(opts, :event_prefix, "ash")

    bindings = extract_event_bindings(iur, event_prefix)

    %{
      events: bindings,
      handlers: build_event_handlers(bindings),
      event_prefix: event_prefix
    }
  end

  @doc """
  Configures LiveView hooks for a screen.

  ## Parameters
    * `canonical_iur` - Canonical IUR map
    * `opts` - Options

  ## Returns
    * Hook configuration list
  """
  @spec configure_hooks(map(), keyword()) :: [map()]
  def configure_hooks(%{"type" => "screen"} = _iur, opts \\ []) do
    custom_hooks = Keyword.get(opts, :hooks, [])
    optimize_patches = Keyword.get(opts, :optimize_patches, true)

    default_hooks = [
      %{
        name: :ash_ui_lifecycle,
        on_mount: {AshUI.LiveView.Hooks, :on_mount_ash_ui}
      }
    ]

    patch_hooks =
      if optimize_patches do
        [
          %{
            name: :ash_ui_patches,
            on_mount: {AshUI.LiveView.PatchOptimizer, :on_mount_optimize}
          }
        ]
      else
        []
      end

    default_hooks ++ patch_hooks ++ custom_hooks
  end

  @doc """
  Configures LiveView assigns for reactive data binding.

  ## Parameters
    * `canonical_iur` - Canonical IUR map
    * `opts` - Options

  ## Returns
    * Assigns configuration map
  """
  @spec configure_assigns(map(), keyword()) :: map()
  def configure_assigns(%{"type" => "screen"} = iur, opts \\ []) do
    initial_assigns = Keyword.get(opts, :assigns, %{})
    bindings = Map.get(iur, "bindings", [])

    # Extract assigns from bidirectional bindings
    binding_assigns =
      bindings
      |> Enum.filter(fn binding ->
        Map.get(binding, "type") in ["bidirectional", "collection"]
      end)
      |> Enum.map(fn binding ->
        target = Map.get(binding, "target")
        source = Map.get(binding, "source", %{})
        {target, extract_default_value(source)}
      end)
      |> Map.new()

    Map.merge(initial_assigns, binding_assigns)
  end

  @doc """
  Configures LiveView patch optimizations.

  ## Parameters
    * `canonical_iur` - Canonical IUR map
    * `opts` - Options

  ## Returns
    * Patch optimization configuration
  """
  @spec configure_patch_optimization(map(), keyword()) :: map()
  def configure_patch_optimization(%{"type" => "screen"} = iur, opts \\ []) do
    enabled = Keyword.get(opts, :optimize_patches, true)
    static_elements = extract_static_elements(iur)

    %{
      enabled: enabled,
      static_ids: static_elements,
      dynamic_streams: extract_dynamic_streams(iur)
    }
  end

  # Private Functions

  defp live_ui_renderer_module do
    Module.concat(LiveUI, Renderer)
  end

  # Call actual LiveUI.Renderer if available
  defp call_live_ui_renderer(canonical_iur, opts) do
    renderer_module = live_ui_renderer_module()

    try do
      case apply(renderer_module, :render, [canonical_iur, opts]) do
        {:ok, heex} -> {:ok, heex}
        {:error, reason} -> {:error, {:live_ui_error, reason}}
        other -> {:error, {:unexpected_response, other}}
      end
    rescue
      error -> {:error, {:live_ui_exception, error}}
    end
  end

  # Fallback renderer when LiveUI is not available
  defp render_fallback(canonical_iur, opts) do
    optimize_patches = Keyword.get(opts, :optimize_patches, true)
    event_prefix = Keyword.get(opts, :event_prefix, "ash")

    heex =
      generate_heex(canonical_iur, %{
        optimize_patches: optimize_patches,
        event_prefix: event_prefix
      })

    {:ok, heex}
  end

  # Generate HEEx from canonical IUR with options
  defp generate_heex(%{"type" => "screen"} = iur, opts) do
    patch_attrs =
      if Map.get(opts, :optimize_patches, true) do
        " phx-update=\"stream\" id=\"#{iur["id"]}\""
      else
        " id=\"#{iur["id"]}\""
      end

    """
    <div class="ash-screen ash-screen-#{iur["name"]}" data-screen-id="#{iur["id"]}"#{patch_attrs}>
      #{generate_children(iur["children"], opts)}
    </div>
    """
  end

  defp generate_heex(%{"type" => "row"} = iur, opts) do
    spacing = Map.get(iur["props"] || %{}, "spacing", 8)

    """
    <div class="ash-row" style="gap: #{spacing}px">
      #{generate_children(iur["children"], opts)}
    </div>
    """
  end

  defp generate_heex(%{"type" => "column"} = iur, opts) do
    spacing = Map.get(iur["props"] || %{}, "spacing", 8)

    """
    <div class="ash-column" style="gap: #{spacing}px">
      #{generate_children(iur["children"], opts)}
    </div>
    """
  end

  defp generate_heex(%{"type" => "text"} = iur, _opts) do
    content = Map.get(iur["props"] || %{}, "content", "")
    size = Map.get(iur["props"] || %{}, "size", 14)
    color = Map.get(iur["props"] || %{}, "color", "inherit")

    """
    <span class="ash-text" style="font-size: #{size}px; color: #{color};">#{content}</span>
    """
  end

  defp generate_heex(%{"type" => "button"} = iur, opts) do
    label = Map.get(iur["props"] || %{}, "label", "Button")
    event_prefix = Map.get(opts, :event_prefix, "ash")
    variant = Map.get(iur["props"] || %{}, "variant", "primary")

    click_event = "#{event_prefix}:click"

    """
    <button class="ash-button ash-button-#{variant}" phx-click="#{click_event}" data-target="#{iur["id"]}">#{label}</button>
    """
  end

  defp generate_heex(%{"type" => "input"} = iur, opts) do
    name = Map.get(iur["props"] || %{}, "name", "input")
    placeholder = Map.get(iur["props"] || %{}, "placeholder", "")
    event_prefix = Map.get(opts, :event_prefix, "ash")

    """
    <input class="ash-input" name="#{name}" placeholder="#{placeholder}" phx-blur="#{event_prefix}:blur" phx-change="#{event_prefix}:change" data-target="#{iur["id"]}" />
    """
  end

  defp generate_heex(%{"type" => "checkbox"} = iur, opts) do
    name = Map.get(iur["props"] || %{}, "name", "checkbox")
    event_prefix = Map.get(opts, :event_prefix, "ash")

    """
    <input type="checkbox" class="ash-checkbox" name="#{name}" phx-click="#{event_prefix}:toggle" data-target="#{iur["id"]}" />
    """
  end

  defp generate_heex(%{"type" => "select"} = iur, opts) do
    name = Map.get(iur["props"] || %{}, "name", "select")
    options = Map.get(iur["props"] || %{}, "options", [])
    event_prefix = Map.get(opts, :event_prefix, "ash")

    options_html =
      Enum.map_join(options, fn option ->
        {label, value} = if is_binary(option), do: {option, option}, else: option
        "<option value=\"#{value}\">#{label}</option>"
      end)

    """
    <select class="ash-select" name="#{name}" phx-change="#{event_prefix}:change" data-target="#{iur["id"]}">
      #{options_html}
    </select>
    """
  end

  defp generate_heex(iur, opts) do
    """
    <div class="ash-widget ash-widget-#{iur["type"]}" data-widget-id="#{iur["id"]}">
      #{generate_children(iur["children"], opts)}
    </div>
    """
  end

  defp generate_children(nil, _opts), do: ""
  defp generate_children([], _opts), do: ""

  defp generate_children(children, opts) when is_list(children) do
    Enum.map_join(children, &generate_heex(&1, opts))
  end

  # Extract event bindings from IUR
  defp extract_event_bindings(iur, event_prefix) do
    events = []

    events = extract_events_from_children(iur["children"] || [], events, event_prefix)
    events = extract_events_from_bindings(iur["bindings"] || [], events, event_prefix)

    Enum.uniq(events)
  end

  defp extract_events_from_children(children, events, event_prefix) do
    Enum.reduce(children, events, fn child, acc ->
      case child["type"] do
        "button" ->
          [%{event: "#{event_prefix}:click", target: child["id"]} | acc]

        "input" ->
          [
            %{event: "#{event_prefix}:blur", target: child["id"]},
            %{event: "#{event_prefix}:change", target: child["id"]} | acc
          ]

        "checkbox" ->
          [%{event: "#{event_prefix}:toggle", target: child["id"]} | acc]

        _ ->
          extract_events_from_children(child["children"] || [], acc, event_prefix)
      end
    end)
  end

  defp extract_events_from_bindings(bindings, events, event_prefix) do
    Enum.reduce(bindings, events, fn binding, acc ->
      type = Map.get(binding, "type")

      event_type =
        case type do
          "event" -> "action"
          "bidirectional" -> "update"
          "collection" -> "stream"
          _ -> "change"
        end

      [%{event: "#{event_prefix}:#{event_type}", target: binding["target"]} | acc]
    end)
  end

  defp build_event_handlers(bindings) do
    Enum.map(bindings, fn binding ->
      %{
        event: binding.event,
        handler: :"handle_#{String.replace(binding.event, ":", "_")}",
        target: binding.target
      }
    end)
  end

  defp extract_default_value(source) when is_map(source) do
    Map.get(source, "default", nil)
  end

  defp extract_default_value(_), do: nil

  defp extract_static_elements(iur) do
    # Elements that don't need reactive updates
    extract_static(iur["children"] || [], [])
  end

  defp extract_static(children, acc) when is_list(children) do
    Enum.reduce(children, acc, fn child, acc2 ->
      if child["type"] in ["text", "divider", "spacer"] and
           not has_signals(child) do
        [child["id"] | acc2]
      else
        extract_static(child["children"] || [], acc2)
      end
    end)
  end

  defp extract_static(_, acc), do: acc

  defp has_signals(child) do
    signals = Map.get(child, "signals", [])
    length(signals) > 0
  end

  defp extract_dynamic_streams(iur) do
    # Extract bindings that should be streams (collections)
    bindings = iur["bindings"] || []

    bindings
    |> Enum.filter(fn binding -> Map.get(binding, "type") == "collection" end)
    |> Enum.map(fn binding -> Map.get(binding, "target") end)
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
