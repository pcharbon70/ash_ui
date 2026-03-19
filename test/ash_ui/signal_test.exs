defmodule AshUI.SignalTest do
  use ExUnit.Case, async: true

  alias AshUI.Signal

  describe "to_canonical/1" do
    test "converts value binding to bidirectional signal" do
      binding = %{
        source: %{"resource" => "User", "field" => "name"},
        target: "value",
        binding_type: :value
      }

      signal = Signal.to_canonical(binding)

      assert signal["type"] == "bidirectional"
      assert signal["source"]["resource"] == "User"
      assert signal["source"]["field"] == "name"
      assert signal["target"] == "value"
    end

    test "converts list binding to collection signal" do
      binding = %{
        source: %{"resource" => "Post", "relationship" => "comments"},
        target: "items",
        binding_type: :list
      }

      signal = Signal.to_canonical(binding)

      assert signal["type"] == "collection"
      assert signal["source"]["relationship"] == "comments"
    end

    test "converts action binding to event signal" do
      binding = %{
        source: %{"resource" => "User", "action" => "create"},
        target: "onClick",
        binding_type: :action
      }

      signal = Signal.to_canonical(binding)

      assert signal["type"] == "event"
      assert signal["source"]["action"] == "create"
    end

    test "handles string binding types" do
      binding = %{
        source: %{},
        target: "test",
        binding_type: "value"
      }

      signal = Signal.to_canonical(binding)

      assert signal["type"] == "bidirectional"
    end
  end

  describe "source resolution" do
    test "resolves field source path" do
      source = %{"resource" => "User", "field" => "email"}

      resolved = Signal.to_canonical(%{source: source, target: "test", binding_type: :value})

      assert resolved["source"]["type"] == "field"
      assert resolved["source"]["field"] == "email"
    end

    test "resolves action source path" do
      source = %{"resource" => "User", "action" => "login"}

      resolved = Signal.to_canonical(%{source: source, target: "test", binding_type: :action})

      assert resolved["source"]["type"] == "action"
      assert resolved["source"]["action"] == "login"
    end

    test "parses string source path" do
      binding = %{
        source: "User.name",
        target: "value",
        binding_type: :value
      }

      signal = Signal.to_canonical(binding)

      assert signal["source"]["type"] == "field"
      assert signal["source"]["resource"] == "User"
      assert signal["source"]["field"] == "name"
    end
  end

  describe "valid_source?/1" do
    test "returns true for valid resource reference" do
      source = %{"resource" => "User", "field" => "name"}

      assert Signal.valid_source?(source)
    end

    test "returns false for missing resource" do
      source = %{"field" => "name"}

      refute Signal.valid_source?(source)
    end

    test "returns false for empty resource" do
      source = %{"resource" => "", "field" => "name"}

      refute Signal.valid_source?(source)
    end
  end

  describe "apply_transform/2" do
    test "applies uppercase transformation" do
      assert Signal.apply_transform("hello", %{"function" => "uppercase"}) == "HELLO"
    end

    test "applies lowercase transformation" do
      assert Signal.apply_transform("HELLO", %{"function" => "lowercase"}) == "hello"
    end

    test "applies trim transformation" do
      assert Signal.apply_transform("  test  ", %{"function" => "trim"}) == "test"
    end

    test "applies default transformation for nil" do
      assert Signal.apply_transform(nil, %{"function" => "default", "args" => ["N/A"]}) == "N/A"
    end

    test "applies default transformation for empty string" do
      assert Signal.apply_transform("", %{"function" => "default", "args" => ["fallback"]}) ==
               "fallback"
    end

    test "does not apply default for present values" do
      assert Signal.apply_transform("value", %{"function" => "default", "args" => ["N/A"]}) ==
               "value"
    end
  end
end
