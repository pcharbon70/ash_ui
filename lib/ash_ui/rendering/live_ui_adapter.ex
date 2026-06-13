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

  alias AshUI.Compilation.IUR
  alias AshUI.Rendering.CanonicalIUR
  alias AshUI.Rendering.IURAdapter
  alias AshUI.Telemetry
  alias UnifiedIUR.Element

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
    *: `:event_prefix` - Prefix for event names (default: "ash_ui")

  ## Returns
    * `{:ok, heex_string}` - HEEx template string
    * `{:error, reason}` - Rendering failed
  """
  @spec render(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render(canonical_iur, opts \\ []) when is_map(canonical_iur) do
    started_at = System.monotonic_time()
    metadata = render_metadata(canonical_iur, :live_ui)
    Telemetry.emit(:render, :start, %{count: 1}, metadata)
    force_fallback? = Keyword.get(opts, :force_fallback, false)
    canonical? = CanonicalIUR.canonical?(canonical_iur)

    result =
      if canonical? and available?() and not force_fallback? and not empty_screen?(canonical_iur) do
        call_live_ui_renderer(canonical_iur, opts)
      else
        canonical_iur
        |> CanonicalIUR.to_legacy_map()
        |> render_fallback(opts)
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
         {:ok, heex} <- render(canonical_iur, Keyword.put_new(opts, :force_fallback, true)) do
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
  def configure_event_bindings(iur, opts \\ [])

  def configure_event_bindings(%Element{} = iur, opts) do
    iur
    |> CanonicalIUR.to_legacy_map()
    |> configure_event_bindings(opts)
  end

  def configure_event_bindings(%{"type" => "screen"} = iur, opts) do
    event_prefix = Keyword.get(opts, :event_prefix, "ash_ui")

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
  def configure_hooks(iur, opts \\ [])

  def configure_hooks(%Element{} = iur, opts) do
    iur
    |> CanonicalIUR.to_legacy_map()
    |> configure_hooks(opts)
  end

  def configure_hooks(%{"type" => "screen"} = _iur, opts) do
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
  def configure_assigns(iur, opts \\ [])

  def configure_assigns(%Element{} = iur, opts) do
    iur
    |> CanonicalIUR.to_legacy_map()
    |> configure_assigns(opts)
  end

  def configure_assigns(%{"type" => "screen"} = iur, opts) do
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
  def configure_patch_optimization(iur, opts \\ [])

  def configure_patch_optimization(%Element{} = iur, opts) do
    iur
    |> CanonicalIUR.to_legacy_map()
    |> configure_patch_optimization(opts)
  end

  def configure_patch_optimization(%{"type" => "screen"} = iur, opts) do
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
    Module.concat(LiveUi, Renderer)
  end

  # Call actual LiveUI.Renderer if available
  defp call_live_ui_renderer(%Element{} = canonical_iur, opts) do
    try do
      case LiveUi.Tooling.inspect_canonical(canonical_iur, opts) do
        {:ok, %{html: heex}} -> {:ok, heex}
        {:ok, %{"html" => heex}} -> {:ok, heex}
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
    event_prefix = Keyword.get(opts, :event_prefix, "ash_ui")

    heex =
      generate_heex(canonical_iur, %{
        optimize_patches: optimize_patches,
        event_prefix: event_prefix,
        bindings: Map.get(canonical_iur, "bindings", [])
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
    <div class="#{css_classes(["ash-screen", "ash-screen-#{iur["name"]}", prop_class(iur)])}"#{style_attr(prop_style(iur))} data-screen-id="#{iur["id"]}"#{patch_attrs}>
      #{generate_children(iur["children"], opts)}
    </div>
    """
  end

  defp generate_heex(%{"type" => "row"} = iur, opts) do
    spacing = Map.get(iur["props"] || %{}, "spacing", 8)

    style =
      merge_style(["display: flex", "flex-direction: row", "gap: #{spacing}px"], prop_style(iur))

    """
    <div class="#{css_classes(["ash-row", prop_class(iur)])}"#{style_attr(style)}>
      #{generate_children(iur["children"], opts)}
    </div>
    """
  end

  defp generate_heex(%{"type" => "column"} = iur, opts) do
    spacing = Map.get(iur["props"] || %{}, "spacing", 8)

    style =
      merge_style(
        ["display: flex", "flex-direction: column", "gap: #{spacing}px"],
        prop_style(iur)
      )

    """
    <div class="#{css_classes(["ash-column", prop_class(iur)])}"#{style_attr(style)}>
      #{generate_children(iur["children"], opts)}
    </div>
    """
  end

  defp generate_heex(%{"type" => "grid"} = iur, opts) do
    props = iur["props"] || %{}
    columns = Map.get(props, "columns", 2)
    spacing = Map.get(props, "spacing", 8)

    style =
      merge_style(
        [
          "display: grid",
          "grid-template-columns: repeat(#{columns}, minmax(0, 1fr))",
          "gap: #{spacing}px"
        ],
        prop_style(iur)
      )

    """
    <div class="#{css_classes(["ash-grid", prop_class(iur)])}"#{style_attr(style)}>
      #{generate_children(iur["children"], opts)}
    </div>
    """
  end

  defp generate_heex(%{"type" => "stack"} = iur, opts) do
    style =
      merge_style(
        ["display: grid", "gap: #{Map.get(iur["props"] || %{}, "spacing", 0)}px"],
        prop_style(iur)
      )

    """
    <div class="#{css_classes(["ash-stack", prop_class(iur)])}"#{style_attr(style)}>
      #{generate_children(iur["children"], opts)}
    </div>
    """
  end

  defp generate_heex(%{"type" => "card"} = iur, opts) do
    """
    <section class="#{css_classes(["ash-card", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      #{generate_children(iur["children"], opts)}
    </section>
    """
  end

  defp generate_heex(%{"type" => "text"} = iur, _opts) do
    props = iur["props"] || %{}
    content = text_prop(props, ["content", "text"], "")
    size = prop(props, "size", 14)
    color = prop(props, "color", "inherit")
    weight = prop(props, "weight", "normal")
    align = prop(props, "align", "inherit")

    style =
      merge_style(
        [
          "font-size: #{size}px",
          "color: #{color}",
          "font-weight: #{weight}",
          "text-align: #{align}"
        ],
        prop_style(iur)
      )

    """
    <span class="#{css_classes(["ash-text", prop_class(iur)])}"#{style_attr(style)}>#{content}</span>
    """
  end

  defp generate_heex(%{"type" => "inline_rich_text_heading"} = iur, _opts) do
    props = iur["props"] || %{}
    level = normalize_heading_level(prop(props, "level", "h1"))
    segments = normalize_segments(prop(props, "segments", []))

    inner =
      segments
      |> Enum.map_join("", &render_segment/1)

    """
    <#{level} class="#{css_classes(["ash-inline-rich-text-heading", "ash-inline-rich-text-heading-#{level}", prop_class(iur)])}"#{style_attr(prop_style(iur))}>#{inner}</#{level}>
    """
  end

  defp generate_heex(%{"type" => "disclosure"} = iur, opts) do
    props = iur["props"] || %{}
    summary = escaped_text_prop(props, ["summary", "label", "title"], "Details")
    open? = truthy_prop(props, "open?", truthy_prop(props, "open", false))

    """
    <details class="#{css_classes(["ash-disclosure", open? && "is-open", prop_class(iur)])}"#{if(open?, do: " open", else: "")}#{style_attr(prop_style(iur))}>
      <summary class="ash-disclosure-summary">#{summary}</summary>
      <div class="ash-disclosure-body">
        #{generate_children(iur["children"], opts)}
      </div>
    </details>
    """
  end

  defp generate_heex(%{"type" => "kicker"} = iur, _opts) do
    props = iur["props"] || %{}
    items = prop(props, "items", [])
    separator = escaped_text_prop(props, "separator", "/")

    content =
      items
      |> List.wrap()
      |> Enum.map_join(~s(<span class="ash-kicker-separator">#{separator}</span>), fn item ->
        ~s(<span class="ash-kicker-item">#{html_escape(item)}</span>)
      end)

    """
    <p class="#{css_classes(["ash-kicker", prop_class(iur)])}"#{style_attr(prop_style(iur))}>#{content}</p>
    """
  end

  defp generate_heex(%{"type" => "avatar"} = iur, _opts) do
    props = iur["props"] || %{}
    label = escaped_text_prop(props, ["label", "initials"], "Avatar")
    initials = escaped_text_prop(props, "initials")
    image_source = text_prop(props, ["image_source", "src", "url"])

    content =
      if image_source do
        ~s(<img class="ash-avatar-image" src="#{html_attr(image_source)}" alt="#{label}" />)
      else
        ~s(<span class="ash-avatar-initials">#{initials || label}</span>)
      end

    """
    <span class="#{css_classes(["ash-avatar", "ash-avatar-#{text_prop(props, "size", "medium")}", prop_class(iur)])}" role="img" aria-label="#{label}"#{style_attr(prop_style(iur))}>#{content}</span>
    """
  end

  defp generate_heex(%{"type" => "presence_dot"} = iur, _opts) do
    props = iur["props"] || %{}
    state = escaped_text_prop(props, ["state", "status"], "offline")

    label =
      escaped_text_prop(
        props,
        ["label", "accessibility_label", "aria_label"],
        "Presence: #{state}"
      )

    aria_attrs =
      if presence_decorative?(props) do
        ~s(aria-hidden="true")
      else
        ~s(role="img" aria-label="#{label}")
      end

    """
    <span class="#{css_classes(["ash-presence-dot", "ash-presence-dot-#{state}", prop_class(iur)])}" #{aria_attrs} data-state="#{state}"#{style_attr(prop_style(iur))}></span>
    """
  end

  defp generate_heex(%{"type" => "file_tree_browser"} = iur, _opts) do
    raw_props = iur["props"] || %{}
    props = prop(raw_props, "file_tree", raw_props)
    tree_id = escaped_text_prop(props, ["tree_id", "id"], iur["id"] || "file-tree")
    root_label = escaped_text_prop(props, ["root_label", "label"], "Files")
    selected_path = text_prop(props, "selected_path")
    default_expanded? = truthy_prop(props, "default_expanded?", true)
    nodes = prop(props, "nodes", [])

    """
    <div class="#{css_classes(["ash-file-tree-browser", prop_class(iur)])}" data-live-ui-widget="file-tree-browser" data-tree-id="#{tree_id}" role="tree" aria-label="#{root_label}"#{style_attr(prop_style(iur))}>
      #{file_tree_nodes_html(nodes, selected_path, default_expanded?, 0)}
    </div>
    """
  end

  defp generate_heex(%{"type" => "runtime_form_shell"} = iur, opts) do
    props = iur["props"] || %{}
    fields = prop(props, "fields", [])
    submit_label = escaped_text_prop(props, "submit_label", "Submit")

    fields_html =
      Enum.map_join(List.wrap(fields), fn field ->
        field = normalize_item(field)
        name = escaped_text_prop(field, ["name", "id"], "field")
        label = escaped_text_prop(field, ["label", "name"], name)

        """
        <label class="ash-runtime-form-field">
          <span class="ash-runtime-form-label">#{label}</span>
          <input class="ash-runtime-form-input" name="#{html_attr(name)}" />
        </label>
        """
      end)

    """
    <form class="#{css_classes(["ash-runtime-form-shell", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      #{fields_html}
      #{generate_children(iur["children"], opts)}
      <button type="submit" class="ash-runtime-form-submit">#{submit_label}</button>
    </form>
    """
  end

  defp generate_heex(%{"type" => "segmented_button_group"} = iur, _opts) do
    props = iur["props"] || %{}
    options = prop(props, "options", [])
    active_value = prop(props, "active_value", prop(props, "value"))

    options_html =
      Enum.map_join(List.wrap(options), fn option ->
        option = normalize_item(option)
        {label, value} = normalize_choice(option)
        selected? = to_string(value) == to_string(active_value)

        """
        <button type="button" class="#{css_classes(["ash-segmented-button", selected? && "is-selected"])}" aria-pressed="#{selected?}" value="#{html_attr(value)}">#{html_escape(label)}</button>
        """
      end)

    """
    <div class="#{css_classes(["ash-segmented-button-group", prop_class(iur)])}" role="group"#{style_attr(prop_style(iur))}>
      #{options_html}
    </div>
    """
  end

  defp generate_heex(%{"type" => "chat_composer"} = iur, opts) do
    props = iur["props"] || %{}
    placeholder = escaped_text_prop(props, "placeholder", "")
    value = escaped_text_prop(props, ["value", "text", "content"], "")
    rows = prop(props, "rows", 3)
    send_label = escaped_text_prop(props, "send_label", "Send")

    """
    <form class="#{css_classes(["ash-chat-composer", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <textarea class="ash-chat-composer-input" rows="#{rows}" placeholder="#{placeholder}">#{value}</textarea>
      <div class="ash-chat-composer-tools">#{generate_children(iur["children"], opts)}</div>
      <button type="submit" class="ash-chat-composer-send">#{send_label}</button>
    </form>
    """
  end

  defp generate_heex(%{"type" => "collection_picker"} = iur, _opts) do
    raw_props = iur["props"] || %{}

    nested_props =
      case prop(raw_props, "collection_picker", %{}) do
        nested when is_map(nested) -> nested
        _other -> %{}
      end

    props = Map.merge(raw_props, nested_props)
    picker_id = text_prop(props, ["picker_id", "collection_id", "id"], iur["id"] || "collection")
    title = escaped_text_prop(props, ["title", "label"])
    query = html_attr(text_prop(props, ["query", "search_query"], ""))

    placeholder =
      html_attr(text_prop(props, ["placeholder", "search_placeholder"], "Search collection"))

    empty_label =
      escaped_text_prop(props, ["empty_label", "empty_state_message"], "No matching items.")

    filters = prop(props, "filters", prop(props, "filter_chips", []))
    items = prop(props, "items", [])
    suggestions = prop(props, "suggestions", prop(props, "agent_suggestions", []))

    filters_html =
      filters
      |> List.wrap()
      |> Enum.map_join(&render_collection_picker_filter/1)

    items_html =
      case List.wrap(items) do
        [] -> ~s(<li class="ash-collection-picker-empty">#{empty_label}</li>)
        collection -> Enum.map_join(collection, &render_collection_picker_item/1)
      end

    suggestions_html =
      suggestions
      |> List.wrap()
      |> Enum.map_join(&render_collection_picker_suggestion/1)

    """
    <section class="#{css_classes(["ash-collection-picker", prop_class(iur)])}" data-widget-type="collection_picker"#{attr("data-picker-id", html_attr(picker_id))}#{style_attr(prop_style(iur))}>
      #{if title, do: "<header class=\"ash-collection-picker-header\"><h2 class=\"ash-collection-picker-title\">#{title}</h2></header>", else: ""}
      <div class="ash-collection-picker-search">
        <input type="search" name="query" value="#{query}" placeholder="#{placeholder}" class="ash-collection-picker-search-input" />
      </div>
      #{if filters_html == "", do: "", else: "<div class=\"ash-collection-picker-filters\" role=\"group\" aria-label=\"Collection filters\">#{filters_html}</div>"}
      <ul class="ash-collection-picker-items" role="listbox" aria-label="Collection items">
        #{items_html}
      </ul>
      #{if suggestions_html == "", do: "", else: "<div class=\"ash-collection-picker-suggestions\" aria-label=\"Suggestions\">#{suggestions_html}</div>"}
    </section>
    """
  end

  defp generate_heex(%{"type" => "composer_query_preview"} = iur, _opts) do
    props = iur["props"] || %{}
    preview = props |> prop("query_preview", props) |> normalize_item()
    composer_id = escaped_text_prop(preview, "composer_id", iur["id"] || "")
    query = escaped_text_prop(preview, "query", "")
    preview_state = escaped_text_prop(preview, "preview_state", "empty")
    explanation = escaped_text_prop(preview, "explanation")
    error_message = escaped_text_prop(preview, "error_message", "Query failed. Try again.")
    loading_label = escaped_text_prop(preview, "loading_label", "Searching")
    empty_label = escaped_text_prop(preview, "empty_label", "No results for this query.")
    metrics = preview |> prop("metrics", %{}) |> normalize_item()
    findings = List.wrap(prop(preview, "findings", []))
    max_findings_shown = max(numeric_count(prop(preview, "max_findings_shown", 2)), 1)

    metrics_html =
      if metrics == %{} do
        ""
      else
        results_count = escaped_text_prop(metrics, "results_count")
        duration_ms = prop(metrics, "duration_ms")
        sources_visited = escaped_text_prop(metrics, "sources_visited")

        duration =
          case duration_ms do
            value when is_integer(value) or is_float(value) ->
              :erlang.float_to_binary(value / 1000, decimals: 2) <> "s"

            value when not is_nil(value) ->
              html_escape(value)

            _other ->
              nil
          end

        """
        <div class="ash-composer-query-preview__metrics" aria-label="Query statistics">
          #{if results_count != "", do: "<span><strong>#{results_count}</strong> results</span>", else: ""}
          #{if duration, do: "<span>#{duration}</span>", else: ""}
          #{if sources_visited != "", do: "<span>#{sources_visited} sources</span>", else: ""}
        </div>
        """
      end

    findings_html =
      findings
      |> Enum.take(max_findings_shown)
      |> Enum.map_join(fn finding ->
        finding = normalize_item(finding)
        id = escaped_text_prop(finding, ["id", "finding_id"], "")
        n = escaped_text_prop(finding, "n", "")
        snippet = escaped_text_prop(finding, "snippet", "")
        confidence = escaped_text_prop(finding, "confidence", "")

        """
        <li class="ash-composer-query-preview__finding" data-result-id="#{id}">
          <span class="ash-composer-query-preview__finding-rank">##{n}</span>
          <span class="ash-composer-query-preview__finding-snippet">#{snippet}</span>
          <span class="ash-composer-query-preview__finding-confidence">#{confidence}</span>
        </li>
        """
      end)

    body_html =
      case preview_state do
        "loading" ->
          ~s(<div class="ash-composer-query-preview__loading" aria-busy="true">#{loading_label}</div>)

        "ready" ->
          """
          #{if explanation, do: "<div class=\"ash-composer-query-preview__explanation\">#{explanation}</div>", else: ""}
          #{metrics_html}
          #{if findings_html != "", do: "<ul class=\"ash-composer-query-preview__findings\" aria-label=\"Query preview results\">#{findings_html}</ul>", else: ""}
          """

        "error" ->
          ~s(<div class="ash-composer-query-preview__error" role="alert">#{error_message}</div>)

        _other ->
          ~s(<div class="ash-composer-query-preview__empty">#{empty_label}</div>)
      end

    """
    <section class="#{css_classes(["ash-composer-query-preview", prop_class(iur)])}" data-live-ui-widget="composer-query-preview" data-composer-id="#{composer_id}" data-preview-state="#{preview_state}" role="region" aria-label="Query preview: #{query}" aria-live="polite"#{style_attr(prop_style(iur))}>
      <header class="ash-composer-query-preview__header">
        <span class="ash-composer-query-preview__query"><q>#{query}</q></span>
      </header>
      #{body_html}
    </section>
    """
  end

  defp generate_heex(%{"type" => "propose_new_doc_card"} = iur, _opts) do
    props = iur["props"] || %{}
    proposal = props |> prop("propose_new_doc", props) |> normalize_item()

    target_path =
      escaped_text_prop(proposal, "target_path", escaped_text_prop(props, "target_path", ""))

    title =
      escaped_text_prop(
        proposal,
        "title",
        escaped_text_prop(props, ["title", "label"], "Document")
      )

    body_md_preview =
      escaped_text_prop(
        proposal,
        "body_md_preview",
        escaped_text_prop(proposal, "body_md", escaped_text_prop(props, "body_md_preview", ""))
      )

    body_md = escaped_text_prop(proposal, "body_md")
    status = escaped_text_prop(proposal, "status", escaped_text_prop(props, "status", "pending"))
    actor_handle = escaped_text_prop(proposal, "actor_handle")
    proposed_at = escaped_text_prop(proposal, "proposed_at")
    seed = escaped_text_prop(proposal, "conversation_seed_md")
    iur_id = html_attr(iur["id"] || iur[:id] || "propose-new-doc-card")
    body_id = "#{iur_id}-body"
    seed_id = "#{iur_id}-conversation-seed"

    full_body? = body_md not in [nil, ""] and body_md != body_md_preview

    body_toggle =
      if full_body? do
        ~s(<button type="button" class="ash-propose-new-doc-card__body-toggle" aria-expanded="false" aria-controls="#{body_id}">Show full draft</button>)
      else
        ""
      end

    seed_html =
      if seed do
        """
        <section class="ash-propose-new-doc-card__conversation">
          <button type="button" class="ash-propose-new-doc-card__conversation-toggle" aria-expanded="false" aria-controls="#{seed_id}">Conversation seed</button>
        </section>
        """
      else
        ""
      end

    decision_html =
      if status == "pending" do
        """
        <button type="button" class="ash-propose-new-doc-card__accept" aria-label="Accept proposed document #{title}">Accept</button>
        <button type="button" class="ash-propose-new-doc-card__reject" aria-label="Reject proposed document #{title}">Reject</button>
        """
      else
        ~s(<p class="ash-propose-new-doc-card__locked-message" role="status">This proposal is #{status}.</p>)
      end

    """
    <article id="#{iur_id}" class="#{css_classes(["ash-propose-new-doc-card", "ash-propose-new-doc-card--#{status}", prop_class(iur)])}" data-live-ui-widget="propose-new-doc-card" data-status="#{status}" data-target-path="#{target_path}" aria-label="Proposed document #{title}, #{status}"#{style_attr(prop_style(iur))}>
      <header class="ash-propose-new-doc-card__header">
        <div class="ash-propose-new-doc-card__identity">
          <h3 class="ash-propose-new-doc-card__title">#{title}</h3>
          #{if actor_handle, do: "<span class=\"ash-propose-new-doc-card__actor\">#{actor_handle}</span>", else: ""}
          #{if proposed_at, do: "<time class=\"ash-propose-new-doc-card__proposed-at\" datetime=\"#{proposed_at}\">#{proposed_at}</time>", else: ""}
        </div>
        <span class="ash-propose-new-doc-card__status-badge ash-propose-new-doc-card__status-badge--#{status}" role="status">#{status}</span>
      </header>
      <p class="ash-propose-new-doc-card__target-path font-mono">#{target_path}</p>
      <section id="#{body_id}" class="ash-propose-new-doc-card__body" aria-label="Draft preview for #{title}">
        <pre class="ash-propose-new-doc-card__body-preview">#{body_md_preview}</pre>
      </section>
      #{body_toggle}
      #{seed_html}
      <footer class="ash-propose-new-doc-card__actions">
        #{decision_html}
        <button type="button" class="ash-propose-new-doc-card__preview" aria-label="Preview proposed document #{title}">Preview</button>
      </footer>
    </article>
    """
  end

  defp generate_heex(%{"type" => "escalation_card"} = iur, _opts) do
    props = iur["props"] || %{}
    escalation = props |> prop("escalation", props) |> normalize_item()

    target_project_id =
      escaped_text_prop(
        escalation,
        "target_project_id",
        escaped_text_prop(props, "target_project_id", "")
      )

    text =
      escaped_text_prop(
        escalation,
        "text",
        escaped_text_prop(props, ["text", "description"], "")
      )

    severity =
      escaped_text_prop(escalation, "severity", escaped_text_prop(props, "severity", "p2"))

    actor_handle = escaped_text_prop(escalation, "actor_handle")
    proposed_action = escaped_text_prop(escalation, "proposed_action")

    acknowledged? =
      truthy_prop(escalation, "acknowledged?", truthy_prop(props, "acknowledged?", false))

    iur_id = html_attr(iur["id"] || iur[:id] || "escalation-card")
    severity_label = String.upcase(severity)

    meta_html =
      if target_project_id != "" || proposed_action do
        project_row =
          if target_project_id != "" do
            "<dt>Target project</dt><dd>#{target_project_id}</dd>"
          else
            ""
          end

        action_row =
          if proposed_action do
            "<dt>Proposed action</dt><dd>#{proposed_action}</dd>"
          else
            ""
          end

        ~s(<dl class="ash-escalation-card__meta">#{project_row}#{action_row}</dl>)
      else
        ""
      end

    footer_html =
      if acknowledged? do
        ~s(<p class="ash-escalation-card__acknowledged" role="status">Acknowledged</p>)
      else
        """
        <footer class="ash-escalation-card__actions">
          <button type="button" class="ash-escalation-card__acknowledge" aria-label="Acknowledge #{severity} escalation">Acknowledge</button>
          <button type="button" class="ash-escalation-card__route-to-rail" aria-label="Route #{severity} escalation to rail">Route to rail</button>
        </footer>
        """
      end

    """
    <article id="#{iur_id}" class="#{css_classes(["ash-escalation-card", "ash-escalation-card--#{severity}", prop_class(iur)])}" data-live-ui-widget="escalation-card" data-severity="#{severity}" data-acknowledged="#{acknowledged?}"#{style_attr(prop_style(iur))} role="alert" aria-labelledby="#{iur_id}-title">
      <header class="ash-escalation-card__header">
        <span class="ash-escalation-card__severity-badge" role="status">#{severity_label}</span>
        <h3 id="#{iur_id}-title" class="ash-escalation-card__title">Escalation</h3>
        #{if actor_handle, do: "<span class=\"ash-escalation-card__actor\">#{actor_handle}</span>", else: ""}
      </header>
      <p class="ash-escalation-card__text">#{text}</p>
      #{meta_html}
      #{footer_html}
    </article>
    """
  end

  defp generate_heex(%{"type" => "list_item_multi_column"} = iur, opts) do
    props = iur["props"] || %{}
    active? = truthy_prop(props, "active?", truthy_prop(props, "active", false))
    columns = prop(props, "column_template", [])

    columns_html =
      Enum.map_join(List.wrap(columns), fn column ->
        column = normalize_item(column)
        label = escaped_text_prop(column, ["label", "title", "id"], "")
        ~s(<span class="ash-list-item-column">#{label}</span>)
      end)

    """
    <article class="#{css_classes(["ash-list-item-multi-column", active? && "is-active", prop_class(iur)])}" data-row-id="#{html_attr(prop(props, "row_identity"))}"#{style_attr(prop_style(iur))}>
      <div class="ash-list-item-columns">#{columns_html}</div>
      #{generate_children(iur["children"], opts)}
    </article>
    """
  end

  defp generate_heex(%{"type" => "artifact_row"} = iur, opts) do
    props = iur["props"] || %{}
    title = escaped_text_prop(props, ["title", "label"], "Artifact")
    meta = escaped_text_prop(props, "meta")

    """
    <article class="#{css_classes(["ash-artifact-row", prop_class(iur)])}" data-row-id="#{html_attr(prop(props, "row_identity"))}"#{style_attr(prop_style(iur))}#{passthrough_attrs(props)}>
      <div class="ash-artifact-row-main">
        <p class="ash-artifact-row-title">#{title}</p>
        #{if meta, do: "<p class=\"ash-artifact-row-meta\">#{meta}</p>", else: ""}
      </div>
      <div class="ash-artifact-row-trailing">#{generate_children(iur["children"], opts)}</div>
    </article>
    """
  end

  defp generate_heex(%{"type" => "thread_card"} = iur, _opts) do
    props = iur["props"] || %{}
    thread = props |> prop("thread", %{}) |> normalize_item()
    participants = List.wrap(prop(props, "participants", []))

    title =
      escaped_text_prop(thread, "title", escaped_text_prop(props, ["title", "label"], "Thread"))

    thread_id = html_attr(prop(thread, "thread_id", prop(props, "thread_id", iur["id"])))

    seed_quote =
      escaped_text_prop(thread, "seed_quote", escaped_text_prop(props, "seed_quote", ""))

    reply_count = prop(thread, "reply_count", prop(props, "reply_count", 0))
    progress_pct = prop(thread, "progress_pct", prop(props, "progress_pct"))

    avatars =
      participants
      |> Enum.take(3)
      |> Enum.map_join(fn participant ->
        participant = normalize_item(participant)
        avatar = participant |> prop("avatar", %{}) |> normalize_item()

        initials =
          escaped_text_prop(avatar, "initials", escaped_text_prop(participant, "actor_name", "?"))

        ~s(<span class="ash-thread-card__avatar">#{initials}</span>)
      end)

    progress_html =
      case progress_pct do
        value when is_integer(value) or is_float(value) ->
          percent = if value <= 1, do: trunc(value * 100), else: trunc(value)

          ~s(<div class="ash-thread-card__progress" role="progressbar" aria-valuenow="#{percent}" aria-valuemin="0" aria-valuemax="100"><div class="ash-thread-card__progress-fill" style="width: #{percent}%"></div></div>)

        _other ->
          ""
      end

    """
    <article class="#{css_classes(["ash-thread-card", prop_class(iur)])}" data-thread-id="#{thread_id}"#{style_attr(prop_style(iur))}>
      <header class="ash-thread-card__header">
        <div class="ash-thread-card__avatars" aria-hidden="true">#{avatars}</div>
        <h3 class="ash-thread-card__title">#{title}</h3>
      </header>
      <blockquote class="ash-thread-card__seed-quote">#{seed_quote}</blockquote>
      #{progress_html}
      <footer class="ash-thread-card__footer">
        <span class="ash-thread-card__meta">#{reply_count} replies</span>
        <button type="button" class="ash-thread-card__open" aria-label="Open thread: #{title}">Open</button>
      </footer>
    </article>
    """
  end

  defp generate_heex(%{"type" => "tool_call_card"} = iur, _opts) do
    props = iur["props"] || %{}
    tool_call = props |> prop("tool_call", %{}) |> normalize_item()

    tool_name =
      escaped_text_prop(
        tool_call,
        "tool_name",
        escaped_text_prop(props, ["tool_name", "name"], "Tool")
      )

    tool_kind =
      escaped_text_prop(tool_call, "tool_kind", escaped_text_prop(props, "tool_kind", "other"))

    target = escaped_text_prop(tool_call, "target", escaped_text_prop(props, "target", ""))
    summary = escaped_text_prop(tool_call, "summary", escaped_text_prop(props, "summary", ""))
    status = escaped_text_prop(tool_call, "status", escaped_text_prop(props, "status", "pending"))
    expanded? = truthy_prop(tool_call, "expanded?", truthy_prop(props, "expanded?", false))
    args = prop(tool_call, "args", prop(props, "args", %{}))
    result = prop(tool_call, "tool_result_summary", prop(props, "tool_result_summary"))

    iur_id = iur["id"] || iur[:id] || "tool-call-card"
    details_id = "#{iur_id}-details"

    args_html =
      if expanded? do
        ~s(<section id="#{details_id}" class="ash-tool-call-card__details"><h4 class="ash-tool-call-card__args-label">Args</h4><pre class="ash-tool-call-card__args"><code>#{html_escape(inspect(args, pretty: true, limit: :infinity, printable_limit: :infinity))}</code></pre></section>)
      else
        ""
      end

    result_html =
      case result do
        nil ->
          ""

        result ->
          result = normalize_item(result)
          event_id = escaped_text_prop(result, ["event_id", "result_event_id"], "")
          result_status = escaped_text_prop(result, "status", "")
          compact_output = escaped_text_prop(result, ["compact_output", "summary"], "")
          diff_summary = escaped_text_prop(result, "diff_summary")
          error? = truthy_prop(result, "error?", truthy_prop(result, "error", false))

          """
          <section class="#{css_classes(["ash-tool-call-card__result", error? && "has-error"])}">
            <header class="ash-tool-call-card__result-header">
              <span class="ash-tool-call-card__result-event">#{event_id}</span>
              <span class="ash-tool-call-card__result-status ash-tool-call-card__result-status--#{result_status}">#{result_status}</span>
            </header>
            <p class="ash-tool-call-card__result-output">#{compact_output}</p>
            #{if diff_summary, do: "<p class=\"ash-tool-call-card__result-diff\">#{diff_summary}</p>", else: ""}
            #{if error?, do: "<p class=\"ash-tool-call-card__result-error\">Error</p>", else: ""}
          </section>
          """
      end

    """
    <article id="#{iur_id}" class="#{css_classes(["ash-tool-call-card", "ash-tool-call-card--#{status}", expanded? && "is-expanded", prop_class(iur)])}" data-live-ui-widget="tool-call-card" data-tool-kind="#{tool_kind}" data-status="#{status}"#{style_attr(prop_style(iur))}>
      <header class="ash-tool-call-card__header">
        <span class="ash-tool-call-card__glyph" aria-hidden="true">#{tool_kind}</span>
        <div class="ash-tool-call-card__identity">
          <h3 class="ash-tool-call-card__name">#{tool_name}</h3>
          <p class="ash-tool-call-card__target">#{target}</p>
        </div>
        <span class="ash-tool-call-card__status-badge ash-tool-call-card__status-badge--#{status}">#{status}</span>
      </header>
      <p class="ash-tool-call-card__summary">#{summary}</p>
      <button type="button" class="ash-tool-call-card__expand-toggle" aria-label="Toggle tool call #{tool_name} (#{status}) details" aria-expanded="#{expanded?}" aria-controls="#{details_id}">Details</button>
      #{args_html}
      #{result_html}
    </article>
    """
  end

  defp generate_heex(%{"type" => "pipeline_stepper_horizontal"} = iur, _opts) do
    props = iur["props"] || %{}
    steps = prop(props, "steps", [])
    active_index = prop(props, "active_index", 0)

    steps_html =
      steps
      |> List.wrap()
      |> Enum.with_index()
      |> Enum.map_join(fn {step, index} ->
        step = normalize_item(step)
        label = escaped_text_prop(step, ["label", "title", "id"], "Step")

        state =
          escaped_text_prop(
            step,
            "state",
            if(index == active_index, do: "active", else: "pending")
          )

        ~s(<li class="ash-pipeline-step ash-pipeline-step-#{state}" aria-current="#{index == active_index}">#{label}</li>)
      end)

    """
    <ol class="#{css_classes(["ash-pipeline-stepper-horizontal", prop_class(iur)])}"#{style_attr(prop_style(iur))}>#{steps_html}</ol>
    """
  end

  defp generate_heex(%{"type" => "segmented_progress_bar"} = iur, _opts) do
    props = iur["props"] || %{}
    label = escaped_text_prop(props, "label", "Progress")
    segments = List.wrap(prop(props, "segments", []))

    total =
      max(Enum.reduce(segments, 0, &(numeric_value(normalize_item(&1), "weight", 1) + &2)), 1)

    segments_html =
      Enum.map_join(segments, fn segment ->
        segment = normalize_item(segment)
        width = percentage(numeric_value(segment, "weight", 1), total)
        state = escaped_text_prop(segment, "state", "neutral")

        ~s(<span class="ash-segmented-progress-segment ash-segmented-progress-#{state}" style="width: #{width}%"></span>)
      end)

    """
    <div class="#{css_classes(["ash-segmented-progress-bar", prop_class(iur)])}" role="progressbar" aria-label="#{label}"#{style_attr(prop_style(iur))}>#{segments_html}</div>
    """
  end

  defp generate_heex(%{"type" => "workflow_stage_list_vertical"} = iur, _opts) do
    props = iur["props"] || %{}
    stages = List.wrap(prop(props, "stages", []))
    active_index = prop(props, "active_index", 0)

    stages_html =
      stages
      |> Enum.with_index()
      |> Enum.map_join(fn {stage, index} ->
        stage = normalize_item(stage)
        label = escaped_text_prop(stage, ["label", "title", "id"], "Stage")

        state =
          escaped_text_prop(
            stage,
            "state",
            if(index == active_index, do: "active", else: "pending")
          )

        ~s(<li class="ash-workflow-stage ash-workflow-stage-#{state}" aria-current="#{index == active_index}">#{label}</li>)
      end)

    """
    <ol class="#{css_classes(["ash-workflow-stage-list-vertical", prop_class(iur)])}"#{style_attr(prop_style(iur))}>#{stages_html}</ol>
    """
  end

  defp generate_heex(%{"type" => "meter_thin"} = iur, _opts) do
    props = iur["props"] || %{}
    current = numeric_value(props, "current", numeric_value(props, "value", 0))
    minimum = numeric_value(props, "minimum", 0)
    maximum = max(numeric_value(props, "maximum", 100), minimum + 1)
    label = escaped_text_prop(props, "label", "Meter")

    """
    <label class="#{css_classes(["ash-meter-thin", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <span class="ash-meter-thin-label">#{label}</span>
      <meter class="ash-meter-thin-value" min="#{minimum}" max="#{maximum}" value="#{current}"></meter>
    </label>
    """
  end

  defp generate_heex(%{"type" => "workflow_progress_status_card"} = iur, _opts) do
    props = iur["props"] || %{}
    subject = if is_map(prop(props, "subject")), do: prop(props, "subject", %{}), else: %{}

    status_counts =
      if is_map(prop(subject, "status_counts")),
        do: prop(subject, "status_counts", %{}),
        else: %{}

    state = if is_map(prop(subject, "state")), do: prop(subject, "state", %{}), else: %{}

    name = escaped_text_prop(subject, "name", "")
    progress_value = prop(subject, "progress", 0.0)

    progress_pct_int =
      case progress_value do
        n when is_float(n) -> trunc(n)
        n when is_integer(n) -> n
        _ -> 0
      end

    active_count = numeric_value(status_counts, "active", 0)
    blocked_count = numeric_value(status_counts, "blocked", 0)
    path = text_prop(subject, "path")
    selected = truthy_prop(state, "selected?", false)

    """
    <article class="#{css_classes(["ash-workflow-progress-status-card", selected && "ash-workflow-progress-status-card--selected", prop_class(iur)])}" data-subject-card="#{name}" data-selected="#{selected}"#{style_attr(prop_style(iur))}>
      <header class="ash-workflow-progress-status-card__header">
        <span class="ash-workflow-progress-status-card__title">#{name}</span>
        #{if path, do: "<span class=\"ash-workflow-progress-status-card__path\">#{html_attr(path)}</span>", else: ""}
      </header>
      <div class="ash-workflow-progress-status-card__progress-track" role="progressbar" aria-valuenow="#{progress_pct_int}" aria-valuemin="0" aria-valuemax="100" aria-label="#{name} progress: #{progress_pct_int}%">
        <div class="ash-workflow-progress-status-card__progress-fill" style="width: #{progress_pct_int}%"></div>
      </div>
      <div class="ash-workflow-progress-status-card__stats">
        <span class="ash-workflow-progress-status-card__stat-chip">#{active_count} active</span>
        <span class="ash-workflow-progress-status-card__stat-chip" data-loud="#{blocked_count > 0}">#{blocked_count} blocked</span>
      </div>
    </article>
    """
  end

  defp generate_heex(%{"type" => "live_session_card"} = iur, _opts) do
    props = iur["props"] || %{}
    live_session = prop(props, "live_session", props) |> normalize_item()

    session_id = escaped_text_prop(live_session, "session_id", "")
    actor_handle = escaped_text_prop(live_session, "actor_handle", "")
    status = escaped_text_prop(live_session, "status", "running")
    status_version = numeric_value(live_session, "status_version", 0)
    tools_count = numeric_value(live_session, "tools_count", 0)
    edits_count = numeric_value(live_session, "edits_count", 0)
    tokens_consumed = numeric_value(live_session, "tokens_consumed", 0)
    started_at = escaped_text_prop(live_session, "started_at", "")
    current_step = escaped_text_prop(live_session, "current_step")
    current_task_title = escaped_text_prop(live_session, "current_task_title")
    now_streaming = escaped_text_prop(live_session, "now_streaming")
    pinned? = truthy_prop(live_session, "pinned?", false)
    iur_id = iur["id"] || iur[:id] || "live-session-card"

    recent_events =
      live_session
      |> prop("recent_events", [])
      |> List.wrap()
      |> Enum.take(5)
      |> Enum.map_join(fn event ->
        event = normalize_item(event)
        kind = escaped_text_prop(event, "kind", "")
        body = escaped_text_prop(event, ["body", "body_fragment", "fragment"], "")

        """
        <li class="ash-live-session-card__recent-item" data-event-kind="#{kind}">
          <span class="ash-live-session-card__recent-kind">#{kind}</span>
          <span class="ash-live-session-card__recent-body">#{body}</span>
        </li>
        """
      end)

    task_html =
      cond do
        current_task_title ->
          ~s(<p class="ash-live-session-card__task">#{current_task_title}</p>)

        current_step ->
          ~s(<p class="ash-live-session-card__task">#{current_step}</p>)

        true ->
          ""
      end

    now_streaming_html =
      if now_streaming do
        """
        <div class="ash-live-session-card__now-streaming" aria-live="polite" aria-atomic="true">
          <span class="ash-live-session-card__live-indicator" aria-hidden="true">LIVE</span>
          <span class="ash-live-session-card__now-streaming-text">#{now_streaming}</span>
        </div>
        """
      else
        ""
      end

    """
    <article id="#{html_attr(iur_id)}" class="#{css_classes(["ash-live-session-card", "ash-live-session-card--#{status}", pinned? && "is-pinned", prop_class(iur)])}" data-live-ui-widget="live-session-card" data-session-id="#{session_id}" data-status-version="#{status_version}" data-pinned="#{pinned?}"#{style_attr(prop_style(iur))}>
      <header class="ash-live-session-card__header">
        <span class="ash-live-session-card__avatar" aria-hidden="true">#{String.first(actor_handle) || "?"}</span>
        <div class="ash-live-session-card__identity">
          <h3 class="ash-live-session-card__actor">#{actor_handle}</h3>
          #{task_html}
        </div>
        <span class="ash-live-session-card__status-badge" role="status">#{String.upcase(status)}</span>
        <time class="ash-live-session-card__duration" datetime="#{started_at}">#{adapter_duration_label(started_at)}</time>
      </header>
      <div class="ash-live-session-card__meters">
        <div class="ash-live-session-card__meter" data-meter="tools"><span class="ash-live-session-card__meter-value">#{tools_count}</span><span class="ash-live-session-card__meter-label">tools</span></div>
        <div class="ash-live-session-card__meter" data-meter="edits"><span class="ash-live-session-card__meter-value">#{edits_count}</span><span class="ash-live-session-card__meter-label">edits</span></div>
        <div class="ash-live-session-card__meter" data-meter="tokens"><span class="ash-live-session-card__meter-value">#{tokens_consumed}</span><span class="ash-live-session-card__meter-label">tokens</span></div>
      </div>
      #{now_streaming_html}
      <ol class="ash-live-session-card__recent" aria-label="Recent activity for #{actor_handle}" data-live-ui-intent="expanded_recent">#{recent_events}</ol>
      <footer class="ash-live-session-card__actions">
        <button type="button" class="ash-live-session-card__pin" aria-label="#{if pinned?, do: "Unpin", else: "Pin"} #{actor_handle} running session" aria-pressed="#{pinned?}" data-live-ui-intent="pin_toggled">#{if(pinned?, do: "Pinned", else: "Pin")}</button>
        <button type="button" class="ash-live-session-card__interrupt" aria-label="Interrupt #{actor_handle} running session" data-live-ui-intent="interrupted">Interrupt</button>
      </footer>
    </article>
    """
  end

  defp generate_heex(%{"type" => "confidence_indicator"} = iur, _opts) do
    props = iur["props"] || %{}

    confidence =
      if is_map(prop(props, "confidence")), do: prop(props, "confidence", %{}), else: props

    thresholds =
      if is_map(prop(confidence, "thresholds")),
        do: prop(confidence, "thresholds", %{}),
        else: %{}

    value = confidence_number(prop(confidence, "value", 0.0), 0.0)
    pct = trunc(value * 100)
    warn_threshold = confidence_number(prop(thresholds, "warn", 0.5), 0.5)
    pass_threshold = confidence_number(prop(thresholds, "pass", 0.8), 0.8)
    label = escaped_text_prop(confidence, "label", "Confidence: #{pct}%")
    size = escaped_text_prop(confidence, "size", "medium")
    show_glyph? = truthy_prop(confidence, "show_glyph?", true)
    show_numeric? = truthy_prop(confidence, "show_numeric?", true)

    band =
      cond do
        value >= pass_threshold -> "pass"
        value >= warn_threshold -> "warn"
        true -> "fail"
      end

    glyph =
      case band do
        "pass" -> "OK"
        "warn" -> "!"
        _band -> "X"
      end

    """
    <div class="#{css_classes(["ash-confidence-indicator", "ash-confidence-indicator-#{band}", "ash-confidence-indicator-#{size}", prop_class(iur)])}" data-confidence-band="#{band}" role="meter" aria-valuenow="#{pct}" aria-valuemin="0" aria-valuemax="100" aria-label="#{label}"#{style_attr(prop_style(iur))}>
      #{if(show_glyph?, do: ~s(<span class="ash-confidence-indicator__glyph" aria-hidden="true">#{glyph}</span>), else: "")}
      <div class="ash-confidence-indicator__bar"><div class="ash-confidence-indicator__bar-fill" style="width: #{pct}%"></div></div>
      #{if(show_numeric?, do: ~s(<span class="ash-confidence-indicator__numeric">#{pct}%</span>), else: "")}
    </div>
    """
  end

  defp generate_heex(%{"type" => "diff_banner"} = iur, _opts) do
    props = iur["props"] || %{}
    diff = if is_map(prop(props, "diff")), do: prop(props, "diff", %{}), else: props
    new_count = prop(diff, "new_count", 0)
    changed_count = prop(diff, "changed_count", 0)
    removed_count = prop(diff, "removed_count", 0)

    total_count =
      numeric_count(new_count) + numeric_count(changed_count) + numeric_count(removed_count)

    active_filter = text_prop(diff, "active_filter", "all")
    size = text_prop(diff, "size", "default")
    base_label = escaped_text_prop(diff, ["base_label", "base"])

    chips =
      [
        {"all", total_count},
        {"new", new_count},
        {"changed", changed_count},
        {"removed", removed_count}
      ]
      |> Enum.map_join("\n      ", fn {kind, count} ->
        active_class = if active_filter == kind, do: " ash-diff-banner__chip--active", else: ""

        ~s(<span class="ash-diff-banner__chip ash-diff-banner__chip--#{kind}#{active_class}" data-filter-kind="#{kind}">#{html_escape(count)} #{kind}</span>)
      end)

    base_html =
      if base_label && size != "compact" do
        ~s(<span class="ash-diff-banner__base">#{base_label}</span>)
      else
        ""
      end

    """
    <aside class="#{css_classes(["ash-diff-banner", "ash-diff-banner--#{size}", prop_class(iur)])}" data-live-ui-widget="diff-banner" data-active-filter="#{html_attr(active_filter)}"#{style_attr(prop_style(iur))}>
      #{base_html}
      <div class="ash-diff-banner__chips">
      #{chips}
      </div>
    </aside>
    """
  end

  defp generate_heex(%{"type" => "ask_sidebar"} = iur, _opts) do
    props = iur["props"] || %{}
    sidebar_id = escaped_text_prop(props, ["sidebar_id"], "")
    on_map_jump_event = escaped_text_prop(props, ["on_map_jump_event"], "switch_to_map")
    recent_items = List.wrap(prop(props, "recent_items", []))
    saved_items = List.wrap(prop(props, "saved_items", []))
    active_item_id = text_prop(props, "active_item_id")
    blocker_count = trunc(numeric_value(props, "blocker_count", 0))
    on_new_saved_event = text_prop(props, "on_new_saved_event")
    on_see_all_event = text_prop(props, "on_see_all_event")
    empty_recent_label = escaped_text_prop(props, "empty_recent_label", "No recent queries")
    empty_saved_label = escaped_text_prop(props, "empty_saved_label", "No saved queries yet")

    recent_display = Enum.take(recent_items, 10)
    show_see_all = on_see_all_event != nil and length(recent_items) > 6

    recent_rows_html =
      if Enum.empty?(recent_display) do
        "<p class=\"ash-ask-sidebar__empty\">#{empty_recent_label}</p>"
      else
        Enum.map_join(recent_display, fn item ->
          item = normalize_item(item)
          item_id = text_prop(item, "id", "")
          query = html_escape(text_prop(item, "query", ""))
          on_open_event = text_prop(item, "on_open_event", "")

          active_class =
            if active_item_id != nil and item_id == active_item_id,
              do: " ash-ask-sidebar__item--active",
              else: ""

          aria_current =
            if active_item_id != nil and item_id == active_item_id, do: "true", else: "false"

          "<button type=\"button\" class=\"ash-ask-sidebar__item ash-ask-sidebar__item--recent#{active_class}\" aria-current=\"#{aria_current}\" data-live-ui-intent=\"#{html_attr(on_open_event)}\" data-live-ui-value=\"#{html_attr(item_id)}\" data-item-id=\"#{html_attr(item_id)}\">#{query}</button>"
        end)
      end

    see_all_html =
      if show_see_all do
        "<button type=\"button\" class=\"ash-ask-sidebar__see-all\" data-live-ui-intent=\"#{html_attr(on_see_all_event)}\">see all</button>"
      else
        ""
      end

    saved_rows_html =
      if Enum.empty?(saved_items) do
        "<p class=\"ash-ask-sidebar__empty\">#{empty_saved_label}</p>"
      else
        Enum.map_join(saved_items, fn item ->
          item = normalize_item(item)
          item_id = text_prop(item, "id", "")
          title = html_escape(text_prop(item, "title", ""))
          on_open_event = text_prop(item, "on_open_event", "")

          active_class =
            if active_item_id != nil and item_id == active_item_id,
              do: " ash-ask-sidebar__item--active",
              else: ""

          aria_current =
            if active_item_id != nil and item_id == active_item_id, do: "true", else: "false"

          "<button type=\"button\" class=\"ash-ask-sidebar__item ash-ask-sidebar__item--saved#{active_class}\" aria-current=\"#{aria_current}\" data-live-ui-intent=\"#{html_attr(on_open_event)}\" data-live-ui-value=\"#{html_attr(item_id)}\" data-item-id=\"#{html_attr(item_id)}\"><span aria-hidden=\"true\">&#x2605;</span>#{title}</button>"
        end)
      end

    new_saved_html =
      if on_new_saved_event do
        "<button type=\"button\" class=\"ash-ask-sidebar__new-saved\" data-live-ui-intent=\"#{html_attr(on_new_saved_event)}\">+ new</button>"
      else
        ""
      end

    blocker_badge_html =
      if blocker_count > 0 do
        "<span class=\"ash-ask-sidebar__blocker-badge\" aria-label=\"#{blocker_count} blockers\">#{blocker_count}</span>"
      else
        ""
      end

    """
    <aside class="#{css_classes(["ash-ask-sidebar", prop_class(iur)])}" data-live-ui-widget="ask-sidebar" data-sidebar-id="#{sidebar_id}" aria-label="Ask sidebar"#{style_attr(prop_style(iur))}>
      <div class="ash-ask-sidebar__scroll">
        <section class="ash-ask-sidebar__section" aria-labelledby="ask-recent-h-#{sidebar_id}">
          <div class="ash-ask-sidebar__section-header">
            <span id="ask-recent-h-#{sidebar_id}" class="ash-ask-sidebar__section-label">Recent</span>
            #{see_all_html}
          </div>
          <div class="ash-ask-sidebar__rail">#{recent_rows_html}</div>
        </section>
        <section class="ash-ask-sidebar__section" aria-labelledby="ask-saved-h-#{sidebar_id}">
          <div class="ash-ask-sidebar__section-header">
            <span id="ask-saved-h-#{sidebar_id}" class="ash-ask-sidebar__section-label">Saved</span>
            #{new_saved_html}
          </div>
          <div class="ash-ask-sidebar__rail">#{saved_rows_html}</div>
        </section>
        <div class="ash-ask-sidebar__map-jump">
          <button type="button" class="ash-ask-sidebar__map-jump-btn" aria-label="Switch to Map mode" data-live-ui-intent="#{on_map_jump_event}" data-live-ui-value="map">Map#{blocker_badge_html}</button>
        </div>
      </div>
    </aside>
    """
  end

  defp generate_heex(%{"type" => "sticky_frosted_header"} = iur, opts) do
    props = iur["props"] || %{}
    title = escaped_text_prop(props, ["title", "label"], "")

    """
    <header class="#{css_classes(["ash-sticky-frosted-header", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      #{if title != "", do: "<h2 class=\"ash-sticky-frosted-header-title\">#{title}</h2>", else: ""}
      <div class="ash-sticky-frosted-header-actions">#{generate_children(iur["children"], opts)}</div>
    </header>
    """
  end

  defp generate_heex(%{"type" => "slide_over_panel"} = iur, opts) do
    props = iur["props"] || %{}
    label = escaped_text_prop(props, ["label", "title"], "Panel")
    open? = truthy_prop(props, "open?", truthy_prop(props, "open", false))

    """
    <aside class="#{css_classes(["ash-slide-over-panel", open? && "is-open", !open? && "is-closed", prop_class(iur)])}" aria-label="#{label}" aria-hidden="#{!open?}"#{style_attr(prop_style(iur))}>
      <header class="ash-slide-over-panel-header"><h2>#{label}</h2></header>
      <div class="ash-slide-over-panel-body">#{generate_children(iur["children"], opts)}</div>
    </aside>
    """
  end

  defp generate_heex(%{"type" => "event_callout"} = iur, opts) do
    props = iur["props"] || %{}
    message = escaped_text_prop(props, ["message", "body", "content", "text"], "")
    title = escaped_text_prop(props, "title")
    eyebrow = escaped_text_prop(props, "eyebrow")
    tone = escaped_text_prop(props, "tone", "info")

    """
    <aside class="#{css_classes(["ash-event-callout", "ash-event-callout-#{tone}", prop_class(iur)])}" role="note"#{style_attr(prop_style(iur))}>
      #{if eyebrow, do: "<p class=\"ash-event-callout-eyebrow\">#{eyebrow}</p>", else: ""}
      #{if title, do: "<h2 class=\"ash-event-callout-title\">#{title}</h2>", else: ""}
      <p class="ash-event-callout-message">#{message}</p>
      #{generate_children(iur["children"], opts)}
    </aside>
    """
  end

  defp generate_heex(%{"type" => "redline_inline"} = iur, _opts) do
    props = iur["props"] || %{}
    segments = List.wrap(prop(props, "segments", []))

    content =
      Enum.map_join(segments, fn segment ->
        segment = normalize_item(segment)
        state = text_prop(segment, "state", "keep")
        text = html_escape(text_prop(segment, "text", ""))
        tag = if state in ["delete", "rejected"], do: "del", else: "span"

        ~s(<#{tag} class="ash-redline-inline-segment ash-redline-inline-#{state}">#{text}</#{tag}>)
      end)

    """
    <span class="#{css_classes(["ash-redline-inline", prop_class(iur)])}"#{style_attr(prop_style(iur))}>#{content}</span>
    """
  end

  defp generate_heex(%{"type" => "code_block_syntax_highlighted"} = iur, _opts) do
    props = iur["props"] || %{}
    language = escaped_text_prop(props, "language", "text")
    tokens = List.wrap(prop(props, "tokens", []))

    code =
      Enum.map_join(tokens, fn token ->
        token = normalize_item(token)
        type = escaped_text_prop(token, "type", "text")
        text = html_escape(text_prop(token, "text", ""))
        ~s(<span class="ash-code-token ash-code-token-#{type}">#{text}</span>)
      end)

    """
    <pre class="#{css_classes(["ash-code-block-syntax-highlighted", prop_class(iur)])}" data-language="#{language}"#{style_attr(prop_style(iur))}><code>#{code}</code></pre>
    """
  end

  defp generate_heex(%{"type" => "list_repeat"} = iur, opts) do
    props = iur["props"] || %{}
    binding_id = escaped_text_prop(props, ["binding_id", "repeat_binding"], "rows")

    """
    <div class="#{css_classes(["ash-list-repeat", prop_class(iur)])}" data-repeat-binding="#{binding_id}"#{style_attr(prop_style(iur))}>
      #{generate_children(iur["children"], opts)}
    </div>
    """
  end

  defp generate_heex(%{"type" => "label"} = iur, _opts) do
    props = iur["props"] || %{}
    content = text_prop(props, ["text", "content", "label"], "")

    """
    <label class="#{css_classes(["ash-label", prop_class(iur)])}"#{attr("for", dom_id(prop(props, "for")))}#{style_attr(prop_style(iur))}>#{content}</label>
    """
  end

  defp generate_heex(%{"type" => "icon"} = iur, _opts) do
    props = iur["props"] || %{}
    name = text_prop(props, ["name", "icon", "value"], "spark")
    label = text_prop(props, ["label", "text", "content"], name)

    """
    <span class="#{css_classes(["ash-icon", prop_class(iur)])}" role="img" aria-label="#{label}"#{style_attr(prop_style(iur))}>
      <span class="ash-icon-glyph">#{icon_glyph(name)}</span>
      <span class="ash-icon-label">#{label}</span>
    </span>
    """
  end

  defp generate_heex(%{"type" => "image"} = iur, _opts) do
    props = iur["props"] || %{}
    src = text_prop(props, ["src", "source", "url"], "")
    alt = text_prop(props, ["alt", "label", "content"], "Image")
    caption = text_prop(props, ["caption", "description"])

    """
    <figure class="#{css_classes(["ash-image", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <img src="#{src}" alt="#{alt}" loading="lazy" />
      #{if caption, do: "<figcaption class=\"ash-image-caption\">#{caption}</figcaption>", else: ""}
    </figure>
    """
  end

  defp generate_heex(%{"type" => "link"} = iur, opts) do
    generate_heex(%{iur | "type" => "custom:link"}, opts)
  end

  defp generate_heex(%{"type" => "badge"} = iur, opts) do
    props = iur["props"] || %{}
    presentation = prop(props, "presentation", "default")
    content = text_prop(props, ["text", "label", "content"], "")

    """
    <span class="#{css_classes(["ash-badge", "ash-badge-#{presentation}", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      #{content}
      #{generate_children(iur["children"], opts)}
    </span>
    """
  end

  defp generate_heex(%{"type" => "hero"} = iur, opts) do
    props = iur["props"] || %{}
    eyebrow = text_prop(props, "eyebrow")
    title = text_prop(props, "title")
    message = text_prop(props, "message")

    """
    <section class="#{css_classes(["ash-hero", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      #{if eyebrow, do: "<p class=\"ash-hero-eyebrow\">#{eyebrow}</p>", else: ""}
      #{if title, do: "<h1 class=\"ash-hero-title\">#{title}</h1>", else: ""}
      #{if message, do: "<p class=\"ash-hero-message\">#{message}</p>", else: ""}
      #{generate_children(iur["children"], opts)}
    </section>
    """
  end

  defp generate_heex(%{"type" => "stat"} = iur, _opts) do
    props = iur["props"] || %{}
    title = text_prop(props, "title")
    value = text_prop(props, "value")
    message = text_prop(props, "message")

    """
    <article class="#{css_classes(["ash-stat", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      #{if title, do: "<p class=\"ash-stat-title\">#{title}</p>", else: ""}
      #{if value, do: "<p class=\"ash-stat-value\">#{value}</p>", else: ""}
      #{if message, do: "<p class=\"ash-stat-message\">#{message}</p>", else: ""}
    </article>
    """
  end

  defp generate_heex(%{"type" => "key_value"} = iur, _opts) do
    props = iur["props"] || %{}
    label = text_prop(props, ["label", "title"])
    value = text_prop(props, "value")
    description = text_prop(props, "description")

    """
    <dl class="#{css_classes(["ash-key-value", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      #{if label, do: "<dt class=\"ash-key-value-label\">#{label}</dt>", else: ""}
      #{if value, do: "<dd class=\"ash-key-value-value\">#{value}</dd>", else: ""}
      #{if description, do: "<dd class=\"ash-key-value-description\">#{description}</dd>", else: ""}
    </dl>
    """
  end

  defp generate_heex(%{"type" => "info_list"} = iur, _opts) do
    props = iur["props"] || %{}
    items = prop(props, "items", [])
    list_tag = if prop(props, "ordered?", false), do: "ol", else: "ul"

    items_html =
      Enum.map_join(items, fn item ->
        item = normalize_item(item)
        label = text_prop(item, ["label", "title", "value", "id"], "")
        value = text_prop(item, "value")

        """
        <li class="ash-info-list-item">
          <span class="ash-info-list-label">#{label}</span>
          #{if value && value != label, do: "<span class=\"ash-info-list-value\">#{value}</span>", else: ""}
        </li>
        """
      end)

    """
    <#{list_tag} class="#{css_classes(["ash-info-list", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      #{items_html}
    </#{list_tag}>
    """
  end

  defp generate_heex(%{"type" => "list"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "List")
    description = text_prop(props, ["description", "help"])
    empty_text = text_prop(props, "empty_text", "No items available.")
    items = collection_items(props)
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    items_html =
      case items do
        [] ->
          ~s(<li class="ash-list-empty">#{empty_text}</li>)

        collection ->
          Enum.map_join(collection, &render_list_item/1)
      end

    """
    <section class="#{css_classes(["ash-list", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-list-header">
        <h2 class="ash-list-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-list-description\">#{description}</p>", else: ""}
      </header>
      <ul class="ash-list-items">
        #{items_html}
      </ul>
      <div class="ash-list-body">
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-list-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-list-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "table"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Table")
    description = text_prop(props, ["description", "help"])
    empty_text = text_prop(props, "empty_text", "No rows available.")
    columns = table_columns(props)
    rows = collection_items(props)
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    header_html = Enum.map_join(columns, &render_table_header/1)

    rows_html =
      case rows do
        [] ->
          """
          <tr class="ash-table-empty-row">
            <td class="ash-table-empty" colspan="#{max(length(columns), 1)}">#{empty_text}</td>
          </tr>
          """

        collection ->
          Enum.map_join(collection, &render_table_row(&1, columns))
      end

    """
    <section class="#{css_classes(["ash-table-surface", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-table-header">
        <h2 class="ash-table-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-table-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-table-wrapper">
        <table class="ash-table">
          <thead>
            <tr>#{header_html}</tr>
          </thead>
          <tbody>
            #{rows_html}
          </tbody>
        </table>
      </div>
      <div class="ash-table-body">
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-table-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-table-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "form_builder"} = iur, opts) do
    event_prefix = Map.get(opts, :event_prefix, "ash_ui")
    binding = find_binding(opts, iur["id"], "event")

    submit_attrs =
      if binding do
        ~s( phx-submit="#{event_name(event_prefix, :action)}"#{attr("phx-value-action_id", binding["id"])}#{attr("phx-value-element_id", iur["id"])}#{attr("phx-value-signal", binding_signal(binding, "submit"))})
      else
        ""
      end

    """
    <form class="#{css_classes(["ash-form-builder", prop_class(iur)])}"#{style_attr(prop_style(iur))}#{submit_attrs}>
      #{generate_children(iur["children"], opts)}
    </form>
    """
  end

  defp generate_heex(%{"type" => "form_field"} = iur, opts) do
    props = iur["props"] || %{}
    label = text_prop(props, ["label", "title"])
    help = text_prop(props, ["help", "description"])

    """
    <div class="#{css_classes(["ash-form-field", prop_class(iur)])}"#{attr("data-field-name", dom_id(prop(props, "name")))}#{style_attr(prop_style(iur))}>
      #{if label, do: "<label class=\"ash-form-field-label\">#{label}</label>", else: ""}
      #{generate_children(iur["children"], opts)}
      #{if help, do: "<p class=\"ash-form-field-help\">#{help}</p>", else: ""}
    </div>
    """
  end

  defp generate_heex(%{"type" => "button"} = iur, opts) do
    label = Map.get(iur["props"] || %{}, "label", "Button")
    event_prefix = Map.get(opts, :event_prefix, "ash_ui")
    variant = Map.get(iur["props"] || %{}, "variant", "primary")
    button_type = Map.get(iur["props"] || %{}, "type", "button")
    disabled? = !!Map.get(iur["props"] || %{}, "disabled")
    binding = find_binding(opts, iur["id"], "event")

    class_name =
      css_classes([
        "ash-button",
        "ash-button-#{variant}",
        disabled? && "is-disabled",
        prop_class(iur)
      ])

    event_attrs =
      if binding && button_type != "submit" do
        click_event = event_name(event_prefix, :action)
        action_attr = attr("phx-value-action_id", binding["id"])
        element_attr = attr("phx-value-element_id", iur["id"])
        signal_attr = attr("phx-value-signal", binding_signal(binding, "click"))
        ~s( phx-click="#{click_event}"#{action_attr}#{element_attr}#{signal_attr})
      else
        ""
      end

    """
    <button type="#{button_type}" class="#{class_name}"#{style_attr(prop_style(iur))}#{if(disabled?, do: " disabled", else: "")}#{event_attrs}>#{label}</button>
    """
  end

  defp generate_heex(%{"type" => "input"} = iur, opts) do
    render_text_input(iur, opts, "input")
  end

  defp generate_heex(%{"type" => "textarea"} = iur, opts) do
    name = Map.get(iur["props"] || %{}, "name", "textarea")
    placeholder = Map.get(iur["props"] || %{}, "placeholder", "")
    value = Map.get(iur["props"] || %{}, "value", "")
    rows = Map.get(iur["props"] || %{}, "rows", 4)
    event_prefix = Map.get(opts, :event_prefix, "ash_ui")
    binding = find_binding(opts, iur["id"], "bidirectional")

    """
    <textarea class="#{css_classes(["ash-textarea", prop_class(iur)])}" name="#{name}" rows="#{rows}" placeholder="#{placeholder}"#{style_attr(prop_style(iur))} phx-blur="#{event_name(event_prefix, :change)}" phx-change="#{event_name(event_prefix, :change)}"#{attr("phx-value-binding_id", binding && binding["id"])}#{attr("phx-value-target", binding && binding["target"])}#{attr("phx-value-element_id", iur["id"])}#{attr("phx-value-signal", "change")}>#{value}</textarea>
    """
  end

  defp generate_heex(%{"type" => "checkbox"} = iur, opts) do
    name = Map.get(iur["props"] || %{}, "name", "checkbox")
    event_prefix = Map.get(opts, :event_prefix, "ash_ui")
    checked? = !!Map.get(iur["props"] || %{}, "checked")
    checked = if checked?, do: " checked", else: ""
    binding = find_binding(opts, iur["id"], "bidirectional")
    next_value = if checked?, do: "false", else: "true"

    """
    <input type="checkbox" class="#{css_classes(["ash-checkbox", prop_class(iur)])}" name="#{name}"#{style_attr(prop_style(iur))}#{checked} phx-click="#{event_name(event_prefix, :change)}"#{attr("phx-value-binding_id", binding && binding["id"])}#{attr("phx-value-target", binding && binding["target"])}#{attr("phx-value-element_id", iur["id"])}#{attr("phx-value-signal", "change")}#{attr("phx-value-value", next_value)} />
    """
  end

  defp generate_heex(%{"type" => "radio"} = iur, opts) do
    props = iur["props"] || %{}
    name = Map.get(props, "name", "radio")
    options = Map.get(props, "options", [])
    selected_value = Map.get(props, "value")
    event_prefix = Map.get(opts, :event_prefix, "ash_ui")
    binding = find_binding(opts, iur["id"], "bidirectional")

    options_html =
      Enum.map_join(options, fn option ->
        {label, option_value} = normalize_choice(option)

        checked =
          if to_string(option_value) == to_string(selected_value), do: " checked", else: ""

        """
        <label class="ash-radio-option">
          <input type="radio" name="#{name}" value="#{option_value}"#{checked} phx-click="#{event_name(event_prefix, :change)}"#{attr("phx-value-binding_id", binding && binding["id"])}#{attr("phx-value-target", binding && binding["target"])}#{attr("phx-value-element_id", iur["id"])}#{attr("phx-value-signal", "change")}#{attr("phx-value-value", option_value)} />
          <span class="ash-radio-option-label">#{label}</span>
        </label>
        """
      end)

    """
    <fieldset class="#{css_classes(["ash-radio-group", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      #{options_html}
    </fieldset>
    """
  end

  defp generate_heex(%{"type" => "radio_group"} = iur, opts) do
    generate_heex(%{iur | "type" => "radio"}, opts)
  end

  defp generate_heex(%{"type" => "switch"} = iur, opts) do
    props = iur["props"] || %{}
    checked? = !!Map.get(props, "checked")
    label = text_prop(props, ["label", "text", "content"], "Toggle")
    event_prefix = Map.get(opts, :event_prefix, "ash_ui")
    binding = find_binding(opts, iur["id"], "bidirectional")
    next_value = if checked?, do: "false", else: "true"

    """
    <button type="button" role="switch" aria-checked="#{checked?}" class="#{css_classes(["ash-switch", checked? && "is-on", prop_class(iur)])}"#{style_attr(prop_style(iur))} phx-click="#{event_name(event_prefix, :change)}"#{attr("phx-value-binding_id", binding && binding["id"])}#{attr("phx-value-target", binding && binding["target"])}#{attr("phx-value-element_id", iur["id"])}#{attr("phx-value-signal", "change")}#{attr("phx-value-value", next_value)}>
      <span class="ash-switch-track"><span class="ash-switch-thumb"></span></span>
      <span class="ash-switch-label">#{label}</span>
    </button>
    """
  end

  defp generate_heex(%{"type" => "toggle"} = iur, opts) do
    generate_heex(%{iur | "type" => "switch"}, opts)
  end

  defp generate_heex(%{"type" => "select"} = iur, opts) do
    name = Map.get(iur["props"] || %{}, "name", "select")
    options = Map.get(iur["props"] || %{}, "options", [])
    selected_value = Map.get(iur["props"] || %{}, "value")
    event_prefix = Map.get(opts, :event_prefix, "ash_ui")
    binding = find_binding(opts, iur["id"], "bidirectional")

    options_html =
      Enum.map_join(options, fn option ->
        {label, option_value} = normalize_choice(option)

        selected =
          if to_string(option_value) == to_string(selected_value), do: " selected", else: ""

        "<option value=\"#{option_value}\"#{selected}>#{label}</option>"
      end)

    """
    <select class="#{css_classes(["ash-select", prop_class(iur)])}" name="#{name}"#{style_attr(prop_style(iur))} phx-change="#{event_name(event_prefix, :change)}"#{attr("phx-value-binding_id", binding && binding["id"])}#{attr("phx-value-target", binding && binding["target"])}#{attr("phx-value-element_id", iur["id"])}#{attr("phx-value-signal", "change")}>
      #{options_html}
    </select>
    """
  end

  defp generate_heex(%{"type" => "divider"} = iur, _opts) do
    """
    <hr class="#{css_classes(["ash-divider", prop_class(iur)])}"#{style_attr(prop_style(iur))} />
    """
  end

  defp generate_heex(%{"type" => "spacer"} = iur, _opts) do
    size = Map.get(iur["props"] || %{}, "size", 8)

    """
    <div class="#{css_classes(["ash-spacer", prop_class(iur)])}"#{style_attr(merge_style(["height: #{size}px"], prop_style(iur)))}></div>
    """
  end

  defp generate_heex(%{"type" => "custom:link"} = iur, _opts) do
    props = iur["props"] || %{}
    href = text_prop(props, ["href", "to", "url", "target"], "#")
    label = text_prop(props, ["label", "text", "content"], href)
    target = text_prop(props, "target")
    rel = text_prop(props, "rel")

    """
    <a class="#{css_classes(["ash-link", prop_class(iur)])}" href="#{href}"#{attr("target", target)}#{attr("rel", rel)}#{style_attr(prop_style(iur))}>#{label}</a>
    """
  end

  defp generate_heex(%{"type" => "pick_list"} = iur, opts) do
    generate_heex(%{iur | "type" => "custom:pick_list"}, opts)
  end

  defp generate_heex(%{"type" => "custom:pick_list"} = iur, opts) do
    props = iur["props"] || %{}
    options = Map.get(props, "options", [])
    selected_value = Map.get(props, "value")
    event_prefix = Map.get(opts, :event_prefix, "ash_ui")
    binding = find_binding(opts, iur["id"], "bidirectional")

    options_html =
      Enum.map_join(options, fn option ->
        {label, option_value} = normalize_choice(option)
        selected? = to_string(option_value) == to_string(selected_value)

        """
        <button type="button" class="#{css_classes(["ash-pick-list-option", selected? && "is-selected"])}" phx-click="#{event_name(event_prefix, :change)}"#{attr("phx-value-binding_id", binding && binding["id"])}#{attr("phx-value-target", binding && binding["target"])}#{attr("phx-value-element_id", iur["id"])}#{attr("phx-value-signal", "change")}#{attr("phx-value-value", option_value)}>#{label}</button>
        """
      end)

    """
    <div class="#{css_classes(["ash-pick-list", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      #{options_html}
    </div>
    """
  end

  defp generate_heex(%{"type" => "custom:field_group"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"])
    description = text_prop(props, ["description", "help"])

    """
    <section class="#{css_classes(["ash-field-group", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      #{if title, do: "<header class=\"ash-field-group-header\"><h2 class=\"ash-field-group-title\">#{title}</h2>#{if description, do: "<p class=\"ash-field-group-description\">#{description}</p>", else: ""}</header>", else: ""}
      <div class="ash-field-group-body">
        #{generate_children(iur["children"], opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:menu"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Menu")
    description = text_prop(props, ["description", "help"])
    nav_children = slot_children(iur, "nav")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if nav_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <nav class="#{css_classes(["ash-menu", prop_class(iur)])}" aria-label="#{title}"#{style_attr(prop_style(iur))}>
      <header class="ash-menu-header">
        <h2 class="ash-menu-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-menu-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-menu-nav" role="list">
        #{generate_children(nav_children, opts)}
      </div>
      <div class="ash-menu-body">
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-menu-footer">
        #{generate_children(footer_children, opts)}
      </footer>
    </nav>
    """
  end

  defp generate_heex(%{"type" => "custom:tabs"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Tabs")
    description = text_prop(props, ["description", "help"])
    nav_children = slot_children(iur, "nav")
    panel_children = slot_children(iur, "body")

    panel_children =
      if nav_children == [] and panel_children == [] do
        iur["children"] || []
      else
        panel_children
      end

    """
    <section class="#{css_classes(["ash-tabs", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-tabs-header">
        <h2 class="ash-tabs-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-tabs-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-tabs-nav" role="tablist" aria-label="#{title}">
        #{generate_children(nav_children, opts)}
      </div>
      <div class="ash-tabs-panels">
        #{generate_children(panel_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "context_selector"} = iur, _opts) do
    raw_props = iur["props"] || %{}
    props = prop(raw_props, "context_selector", raw_props)
    selector_id = escaped_text_prop(props, ["selector_id", "id"], iur["id"] || "context-selector")
    placeholder = escaped_text_prop(props, "placeholder", "Select context...")
    label_prefix = escaped_text_prop(props, "label_prefix", "context:")
    selected_values = prop(props, "selected_values", []) |> List.wrap() |> Enum.map(&to_string/1)
    open? = truthy_prop(props, "open?", truthy_prop(props, "open", false))
    disabled? = truthy_prop(props, "disabled?", truthy_prop(props, "disabled", false))
    multi? = context_selector_multi?(props)
    groups = prop(props, "groups", [])

    summary =
      case selected_values do
        [] -> placeholder
        [value] -> context_selector_label_for(groups, value) || html_escape(value)
        values -> "#{length(values)} selected"
      end

    groups_html =
      groups
      |> List.wrap()
      |> Enum.map_join(fn group ->
        group_label = escaped_text_prop(group, ["label", "group_label", "id"], "Context")
        items = prop(group, "items", [])

        item_html =
          items
          |> List.wrap()
          |> Enum.map_join(fn item ->
            value = text_prop(item, ["value", "id"], "")
            label = escaped_text_prop(item, ["label", "value", "id"], value)
            description = escaped_text_prop(item, "description")

            selected? =
              to_string(value) in selected_values or truthy_prop(item, "selected?", false)

            item_disabled? = truthy_prop(item, "disabled?", truthy_prop(item, "disabled", false))

            """
            <button type="button" class="#{css_classes(["ash-context-selector-item", selected? && "is-selected"])}" role="option" aria-selected="#{selected?}" data-context-value="#{html_attr(value)}"#{if(item_disabled?, do: " disabled", else: "")}>
              <span class="ash-context-selector-item-indicator" aria-hidden="true">#{if(selected?, do: "[x]", else: "[ ]")}</span>
              <span class="ash-context-selector-item-body">
                <span class="ash-context-selector-item-label">#{label}</span>
                #{if description, do: "<span class=\"ash-context-selector-item-description\">#{description}</span>", else: ""}
              </span>
            </button>
            """
          end)

        """
        <div class="ash-context-selector-group" role="group" aria-label="#{group_label}">
          <div class="ash-context-selector-group-header">#{group_label}</div>
          #{item_html}
        </div>
        """
      end)

    """
    <div class="#{css_classes(["ash-context-selector", disabled? && "is-disabled", prop_class(iur)])}" data-live-ui-widget="context-selector" data-selector-id="#{selector_id}"#{style_attr(prop_style(iur))}>
      <button type="button" id="#{selector_id}-trigger" class="#{css_classes(["ash-context-selector-trigger", open? && "is-open"])}" aria-haspopup="listbox" aria-expanded="#{open?}" aria-controls="#{selector_id}-panel" aria-label="#{label_prefix} #{summary}"#{if(disabled?, do: " disabled", else: "")}>
        <span class="ash-context-selector-prefix">#{label_prefix}</span>
        <span class="ash-context-selector-summary">#{summary}</span>
        <span class="ash-context-selector-caret" aria-hidden="true">v</span>
      </button>
      #{if open?, do: "<div id=\"#{selector_id}-panel\" class=\"ash-context-selector-panel\" role=\"listbox\" aria-labelledby=\"#{selector_id}-trigger\" aria-multiselectable=\"#{multi?}\">#{groups_html}</div>", else: ""}
    </div>
    """
  end

  defp generate_heex(%{"type" => "custom:command_palette"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Command palette")
    description = text_prop(props, ["description", "help"])
    search_children = slot_children(iur, "search")
    command_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    command_children =
      if search_children == [] and command_children == [] and footer_children == [] do
        iur["children"] || []
      else
        command_children
      end

    """
    <section class="#{css_classes(["ash-command-palette", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-command-palette-header">
        <h2 class="ash-command-palette-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-command-palette-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-command-palette-search">
        #{generate_children(search_children, opts)}
      </div>
      <div class="ash-command-palette-results">
        #{generate_children(command_children, opts)}
      </div>
      <footer class="ash-command-palette-footer">
        #{generate_children(footer_children, opts)}
      </footer>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:viewport"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Viewport")
    description = text_prop(props, ["description", "help"])
    body_children = slot_children(iur, "body")
    aside_children = slot_children(iur, "aside")
    footer_children = slot_children(iur, "footer")

    body_children =
      if body_children == [] and aside_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-viewport", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-viewport-header">
        <h2 class="ash-viewport-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-viewport-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-viewport-frame">
        <div class="ash-viewport-body">
          #{generate_children(body_children, opts)}
        </div>
        <aside class="ash-viewport-aside">
          #{generate_children(aside_children, opts)}
        </aside>
      </div>
      <footer class="ash-viewport-footer">
        #{generate_children(footer_children, opts)}
      </footer>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:scroll_bar"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Scroll bar")
    description = text_prop(props, ["description", "help"])
    thumb_label = text_prop(props, ["thumb_label", "current_position"], "Focused lane")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-scroll-bar", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-scroll-bar-header">
        <h2 class="ash-scroll-bar-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-scroll-bar-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-scroll-bar-frame">
        <div class="ash-scroll-bar-body">
          #{generate_children(body_children, opts)}
        </div>
        <div class="ash-scroll-bar-track" aria-hidden="true">
          <span class="ash-scroll-bar-thumb">#{thumb_label}</span>
        </div>
      </div>
      <footer class="ash-scroll-bar-footer">
        #{generate_children(footer_children, opts)}
      </footer>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:split_pane"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Split pane")
    description = text_prop(props, ["description", "help"])
    primary_children = slot_children(iur, "primary")
    secondary_children = slot_children(iur, "secondary")
    action_children = slot_children(iur, "actions")

    primary_children =
      if primary_children == [] and secondary_children == [] and action_children == [] do
        iur["children"] || []
      else
        primary_children
      end

    """
    <section class="#{css_classes(["ash-split-pane", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-split-pane-header">
        <h2 class="ash-split-pane-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-split-pane-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-split-pane-layout">
        <section class="ash-split-pane-primary">
          #{generate_children(primary_children, opts)}
        </section>
        <section class="ash-split-pane-secondary">
          #{generate_children(secondary_children, opts)}
        </section>
      </div>
      <footer class="ash-split-pane-actions">
        #{generate_children(action_children, opts)}
      </footer>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:canvas"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Canvas")
    description = text_prop(props, ["description", "help"])
    toolbar_children = slot_children(iur, "toolbar")
    body_children = slot_children(iur, "body")
    legend_children = slot_children(iur, "legend")

    body_children =
      if toolbar_children == [] and body_children == [] and legend_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-canvas-surface", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-canvas-header">
        <h2 class="ash-canvas-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-canvas-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-canvas-toolbar">
        #{generate_children(toolbar_children, opts)}
      </div>
      <div class="ash-canvas-board">
        #{generate_children(body_children, opts)}
      </div>
      <aside class="ash-canvas-legend">
        #{generate_children(legend_children, opts)}
      </aside>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:overlay"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Overlay")
    description = text_prop(props, ["description", "help"])
    open? = truthy_prop(props, "open", false)
    body_children = slot_children(iur, "body")
    action_children = slot_children(iur, "actions")
    footer_children = slot_children(iur, "footer")

    body_children =
      if body_children == [] and action_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-overlay-surface", open? && "is-open", !open? && "is-closed", prop_class(iur)])}" data-state="#{if(open?, do: "open", else: "closed")}"#{style_attr(prop_style(iur))}>
      <div class="ash-overlay-panel">
        <header class="ash-overlay-header">
          <h2 class="ash-overlay-title">#{title}</h2>
          #{if description, do: "<p class=\"ash-overlay-description\">#{description}</p>", else: ""}
        </header>
        <div class="ash-overlay-body">
          #{generate_children(body_children, opts)}
        </div>
        <footer class="ash-overlay-actions">
          #{generate_children(action_children, opts)}
        </footer>
        <div class="ash-overlay-footer">
          #{generate_children(footer_children, opts)}
        </div>
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:dialog"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Dialog")
    description = text_prop(props, ["description", "help"])
    open? = truthy_prop(props, "open", true)
    body_children = slot_children(iur, "body")
    action_children = slot_children(iur, "actions")
    footer_children = slot_children(iur, "footer")

    body_children =
      if body_children == [] and action_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-dialog-surface", open? && "is-open", !open? && "is-closed", prop_class(iur)])}" data-state="#{if(open?, do: "open", else: "closed")}"#{style_attr(prop_style(iur))}>
      <div class="ash-dialog-panel">
        <header class="ash-dialog-header">
          <h2 class="ash-dialog-title">#{title}</h2>
          #{if description, do: "<p class=\"ash-dialog-description\">#{description}</p>", else: ""}
        </header>
        <div class="ash-dialog-body">
          #{generate_children(body_children, opts)}
        </div>
        <footer class="ash-dialog-actions">
          #{generate_children(action_children, opts)}
        </footer>
        <div class="ash-dialog-footer">
          #{generate_children(footer_children, opts)}
        </div>
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:alert_dialog"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Alert dialog")
    description = text_prop(props, ["description", "help"])
    open? = truthy_prop(props, "open", true)
    body_children = slot_children(iur, "body")
    action_children = slot_children(iur, "actions")
    footer_children = slot_children(iur, "footer")

    body_children =
      if body_children == [] and action_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-alert-dialog-surface", open? && "is-open", !open? && "is-closed", prop_class(iur)])}" data-state="#{if(open?, do: "open", else: "closed")}"#{style_attr(prop_style(iur))}>
      <div class="ash-alert-dialog-panel">
        <header class="ash-alert-dialog-header">
          <h2 class="ash-alert-dialog-title">#{title}</h2>
          #{if description, do: "<p class=\"ash-alert-dialog-description\">#{description}</p>", else: ""}
        </header>
        <div class="ash-alert-dialog-body">
          #{generate_children(body_children, opts)}
        </div>
        <footer class="ash-alert-dialog-actions">
          #{generate_children(action_children, opts)}
        </footer>
        <div class="ash-alert-dialog-footer">
          #{generate_children(footer_children, opts)}
        </div>
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:context_menu"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Context menu")
    description = text_prop(props, ["description", "help"])
    open? = truthy_prop(props, "open", true)
    menu_children = slot_children(iur, "menu")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if menu_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-context-menu", open? && "is-open", !open? && "is-closed", prop_class(iur)])}" data-state="#{if(open?, do: "open", else: "closed")}"#{style_attr(prop_style(iur))}>
      <header class="ash-context-menu-header">
        <h2 class="ash-context-menu-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-context-menu-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-context-menu-items" role="menu">
        #{generate_children(menu_children, opts)}
      </div>
      <div class="ash-context-menu-body">
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-context-menu-footer">
        #{generate_children(footer_children, opts)}
      </footer>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:toast"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Toast")
    description = text_prop(props, ["description", "help"])
    visible? = truthy_prop(props, "visible", true)
    body_children = slot_children(iur, "body")
    action_children = slot_children(iur, "actions")
    footer_children = slot_children(iur, "footer")

    body_children =
      if body_children == [] and action_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-toast", visible? && "is-visible", !visible? && "is-hidden", prop_class(iur)])}" data-state="#{if(visible?, do: "visible", else: "hidden")}"#{style_attr(prop_style(iur))}>
      <header class="ash-toast-header">
        <h2 class="ash-toast-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-toast-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-toast-body">
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-toast-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-toast-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:tree_view"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Tree view")
    description = text_prop(props, ["description", "help"])
    model = tree_nodes(props)
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-tree-view", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-tree-view-header">
        <h2 class="ash-tree-view-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-tree-view-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-tree-view-body">
        <ul class="ash-tree-view-list">
          #{render_tree_nodes(model)}
        </ul>
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-tree-view-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-tree-view-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:markdown_viewer"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Markdown viewer")
    description = text_prop(props, ["description", "help"])
    content = text_prop(props, "content", "")
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-markdown-viewer", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-markdown-viewer-header">
        <h2 class="ash-markdown-viewer-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-markdown-viewer-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-markdown-viewer-body">
        #{render_markdown_content(content)}
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-markdown-viewer-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-markdown-viewer-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:log_viewer"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Log viewer")
    description = text_prop(props, ["description", "help"])
    entries = log_entries(props)
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-log-viewer", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-log-viewer-header">
        <h2 class="ash-log-viewer-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-log-viewer-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-log-viewer-body">
        <div class="ash-log-viewer-lines">
          #{Enum.map_join(entries, &render_log_entry/1)}
        </div>
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-log-viewer-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-log-viewer-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:status"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Status")
    description = text_prop(props, ["description", "help"])
    model = metric_model(props)
    label = text_prop(model, "label", "Unknown")
    tone = text_prop(model, "tone", "neutral")
    detail = text_prop(model, ["detail", "description"])
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-status-surface", "ash-status-tone-#{tone}", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-status-header">
        <h2 class="ash-status-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-status-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-status-body">
        <p class="ash-status-pill">#{label}</p>
        #{if detail, do: "<p class=\"ash-status-detail\">#{detail}</p>", else: ""}
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-status-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-status-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:progress"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Progress")
    description = text_prop(props, ["description", "help"])
    model = metric_model(props)
    label = text_prop(model, "label", "Progress")
    detail = text_prop(model, ["detail", "description"])
    value = numeric_value(model, "value", 0)
    total = max(numeric_value(model, "total", 100), 1)
    percent = percentage(value, total)
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-progress-surface", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-progress-header">
        <h2 class="ash-progress-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-progress-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-progress-body">
        <div class="ash-progress-summary">
          <span class="ash-progress-label">#{label}</span>
          <span class="ash-progress-value">#{percent}%</span>
        </div>
        <div class="ash-progress-track" aria-hidden="true">
          <span class="ash-progress-fill" style="width: #{percent}%"></span>
        </div>
        #{if detail, do: "<p class=\"ash-progress-detail\">#{detail}</p>", else: ""}
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-progress-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-progress-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:gauge"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Gauge")
    description = text_prop(props, ["description", "help"])
    model = metric_model(props)
    label = text_prop(model, "label", "Gauge")
    detail = text_prop(model, ["detail", "description"])
    value = numeric_value(model, "value", 0)
    max_value = max(numeric_value(model, "max", 100), 1)
    percent = percentage(value, max_value)
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-gauge-surface", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-gauge-header">
        <h2 class="ash-gauge-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-gauge-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-gauge-body">
        <div class="ash-gauge-meter">
          <div class="ash-gauge-arc">
            <span class="ash-gauge-fill" style="height: #{percent}%"></span>
          </div>
          <div class="ash-gauge-summary">
            <span class="ash-gauge-label">#{label}</span>
            <span class="ash-gauge-value">#{percent}%</span>
          </div>
        </div>
        #{if detail, do: "<p class=\"ash-gauge-detail\">#{detail}</p>", else: ""}
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-gauge-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-gauge-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:inline_feedback"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Inline feedback")
    description = text_prop(props, ["description", "help"])
    model = metric_model(props)
    tone = text_prop(model, "tone", "neutral")
    feedback_title = text_prop(model, "title", title)
    detail = text_prop(model, ["detail", "description"])
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-inline-feedback", "ash-inline-feedback-#{tone}", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-inline-feedback-header">
        <h2 class="ash-inline-feedback-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-inline-feedback-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-inline-feedback-body">
        <p class="ash-inline-feedback-badge">#{feedback_title}</p>
        #{if detail, do: "<p class=\"ash-inline-feedback-detail\">#{detail}</p>", else: ""}
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-inline-feedback-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-inline-feedback-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:sparkline"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Sparkline")
    description = text_prop(props, ["description", "help"])
    series = series_points(props)
    max_value = series_max(series)
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-sparkline-surface", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-sparkline-header">
        <h2 class="ash-sparkline-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-sparkline-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-sparkline-body">
        <div class="ash-sparkline-chart">
          #{Enum.map_join(series, &render_spark_point(&1, max_value))}
        </div>
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-sparkline-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-sparkline-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:bar_chart"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Bar chart")
    description = text_prop(props, ["description", "help"])
    series = series_points(props)
    max_value = series_max(series)
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-bar-chart", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-bar-chart-header">
        <h2 class="ash-bar-chart-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-bar-chart-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-bar-chart-body">
        <div class="ash-bar-chart-bars">
          #{Enum.map_join(series, &render_bar_chart_column(&1, max_value))}
        </div>
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-bar-chart-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-bar-chart-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:line_chart"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Line chart")
    description = text_prop(props, ["description", "help"])
    series = series_points(props)
    max_value = series_max(series)
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-line-chart", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-line-chart-header">
        <h2 class="ash-line-chart-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-line-chart-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-line-chart-body">
        <div class="ash-line-chart-grid">
          #{Enum.map_join(series, &render_line_chart_point(&1, max_value))}
        </div>
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-line-chart-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-line-chart-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:stream_widget"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Stream widget")
    description = text_prop(props, ["description", "help"])
    entries = log_entries(props)
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-stream-widget", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-stream-widget-header">
        <h2 class="ash-stream-widget-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-stream-widget-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-stream-widget-body">
        <div class="ash-stream-widget-entries">
          #{Enum.map_join(entries, &render_stream_entry/1)}
        </div>
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-stream-widget-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-stream-widget-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:process_monitor"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Process monitor")
    description = text_prop(props, ["description", "help"])
    model = metric_model(props)
    summary = text_prop(model, ["summary", "detail", "description"])
    processes = model_entries(model, "processes")
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-process-monitor", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-process-monitor-header">
        <h2 class="ash-process-monitor-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-process-monitor-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-process-monitor-body">
        #{if summary, do: "<p class=\"ash-process-monitor-summary\">#{summary}</p>", else: ""}
        <div class="ash-process-monitor-cards">
          #{Enum.map_join(processes, &render_process_card/1)}
        </div>
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-process-monitor-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-process-monitor-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:supervision_tree_viewer"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Supervision tree viewer")
    description = text_prop(props, ["description", "help"])
    model = metric_model(props)
    root_label = text_prop(model, "label", "Supervisor")
    root_meta = text_prop(model, "meta")
    nodes = model_entries(model, "nodes")
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-supervision-tree-viewer", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-supervision-tree-viewer-header">
        <h2 class="ash-supervision-tree-viewer-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-supervision-tree-viewer-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-supervision-tree-viewer-body">
        <div class="ash-supervision-tree-root">
          <span class="ash-supervision-tree-root-label">#{root_label}</span>
          #{if root_meta, do: "<span class=\"ash-supervision-tree-root-meta\">#{root_meta}</span>", else: ""}
        </div>
        <ul class="ash-supervision-tree-list">
          #{render_supervision_nodes(nodes)}
        </ul>
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-supervision-tree-viewer-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-supervision-tree-viewer-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(%{"type" => "custom:cluster_dashboard"} = iur, opts) do
    props = iur["props"] || %{}
    title = text_prop(props, ["title", "label"], "Cluster dashboard")
    description = text_prop(props, ["description", "help"])
    model = metric_model(props)
    headline = text_prop(model, "headline", "Cluster snapshot")
    detail = text_prop(model, ["detail", "description"])
    regions = model_entries(model, "regions")
    alerts = model_entries(model, "alerts")
    action_children = slot_children(iur, "actions")
    body_children = slot_children(iur, "body")
    footer_children = slot_children(iur, "footer")

    body_children =
      if action_children == [] and body_children == [] and footer_children == [] do
        iur["children"] || []
      else
        body_children
      end

    """
    <section class="#{css_classes(["ash-cluster-dashboard", prop_class(iur)])}"#{style_attr(prop_style(iur))}>
      <header class="ash-cluster-dashboard-header">
        <h2 class="ash-cluster-dashboard-title">#{title}</h2>
        #{if description, do: "<p class=\"ash-cluster-dashboard-description\">#{description}</p>", else: ""}
      </header>
      <div class="ash-cluster-dashboard-body">
        <article class="ash-cluster-dashboard-hero">
          <h3 class="ash-cluster-dashboard-headline">#{headline}</h3>
          #{if detail, do: "<p class=\"ash-cluster-dashboard-detail\">#{detail}</p>", else: ""}
        </article>
        <div class="ash-cluster-dashboard-grid">
          <section class="ash-cluster-dashboard-regions">
            #{Enum.map_join(regions, &render_region_card/1)}
          </section>
          <aside class="ash-cluster-dashboard-alerts">
            #{Enum.map_join(alerts, &render_alert_card/1)}
          </aside>
        </div>
        #{generate_children(body_children, opts)}
      </div>
      <footer class="ash-cluster-dashboard-actions">
        #{generate_children(action_children, opts)}
      </footer>
      <div class="ash-cluster-dashboard-footer">
        #{generate_children(footer_children, opts)}
      </div>
    </section>
    """
  end

  defp generate_heex(iur, opts) do
    props = iur["props"] || %{}

    """
    <div class="#{css_classes(["ash-widget", "ash-widget-#{iur["type"]}", prop_class(iur)])}"#{style_attr(prop_style(iur))} data-widget-id="#{iur["id"]}"#{passthrough_attrs(props)}>
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
          [%{event: event_name(event_prefix, :action), target: child["id"]} | acc]

        "input" ->
          [
            %{event: event_name(event_prefix, :change), target: child["id"]} | acc
          ]

        "checkbox" ->
          [%{event: event_name(event_prefix, :change), target: child["id"]} | acc]

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
          "event" -> :action
          "bidirectional" -> :change
          "collection" -> :change
          _ -> :change
        end

      [%{event: event_name(event_prefix, event_type), target: binding["target"]} | acc]
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
      resource_id: CanonicalIUR.id(canonical_iur),
      resource_type: :screen,
      screen_id: CanonicalIUR.id(canonical_iur)
    }
  end

  defp render_text_input(iur, opts, css_base) do
    props = iur["props"] || %{}
    name = Map.get(props, "name", "input")
    placeholder = Map.get(props, "placeholder", "")
    value = Map.get(props, "value", "")
    type = Map.get(props, "type", "text")
    binding = find_binding(opts, iur["id"], "bidirectional")
    event_prefix = Map.get(opts, :event_prefix, "ash_ui")
    value_attr = if type == "file", do: "", else: attr("value", value)

    """
    <input type="#{type}" class="#{css_classes(["ash-#{css_base}", prop_class(iur)])}" name="#{name}"#{value_attr} placeholder="#{placeholder}"#{style_attr(prop_style(iur))} phx-blur="#{event_name(event_prefix, :change)}" phx-change="#{event_name(event_prefix, :change)}"#{attr("phx-value-binding_id", binding && binding["id"])}#{attr("phx-value-target", binding && binding["target"])}#{attr("phx-value-element_id", iur["id"])}#{attr("phx-value-signal", "change")} />
    """
  end

  defp find_binding(opts, element_id, type) do
    opts
    |> Map.get(:bindings, [])
    |> Enum.find(fn binding ->
      binding["element_id"] == element_id and binding["type"] == type
    end)
  end

  defp binding_signal(nil, default), do: default

  defp binding_signal(binding, default) do
    metadata = Map.get(binding, "metadata", %{})
    Map.get(metadata, "owner_signal") || Map.get(metadata, "signal") || default
  end

  defp prop_class(iur), do: Map.get(iur["props"] || %{}, "class")

  defp prop_style(iur) do
    props = iur["props"] || %{}

    prop(props, "inline_style") ||
      case prop(props, "style") do
        %{"extra" => %{"css" => css}} when is_binary(css) and css != "" -> css
        %{extra: %{css: css}} when is_binary(css) and css != "" -> css
        style when is_binary(style) -> style
        _other -> nil
      end
  end

  defp prop(props, key, default \\ nil) when is_map(props) and is_binary(key) do
    Map.get(props, key, Map.get(props, String.to_atom(key), default))
  rescue
    ArgumentError -> Map.get(props, key, default)
  end

  defp truthy_prop(props, key, default) do
    case prop(props, key, default) do
      value when value in [true, "true", "open", "visible", 1, "1", "yes"] -> true
      _ -> false
    end
  end

  defp presence_decorative?(props) do
    truthy_prop(props, "decorative?", false) ||
      truthy_prop(props, "decorative", false) ||
      prop(props, "aria_label") == false ||
      prop(props, "label") == false
  end

  defp text_prop(props, keys, default \\ nil)

  defp text_prop(props, keys, default) when is_list(keys) do
    Enum.reduce_while(keys, default, fn key, _acc ->
      case prop(props, key) do
        value when value in [nil, "", []] -> {:cont, default}
        value -> {:halt, text_value(value)}
      end
    end)
  end

  defp text_prop(props, key, default), do: text_prop(props, [key], default)

  defp escaped_text_prop(props, keys, default \\ nil) do
    case text_prop(props, keys, default) do
      nil -> nil
      value -> html_escape(value)
    end
  end

  defp html_attr(value), do: html_escape(value)

  defp adapter_duration_label(started_at) when is_binary(started_at) do
    case DateTime.from_iso8601(started_at) do
      {:ok, dt, _offset} ->
        diff_seconds = max(DateTime.diff(DateTime.utc_now(), dt, :second), 0)

        cond do
          diff_seconds < 60 -> "#{diff_seconds}s"
          diff_seconds < 3_600 -> "#{div(diff_seconds, 60)}m"
          true -> "#{div(diff_seconds, 3_600)}h"
        end

      _ ->
        "running"
    end
  end

  defp adapter_duration_label(_started_at), do: "running"

  defp html_escape(nil), do: ""

  defp html_escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp text_value(value) when is_binary(value), do: value
  defp text_value(value) when is_atom(value) or is_number(value), do: to_string(value)

  defp text_value(value) when is_list(value) do
    Enum.map_join(value, " ", &text_value/1)
  end

  defp text_value(value) when is_map(value) do
    case text_prop(value, [
           "text",
           "label",
           "value",
           "name",
           "content",
           "title",
           "source",
           "src",
           "url"
         ]) do
      nil -> inspect(value)
      "" -> inspect(value)
      text -> text
    end
  end

  defp text_value(value), do: to_string(value)

  defp normalize_choice(option) when is_map(option) do
    {text_prop(option, ["label", "title", "value"], ""), prop(option, "value")}
  end

  defp normalize_choice({label, value}), do: {label, value}
  defp normalize_choice(option) when is_binary(option), do: {option, option}
  defp normalize_choice(option), do: {to_string(option), option}

  defp context_selector_multi?(props) do
    max_selections = prop(props, "max_selections", 1)

    truthy_prop(props, "multiple?", false) ||
      max_selections in [:unlimited, "unlimited"] ||
      (is_integer(max_selections) and max_selections > 1)
  end

  defp context_selector_label_for(groups, value) do
    groups
    |> List.wrap()
    |> Enum.flat_map(&(prop(&1, "items", []) |> List.wrap()))
    |> Enum.find_value(fn item ->
      item_value = text_prop(item, ["value", "id"], "")

      if to_string(item_value) == to_string(value) do
        escaped_text_prop(item, ["label", "value", "id"], value)
      end
    end)
  end

  defp normalize_item(item) when is_map(item), do: item

  defp normalize_item(item) when is_list(item) do
    if Keyword.keyword?(item), do: Enum.into(item, %{}), else: %{"value" => item}
  end

  defp normalize_item(item), do: %{"value" => item}

  defp collection_items(props) do
    items = prop(props, "items")
    collection = prop(props, "collection")
    entries = prop(props, "entries")

    cond do
      is_list(items) -> items
      is_map(collection) -> prop(collection, "items", [])
      is_list(entries) -> entries
      true -> []
    end
  end

  defp table_columns(props) do
    case prop(props, "columns", []) do
      columns when is_list(columns) and columns != [] ->
        columns

      _other ->
        collection_items(props)
        |> List.first()
        |> normalize_item()
        |> Map.keys()
        |> Enum.sort()
        |> Enum.map(&%{"key" => &1, "label" => Macro.camelize(&1)})
    end
  end

  defp render_list_item(item) do
    item = normalize_item(item)
    title = text_prop(item, ["title", "label", "name", "value"], "Item")
    summary = text_prop(item, ["summary", "description", "message"])
    meta = text_prop(item, ["meta", "status"])

    """
    <li class="ash-list-item">
      <div class="ash-list-item-main">
        <p class="ash-list-item-title">#{title}</p>
        #{if summary, do: "<p class=\"ash-list-item-summary\">#{summary}</p>", else: ""}
      </div>
      #{if meta, do: "<span class=\"ash-list-item-meta\">#{meta}</span>", else: ""}
    </li>
    """
  end

  defp render_collection_picker_filter(filter) do
    filter = normalize_item(filter)
    filter_id = escaped_text_prop(filter, ["id", "filter_id", "value"], "filter")
    label = escaped_text_prop(filter, ["label", "title", "name", "value"], filter_id)
    count = escaped_text_prop(filter, "count")
    selected? = truthy_prop(filter, "selected?", false) || truthy_prop(filter, "selected", false)

    """
    <button type="button" class="#{css_classes(["ash-collection-picker-filter", selected? && "is-selected"])}" aria-pressed="#{selected?}"#{attr("data-filter-id", filter_id)}>
      <span class="ash-collection-picker-filter-label">#{label}</span>
      #{if count, do: "<span class=\"ash-collection-picker-filter-count\">#{count}</span>", else: ""}
    </button>
    """
  end

  defp render_collection_picker_item(item) do
    item = normalize_item(item)
    item_id = escaped_text_prop(item, ["id", "item_id", "value"], "item")
    label = escaped_text_prop(item, ["label", "title", "name", "value"], item_id)
    description = escaped_text_prop(item, ["description", "summary", "subtitle"])
    selected? = truthy_prop(item, "selected?", false) || truthy_prop(item, "selected", false)

    """
    <li class="#{css_classes(["ash-collection-picker-item", selected? && "is-selected"])}" role="option" aria-selected="#{selected?}"#{attr("data-item-id", item_id)}>
      <span class="ash-collection-picker-item-label">#{label}</span>
      #{if description, do: "<span class=\"ash-collection-picker-item-description\">#{description}</span>", else: ""}
    </li>
    """
  end

  defp render_collection_picker_suggestion(suggestion) do
    suggestion = normalize_item(suggestion)
    suggestion_id = escaped_text_prop(suggestion, ["id", "suggestion_id", "value"], "suggestion")
    label = escaped_text_prop(suggestion, ["label", "title", "name", "value"], suggestion_id)
    description = escaped_text_prop(suggestion, ["description", "summary", "subtitle"])
    source = escaped_text_prop(suggestion, ["source", "agent"])

    """
    <article class="ash-collection-picker-suggestion"#{attr("data-suggestion-id", suggestion_id)}>
      <div class="ash-collection-picker-suggestion-body">
        <span class="ash-collection-picker-suggestion-label">#{label}</span>
        #{if description, do: "<span class=\"ash-collection-picker-suggestion-description\">#{description}</span>", else: ""}
        #{if source, do: "<span class=\"ash-collection-picker-suggestion-source\">#{source}</span>", else: ""}
      </div>
      <div class="ash-collection-picker-suggestion-actions">
        <button type="button" class="ash-collection-picker-suggestion-accept">Accept</button>
        <button type="button" class="ash-collection-picker-suggestion-dismiss">Dismiss</button>
      </div>
    </article>
    """
  end

  defp render_table_header(column) do
    column = normalize_item(column)
    label = text_prop(column, ["label", "title", "key"], "")
    "<th>#{label}</th>"
  end

  defp render_table_row(item, columns) do
    item = normalize_item(item)

    cells =
      columns
      |> Enum.map_join(fn column ->
        column = normalize_item(column)
        key = text_prop(column, "key", "")
        value = table_cell_value(item, key)
        "<td>#{value}</td>"
      end)

    "<tr>#{cells}</tr>"
  end

  defp table_cell_value(item, key) when is_binary(key) do
    value =
      Map.get(item, key) ||
        try do
          Map.get(item, String.to_existing_atom(key))
        rescue
          ArgumentError -> nil
        end

    case value do
      nil -> ""
      value -> to_string(value)
    end
  end

  defp tree_nodes(props) do
    case prop(props, "model", []) do
      nodes when is_list(nodes) -> nodes
      %{} = node -> [node]
      _other -> []
    end
  end

  defp render_tree_nodes([]) do
    ~s(<li class="ash-tree-view-empty">No nodes loaded.</li>)
  end

  defp render_tree_nodes(nodes) when is_list(nodes) do
    Enum.map_join(nodes, fn node ->
      node = normalize_item(node)
      label = text_prop(node, ["label", "title", "name", "value"], "Node")
      meta = text_prop(node, ["meta", "status"])
      children = Map.get(node, "children") || Map.get(node, :children) || []

      """
      <li class="ash-tree-view-node">
        <div class="ash-tree-view-node-row">
          <span class="ash-tree-view-node-label">#{label}</span>
          #{if meta, do: "<span class=\"ash-tree-view-node-meta\">#{meta}</span>", else: ""}
        </div>
        #{if children != [], do: "<ul class=\"ash-tree-view-children\">#{render_tree_nodes(children)}</ul>", else: ""}
      </li>
      """
    end)
  end

  defp render_markdown_content(markdown) when markdown in [nil, ""] do
    ~s(<p class="ash-markdown-viewer-empty">No markdown content loaded.</p>)
  end

  defp render_markdown_content(markdown) do
    markdown
    |> String.split("\n", trim: false)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map_join(fn line ->
      cond do
        String.starts_with?(line, "## ") ->
          "<h3>#{String.trim_leading(line, "## ")}</h3>"

        String.starts_with?(line, "# ") ->
          "<h2>#{String.trim_leading(line, "# ")}</h2>"

        String.starts_with?(line, "- ") ->
          "<p class=\"ash-markdown-viewer-bullet\">• #{String.trim_leading(line, "- ")}</p>"

        true ->
          "<p>#{line}</p>"
      end
    end)
  end

  defp log_entries(props) do
    case prop(props, "entries", []) do
      entries when is_list(entries) -> entries
      _other -> []
    end
  end

  defp render_log_entry(entry) do
    entry = normalize_item(entry)
    timestamp = text_prop(entry, ["timestamp", "time"], "--:--:--")
    level = text_prop(entry, "level", "INFO")
    message = text_prop(entry, ["message", "summary", "value"], "")

    """
    <article class="ash-log-viewer-entry">
      <span class="ash-log-viewer-time">#{timestamp}</span>
      <span class="ash-log-viewer-level">#{level}</span>
      <span class="ash-log-viewer-message">#{message}</span>
    </article>
    """
  end

  defp confidence_number(value, _default) when is_integer(value), do: value / 1
  defp confidence_number(value, _default) when is_float(value), do: value

  defp confidence_number(value, default) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> default
    end
  end

  defp confidence_number(_value, default), do: default

  defp file_tree_nodes_html(nodes, selected_path, default_expanded?, depth) do
    nodes
    |> List.wrap()
    |> Enum.map_join(fn node ->
      node
      |> normalize_item()
      |> file_tree_node_html(selected_path, default_expanded?, depth)
    end)
  end

  defp file_tree_node_html(node, selected_path, default_expanded?, depth) do
    case text_prop(node, "type", "file_leaf") do
      type when type in ["folder", "directory"] ->
        file_tree_folder_html(node, selected_path, default_expanded?, depth)

      _type ->
        file_tree_leaf_html(node, selected_path, depth)
    end
  end

  defp file_tree_folder_html(node, selected_path, default_expanded?, depth) do
    id = escaped_text_prop(node, ["id", "path"], "folder")
    path = escaped_text_prop(node, ["path", "id"], id)
    name = escaped_text_prop(node, ["name", "label"], Path.basename(path))
    expanded? = truthy_prop(node, "expanded?", default_expanded?)
    marker = if expanded?, do: "v", else: ">"

    children =
      if expanded? do
        ~s(<div class="ash-file-tree-children" role="group">#{file_tree_nodes_html(prop(node, "children", []), selected_path, default_expanded?, depth + 1)}</div>)
      else
        ""
      end

    """
    <div class="ash-file-tree-folder" role="none">
      <div class="#{css_classes(["ash-file-tree-folder-row", expanded? && "is-expanded"])}" role="treeitem" aria-expanded="#{expanded?}" data-node-id="#{id}" data-node-path="#{path}" style="padding-inline-start: #{depth * 12}px">
        <span class="ash-file-tree-marker" aria-hidden="true">#{marker}</span>
        <span class="ash-file-tree-folder-name">#{name}/</span>
      </div>
      #{children}
    </div>
    """
  end

  defp file_tree_leaf_html(node, selected_path, depth) do
    id = escaped_text_prop(node, ["id", "path"], "file")
    path = escaped_text_prop(node, ["path", "id"], id)
    name = escaped_text_prop(node, ["name", "label"], Path.basename(path))
    selected? = selected_path && to_string(selected_path) == text_prop(node, ["path", "id"], "")
    language = escaped_text_prop(node, ["language", "lang"])
    line_count = text_prop(node, ["line_count", "lines"])

    meta =
      [language, line_count && "#{html_escape(line_count)} lines"]
      |> Enum.reject(&nil_or_empty?/1)
      |> Enum.join(" - ")

    """
    <div class="#{css_classes(["ash-file-tree-file", selected? && "is-selected"])}" role="treeitem" aria-selected="#{!!selected?}" data-node-id="#{id}" data-file-path="#{path}" style="padding-inline-start: #{depth * 12}px">
      <span class="ash-file-tree-file-glyph" aria-hidden="true">#{file_tree_file_glyph(node)}</span>
      <span class="ash-file-tree-file-name">#{name}</span>
      #{if meta == "", do: "", else: ~s(<span class="ash-file-tree-file-meta">#{meta}</span>)}
    </div>
    """
  end

  defp file_tree_file_glyph(node) do
    node
    |> text_prop(["file_kind", "language", "lang", "name", "path"], "")
    |> case do
      "elixir" -> "ex"
      "markdown" -> "md"
      "json" -> "{}"
      value -> value |> Path.extname() |> String.trim_leading(".") |> String.slice(0, 3)
    end
    |> case do
      "" -> "-"
      glyph -> html_escape(glyph)
    end
  end

  defp numeric_count(value) when is_integer(value), do: value
  defp numeric_count(value) when is_float(value), do: round(value)

  defp numeric_count(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _rest} -> parsed
      :error -> 0
    end
  end

  defp numeric_count(_value), do: 0

  defp metric_model(props) do
    case prop(props, "model", %{}) do
      %{} = model -> model
      _other -> %{}
    end
  end

  defp numeric_value(model, key, default) do
    case prop(model, key, default) do
      value when is_integer(value) ->
        value

      value when is_float(value) ->
        round(value)

      value when is_binary(value) ->
        case Integer.parse(value) do
          {parsed, _rest} -> parsed
          :error -> default
        end

      _other ->
        default
    end
  end

  defp percentage(value, total) when is_integer(value) and is_integer(total) and total > 0 do
    value
    |> Kernel./(total)
    |> Kernel.*(100)
    |> round()
    |> min(100)
    |> max(0)
  end

  defp series_points(props) do
    case prop(props, "series", []) do
      series when is_list(series) -> series
      _other -> []
    end
  end

  defp series_max(series) do
    series
    |> Enum.map(&numeric_value(normalize_item(&1), "value", 0))
    |> Enum.max(fn -> 1 end)
    |> max(1)
  end

  defp render_spark_point(point, max_value) do
    point = normalize_item(point)
    label = text_prop(point, "label", "")
    value = numeric_value(point, "value", 0)
    height = chart_height(value, max_value)

    """
    <span class="ash-sparkline-point" title="#{label}: #{value}">
      <span class="ash-sparkline-bar" style="height: #{height}%"></span>
      <span class="ash-sparkline-label">#{label}</span>
    </span>
    """
  end

  defp render_bar_chart_column(point, max_value) do
    point = normalize_item(point)
    label = text_prop(point, "label", "")
    value = numeric_value(point, "value", 0)
    height = chart_height(value, max_value)

    """
    <article class="ash-bar-chart-column">
      <span class="ash-bar-chart-value">#{value}</span>
      <span class="ash-bar-chart-bar" style="height: #{height}%"></span>
      <span class="ash-bar-chart-label">#{label}</span>
    </article>
    """
  end

  defp render_line_chart_point(point, max_value) do
    point = normalize_item(point)
    label = text_prop(point, "label", "")
    value = numeric_value(point, "value", 0)
    height = chart_height(value, max_value)

    """
    <article class="ash-line-chart-point">
      <span class="ash-line-chart-marker" style="bottom: #{height}%"></span>
      <span class="ash-line-chart-stem" style="height: #{height}%"></span>
      <span class="ash-line-chart-value">#{value}</span>
      <span class="ash-line-chart-label">#{label}</span>
    </article>
    """
  end

  defp chart_height(value, max_value) when max_value > 0 do
    value
    |> Kernel./(max_value)
    |> Kernel.*(100)
    |> round()
    |> min(100)
    |> max(8)
  end

  defp render_stream_entry(entry) do
    entry = normalize_item(entry)
    timestamp = text_prop(entry, ["timestamp", "time"], "--:--:--")
    label = text_prop(entry, ["label", "level"], "feed")
    message = text_prop(entry, ["message", "summary", "value"], "")

    """
    <article class="ash-stream-widget-entry">
      <span class="ash-stream-widget-time">#{timestamp}</span>
      <span class="ash-stream-widget-label">#{label}</span>
      <p class="ash-stream-widget-message">#{message}</p>
    </article>
    """
  end

  defp model_entries(model, key) do
    case prop(model, key, []) do
      entries when is_list(entries) -> entries
      _other -> []
    end
  end

  defp render_process_card(process) do
    process = normalize_item(process)
    name = text_prop(process, ["name", "label", "title"], "process")
    state = text_prop(process, ["state", "status"], "unknown")
    meta = text_prop(process, "meta")

    """
    <article class="ash-process-monitor-card">
      <span class="ash-process-monitor-name">#{name}</span>
      <span class="ash-process-monitor-state">#{state}</span>
      #{if meta, do: "<span class=\"ash-process-monitor-meta\">#{meta}</span>", else: ""}
    </article>
    """
  end

  defp render_supervision_nodes([]) do
    ~s(<li class="ash-supervision-tree-empty">No supervised children loaded.</li>)
  end

  defp render_supervision_nodes(nodes) when is_list(nodes) do
    Enum.map_join(nodes, fn node ->
      node = normalize_item(node)
      label = text_prop(node, ["label", "title", "name"], "node")
      meta = text_prop(node, ["meta", "status"])
      children = Map.get(node, "children") || Map.get(node, :children) || []

      """
      <li class="ash-supervision-tree-node">
        <div class="ash-supervision-tree-node-row">
          <span class="ash-supervision-tree-node-label">#{label}</span>
          #{if meta, do: "<span class=\"ash-supervision-tree-node-meta\">#{meta}</span>", else: ""}
        </div>
        #{if children != [], do: "<ul class=\"ash-supervision-tree-children\">#{render_supervision_nodes(children)}</ul>", else: ""}
      </li>
      """
    end)
  end

  defp render_region_card(region) do
    region = normalize_item(region)
    label = text_prop(region, ["label", "title"], "region")
    status = text_prop(region, ["status", "state"], "unknown")
    load = text_prop(region, "load")

    """
    <article class="ash-cluster-dashboard-region">
      <span class="ash-cluster-dashboard-region-label">#{label}</span>
      <span class="ash-cluster-dashboard-region-status">#{status}</span>
      #{if load, do: "<span class=\"ash-cluster-dashboard-region-load\">#{load}</span>", else: ""}
    </article>
    """
  end

  defp render_alert_card(alert) do
    alert = normalize_item(alert)
    title = text_prop(alert, ["title", "label"], "Alert")
    message = text_prop(alert, ["message", "summary", "value"], "")

    """
    <article class="ash-cluster-dashboard-alert">
      <span class="ash-cluster-dashboard-alert-title">#{title}</span>
      <p class="ash-cluster-dashboard-alert-message">#{message}</p>
    </article>
    """
  end

  defp slot_children(iur, slot) do
    desired = to_string(slot)

    (iur["children"] || [])
    |> Enum.filter(&(child_slot(&1) == desired))
  end

  defp child_slot(child) do
    metadata = child["metadata"] || %{}
    slot = Map.get(metadata, "slot", Map.get(metadata, :slot, "body"))
    to_string(slot)
  end

  defp icon_glyph(nil), do: "•"

  defp icon_glyph(name) do
    case to_string(name) do
      "sparkles" -> "✦"
      "star" -> "★"
      "check" -> "✓"
      "alert" -> "!"
      "image" -> "▣"
      other -> other |> String.first() |> Kernel.||("•") |> String.upcase()
    end
  end

  defp dom_id(nil), do: nil
  defp dom_id(value) when is_atom(value), do: Atom.to_string(value)
  defp dom_id(value), do: to_string(value)

  defp css_classes(classes) do
    classes
    |> List.flatten()
    |> Enum.reject(&nil_or_empty?/1)
    |> Enum.join(" ")
  end

  defp style_attr(nil), do: ""
  defp style_attr(""), do: ""
  defp style_attr(style), do: " style=\"#{style}\""

  defp attr(_name, nil), do: ""
  defp attr(_name, ""), do: ""
  defp attr(name, value), do: " #{name}=\"#{value}\""

  # Additive, opt-in passthrough of declared interaction + identity attributes.
  #
  # A node may declare, via its props:
  #
  #   * `"on_click"` => `%{"event" => "select_doc", "values" => %{"doc_id" => "d1"}}`
  #     (or a bare event string `"select_doc"`) -> emits
  #     `phx-click="select_doc"` plus a `phx-value-<key>="<val>"` pair per value.
  #   * `"data"` => `%{"block_id" => "b1"}` -> emits `data-<key>="<val>"` per pair.
  #
  # When neither prop is present this returns "" so a node WITHOUT the props
  # renders byte-identically to before. Values are HTML-escaped via `html_attr/1`;
  # keys are restricted to safe attribute-name characters so a hostile key cannot
  # inject additional attributes. Pairs are emitted in sorted key order so output
  # is deterministic.
  defp passthrough_attrs(props) when is_map(props) do
    on_click_attrs(prop(props, "on_click")) <> data_attrs(prop(props, "data"))
  end

  defp passthrough_attrs(_props), do: ""

  defp on_click_attrs(nil), do: ""

  defp on_click_attrs(event) when is_binary(event) do
    on_click_attrs(%{"event" => event})
  end

  defp on_click_attrs(on_click) when is_map(on_click) do
    case prop(on_click, "event") do
      event when is_binary(event) and event != "" ->
        attr("phx-click", html_attr(event)) <>
          value_attrs("phx-value-", prop(on_click, "values"))

      _ ->
        ""
    end
  end

  defp on_click_attrs(_), do: ""

  defp data_attrs(data) when is_map(data) and map_size(data) > 0 do
    value_attrs("data-", data)
  end

  defp data_attrs(_), do: ""

  defp value_attrs(prefix, values) when is_map(values) do
    values
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Enum.filter(fn {key, _value} -> safe_attr_key?(key) end)
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.map_join(fn {key, value} -> attr(prefix <> key, html_attr(value)) end)
  end

  defp value_attrs(_prefix, _values), do: ""

  # Attribute-name segments may contain letters, digits, hyphen, and underscore.
  # Anything else (whitespace, quotes, `=`, `>`...) is rejected so a key can never
  # break out of the attribute it names.
  defp safe_attr_key?(key) when is_binary(key) do
    key != "" and Regex.match?(~r/\A[A-Za-z0-9_-]+\z/, key)
  end

  defp safe_attr_key?(_key), do: false

  defp merge_style(defaults, extra) do
    defaults
    |> List.wrap()
    |> Enum.reject(&nil_or_empty?/1)
    |> Kernel.++(if nil_or_empty?(extra), do: [], else: [extra])
    |> Enum.join("; ")
  end

  defp event_name(prefix, :action), do: "#{prefix}_action"
  defp event_name(prefix, :change), do: "#{prefix}_change"

  defp nil_or_empty?(value), do: value in [nil, ""]

  defp empty_screen?(%Element{kind: :screen, children: []}), do: true
  defp empty_screen?(_other), do: false

  @valid_heading_levels ~w(h1 h2 h3 h4 h5 h6)

  defp normalize_heading_level(value) when is_atom(value),
    do: normalize_heading_level(Atom.to_string(value))

  defp normalize_heading_level(value) when is_binary(value) do
    downcased = String.downcase(value)

    if downcased in @valid_heading_levels do
      downcased
    else
      "h1"
    end
  end

  defp normalize_heading_level(_), do: "h1"

  defp normalize_segments(segments) when is_list(segments) do
    Enum.flat_map(segments, &normalize_segment/1)
  end

  defp normalize_segments(_), do: []

  defp normalize_segment(%{"type" => type, "value" => value})
       when is_binary(value) and type in ["text", "em"] do
    [%{type: type, value: value}]
  end

  defp normalize_segment(%{type: type, value: value})
       when is_binary(value) and type in [:text, :em] do
    [%{type: Atom.to_string(type), value: value}]
  end

  defp normalize_segment({:em, value}) when is_binary(value), do: [%{type: "em", value: value}]

  defp normalize_segment({:text, value}) when is_binary(value),
    do: [%{type: "text", value: value}]

  defp normalize_segment(_), do: []

  defp render_segment(%{type: "em", value: value}), do: "<em>#{html_escape(value)}</em>"
  defp render_segment(%{type: "text", value: value}), do: html_escape(value)
end
