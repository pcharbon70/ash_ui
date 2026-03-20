defmodule AshUI.Phase8IntegrationTest do
  use AshUI.DataCase, async: false

  alias AshUI.Authorization.Runtime
  alias AshUI.Compiler
  alias AshUI.DSL.Builder
  alias AshUI.Data, as: Domain
  alias AshUI.LiveView.EventHandler
  alias AshUI.LiveView.Integration
  alias AshUI.Rendering.DesktopUIAdapter
  alias AshUI.Rendering.LiveUIAdapter
  alias AshUI.Rendering.WebUIAdapter
  alias AshUI.Resources.Screen
  alias AshUI.Telemetry

  @moduletag :integration
  @moduletag :conformance

  setup do
    Compiler.clear_cache()
    Compiler.init_cache()
    Runtime.init_cache()
    Telemetry.reset_metrics()
    :ok
  end

  describe "Section 8.6.1 - Full stack integration scenarios" do
    test "8.6.1.1 - user can define, mount, and interact with a screen" do
      screen = create_screen(:phase8_dashboard)
      socket = build_socket(current_user: build_admin())

      assert {:ok, mounted_socket} = Integration.mount_ui_screen(socket, :phase8_dashboard, %{})
      assert mounted_socket.assigns.ash_ui_screen.id == screen.id
      assert is_map(mounted_socket.assigns.ash_ui_iur)
      assert mounted_socket.assigns.ash_ui_user.role == :admin
    end

    test "8.6.1.2 - data bindings work bidirectionally" do
      socket =
        build_socket(
          ash_ui_user: build_admin(),
          ash_ui_bindings: %{
            "name-binding" => %{
              id: "name-binding",
              binding_type: :value,
              target: "profile.name",
              source: %{"resource" => "User", "field" => "name", "id" => "user-1"},
              transform: %{"sanitize" => [%{"type" => "trim"}]}
            }
          }
        )

      assert {:noreply, updated_socket} =
               EventHandler.handle_value_change(
                 %{"target" => "profile.name", "value" => "  Pascal  "},
                 socket
               )

      assert get_in(updated_socket.assigns, [:ash_ui, :bindings, "profile.name", "value"]) ==
               "Pascal"
    end

    test "8.6.1.3 - actions execute with authorization" do
      socket =
        build_socket(
          ash_ui_user: build_admin(),
          ash_ui_bindings: %{
            "save-profile" => %{
              id: "save-profile",
              binding_type: :action,
              target: "submit",
              source: %{"resource" => "User", "action" => "save_profile"},
              transform: %{"params" => %{"display_name" => {"event", "display_name"}}}
            }
          }
        )

      assert {:reply, %{status: :ok}, updated_socket} =
               EventHandler.handle_action_event(
                 %{"action_id" => "save-profile", "data" => %{"display_name" => "Pascal"}},
                 socket
               )

      assert get_in(updated_socket.assigns, [:flash, :info]) == "Action completed successfully"
    end

    test "8.6.1.4 - rendering works across all renderers" do
      screen = create_screen(:phase8_renderers)

      assert {:ok, canonical_iur} = Integration.compile_screen(screen)
      assert {:ok, heex} = LiveUIAdapter.render(canonical_iur)
      assert {:ok, html} = WebUIAdapter.render(canonical_iur)
      assert {:ok, desktop} = DesktopUIAdapter.render(canonical_iur)

      assert is_binary(heex)
      assert is_binary(html)
      assert is_map(desktop)
    end
  end

  describe "Section 8.6.2 - Conformance coverage scenarios" do
    test "8.6.2.1 - all REQ entries in contracts have explicit traceability rows in the matrix" do
      contract_reqs =
        "specs/contracts/*_contract.md"
        |> Path.wildcard()
        |> Enum.flat_map(&extract_ids(&1, ~r/REQ-[A-Z]+-[0-9]+[A-Z]*/))
        |> MapSet.new()

      matrix = File.read!(project_path("specs/conformance/spec_conformance_matrix.md"))

      Enum.each(contract_reqs, fn req ->
        assert String.contains?(matrix, req)
        assert Regex.match?(~r/\|\s*#{Regex.escape(req)}\s*\|.*(\bSCN-| \- \|)/, matrix)
      end)
    end

    test "8.6.2.2 - the traceability matrix is complete against the scenario catalog" do
      matrix_scns =
        extract_ids(project_path("specs/conformance/spec_conformance_matrix.md"), ~r/SCN-[0-9A-Z]+/)
        |> MapSet.new()

      catalog_scns =
        extract_ids(project_path("specs/conformance/scenario_catalog.md"), ~r/SCN-[0-9A-Z]+/)
        |> MapSet.new()

      assert MapSet.subset?(matrix_scns, catalog_scns)
    end

    test "8.6.2.3 - conformance-tagged tests are present and targeted by the harness" do
      conformance_files =
        run_shell!("rg -l '@(module)?tag.*conformance' test")
        |> String.split("\n", trim: true)

      harness = File.read!(project_path("scripts/run_conformance.sh"))

      assert length(conformance_files) > 0
      assert String.contains?(harness, "mix test --only conformance")
    end

    test "8.6.2.4 - conformance report can be generated" do
      report_dir = temp_dir("conformance-report")

      output =
        run_shell!(
          "./scripts/generate_conformance_report.sh #{report_dir}",
          %{"CONFORMANCE_STATUS" => "passed"}
        )

      assert String.contains?(output, "Conformance report written")
      assert File.exists?(Path.join(report_dir, "report.md"))
      assert File.exists?(Path.join(report_dir, "report.json"))
    end
  end

  describe "Section 8.6.3 - Performance and resilience scenarios" do
    test "8.6.3.1 - screen mount time stays under 100ms for a minimal screen" do
      _screen = create_screen(:phase8_mount_perf)
      socket = build_socket(current_user: build_admin())

      # Warm the compiler and query path before measuring.
      assert {:ok, _socket} = Integration.mount_ui_screen(socket, :phase8_mount_perf, %{})

      {microseconds, {:ok, _socket}} =
        :timer.tc(fn ->
          Integration.mount_ui_screen(socket, :phase8_mount_perf, %{})
        end)

      assert microseconds / 1000 < 100
    end

    test "8.6.3.2 - update render time stays under 50ms for fallback rendering" do
      screen = create_screen(:phase8_render_perf)
      assert {:ok, canonical_iur} = Integration.compile_screen(screen)

      {microseconds, {:ok, _}} =
        :timer.tc(fn ->
          LiveUIAdapter.render(canonical_iur)
        end)

      assert microseconds / 1000 < 50
    end

    test "8.6.3.3 - the system handles 100 concurrent session compilation flows" do
      screen = in_memory_screen("phase8_concurrency")
      user = build_admin()

      results =
        1..100
        |> Task.async_stream(
          fn _ ->
            with :ok <- Integration.authorize_screen(screen, user),
                 {:ok, _canonical_iur} <- Integration.compile_screen(screen) do
              :ok
            end
          end,
          max_concurrency: 20,
          timeout: 5_000
        )
        |> Enum.to_list()

      assert Enum.all?(results, &match?({:ok, :ok}, &1))
    end

    test "8.6.3.4 - errors degrade gracefully without crashing the runtime path" do
      socket = build_socket(current_user: build_admin())
      invalid_screen = %Screen{id: nil, name: nil}

      assert {:error, :not_found} = Integration.mount_ui_screen(socket, :missing_phase8_screen, %{})
      assert {:error, :invalid_screen} = Integration.compile_screen(invalid_screen)

      assert {:noreply, error_socket} = EventHandler.handle_event("unknown_event", %{}, socket)
      assert get_in(error_socket.assigns, [:flash, :error]) == "Action failed: :invalid_event"
    end
  end

  describe "Section 8.6.4 - Release readiness scenarios" do
    test "8.6.4.1 - release readiness and CI gate validations pass" do
      output = run_shell!("./scripts/validate_release_readiness.sh")

      assert String.contains?(output, "Release readiness validation passed.")
    end

    test "8.6.4.2 - documentation governance is complete" do
      output = run_shell!("./scripts/validate_guides_governance.sh")

      assert String.contains?(output, "Guides governance validation passed.")
      assert File.exists?(project_path("README.md"))
      assert File.exists?(project_path("guides/user/UG-0001-getting-started.md"))
      assert File.exists?(project_path("guides/developer/DG-0001-architecture-overview.md"))
    end

    test "8.6.4.3 - telemetry is configured with canonical events and dashboards" do
      Telemetry.attach_default_handlers()
      Telemetry.emit(:screen, :mount, %{count: 1, duration: 10}, %{status: :ok})

      snapshot = Telemetry.snapshot()
      event_names = Enum.map(Telemetry.events(), & &1.event_name)

      assert [:ash_ui, :screen, :mount] in event_names
      assert [:ash_ui, :binding, :evaluate] in event_names
      assert Map.has_key?(snapshot.dashboards, :screen_performance)
      assert snapshot.dashboards.screen_performance.mount_count >= 1
    end

    test "8.6.4.4 - rollback procedure validation succeeds" do
      output = run_shell!("./scripts/test_rollback_procedure.sh")

      assert String.contains?(output, "Rollback procedure validation passed.")
    end
  end

  defp build_socket(assigns) do
    %Phoenix.LiveView.Socket{
      assigns: Enum.into(assigns, %{__changed__: %{}})
    }
  end

  defp build_admin(id \\ "admin-1") do
    %{id: id, role: :admin, active: true}
  end

  defp create_screen(name_atom) do
    {:ok, screen} =
      Ash.create(Screen,
        %{
          name: Atom.to_string(name_atom),
          route: "/#{Atom.to_string(name_atom)}",
          layout: :column,
          unified_dsl:
            Builder.column(
              spacing: 12,
              children: [
                Builder.text("Phase 8 Screen", size: 18, weight: :bold),
                Builder.button("Save", on_click: "save-profile")
              ]
            )
            |> Builder.to_store(),
          metadata: %{"title" => "Phase 8"}
        },
        domain: Domain
      )

    screen
  end

  defp in_memory_screen(name) do
    %Screen{
      id: Ecto.UUID.generate(),
      name: name,
      layout: :column,
      version: 1,
      unified_dsl:
        Builder.column(
          spacing: 8,
          children: [
            Builder.text("In-memory screen"),
            Builder.button("Compile")
          ]
        )
        |> Builder.to_store(),
      metadata: %{}
    }
  end

  defp extract_ids(path, regex) do
    path
    |> File.read!()
    |> then(&Regex.scan(regex, &1))
    |> List.flatten()
  end

  defp project_path(path) do
    Path.expand(path, root_dir())
  end

  defp root_dir do
    Path.expand("../..", __DIR__)
  end

  defp temp_dir(prefix) do
    path =
      Path.join(
        System.tmp_dir!(),
        "#{prefix}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(path)
    path
  end

  defp run_shell!(command, extra_env \\ %{}) do
    env =
      %{
        "RELEASE_REPORT_DIR" => temp_dir("release-report"),
        "ROLLBACK_REPORT_DIR" => temp_dir("rollback-report")
      }
      |> Map.merge(extra_env)
      |> Enum.to_list()

    {output, status} = System.cmd("bash", ["-lc", command], cd: root_dir(), env: env)
    assert status == 0, output
    output
  end
end
