defmodule AshUI.Runtime.BidirectionalBindingTest do
  use ExUnit.Case, async: true

  require Ash.Query

  alias AshUI.Runtime.BidirectionalBinding
  alias AshUI.Test.RuntimeDomain
  alias AshUI.Test.RuntimeFixtures
  alias AshUI.Test.User

  describe "read_binding/3" do
    test "reads binding value and updates socket assigns" do
      fixtures = RuntimeFixtures.seed!()
      socket = RuntimeFixtures.socket()

      binding = %{
        id: "binding-read-test",
        source: %{"resource" => "User", "field" => "name", "id" => fixtures.user.id},
        target: "name-input",
        binding_type: :value
      }

      context = RuntimeFixtures.context(fixtures)

      assert {:ok, updated_socket} = BidirectionalBinding.read_binding(binding, socket, context)
      assert get_in(updated_socket.assigns, [:ash_ui, :bindings, "name-input", "value"]) == "Pascal"
    end
  end

  describe "write_binding/4" do
    setup do
      fixtures = RuntimeFixtures.seed!()

      %{
        fixtures: fixtures,
        socket: RuntimeFixtures.socket(),
        context: RuntimeFixtures.context(fixtures)
      }
    end

    test "writes sanitized user input back to the Ash resource", %{
      fixtures: fixtures,
      socket: socket,
      context: context
    } do
      binding = %{
        id: "binding-write-test",
        source: %{"resource" => "User", "field" => "name", "id" => fixtures.user.id},
        target: "name-input",
        binding_type: :value,
        transform: %{"sanitize" => [%{"type" => "trim"}]}
      }

      assert {:ok, updated_socket, result} =
               BidirectionalBinding.write_binding(binding, "  Updated Name  ", socket, context)

      assert result.status == :ok
      assert result.value == "Updated Name"
      assert get_in(updated_socket.assigns, [:ash_ui, :bindings, "name-input", "value"]) == "Updated Name"

      query = Ash.Query.filter(User, id == ^fixtures.user.id)

      assert {:ok, updated_user} = Ash.read_one(query, domain: RuntimeDomain)
      assert updated_user.name == "Updated Name"
    end

    test "validates input before writing", %{fixtures: fixtures, socket: socket, context: context} do
      binding = %{
        id: "binding-validate-test",
        source: %{"resource" => "User", "field" => "email", "id" => fixtures.user.id},
        target: "email-input",
        binding_type: :value,
        transform: %{"validate" => [%{"type" => "required"}]}
      }

      assert {:error, :required, error_socket} =
               BidirectionalBinding.write_binding(binding, "", socket, context)

      assert get_in(error_socket.assigns, [:ash_ui, :bindings, "email-input", "error"]) == :required
    end
  end

  describe "subscribe_binding/3" do
    test "subscribes to resource changes" do
      fixtures = RuntimeFixtures.seed!()
      socket = RuntimeFixtures.socket()

      binding = %{
        id: "binding-subscribe-test",
        source: %{"resource" => "User", "field" => "name", "id" => fixtures.user.id},
        target: "name-input",
        binding_type: :value
      }

      context = RuntimeFixtures.context(fixtures)

      assert {:ok, updated_socket} = BidirectionalBinding.subscribe_binding(binding, socket, context)

      subscriptions = get_in(updated_socket.assigns, [:ash_ui, :subscriptions])
      assert is_map(subscriptions)
      assert map_size(subscriptions) == 1
    end
  end
end
