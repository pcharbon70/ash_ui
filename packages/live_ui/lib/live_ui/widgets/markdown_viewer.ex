defmodule LiveUi.Widgets.MarkdownViewer do
  @moduledoc """
  Native markdown / document viewer widget.

  Two formats:

  - `"rendered"` (default) — parses `:source` as markdown via `Earmark` and
    sanitizes the resulting HTML with `HtmlSanitizeEx.markdown_html/1`. This is
    the safe path for displaying agent-authored or operator-authored markdown
    in a document surface. Two-layer sanitization: `Earmark` is invoked with
    `escape: true` (escapes raw HTML inside markdown plain text); the sanitizer
    then strips dangerous tags + URL schemes that survived (e.g. `javascript:`
    hrefs in markdown links).

  - `"raw"` — wraps `:source` verbatim in `<pre>` (HTML-escaped). For
    displaying markdown source as text without parsing.

  ## Framework note: `:format` instead of `:mode`

  This widget uses `:format` to select between `"rendered"` and `"raw"` —
  NOT `:mode`. `LiveUi.Widget`'s render pipeline reserves `:mode` and drops
  it from the assigns passed to the wrapper module's render (see
  `live_ui/widget.ex` `build_render_assigns/1` `:mode` in the `Map.drop` list).
  A widget that tries to declare `attr :mode` will silently always receive
  the attribute default. Use `:format` (or a widget-specific name) for
  user-facing rendering-mode toggles instead.

  External deps `earmark` and `html_sanitize_ex` are required for the
  rendered format; consumers depending on `live_ui` inherit these
  transitively.
  """

  use LiveUi.Component, family: :data, name: :markdown_viewer

  LiveUi.Component.common_attrs()
  attr(:source, :string, required: true)
  attr(:format, :string, default: "rendered")

  @impl true
  def render(assigns) do
    ~H"""
    <article
      id={@id}
      data-live-ui-widget="markdown-viewer"
      data-live-ui-format={@format}
      data-live-ui-tone={@tone}
      data-live-ui-variant={@variant}
      data-live-ui-state={@state}
      class={@class}
      {@rest}
    >
      {render_content(@source, @format)}
    </article>
    """
  end

  defp render_content(source, "rendered"),
    do: Phoenix.HTML.raw(rendered_markdown(source))

  defp render_content(source, _other),
    do: Phoenix.HTML.raw(raw_pre(source))

  defp rendered_markdown(nil), do: ""
  defp rendered_markdown(""), do: ""

  defp rendered_markdown(source) when is_binary(source) do
    case Earmark.as_html(source, escape: true) do
      {:ok, html, _warnings} -> HtmlSanitizeEx.markdown_html(html)
      {:error, html, _errors} -> HtmlSanitizeEx.markdown_html(html)
    end
  end

  defp raw_pre(nil), do: "<pre></pre>"

  defp raw_pre(source) when is_binary(source) do
    escaped =
      source
      |> Phoenix.HTML.html_escape()
      |> Phoenix.HTML.safe_to_string()

    "<pre>" <> escaped <> "</pre>"
  end
end
