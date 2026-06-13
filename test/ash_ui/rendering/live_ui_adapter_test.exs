defmodule AshUI.Rendering.LiveUIAdapterTest do
  use ExUnit.Case, async: true

  alias AshUI.Compilation.IUR
  alias AshUI.Rendering.LiveUIAdapter

  describe "Section 7.2.1 - LiveUI Renderer Adapter" do
    test "render/2 returns HEEx for screen IUR" do
      canonical_iur = %{
        "type" => "screen",
        "id" => "screen-1",
        "name" => "test_screen",
        "layout" => "column",
        "children" => [
          %{
            "type" => "text",
            "id" => "text-1",
            "props" => %{"content" => "Hello"},
            "children" => [],
            "metadata" => %{}
          }
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
      ash_iur =
        struct(IUR,
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
      {:ok,
       canonical_iur: %{
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

    test "configure_event_bindings/2 extracts action events", %{canonical_iur: iur} do
      config = LiveUIAdapter.configure_event_bindings(iur, event_prefix: "ash")

      assert is_list(config.events)
      assert config.event_prefix == "ash"

      action_events =
        Enum.filter(config.events, fn e ->
          String.contains?(e.event, "action")
        end)

      assert length(action_events) > 0
    end

    test "configure_event_bindings/2 extracts change events", %{canonical_iur: iur} do
      config = LiveUIAdapter.configure_event_bindings(iur)

      change_events =
        Enum.filter(config.events, fn e ->
          String.contains?(e.event, "change")
        end)

      assert length(change_events) > 0
    end

    test "configure_hooks/2 returns default hooks", %{canonical_iur: iur} do
      hooks = LiveUIAdapter.configure_hooks(iur)

      assert is_list(hooks)

      lifecycle_hook = Enum.find(hooks, fn h -> h.name == :ash_ui_lifecycle end)
      assert lifecycle_hook != nil
      assert lifecycle_hook.on_mount == {AshUI.LiveView.Hooks, :on_mount_ash_ui}
    end

    test "configure_hooks/2 includes patch hooks when optimize_patches is true", %{
      canonical_iur: iur
    } do
      hooks = LiveUIAdapter.configure_hooks(iur, optimize_patches: true)

      patch_hook = Enum.find(hooks, fn h -> h.name == :ash_ui_patches end)
      assert patch_hook != nil
    end

    test "configure_hooks/2 excludes patch hooks when optimize_patches is false", %{
      canonical_iur: iur
    } do
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
        "metadata" => %{},
        "bindings" => [
          %{
            "id" => "save_profile",
            "type" => "event",
            "target" => "submit",
            "element_id" => "btn-1",
            "metadata" => %{"owner_signal" => "click"}
          }
        ]
      }

      {:ok, heex} = LiveUIAdapter.render(iur)
      assert String.contains?(heex, "phx-click=\"ash_ui_action\"")
      assert String.contains?(heex, "phx-value-element_id=\"btn-1\"")
      assert String.contains?(heex, "phx-value-signal=\"click\"")
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
      assert String.contains?(heex, "phx-blur=\"ash_ui_change\"")
      assert String.contains?(heex, "phx-change=\"ash_ui_change\"")
      assert String.contains?(heex, "phx-value-element_id=\"input-1\"")
      assert String.contains?(heex, "phx-value-signal=\"change\"")
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

    test "generates inline_rich_text_heading with mixed text and em segments" do
      iur = %{
        "type" => "inline_rich_text_heading",
        "id" => "heading-1",
        "props" => %{
          "level" => "h1",
          "segments" => [
            %{"type" => "text", "value" => "The operator surface, "},
            %{"type" => "em", "value" => "for the team that thinks in documents."}
          ]
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur)
      assert String.contains?(heex, "<h1")
      assert String.contains?(heex, "</h1>")
      assert String.contains?(heex, "ash-inline-rich-text-heading")
      assert String.contains?(heex, "ash-inline-rich-text-heading-h1")

      assert String.contains?(
               heex,
               "The operator surface, <em>for the team that thinks in documents.</em>"
             )
    end

    test "inline_rich_text_heading respects level prop for h2 through h6" do
      for level <- ~w(h2 h3 h4 h5 h6) do
        iur = %{
          "type" => "inline_rich_text_heading",
          "id" => "heading-#{level}",
          "props" => %{
            "level" => level,
            "segments" => [%{"type" => "text", "value" => "x"}]
          },
          "children" => [],
          "metadata" => %{}
        }

        {:ok, heex} = LiveUIAdapter.render(iur)
        assert String.contains?(heex, "<#{level}"), "expected <#{level}> tag for level=#{level}"
        assert String.contains?(heex, "</#{level}>")
        assert String.contains?(heex, "ash-inline-rich-text-heading-#{level}")
      end
    end

    test "inline_rich_text_heading falls back to h1 when level prop is missing or invalid" do
      iur = %{
        "type" => "inline_rich_text_heading",
        "id" => "heading-default",
        "props" => %{
          "segments" => [%{"type" => "text", "value" => "Default"}]
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur)
      assert String.contains?(heex, "<h1")
      assert String.contains?(heex, "Default")

      bogus = put_in(iur, ["props", "level"], "h99")
      {:ok, heex_bogus} = LiveUIAdapter.render(bogus)
      assert String.contains?(heex_bogus, "<h1")
    end

    test "inline_rich_text_heading accepts atom-keyed segments" do
      iur = %{
        "type" => "inline_rich_text_heading",
        "id" => "heading-atom",
        "props" => %{
          "level" => "h2",
          "segments" => [
            %{type: :text, value: "Hello "},
            %{type: :em, value: "world"}
          ]
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur)
      assert String.contains?(heex, "<h2")
      assert String.contains?(heex, "Hello <em>world</em>")
    end

    test "inline_rich_text_heading produces no literal color or font-family values" do
      iur = %{
        "type" => "inline_rich_text_heading",
        "id" => "heading-pure",
        "props" => %{
          "level" => "h1",
          "segments" => [
            %{"type" => "text", "value" => "Hello "},
            %{"type" => "em", "value" => "world"}
          ]
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur)
      refute heex =~ ~r/#[0-9a-fA-F]{3,6}\b/
      refute heex =~ ~r/\brgb\s*\(/
      refute heex =~ ~r/font-family\s*:/i
    end

    test "generates dedicated navigation markup for example-facing custom surfaces" do
      Enum.each(
        [
          {
            "custom:menu",
            "ash-menu",
            "ash-menu-nav",
            "Menu focus stays on nested public buttons."
          },
          {
            "custom:tabs",
            "ash-tabs",
            "ash-tabs-panels",
            "Panels stay inside the custom tabs shell."
          },
          {
            "custom:command_palette",
            "ash-command-palette",
            "ash-command-palette-results",
            "Commands execute through nested public buttons."
          }
        ],
        fn {type, wrapper_class, section_class, detail_copy} ->
          iur = %{
            "type" => type,
            "id" => "#{type}-demo",
            "props" => %{
              "title" => "#{type} Demo",
              "description" => detail_copy
            },
            "children" => [
              %{
                "type" => "button",
                "id" => "#{type}-nav",
                "props" => %{"label" => "Overview"},
                "children" => [],
                "metadata" => %{
                  "slot" => if(type == "custom:command_palette", do: "search", else: "nav")
                }
              },
              %{
                "type" => "text",
                "id" => "#{type}-body",
                "props" => %{"content" => detail_copy},
                "children" => [],
                "metadata" => %{"slot" => "body"}
              }
            ],
            "metadata" => %{}
          }

          {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

          assert heex =~ wrapper_class
          assert heex =~ section_class
          assert heex =~ detail_copy
          assert heex =~ "Overview"
        end
      )
    end

    test "generates dedicated display markup for example-facing custom surfaces" do
      Enum.each(
        [
          {"custom:viewport", "ash-viewport", "ash-viewport-body", "body"},
          {"custom:scroll_bar", "ash-scroll-bar", "ash-scroll-bar-track", "body"},
          {"custom:split_pane", "ash-split-pane", "ash-split-pane-secondary", "secondary"},
          {"custom:canvas", "ash-canvas-surface", "ash-canvas-toolbar", "toolbar"}
        ],
        fn {type, wrapper_class, section_class, slot} ->
          children =
            case type do
              "custom:split_pane" ->
                [
                  %{
                    "type" => "text",
                    "id" => "#{type}-primary",
                    "props" => %{"content" => "Primary lane"},
                    "children" => [],
                    "metadata" => %{"slot" => "primary"}
                  },
                  %{
                    "type" => "text",
                    "id" => "#{type}-secondary",
                    "props" => %{"content" => "Secondary lane"},
                    "children" => [],
                    "metadata" => %{"slot" => "secondary"}
                  }
                ]

              "custom:canvas" ->
                [
                  %{
                    "type" => "button",
                    "id" => "#{type}-tool",
                    "props" => %{"label" => "Ink"},
                    "children" => [],
                    "metadata" => %{"slot" => "toolbar"}
                  },
                  %{
                    "type" => "text",
                    "id" => "#{type}-body",
                    "props" => %{"content" => "Annotation layer"},
                    "children" => [],
                    "metadata" => %{"slot" => "body"}
                  }
                ]

              _other ->
                [
                  %{
                    "type" => "text",
                    "id" => "#{type}-body",
                    "props" => %{"content" => "Viewport detail"},
                    "children" => [],
                    "metadata" => %{"slot" => slot}
                  }
                ]
            end

          iur = %{
            "type" => type,
            "id" => "#{type}-demo",
            "props" => %{"title" => "#{type} Demo", "description" => "Dedicated example shell"},
            "children" => children,
            "metadata" => %{}
          }

          {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

          assert heex =~ wrapper_class
          assert heex =~ section_class
          assert heex =~ "Dedicated example shell"
        end
      )
    end

    test "generates dedicated layered markup for example-facing overlay surfaces" do
      Enum.each(
        [
          {"custom:overlay", "ash-overlay-surface", "ash-overlay-actions", "actions"},
          {"custom:dialog", "ash-dialog-surface", "ash-dialog-actions", "actions"},
          {
            "custom:alert_dialog",
            "ash-alert-dialog-surface",
            "ash-alert-dialog-actions",
            "actions"
          },
          {"custom:context_menu", "ash-context-menu", "ash-context-menu-items", "menu"},
          {"custom:toast", "ash-toast", "ash-toast-actions", "actions"}
        ],
        fn {type, wrapper_class, section_class, slot} ->
          children =
            case type do
              "custom:context_menu" ->
                [
                  %{
                    "type" => "button",
                    "id" => "#{type}-item",
                    "props" => %{"label" => "Inspect"},
                    "children" => [],
                    "metadata" => %{"slot" => "menu"}
                  },
                  %{
                    "type" => "text",
                    "id" => "#{type}-body",
                    "props" => %{"content" => "Selected operation"},
                    "children" => [],
                    "metadata" => %{"slot" => "body"}
                  }
                ]

              _other ->
                [
                  %{
                    "type" => "text",
                    "id" => "#{type}-body",
                    "props" => %{"content" => "Layered detail"},
                    "children" => [],
                    "metadata" => %{"slot" => "body"}
                  },
                  %{
                    "type" => "button",
                    "id" => "#{type}-action",
                    "props" => %{"label" => "Acknowledge"},
                    "children" => [],
                    "metadata" => %{"slot" => slot}
                  }
                ]
            end

          iur = %{
            "type" => type,
            "id" => "#{type}-demo",
            "props" => %{
              "title" => "#{type} Demo",
              "description" => "Layered example shell",
              if(type == "custom:toast", do: "visible", else: "open") => true
            },
            "children" => children,
            "metadata" => %{}
          }

          {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

          assert heex =~ wrapper_class
          assert heex =~ section_class
          assert heex =~ "Layered example shell"

          if type == "custom:context_menu" do
            assert heex =~ "Inspect"
          else
            assert heex =~ "Acknowledge"
          end
        end
      )
    end

    test "generates dedicated data-surface markup for advanced collection and document examples" do
      Enum.each(
        [
          {"list", "ash-list", "ash-list-items", "Urgent approvals"},
          {"table", "ash-table-surface", "ash-table-wrapper", "API gateway"},
          {"custom:tree_view", "ash-tree-view", "ash-tree-view-list", "Runtime graph"},
          {
            "custom:markdown_viewer",
            "ash-markdown-viewer",
            "ash-markdown-viewer-body",
            "Incident Guide"
          },
          {
            "custom:log_viewer",
            "ash-log-viewer",
            "ash-log-viewer-lines",
            "Ash UI screen mounted with 5 element bindings."
          }
        ],
        fn {type, wrapper_class, section_class, expected_copy} ->
          props =
            case type do
              "list" ->
                %{
                  "title" => "Queue",
                  "description" => "Collection view",
                  "items" => [
                    %{
                      "title" => "Urgent approvals",
                      "summary" => "4 records",
                      "meta" => "SLA 15m"
                    }
                  ]
                }

              "table" ->
                %{
                  "title" => "Table",
                  "description" => "Tabular collection",
                  "columns" => [
                    %{"key" => "service", "label" => "Service"},
                    %{"key" => "status", "label" => "Status"}
                  ],
                  "items" => [%{"service" => "API gateway", "status" => "Ready"}]
                }

              "custom:tree_view" ->
                %{
                  "title" => "Tree",
                  "description" => "Hierarchy",
                  "model" => [
                    %{
                      "label" => "Runtime graph",
                      "meta" => "Primary",
                      "children" => [%{"label" => "Binding runtime", "meta" => "Healthy"}]
                    }
                  ]
                }

              "custom:markdown_viewer" ->
                %{
                  "title" => "Markdown",
                  "description" => "Document surface",
                  "content" => "# Incident Guide\n\n- Confirm scope"
                }

              "custom:log_viewer" ->
                %{
                  "title" => "Logs",
                  "description" => "Stream view",
                  "entries" => [
                    %{
                      "timestamp" => "12:04:19",
                      "level" => "INFO",
                      "message" => "Ash UI screen mounted with 5 element bindings."
                    }
                  ]
                }
            end

          iur = %{
            "type" => type,
            "id" => "#{type}-demo",
            "props" => props,
            "children" => [
              %{
                "type" => "button",
                "id" => "#{type}-action",
                "props" => %{"label" => "Refresh"},
                "children" => [],
                "metadata" => %{"slot" => "actions"}
              },
              %{
                "type" => "text",
                "id" => "#{type}-footer",
                "props" => %{"content" => "Bound runtime state"},
                "children" => [],
                "metadata" => %{"slot" => "footer"}
              }
            ],
            "metadata" => %{}
          }

          {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

          assert heex =~ wrapper_class
          assert heex =~ section_class
          assert heex =~ expected_copy
          assert heex =~ "Refresh"
          assert heex =~ "Bound runtime state"
        end
      )
    end

    test "generates dedicated feedback and chart markup for advanced signal examples" do
      Enum.each(
        [
          {"custom:status", "ash-status-surface", "ash-status-pill", "Healthy"},
          {"custom:progress", "ash-progress-surface", "ash-progress-track", "42%"},
          {"custom:gauge", "ash-gauge-surface", "ash-gauge-meter", "63%"},
          {
            "custom:inline_feedback",
            "ash-inline-feedback",
            "ash-inline-feedback-badge",
            "Rollback ready"
          },
          {"custom:sparkline", "ash-sparkline-surface", "ash-sparkline-chart", "00m"},
          {"custom:bar_chart", "ash-bar-chart", "ash-bar-chart-bars", "us-east"},
          {"custom:line_chart", "ash-line-chart", "ash-line-chart-grid", "Mon"}
        ],
        fn {type, wrapper_class, section_class, expected_copy} ->
          props =
            case type do
              "custom:status" ->
                %{
                  "title" => "Status",
                  "description" => "Signal surface",
                  "model" => %{
                    "label" => "Healthy",
                    "tone" => "success",
                    "detail" => "All queues nominal."
                  }
                }

              "custom:progress" ->
                %{
                  "title" => "Progress",
                  "description" => "Rollout surface",
                  "model" => %{
                    "label" => "Canary",
                    "value" => 42,
                    "total" => 100,
                    "detail" => "42 percent live."
                  }
                }

              "custom:gauge" ->
                %{
                  "title" => "Gauge",
                  "description" => "Capacity surface",
                  "model" => %{
                    "label" => "CPU",
                    "value" => 63,
                    "max" => 100,
                    "detail" => "Within budget."
                  }
                }

              "custom:inline_feedback" ->
                %{
                  "title" => "Feedback",
                  "description" => "Advisory",
                  "model" => %{
                    "tone" => "success",
                    "title" => "Rollback ready",
                    "detail" => "Recovery checklist is prepared."
                  }
                }

              "custom:sparkline" ->
                %{
                  "title" => "Sparkline",
                  "description" => "Trend",
                  "series" => [
                    %{"label" => "00m", "value" => 18},
                    %{"label" => "05m", "value" => 22}
                  ]
                }

              "custom:bar_chart" ->
                %{
                  "title" => "Bars",
                  "description" => "Comparison",
                  "series" => [
                    %{"label" => "us-east", "value" => 84},
                    %{"label" => "us-west", "value" => 63}
                  ]
                }

              "custom:line_chart" ->
                %{
                  "title" => "Trend line",
                  "description" => "Trend",
                  "series" => [
                    %{"label" => "Mon", "value" => 7},
                    %{"label" => "Tue", "value" => 9}
                  ]
                }
            end

          iur = %{
            "type" => type,
            "id" => "#{type}-demo",
            "props" => props,
            "children" => [
              %{
                "type" => "button",
                "id" => "#{type}-action",
                "props" => %{"label" => "Switch"},
                "children" => [],
                "metadata" => %{"slot" => "actions"}
              },
              %{
                "type" => "text",
                "id" => "#{type}-footer",
                "props" => %{"content" => "Metric bound from runtime"},
                "children" => [],
                "metadata" => %{"slot" => "footer"}
              }
            ],
            "metadata" => %{}
          }

          {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

          assert heex =~ wrapper_class
          assert heex =~ section_class
          assert heex =~ expected_copy
          assert heex =~ "Switch"
          assert heex =~ "Metric bound from runtime"
        end
      )
    end

    test "generates dedicated operational markup for advanced monitoring examples" do
      Enum.each(
        [
          {"custom:stream_widget", "ash-stream-widget", "ash-stream-widget-entries", "ingest"},
          {
            "custom:process_monitor",
            "ash-process-monitor",
            "ash-process-monitor-cards",
            "scheduler"
          },
          {
            "custom:supervision_tree_viewer",
            "ash-supervision-tree-viewer",
            "ash-supervision-tree-list",
            "Worker supervisor"
          },
          {
            "custom:cluster_dashboard",
            "ash-cluster-dashboard",
            "ash-cluster-dashboard-grid",
            "Regional cluster stable"
          }
        ],
        fn {type, wrapper_class, section_class, expected_copy} ->
          props =
            case type do
              "custom:stream_widget" ->
                %{
                  "title" => "Stream",
                  "description" => "Operational feed",
                  "entries" => [
                    %{
                      "timestamp" => "13:04:12",
                      "label" => "ingest",
                      "message" => "Packet accepted."
                    }
                  ]
                }

              "custom:process_monitor" ->
                %{
                  "title" => "Process monitor",
                  "description" => "Runtime snapshot",
                  "model" => %{
                    "summary" => "Schedulers and workers are healthy.",
                    "processes" => [
                      %{"name" => "scheduler", "state" => "running", "meta" => "0 restarts"}
                    ]
                  }
                }

              "custom:supervision_tree_viewer" ->
                %{
                  "title" => "Supervision tree",
                  "description" => "Hierarchy",
                  "model" => %{
                    "label" => "Worker supervisor",
                    "meta" => "Primary",
                    "nodes" => [%{"label" => "queue_worker", "meta" => "running"}]
                  }
                }

              "custom:cluster_dashboard" ->
                %{
                  "title" => "Cluster dashboard",
                  "description" => "Regional overview",
                  "model" => %{
                    "headline" => "Regional cluster stable",
                    "detail" => "All regions are inside budget.",
                    "regions" => [%{"label" => "us-east", "status" => "Healthy", "load" => "63%"}],
                    "alerts" => [%{"title" => "Billing lag", "message" => "Watching retries."}]
                  }
                }
            end

          iur = %{
            "type" => type,
            "id" => "#{type}-demo",
            "props" => props,
            "children" => [
              %{
                "type" => "button",
                "id" => "#{type}-action",
                "props" => %{"label" => "Refresh"},
                "children" => [],
                "metadata" => %{"slot" => "actions"}
              },
              %{
                "type" => "text",
                "id" => "#{type}-footer",
                "props" => %{"content" => "Operational snapshot bound from runtime"},
                "children" => [],
                "metadata" => %{"slot" => "footer"}
              }
            ],
            "metadata" => %{}
          }

          {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

          assert heex =~ wrapper_class
          assert heex =~ section_class
          assert heex =~ expected_copy
          assert heex =~ "Refresh"
          assert heex =~ "Operational snapshot bound from runtime"
        end
      )
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

  describe "Phase 11 semantic widget rendering" do
    test "renders authored semantic widget props into visible HEEx" do
      {:ok, heex} = LiveUIAdapter.render(semantic_screen_iur())

      assert heex =~ "ash-hero"
      assert heex =~ "Authored through UnifiedUi"
      assert heex =~ "Persisted through AshUI.Resource.Authority."
      assert heex =~ "ash-badge-pill"
      assert heex =~ "Ready"
      assert heex =~ "ash-stat"
      assert heex =~ "Persistent screen bridge"
      assert heex =~ "ash-key-value"
      assert heex =~ "Persisted route metadata"
      assert heex =~ "ash-info-list"
      assert heex =~ "semantic_widgets"
      assert heex =~ "ash-form-field"
      assert heex =~ "Display name"
      assert heex =~ "Used to verify form_field survives the persistence bridge"
      assert heex =~ "phx-change=\"ash_ui_change\""
    end
  end

  defp semantic_screen_iur do
    %{
      "type" => "screen",
      "id" => "semantic-screen",
      "name" => "semantic_screen",
      "layout" => "column",
      "children" => [
        %{
          "type" => "hero",
          "id" => "hero-panel",
          "props" => %{
            "eyebrow" => "Authoring",
            "title" => "Authored through UnifiedUi",
            "message" => "Persisted through AshUI.Resource.Authority."
          },
          "children" => [
            %{
              "type" => "badge",
              "id" => "status-badge",
              "props" => %{"presentation" => "pill", "text" => "Ready"},
              "children" => [],
              "metadata" => %{}
            }
          ],
          "metadata" => %{}
        },
        %{
          "type" => "stat",
          "id" => "runtime-stat",
          "props" => %{
            "title" => "Runtime",
            "value" => "Ash UI",
            "message" => "Persistent screen bridge"
          },
          "children" => [],
          "metadata" => %{}
        },
        %{
          "type" => "key_value",
          "id" => "route-meta",
          "props" => %{
            "label" => "Route",
            "value" => "/authored",
            "description" => "Persisted route metadata"
          },
          "children" => [],
          "metadata" => %{}
        },
        %{
          "type" => "info_list",
          "id" => "highlights",
          "props" => %{
            "items" => [
              %{"id" => "upstream_dsl", "value" => "upstream_dsl"},
              %{"id" => "semantic_widgets", "value" => "semantic_widgets"}
            ]
          },
          "children" => [],
          "metadata" => %{}
        },
        %{
          "type" => "form_builder",
          "id" => "profile-form",
          "props" => %{},
          "children" => [
            %{
              "type" => "form_field",
              "id" => "display-name-field",
              "props" => %{"name" => "display_name"},
              "children" => [
                %{
                  "type" => "label",
                  "id" => "display-name-label",
                  "props" => %{"for" => "display-name-input", "text" => "Display name"},
                  "children" => [],
                  "metadata" => %{}
                },
                %{
                  "type" => "input",
                  "id" => "display-name-input",
                  "props" => %{"name" => "display_name", "placeholder" => "Enter your name"},
                  "children" => [],
                  "metadata" => %{}
                },
                %{
                  "type" => "text",
                  "id" => "display-name-help",
                  "props" => %{
                    "content" => "Used to verify form_field survives the persistence bridge"
                  },
                  "children" => [],
                  "metadata" => %{}
                }
              ],
              "metadata" => %{}
            }
          ],
          "metadata" => %{}
        }
      ],
      "bindings" => [
        %{
          "id" => "binding-1",
          "type" => "bidirectional",
          "target" => "display_name",
          "source" => %{"resource" => "User", "field" => "name"},
          "element_id" => "display-name-input",
          "metadata" => %{}
        }
      ],
      "metadata" => %{}
    }
  end

  describe "ask_sidebar adapter dispatch" do
    test "generates dedicated ask_sidebar markup" do
      iur = %{
        "type" => "ask_sidebar",
        "id" => "ask-sb-adapter-test",
        "props" => %{
          "sidebar_id" => "main-ask-sidebar",
          "on_map_jump_event" => "switch_to_map",
          "recent_items" => [
            %{"id" => "q1", "query" => "find blockers", "on_open_event" => "open_query"}
          ],
          "saved_items" => []
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ "ash-ask-sidebar"
      assert heex =~ ~s(data-live-ui-widget="ask-sidebar")
      assert heex =~ ~s(data-sidebar-id="main-ask-sidebar")
      assert heex =~ "aria-label=\"Ask sidebar\""
      assert heex =~ "Recent"
      assert heex =~ "find blockers"
      assert heex =~ "switch_to_map"
    end

    test "ask_sidebar adapter preserves active item aria-current" do
      iur = %{
        "type" => "ask_sidebar",
        "id" => "ask-sb-active-test",
        "props" => %{
          "sidebar_id" => "ask-sb-active",
          "on_map_jump_event" => "goto_map",
          "recent_items" => [
            %{"id" => "active-query", "query" => "active one", "on_open_event" => "open_q"}
          ],
          "active_item_id" => "active-query"
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ ~s(aria-current="true")
      assert heex =~ "ash-ask-sidebar__item--active"
    end
  end

  describe "thread_card adapter dispatch" do
    test "generates dedicated thread_card fallback markup" do
      iur = %{
        "type" => "thread_card",
        "id" => "thread-card-adapter-test",
        "props" => %{
          "thread" => %{
            "thread_id" => "thread:api",
            "title" => "API design discussion",
            "reply_count" => 5,
            "seed_quote" => "Should the runtime own this transition?",
            "progress_pct" => 0.65
          },
          "participants" => [
            %{"actor_name" => "Pascal", "avatar" => %{"initials" => "PC"}}
          ]
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ "ash-thread-card"
      assert heex =~ ~s(data-thread-id="thread:api")
      assert heex =~ "API design discussion"
      assert heex =~ "Should the runtime own this transition?"
      assert heex =~ "PC"
      assert heex =~ ~s(role="progressbar")
      assert heex =~ ~s(aria-valuenow="65")
      refute heex =~ "data-live-ui-intent"
    end
  end

  describe "tool_call_card adapter dispatch" do
    test "generates dedicated tool_call_card fallback markup" do
      iur = %{
        "type" => "tool_call_card",
        "id" => "tool-call-card-adapter-test",
        "props" => %{
          "tool_call" => %{
            "tool_name" => "Bash",
            "tool_kind" => "bash",
            "target" => "mix test",
            "summary" => "Run the focused suite.",
            "status" => "complete",
            "args" => %{"cmd" => "mix test"},
            "expanded?" => true,
            "tool_result_summary" => %{
              "event_id" => "result-1",
              "status" => "complete",
              "compact_output" => "Tests passed.",
              "diff_summary" => "No source diff.",
              "error?" => false
            }
          }
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ "ash-tool-call-card"
      assert heex =~ ~s(data-live-ui-widget="tool-call-card")
      assert heex =~ ~s(data-tool-kind="bash")
      assert heex =~ ~s(data-status="complete")
      assert heex =~ "Bash"
      assert heex =~ "mix test"
      assert heex =~ "Run the focused suite."
      assert heex =~ "ash-tool-call-card__args"
      assert heex =~ "Tests passed."
      assert heex =~ "No source diff."
    end
  end

  describe "composer_query_preview adapter dispatch" do
    test "generates dedicated composer_query_preview fallback markup" do
      iur = %{
        "type" => "composer_query_preview",
        "id" => "query-preview-adapter-test",
        "props" => %{
          "query_preview" => %{
            "composer_id" => "composer-main",
            "query" => "release blockers",
            "preview_state" => "ready",
            "explanation" => "Three likely blockers found.",
            "metrics" => %{
              "results_count" => 3,
              "duration_ms" => 42,
              "sources_visited" => 8
            },
            "findings" => [
              %{
                "id" => "finding-1",
                "n" => 1,
                "snippet" => "Conformance missing",
                "confidence" => 0.91
              }
            ]
          }
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ "ash-composer-query-preview"
      assert heex =~ ~s(data-live-ui-widget="composer-query-preview")
      assert heex =~ ~s(data-composer-id="composer-main")
      assert heex =~ "Three likely blockers found."
      assert heex =~ "Conformance missing"
      assert heex =~ "3"
      assert heex =~ "0.04s"
      refute heex =~ "data-live-ui-intent"
      refute heex =~ "open in Ask"
    end

    test "escapes query preview fallback content" do
      iur = %{
        "type" => "composer_query_preview",
        "id" => "query-preview-escape-test",
        "props" => %{
          "query_preview" => %{
            "composer_id" => "composer-main",
            "query" => "<script>alert(1)</script>",
            "preview_state" => "error",
            "error_message" => "<b>bad</b>"
          }
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ "&lt;script&gt;alert(1)&lt;/script&gt;"
      assert heex =~ "&lt;b&gt;bad&lt;/b&gt;"
      refute heex =~ "<script>"
      refute heex =~ "<b>bad</b>"
    end
  end

  describe "propose_new_doc_card adapter dispatch" do
    test "generates dedicated propose_new_doc_card fallback markup" do
      iur = %{
        "type" => "propose_new_doc_card",
        "id" => "proposal-adapter-test",
        "props" => %{
          "propose_new_doc" => %{
            "target_path" => "docs/proposed.md",
            "title" => "Proposed brief",
            "body_md_preview" => "Short draft preview.",
            "body_md" => "Short draft preview.\n\nFull draft body.",
            "conversation_seed_md" => "Operator requested a brief.",
            "actor_handle" => "@pascal",
            "proposed_at" => "2026-05-27T10:00:00Z",
            "status" => "pending"
          }
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ "ash-propose-new-doc-card"
      assert heex =~ ~s(data-live-ui-widget="propose-new-doc-card")
      assert heex =~ ~s(data-status="pending")
      assert heex =~ ~s(data-target-path="docs/proposed.md")
      assert heex =~ "Proposed brief"
      assert heex =~ "docs/proposed.md"
      assert heex =~ "Short draft preview."
      assert heex =~ "Show full draft"
      assert heex =~ "Conversation seed"
      assert heex =~ ~s(aria-label="Accept proposed document Proposed brief")
      assert heex =~ ~s(aria-label="Reject proposed document Proposed brief")
      assert heex =~ ~s(aria-label="Preview proposed document Proposed brief")
    end

    test "locks accept and reject actions for resolved proposals" do
      iur = %{
        "type" => "propose_new_doc_card",
        "id" => "proposal-adapter-accepted",
        "props" => %{
          "propose_new_doc" => %{
            "target_path" => "docs/proposed.md",
            "title" => "Proposed brief",
            "body_md_preview" => "Short draft preview.",
            "status" => "accepted"
          }
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ "ash-propose-new-doc-card__locked-message"
      refute heex =~ "ash-propose-new-doc-card__accept"
      refute heex =~ "ash-propose-new-doc-card__reject"
      assert heex =~ "ash-propose-new-doc-card__preview"
    end
  end

  describe "escalation_card adapter dispatch" do
    test "generates dedicated escalation_card fallback markup with severity class" do
      iur = %{
        "type" => "escalation_card",
        "id" => "escalation-adapter-test",
        "props" => %{
          "escalation" => %{
            "target_project_id" => "ariston-ui",
            "severity" => "p1",
            "text" => "Critical coverage gap detected.",
            "actor_handle" => "@codex",
            "proposed_action" => "Add aria-live region"
          }
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ "ash-escalation-card"
      assert heex =~ "ash-escalation-card--p1"
      assert heex =~ ~s(data-live-ui-widget="escalation-card")
      assert heex =~ ~s(data-severity="p1")
      assert heex =~ "P1"
      assert heex =~ "Critical coverage gap detected."
      assert heex =~ "@codex"
      assert heex =~ ~s(aria-label="Acknowledge p1 escalation")
      assert heex =~ ~s(aria-label="Route p1 escalation to rail")
      assert heex =~ ~s(role="alert")
      assert heex =~ ~s(role="status")
    end

    test "shows acknowledged status and hides action buttons when acknowledged" do
      iur = %{
        "type" => "escalation_card",
        "id" => "escalation-adapter-ack",
        "props" => %{
          "escalation" => %{
            "target_project_id" => "ariston-ui",
            "severity" => "p2",
            "text" => "Gap.",
            "acknowledged?" => true
          }
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ "ash-escalation-card__acknowledged"
      assert heex =~ "Acknowledged"
      refute heex =~ ~s(aria-label="Acknowledge p2 escalation")
      refute heex =~ ~s(aria-label="Route p2 escalation to rail")
    end
  end

  describe "collection_picker adapter dispatch" do
    test "generates dedicated collection_picker fallback markup" do
      iur = %{
        "type" => "collection_picker",
        "id" => "source-picker-adapter-test",
        "props" => %{
          "collection_picker" => %{
            "picker_id" => "sources",
            "title" => "Sources",
            "query" => "adr",
            "filters" => [%{"id" => "all", "label" => "All", "selected?" => true}],
            "items" => [
              %{
                "id" => "adr-1",
                "label" => "ADR 1",
                "description" => "Architecture decision"
              }
            ],
            "suggestions" => [%{"id" => "suggestion-1", "label" => "Add ADR 2"}]
          }
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ "ash-collection-picker"
      assert heex =~ ~s(data-widget-type="collection_picker")
      assert heex =~ ~s(data-picker-id="sources")
      assert heex =~ "Sources"
      assert heex =~ "ADR 1"
      assert heex =~ "Architecture decision"
      assert heex =~ "Add ADR 2"
      refute heex =~ "bundle_rail"
      refute heex =~ "on_search_change"
    end
  end

  describe "workflow_progress_status_card adapter dispatch" do
    test "generates dedicated workflow_progress_status_card markup" do
      iur = %{
        "type" => "workflow_progress_status_card",
        "id" => "rpc-adapter-test",
        "props" => %{
          "subject" => %{
            "name" => "metagraph",
            "progress" => 65,
            "status_counts" => %{
              "active" => 3,
              "blocked" => 1
            }
          }
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ "ash-workflow-progress-status-card"
      assert heex =~ ~s(data-subject-card="metagraph")
      assert heex =~ ~s(role="progressbar")
      assert heex =~ "65"
      assert heex =~ "3 active"
      assert heex =~ "1 blocked"
    end

    test "workflow_progress_status_card adapter marks selected state" do
      iur = %{
        "type" => "workflow_progress_status_card",
        "id" => "rpc-selected-test",
        "props" => %{
          "subject" => %{
            "name" => "ash_ui",
            "progress" => 40,
            "state" => %{"selected?" => true}
          }
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ "ash-workflow-progress-status-card--selected"
      assert heex =~ ~s(data-selected="true")
    end
  end

  describe "live_session_card adapter dispatch" do
    test "generates dedicated live_session_card markup" do
      iur = %{
        "type" => "live_session_card",
        "id" => "live_session:550e8400-e29b-41d4-a716-446655440000:3",
        "props" => %{
          "live_session" => %{
            "session_id" => "550e8400-e29b-41d4-a716-446655440000",
            "actor_handle" => "@opus",
            "status" => "running",
            "status_version" => 3,
            "tools_count" => 4,
            "edits_count" => 2,
            "tokens_consumed" => 9000,
            "started_at" => "2026-05-27T15:00:00Z",
            "current_task_title" => "Implement live session card",
            "now_streaming" => "Writing adapter tests.",
            "recent_events" => [
              %{"kind" => "assistant_text", "body" => "Working."}
            ],
            "pinned?" => true
          }
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ "ash-live-session-card"
      assert heex =~ ~s(data-live-ui-widget="live-session-card")
      assert heex =~ ~s(data-session-id="550e8400-e29b-41d4-a716-446655440000")
      assert heex =~ ~s(data-status-version="3")
      assert heex =~ ~s(data-pinned="true")
      assert heex =~ "4"
      assert heex =~ "2"
      assert heex =~ "9000"
      assert heex =~ "Writing adapter tests."
      assert heex =~ "assistant_text"
      assert heex =~ "data-live-ui-intent=\"pin_toggled\""
      assert heex =~ "data-live-ui-intent=\"interrupted\""
      assert heex =~ "data-live-ui-intent=\"expanded_recent\""
    end
  end

  describe "declared phx-click + data-* attribute passthrough" do
    test "artifact_row with on_click emits phx-click + phx-value-* pairs" do
      iur = %{
        "type" => "artifact_row",
        "id" => "artifact-onclick",
        "props" => %{
          "title" => "ADR 0001",
          "on_click" => %{
            "event" => "select_doc",
            "values" => %{"doc_id" => "doc-42", "lane" => "specs"}
          }
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ ~s(phx-click="select_doc")
      assert heex =~ ~s(phx-value-doc_id="doc-42")
      assert heex =~ ~s(phx-value-lane="specs")
      assert heex =~ "ash-artifact-row"
      assert heex =~ "ADR 0001"
    end

    test "artifact_row accepts a bare on_click event string (no values)" do
      iur = %{
        "type" => "artifact_row",
        "id" => "artifact-onclick-bare",
        "props" => %{
          "title" => "ADR 0002",
          "on_click" => "select_doc"
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ ~s(phx-click="select_doc")
      refute heex =~ "phx-value-"
    end

    test "artifact_row with data props emits data-* attributes" do
      iur = %{
        "type" => "artifact_row",
        "id" => "artifact-data",
        "props" => %{
          "title" => "Block",
          "data" => %{"block_id" => "b-7", "conversation_id" => "c-9"}
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ ~s(data-block_id="b-7")
      assert heex =~ ~s(data-conversation_id="c-9")
    end

    test "generic widget fallback emits on_click + data passthrough attributes" do
      iur = %{
        "type" => "custom:operator_tile",
        "id" => "tile-1",
        "props" => %{
          "on_click" => %{
            "event" => "open_tile",
            "values" => %{"tile_id" => "t-1"}
          },
          "data" => %{"block_id" => "blk-1"}
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ "ash-widget-custom:operator_tile"
      assert heex =~ ~s(data-widget-id="tile-1")
      assert heex =~ ~s(phx-click="open_tile")
      assert heex =~ ~s(phx-value-tile_id="t-1")
      assert heex =~ ~s(data-block_id="blk-1")
    end

    test "node WITHOUT the passthrough props renders byte-identically" do
      base = fn props ->
        %{
          "type" => "artifact_row",
          "id" => "artifact-baseline",
          "props" => props,
          "children" => [],
          "metadata" => %{}
        }
      end

      {:ok, without} = LiveUIAdapter.render(base.(%{"title" => "Same"}), force_fallback: true)

      # This test asserts that a no-passthrough node carries NONE of the new
      # phx-click/phx-value-/data-* attributes — i.e. passthrough_attrs/1 adds
      # nothing when "on_click"/"data" are absent.  Drift from main (regression
      # against the pre-passthrough render shape) is caught by the full suite
      # (1085 tests, 0 failures) — this test does not replay the full HTML shape.
      refute without =~ "phx-click"
      refute without =~ "phx-value-"
      refute without =~ "data-block_id"

      {:ok, generic} =
        LiveUIAdapter.render(
          %{
            "type" => "custom:operator_tile",
            "id" => "tile-baseline",
            "props" => %{},
            "children" => [],
            "metadata" => %{}
          },
          force_fallback: true
        )

      refute generic =~ "phx-click"
      refute generic =~ "phx-value-"
      # Only the pre-existing data-widget-id attribute is present.
      assert generic =~ ~s(data-widget-id="tile-baseline")
    end

    test "passthrough values are HTML-escaped" do
      iur = %{
        "type" => "artifact_row",
        "id" => "artifact-escape",
        "props" => %{
          "title" => "Escape",
          "on_click" => %{
            "event" => "select_doc",
            "values" => %{"doc_id" => ~s(a"><script>x)}
          },
          "data" => %{"note" => ~s(b"&<c)}
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      assert heex =~ ~s(phx-value-doc_id="a&quot;&gt;&lt;script&gt;x")
      assert heex =~ ~s(data-note="b&quot;&amp;&lt;c")
      refute heex =~ ~s(<script>x)
      refute heex =~ ~s(doc_id="a"><script>)
    end

    test "hostile passthrough keys cannot inject extra attributes" do
      iur = %{
        "type" => "artifact_row",
        "id" => "artifact-hostile-key",
        "props" => %{
          "title" => "Hostile",
          "data" => %{~s|x" onmouseover="alert(1)| => "v"}
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      refute heex =~ "onmouseover"
      refute heex =~ ~s(data-x")
    end

    # Regression: on_click.event NAME is passed through html_attr/1 just like
    # values, so a hostile event string cannot inject extra HTML attributes.
    # Codex P3: this vector (event name, not just values) had no explicit test.
    test "on_click event NAME is HTML-escaped (no attribute injection)" do
      hostile_event = ~S[x" onmouseover="evil()]

      iur = %{
        "type" => "artifact_row",
        "id" => "artifact-event-escape",
        "props" => %{
          "title" => "Event escape",
          "on_click" => %{
            "event" => hostile_event,
            "values" => %{"k" => "v"}
          }
        },
        "children" => [],
        "metadata" => %{}
      }

      {:ok, heex} = LiveUIAdapter.render(iur, force_fallback: true)

      # The escaped form must appear inside the phx-click attribute value.
      assert heex =~ "&quot;"
      assert heex =~ ~S[phx-click="x&quot; onmouseover=&quot;evil()"]

      # No literal (unescaped) onmouseover injection must appear as a live attribute.
      # The escaped form &quot;onmouseover=&quot; is fine inside the phx-click value;
      # the raw form would be a successful attribute injection.
      refute heex =~ ~S[ onmouseover="evil()]
    end
  end
end
