defmodule AshUI.DSL.StorageTest do
  use ExUnit.Case, async: true

  alias AshUI.DSL.Storage

  describe "attribute_type/0" do
    test "returns :map type" do
      assert Storage.attribute_type() == :map
    end
  end

  describe "default/0" do
    test "returns default DSL structure" do
      dsl = Storage.default()

      assert dsl.type == "fragment"
      assert is_map(dsl.props)
      assert is_list(dsl.children)
      assert is_list(dsl.signals)
      assert is_map(dsl.metadata)
    end

    test "includes metadata with version and timestamp" do
      dsl = Storage.default()

      assert Map.has_key?(dsl.metadata, "version")
      assert Map.has_key?(dsl.metadata, "created_at")
    end
  end

  describe "validate_write/1" do
    test "returns :ok for valid DSL" do
      dsl = %{
        type: "row",
        props: %{},
        children: [],
        signals: [],
        metadata: %{}
      }

      assert Storage.validate_write(dsl) == :ok
    end

    test "returns errors for missing required fields" do
      dsl = %{
        type: "row",
        props: %{}
        # Missing children, signals
      }

      assert {:error, errors} = Storage.validate_write(dsl)
      assert length(errors) > 0
    end

    test "returns errors for invalid widget types" do
      dsl = %{
        type: "invalid_widget",
        props: %{},
        children: [],
        signals: [],
        metadata: %{}
      }

      assert {:error, errors} = Storage.validate_write(dsl)
      assert Enum.any?(errors, &String.contains?(&1, "Invalid widget types"))
    end
  end

  describe "valid_widget_type?/1" do
    test "returns true for valid layout types" do
      assert Storage.valid_widget_type?("row") == true
      assert Storage.valid_widget_type?("column") == true
      assert Storage.valid_widget_type?("grid") == true
      assert Storage.valid_widget_type?("stack") == true
      assert Storage.valid_widget_type?("fragment") == true
      assert Storage.valid_widget_type?("container") == true
    end

    test "returns true for valid widget types" do
      assert Storage.valid_widget_type?("text") == true
      assert Storage.valid_widget_type?("button") == true
      assert Storage.valid_widget_type?("input") == true
      assert Storage.valid_widget_type?("checkbox") == true
      assert Storage.valid_widget_type?("select") == true
      assert Storage.valid_widget_type?("image") == true
      assert Storage.valid_widget_type?("spacer") == true
    end

    test "returns true for custom widget types" do
      assert Storage.valid_widget_type?("custom:my_widget") == true
    end

    test "returns false for invalid widget types" do
      assert Storage.valid_widget_type?("invalid") == false
      assert Storage.valid_widget_type?("bad_widget") == false
    end
  end

  describe "widget_types/1" do
    test "returns all widget types in DSL" do
      dsl = %{
        type: "row",
        props: %{},
        children: [
          %{type: "text", props: %{}, children: [], signals: [], metadata: %{}},
          %{type: "button", props: %{}, children: [], signals: [], metadata: %{}}
        ],
        signals: [],
        metadata: %{}
      }

      types = Storage.widget_types(dsl)

      assert "row" in types
      assert "text" in types
      assert "button" in types
    end

    test "handles empty DSL" do
      dsl = Storage.default()
      types = Storage.widget_types(dsl)

      assert types == ["fragment"]
    end
  end

  describe "signal_references/1" do
    test "returns all signals in DSL" do
      signal = %{type: :bidirectional, target: "name", source: "User.name"}
      dsl = %{
        type: "row",
        props: %{},
        children: [
          %{
            type: "input",
            props: %{},
            children: [],
            signals: [signal],
            metadata: %{}
          }
        ],
        signals: [],
        metadata: %{}
      }

      signals = Storage.signal_references(dsl)

      assert length(signals) == 1
      assert hd(signals).type == :bidirectional
    end

    test "handles nested signals" do
      signal1 = %{type: :bidirectional, target: "name", source: "User.name"}
      signal2 = %{type: :event, target: "button", action: "save"}
      dsl = %{
        type: "row",
        props: %{},
        children: [
          %{
            type: "input",
            props: %{},
            children: [],
            signals: [signal1],
            metadata: %{}
          },
          %{
            type: "button",
            props: %{},
            children: [],
            signals: [signal2],
            metadata: %{}
          }
        ],
        signals: [],
        metadata: %{}
      }

      signals = Storage.signal_references(dsl)

      assert length(signals) == 2
    end
  end

  describe "put_metadata/2" do
    test "merges metadata into DSL" do
      dsl = Storage.default()
      dsl = Storage.put_metadata(dsl, %{screen_id: "screen-1"})

      assert dsl.metadata.screen_id == "screen-1"
    end

    test "updates existing metadata" do
      dsl = Storage.default()
      dsl = Storage.put_metadata(dsl, %{version: "2.0.0"})
      dsl = Storage.put_metadata(dsl, %{screen_id: "screen-1"})

      assert dsl.metadata.version == "2.0.0"
      assert dsl.metadata.screen_id == "screen-1"
    end
  end

  describe "get_metadata/1" do
    test "returns metadata from DSL" do
      dsl = Storage.default()
      dsl = Storage.put_metadata(dsl, %{custom: "value"})

      metadata = Storage.get_metadata(dsl)

      assert metadata.custom == "value"
    end

    test "returns empty map for DSL without metadata" do
      dsl = %{type: "row", props: %{}, children: [], signals: []}

      assert Storage.get_metadata(dsl) == %{}
    end
  end

  describe "increment_version/1" do
    test "increments DSL version" do
      dsl = Storage.default()
      dsl = Storage.increment_version(dsl)

      assert String.starts_with?(dsl.metadata.version, "1.0.")
      assert Map.has_key?(dsl.metadata, "updated_at")
    end
  end
end
