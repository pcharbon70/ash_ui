defmodule AshUI.ConformanceTraceabilityTest do
  use ExUnit.Case, async: true

  @moduletag :conformance

  @catalog_path "/Users/Pascal/code/ash/ash_ui/specs/conformance/scenario_catalog.md"
  @matrix_path "/Users/Pascal/code/ash/ash_ui/specs/conformance/spec_conformance_matrix.md"
  @traceability_path "/Users/Pascal/code/ash/ash_ui/specs/conformance/scenario_test_matrix.md"

  test "every catalog scenario has explicit test traceability" do
    catalog_scenarios =
      @catalog_path
      |> File.read!()
      |> extract_heading_ids()
      |> MapSet.new()

    traceability_scenarios =
      scenario_rows()
      |> Map.keys()
      |> MapSet.new()

    assert MapSet.equal?(catalog_scenarios, traceability_scenarios)
  end

  test "every matrix scenario is backed by traced conformance tests" do
    traced_scenarios = Map.keys(scenario_rows()) |> MapSet.new()

    matrix_scenarios =
      @matrix_path
      |> File.read!()
      |> extract_table_ids()
      |> MapSet.new()

    assert MapSet.subset?(matrix_scenarios, traced_scenarios)
  end

  test "every traced test file exists and is tagged for the conformance harness" do
    Enum.each(scenario_rows(), fn {_scenario, files} ->
      Enum.each(files, fn file ->
        absolute = Path.expand(file, "/Users/Pascal/code/ash/ash_ui")

        assert File.exists?(absolute)
        body = File.read!(absolute)
        assert body =~ "@moduletag :conformance"
      end)
    end)
  end

  defp scenario_rows do
    @traceability_path
    |> File.read!()
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case Regex.run(~r/^\|\s*(SCN-[0-9A-Z]+)\s*\|\s*[^|]+\|\s*([^|]+?)\s*\|$/, line) do
        [_, scenario, files] ->
          parsed_files =
            files
            |> String.split(",", trim: true)
            |> Enum.map(&String.trim/1)

          Map.put(acc, scenario, parsed_files)

        _ ->
          acc
      end
    end)
  end

  defp extract_heading_ids(body) do
    Regex.scan(~r/^####\s+(SCN-[0-9A-Z]+):/m, body, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
  end

  defp extract_table_ids(body) do
    Regex.scan(~r/^\|\s*(SCN-[0-9A-Z]+)\s*\|/m, body, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
  end
end
