defmodule AshUI.Runtime.BindingEvaluatorTest do
  use ExUnit.Case, async: true

  alias AshUI.Runtime.BindingEvaluator

  describe "evaluate/3" do
    setup do
      context = %{
        user_id: "user-123",
        params: %{"screen_id" => "screen-1"},
        assigns: %{}
      }

      %{context: context}
    end

    test "evaluates field binding successfully", %{context: context} do
      binding = %{
        source: %{"resource" => "User", "field" => "name"},
        target: "input-name",
        binding_type: :value
      }

      assert {:ok, value} = BindingEvaluator.evaluate(binding, context)
      assert is_map(value) or is_binary(value)
    end

    test "applies default transformation", %{context: context} do
      binding = %{
        source: %{"resource" => "User", "field" => "nickname"},
        target: "input-nickname",
        binding_type: :value,
        transform: %{"function" => "default", "args" => ["Anonymous"]}
      }

      # When field is nil or empty, should return default
      assert {:ok, _value} = BindingEvaluator.evaluate(binding, context)
    end

    test "applies format transformation", %{context: context} do
      binding = %{
        source: %{"resource" => "User", "field" => "created_at"},
        target: "span-date",
        binding_type: :value,
        transform: %{"function" => "format"}
      }

      assert {:ok, _value} = BindingEvaluator.evaluate(binding, context)
    end
  end

  describe "evaluate_batch/3" do
    test "evaluates multiple bindings" do
      context = %{user_id: "user-123", params: %{}, assigns: %{}}

      bindings = [
        %{
          id: "binding-1",
          source: %{"resource" => "User", "field" => "name"},
          target: "name",
          binding_type: :value
        },
        %{
          id: "binding-2",
          source: %{"resource" => "User", "field" => "email"},
          target: "email",
          binding_type: :value
        }
      ]

      results = BindingEvaluator.evaluate_batch(bindings, context)

      assert Map.has_key?(results, "binding-1")
      assert Map.has_key?(results, "binding-2")
    end
  end

  describe "source path resolution" do
    test "resolves simple field path" do
      source = %{"resource" => "User", "field" => "name"}
      binding = %{source: source, target: "test", binding_type: :value}
      context = %{user_id: "user-123", params: %{}, assigns: %{}}

      assert {:ok, _value} = BindingEvaluator.evaluate(binding, context)
    end

    test "resolves relationship path" do
      source = %{"resource" => "User", "relationship" => "profile.name"}
      binding = %{source: source, target: "test", binding_type: :value}
      context = %{user_id: "user-123", params: %{}, assigns: %{}}

      assert {:ok, _value} = BindingEvaluator.evaluate(binding, context)
    end
  end
end
