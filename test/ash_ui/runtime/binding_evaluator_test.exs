defmodule AshUI.Runtime.BindingEvaluatorTest do
  use ExUnit.Case, async: true

  alias AshUI.Runtime.BindingEvaluator
  alias AshUI.Test.RuntimeFixtures

  describe "evaluate/3" do
    setup do
      fixtures = RuntimeFixtures.seed!()
      context = RuntimeFixtures.context(fixtures)

      %{fixtures: fixtures, context: context}
    end

    test "evaluates field binding successfully", %{fixtures: fixtures, context: context} do
      binding = %{
        source: %{"resource" => "User", "field" => "name", "id" => fixtures.user.id},
        target: "input-name",
        binding_type: :value
      }

      assert {:ok, "Pascal"} = BindingEvaluator.evaluate(binding, context)
    end

    test "applies default transformation", %{fixtures: fixtures, context: context} do
      binding = %{
        source: %{"resource" => "User", "field" => "nickname", "id" => fixtures.user.id},
        target: "input-nickname",
        binding_type: :value,
        transform: %{"function" => "default", "args" => ["Anonymous"]}
      }

      assert {:ok, "Anonymous"} = BindingEvaluator.evaluate(binding, context)
    end

    test "applies format transformation", %{fixtures: fixtures, context: context} do
      binding = %{
        source: %{"resource" => "User", "field" => "created_at", "id" => fixtures.user.id},
        target: "span-date",
        binding_type: :value,
        transform: %{"function" => "format"}
      }

      assert {:ok, formatted} = BindingEvaluator.evaluate(binding, context)
      assert is_binary(formatted)
      assert String.contains?(formatted, "T")
    end
  end

  describe "evaluate_batch/3" do
    test "evaluates multiple bindings" do
      fixtures = RuntimeFixtures.seed!()
      context = RuntimeFixtures.context(fixtures)

      bindings = [
        %{
          id: "binding-1",
          source: %{"resource" => "User", "field" => "name", "id" => fixtures.user.id},
          target: "name",
          binding_type: :value
        },
        %{
          id: "binding-2",
          source: %{"resource" => "User", "field" => "email", "id" => fixtures.user.id},
          target: "email",
          binding_type: :value
        }
      ]

      results = BindingEvaluator.evaluate_batch(bindings, context)

      assert results["binding-1"] == {:ok, "Pascal"}
      assert results["binding-2"] == {:ok, "pascal@example.com"}
    end
  end

  describe "source path resolution" do
    setup do
      fixtures = RuntimeFixtures.seed!()
      context = RuntimeFixtures.context(fixtures)

      %{fixtures: fixtures, context: context}
    end

    test "resolves simple field path", %{fixtures: fixtures, context: context} do
      source = %{"resource" => "User", "field" => "name", "id" => fixtures.user.id}
      binding = %{source: source, target: "test", binding_type: :value}

      assert {:ok, "Pascal"} = BindingEvaluator.evaluate(binding, context)
    end

    test "resolves relationship path", %{fixtures: fixtures, context: context} do
      source = %{"resource" => "User", "relationship" => "profile.name", "id" => fixtures.user.id}
      binding = %{source: source, target: "test", binding_type: :value}

      assert {:ok, "Primary Profile"} = BindingEvaluator.evaluate(binding, context)
    end
  end
end
