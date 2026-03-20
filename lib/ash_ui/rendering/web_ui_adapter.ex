defmodule AshUI.Rendering.WebUIAdapter do
  @moduledoc """
  Adapter for WebUI renderer package.

  This module provides integration with the web_ui package for rendering
  to static HTML with Elm client integration. When the web_ui package is
  not available, this module provides stub implementations.

  ## WebUI-Specific Features

  This adapter supports:
  - SEO meta tags generation
  - Elm client integration
  - Static asset references
  - Static site generation

  If WebUI.Renderer is available, delegates to it. Otherwise, provides
  fallback implementation using the IURAdapter.
  """

  alias AshUI.Rendering.IURAdapter
  alias AshUI.Compilation.IUR
  alias AshUI.Telemetry

  @doc """
  Renders a canonical IUR to static HTML string.

  ## Parameters
    * `canonical_iur` - Canonical IUR map from IURAdapter
    * `opts` - Rendering options

  ## Options
    * `:seo_enabled` - Include SEO meta tags (default: true)
    * `:elm_enabled` - Enable Elm client integration (default: false)
    * `:elm_module` - Elm module name (default: "Main")
    * `:assets_url` - Base URL for static assets (default: "/assets")
    * `:title` - Page title (default: extracted from IUR)
    * `:description` - Page description (default: from IUR or generic)

  ## Returns
    * `{:ok, html_string}` - Static HTML string
    * `{:error, reason}` - Rendering failed
  """
  @spec render(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render(canonical_iur, opts \\ []) when is_map(canonical_iur) do
    started_at = System.monotonic_time()
    metadata = render_metadata(canonical_iur, :web_ui)
    Telemetry.emit(:render, :start, %{count: 1}, metadata)

    result =
      if Code.ensure_loaded?(WebUI.Renderer) do
        call_web_ui_renderer(canonical_iur, opts)
      else
        render_fallback(canonical_iur, opts)
      end

    emit_render_telemetry(result, started_at, metadata)
  end

  @doc """
  Checks if WebUI renderer is available.

  ## Returns
    * `true` - WebUI.Renderer is available
    * `false` - WebUI.Renderer is not available
  """
  @spec available?() :: boolean()
  def available? do
    Code.ensure_loaded?(web_ui_renderer_module())
  end

  @doc """
  Converts an Ash IUR to WebUI-compatible format and renders.

  ## Parameters
    * `ash_iur` - Ash IUR structure
    * `opts` - Rendering options

  ## Returns
    * `{:ok, html_string}` - Static HTML string
    * `{:error, reason}` - Rendering failed
  """
  @spec render_ash_iur(IUR.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render_ash_iur(%IUR{} = ash_iur, opts \\ []) do
    with {:ok, canonical_iur} <- IURAdapter.to_canonical(ash_iur, opts),
         {:ok, html} <- render(canonical_iur, opts) do
      {:ok, html}
    else
      error -> error
    end
  end

  @doc """
  Configures SEO meta tags for a screen.

  ## Parameters
    * `canonical_iur` - Canonical IUR map
    * `opts` - Options

  ## Returns
    * SEO configuration map with title, description, keywords, etc.
  """
  @spec configure_seo(map(), keyword()) :: map()
  def configure_seo(%{"type" => "screen"} = iur, opts \\ []) do
    seo_enabled = Keyword.get(opts, :seo_enabled, true)
    custom_title = Keyword.get(opts, :title)
    custom_description = Keyword.get(opts, :description)

    %{
      enabled: seo_enabled,
      title: custom_title || Map.get(iur, "name", "AshUI Screen"),
      description: custom_description || get_default_description(iur),
      keywords: extract_keywords(iur),
      og_tags: generate_og_tags(iur),
      twitter_tags: generate_twitter_tags(iur)
    }
  end

  @doc """
  Configures Elm client integration.

  ## Parameters
    * `canonical_iur` - Canonical IUR map
    * `opts` - Options

  ## Returns
    * Elm integration configuration
  """
  @spec configure_elm_integration(map(), keyword()) :: map()
  def configure_elm_integration(%{"type" => "screen"} = iur, opts \\ []) do
    elm_enabled = Keyword.get(opts, :elm_enabled, false)
    elm_module = Keyword.get(opts, :elm_module, "Main")
    assets_url = Keyword.get(opts, :assets_url, "/assets")

    # Extract ports from bindings
    ports = extract_elm_ports(iur)

    %{
      enabled: elm_enabled,
      module: elm_module,
      js_file: "#{String.downcase(elm_module)}.js",
      minified_js_file: "#{String.downcase(elm_module)}.min.js",
      assets_url: assets_url,
      mount_node: "elm-app",
      ports: ports
    }
  end

  @doc """
  Configures static asset references.

  ## Parameters
    * `canonical_iur` - Canonical IUR map
    * `opts` - Options

  ## Returns
    * Asset configuration map
  """
  @spec configure_assets(map(), keyword()) :: map()
  def configure_assets(%{"type" => "screen"} = _iur, opts \\ []) do
    assets_url = Keyword.get(opts, :assets_url, "/assets")
    include_css = Keyword.get(opts, :include_css, true)
    include_js = Keyword.get(opts, :include_js, true)

    %{
      base_url: assets_url,
      css_files: if(include_css, do: ["app.css"], else: []),
      js_files: if(include_js, do: ["app.js"], else: []),
      fingerprinted: Keyword.get(opts, :asset_fingerprinting, true)
    }
  end

  @doc """
  Configures static site generation.

  ## Parameters
    * `canonical_iur` - Canonical IUR map
    * `opts` - Options

  ## Returns
    * SSG configuration
  """
  @spec configure_ssg(map(), keyword()) :: map()
  def configure_ssg(%{"type" => "screen"} = _iur, opts \\ []) do
    %{
      output_path: Keyword.get(opts, :output_path, "output"),
      generate_index: Keyword.get(opts, :generate_index, true),
      prerender: Keyword.get(opts, :prerender, false),
      incremental: Keyword.get(opts, :incremental_ssg, false),
      revalidate: Keyword.get(opts, :revalidate, nil)
    }
  end

  # Private Functions

  defp web_ui_renderer_module do
    Module.concat(WebUI, Renderer)
  end

  # Call actual WebUI.Renderer if available
  defp call_web_ui_renderer(canonical_iur, opts) do
    renderer_module = web_ui_renderer_module()

    try do
      case apply(renderer_module, :render, [canonical_iur, opts]) do
        {:ok, html} -> {:ok, html}
        {:error, reason} -> {:error, {:web_ui_error, reason}}
        other -> {:error, {:unexpected_response, other}}
      end
    rescue
      error -> {:error, {:web_ui_exception, error}}
    end
  end

  # Fallback renderer when WebUI is not available
  defp render_fallback(canonical_iur, opts) do
    html = generate_html(canonical_iur, opts)
    {:ok, html}
  end

  # Generate static HTML from canonical IUR
  defp generate_html(%{"type" => "screen"} = iur, opts) do
    seo_config = configure_seo(iur, opts)
    elm_config = configure_elm_integration(iur, opts)
    asset_config = configure_assets(iur, opts)

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      #{if seo_config.enabled, do: generate_seo_tags(seo_config), else: ""}
      #{if elm_config.enabled, do: generate_elm_script(elm_config), else: ""}
      #{generate_asset_tags(asset_config)}
    </head>
    <body class="ash-screen ash-screen-#{iur["name"]}" data-screen-id="#{iur["id"]}">
      #{generate_children(iur["children"])}
      #{if elm_config.enabled, do: generate_elm_mount(elm_config), else: ""}
    </body>
    </html>
    """
  end

  defp generate_html(%{"type" => type, "id" => id} = iur, _opts) do
    """
    <div class="ash-widget ash-widget-#{type}" data-widget-id="#{id}">
      #{generate_children(iur["children"])}
    </div>
    """
  end

  defp generate_seo_tags(seo_config) do
    """
    <title>#{seo_config.title}</title>
    <meta name="description" content="#{seo_config.description}">
    #{if length(seo_config.keywords) > 0, do: "<meta name=\"keywords\" content=\"#{Enum.join(seo_config.keywords, ", ")}\">", else: ""}
    #{generate_og_tag_html(seo_config.og_tags)}
    #{generate_twitter_tag_html(seo_config.twitter_tags)}
    """
  end

  defp generate_og_tag_html(og_tags) do
    Enum.map_join(og_tags, fn {property, content} ->
      "<meta property=\"og:#{property}\" content=\"#{content}\">"
    end)
  end

  defp generate_twitter_tag_html(twitter_tags) do
    Enum.map_join(twitter_tags, fn {name, content} ->
      "<meta name=\"twitter:#{name}\" content=\"#{content}\">"
    end)
  end

  defp generate_elm_script(elm_config) do
    """
    <script src="#{elm_config.assets_url}/#{elm_config.js_file}\"></script>
    """
  end

  defp generate_elm_mount(elm_config) do
    """
    <div id="#{elm_config.mount_node}\"></div>
    <script>
      Elm.#{elm_config.module}.init({
        node: document.getElementById("#{elm_config.mount_node}")
        #{if map_size(elm_config.ports) > 0, do: ",\n        flags: " <> encode_ports_json(elm_config.ports), else: ""}
      });
    </script>
    """
  end

  defp generate_asset_tags(asset_config) do
    css_tags =
      Enum.map_join(asset_config.css_files, fn file ->
        fingerprint =
          if asset_config.fingerprinted, do: "?v=#{:erlang.phash2(:os.system_time())}", else: ""

        "<link rel=\"stylesheet\" href=\"#{asset_config.base_url}/#{file}#{fingerprint}\">"
      end)

    js_tags =
      Enum.map_join(asset_config.js_files, fn file ->
        fingerprint =
          if asset_config.fingerprinted, do: "?v=#{:erlang.phash2(:os.system_time())}", else: ""

        "<script src=\"#{asset_config.base_url}/#{file}#{fingerprint}\"></script>"
      end)

    css_tags <> js_tags
  end

  defp generate_children(nil), do: ""
  defp generate_children([]), do: ""

  defp generate_children(children) when is_list(children) do
    Enum.map_join(children, &generate_html(&1, []))
  end

  defp get_default_description(iur) do
    "Generated by AshUI - #{Map.get(iur, "name", "Screen")}"
  end

  defp extract_keywords(iur) do
    # Extract keywords from metadata or generate from name
    metadata_keywords = get_in(iur, ["metadata", "keywords"]) || []
    name = Map.get(iur, "name", "")

    generated_keywords =
      name
      |> String.split("_")
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.capitalize/1)

    metadata_keywords ++ generated_keywords
  end

  defp generate_og_tags(iur) do
    name = Map.get(iur, "name", "")
    description = get_default_description(iur)

    %{
      title: name,
      type: "website",
      description: description
    }
  end

  defp generate_twitter_tags(iur) do
    name = Map.get(iur, "name", "")

    %{
      card: "summary",
      title: name
    }
  end

  defp extract_elm_ports(iur) do
    bindings = Map.get(iur, "bindings", [])

    bindings
    |> Enum.filter(fn binding ->
      Map.get(binding, "type") in ["bidirectional", "collection"]
    end)
    |> Enum.map(fn binding ->
      target = Map.get(binding, "target")
      source = Map.get(binding, "source", %{})
      {target, extract_port_value(source)}
    end)
    |> Map.new()
  end

  defp extract_port_value(source) when is_map(source) do
    # Extract default value or initial data
    Map.get(source, "default", nil)
  end

  defp extract_port_value(_), do: nil

  defp encode_ports_json(ports) do
    # Simple JSON encoding for ports flags
    # In production, use Jason or similar
    ports
    |> Enum.map_join(", ", fn {key, value} ->
      encoded_value = if is_binary(value), do: "\"#{value}\",", else: inspect(value)
      "\"#{key}\": #{encoded_value}"
    end)
    |> wrap_in_object()
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

  defp wrap_in_object(str), do: "{#{str}}"
end
