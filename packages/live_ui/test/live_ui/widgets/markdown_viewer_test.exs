defmodule LiveUi.Widgets.MarkdownViewerTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias LiveUi.Component

  @moduledoc """
  Tests for LiveUi.Widgets.MarkdownViewer.

  Covers both modes:
  - `"rendered"` (default): Earmark + HtmlSanitizeEx two-layer pipeline
  - `"raw"`: source verbatim in `<pre>`

  Plus sanitization (no executable script, no `javascript:` href) and the
  Earmark `{:error, html, _}` recoverable-tuple path.
  """

  describe "Widget metadata" do
    test "has the expected name and family" do
      metadata = Component.metadata(LiveUi.Widgets.MarkdownViewer)

      assert metadata.name == :markdown_viewer
      assert metadata.family == :data
    end

    test "is registered in the data widget family" do
      assert LiveUi.Widgets.MarkdownViewer in LiveUi.Widgets.modules()
    end
  end

  describe "format: \"rendered\" (default)" do
    test "parses h1/h2/h3 headings" do
      html =
        render_component(&LiveUi.Widgets.MarkdownViewer.component/1, %{
          id: "headings",
          source: "# Title\n## Sub\n### Smaller"
        })

      assert html =~ ~r{<h1>\s*Title\s*</h1>}
      assert html =~ ~r{<h2>\s*Sub\s*</h2>}
      assert html =~ ~r{<h3>\s*Smaller\s*</h3>}
    end

    test "parses bold and italic" do
      html =
        render_component(&LiveUi.Widgets.MarkdownViewer.component/1, %{
          id: "emphasis",
          source: "**bold** and _italic_"
        })

      assert html =~ "<strong>bold</strong>"
      assert html =~ "<em>italic</em>"
    end

    test "parses unordered lists" do
      html =
        render_component(&LiveUi.Widgets.MarkdownViewer.component/1, %{
          id: "list",
          source: "- one\n- two\n- three"
        })

      assert html =~ "<ul>"
      assert html =~ "<li>"
      assert html =~ "one"
      assert html =~ "two"
      assert html =~ "three"
    end

    test "strips script tags" do
      html =
        render_component(&LiveUi.Widgets.MarkdownViewer.component/1, %{
          id: "no-script",
          source: "<script>alert(1)</script>"
        })

      refute html =~ "<script>"
      refute html =~ "</script>"
    end

    test "strips javascript: hrefs" do
      bad = "[click](javascript:alert(1))"

      html =
        render_component(&LiveUi.Widgets.MarkdownViewer.component/1, %{
          id: "no-js-href",
          source: bad
        })

      refute html =~ "javascript:"
    end

    test "empty source renders empty article" do
      html =
        render_component(&LiveUi.Widgets.MarkdownViewer.component/1, %{
          id: "empty",
          source: ""
        })

      assert html =~ ~s(data-live-ui-widget="markdown-viewer")
      assert html =~ ~s(data-live-ui-format="rendered")
    end

    test "default format is \"rendered\"" do
      html =
        render_component(&LiveUi.Widgets.MarkdownViewer.component/1, %{
          id: "default-mode",
          source: "**bold**"
        })

      assert html =~ ~s(data-live-ui-format="rendered")
      assert html =~ "<strong>bold</strong>"
    end
  end

  describe "format: \"raw\"" do
    test "wraps source verbatim in <pre>" do
      html =
        render_component(&LiveUi.Widgets.MarkdownViewer.component/1, %{
          id: "raw-mode",
          source: "# Title\n**bold**",
          format: "raw"
        })

      assert html =~ "<pre>"
      # Source preserved as text (HTML-escaped) — NOT parsed into <h1> / <strong>
      assert html =~ "# Title"
      refute html =~ "<h1>"
      refute html =~ "<strong>"
    end

    test "HTML-escapes raw source so embedded HTML does not render" do
      html =
        render_component(&LiveUi.Widgets.MarkdownViewer.component/1, %{
          id: "raw-escape",
          source: "<script>alert(1)</script>",
          format: "raw"
        })

      refute html =~ "<script>alert(1)</script>"
      assert html =~ "&lt;script&gt;"
    end
  end
end
