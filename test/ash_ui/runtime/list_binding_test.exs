defmodule AshUI.Runtime.ListBindingTest do
  use ExUnit.Case, async: true

  alias AshUI.Runtime.ListBinding

  describe "load_collection/3" do
    setup do
      context = %{user_id: "user-1", params: %{}, assigns: %{}}

      binding = %{
        id: "list-binding-test",
        source: %{"resource" => "Post", "relationship" => "comments"},
        target: "comments-list",
        binding_type: :list
      }

      %{binding: binding, context: context}
    end

    test "loads collection with pagination", %{binding: binding, context: context} do
      assert {:ok, result} = ListBinding.load_collection(binding, context, page: 1, page_size: 20)

      assert is_list(result.items)
      assert result.total > 0
      assert result.page == 1
      assert result.page_size == 20
    end

    test "handles empty collections", %{binding: binding, context: context} do
      assert {:ok, result} = ListBinding.load_collection(binding, context, page: 999, page_size: 20)

      assert result.items == []
      assert result.has_next == false
    end
  end

  describe "handle_collection_change/5" do
    setup do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{ash_ui: %{}}
      }

      binding = %{
        id: "list-change-test",
        source: %{"resource" => "Post", "relationship" => "comments"},
        target: "comments-list",
        binding_type: :list
      }

      context = %{user_id: "user-1", params: %{}, assigns: %{}}

      %{binding: binding, context: context, socket: socket}
    end

    test "handles insert changes", %{binding: binding, context: context, socket: socket} do
      change_data = %{"id" => "comment-123", "content" => "New comment"}

      assert {:ok, updated_socket, should_update} =
               ListBinding.handle_collection_change(binding, :insert, change_data, socket, context)

      assert updated_socket.assigns != %{}
      assert should_update == true
    end

    test "handles update changes", %{binding: binding, context: context, socket: socket} do
      change_data = %{"id" => "comment-123", "content" => "Updated"}

      assert {:ok, updated_socket, should_update} =
               ListBinding.handle_collection_change(binding, :update, change_data, socket, context)

      assert updated_socket.assigns != %{}
      assert should_update == true
    end

    test "handles delete changes", %{binding: binding, context: context, socket: socket} do
      change_data = %{"id" => "comment-123"}

      assert {:ok, updated_socket, should_update} =
               ListBinding.handle_collection_change(binding, :delete, change_data, socket, context)

      assert updated_socket.assigns != %{}
      assert should_update == true
    end
  end
end
