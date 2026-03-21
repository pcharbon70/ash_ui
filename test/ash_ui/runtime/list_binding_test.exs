defmodule AshUI.Runtime.ListBindingTest do
  use ExUnit.Case, async: true

  alias AshUI.Runtime.ListBinding
  alias AshUI.Test.RuntimeFixtures

  @moduletag :conformance

  describe "load_collection/3" do
    setup do
      fixtures = RuntimeFixtures.seed!()

      binding = %{
        id: "list-binding-test",
        source: %{
          "resource" => "Post",
          "relationship" => "comments",
          "id" => fixtures.post.id
        },
        target: "comments-list",
        binding_type: :list
      }

      %{binding: binding, context: RuntimeFixtures.context(fixtures), fixtures: fixtures}
    end

    test "loads collection with pagination", %{binding: binding, context: context} do
      assert {:ok, result} = ListBinding.load_collection(binding, context, page: 1, page_size: 1)

      assert length(result.items) == 1
      assert result.total == 2
      assert result.page == 1
      assert result.page_size == 1
      assert result.has_next == true
      assert result.has_prev == false
    end

    test "handles empty pages past the end of the collection", %{
      binding: binding,
      context: context
    } do
      assert {:ok, result} = ListBinding.load_collection(binding, context, page: 3, page_size: 2)

      assert result.items == []
      assert result.total == 2
      assert result.has_next == false
    end
  end

  describe "handle_collection_change/5" do
    setup do
      fixtures = RuntimeFixtures.seed!()

      socket =
        RuntimeFixtures.socket(%{
          ash_ui: %{
            lists: %{
              "comments-list" => %{
                "items" => fixtures.comments,
                "total" => length(fixtures.comments)
              }
            }
          }
        })

      binding = %{
        id: "list-change-test",
        source: %{"resource" => "Post", "relationship" => "comments", "id" => fixtures.post.id},
        target: "comments-list",
        binding_type: :list
      }

      %{
        binding: binding,
        context: RuntimeFixtures.context(fixtures),
        socket: socket,
        fixtures: fixtures
      }
    end

    test "handles insert changes", %{binding: binding, socket: socket, context: context} do
      change_data = %{"id" => "comment-123", "content" => "New comment"}

      assert {:ok, updated_socket, true} =
               ListBinding.handle_collection_change(
                 binding,
                 :insert,
                 change_data,
                 socket,
                 context
               )

      assert get_in(updated_socket.assigns, [:ash_ui, :list_changes, "comments-list"]) == [
               {:insert, change_data}
             ]
    end

    test "handles update changes", %{
      binding: binding,
      socket: socket,
      context: context,
      fixtures: fixtures
    } do
      first_comment = hd(fixtures.comments)
      change_data = %{"id" => first_comment.id, "content" => "Updated"}

      assert {:ok, updated_socket, true} =
               ListBinding.handle_collection_change(
                 binding,
                 :update,
                 change_data,
                 socket,
                 context
               )

      updated_items = get_in(updated_socket.assigns, [:ash_ui, :lists, "comments-list", "items"])
      assert Enum.any?(updated_items, &(&1.id == first_comment.id and &1.content == "Updated"))
    end

    test "handles delete changes", %{
      binding: binding,
      socket: socket,
      context: context,
      fixtures: fixtures
    } do
      first_comment = hd(fixtures.comments)
      change_data = %{"id" => first_comment.id}

      assert {:ok, updated_socket, true} =
               ListBinding.handle_collection_change(
                 binding,
                 :delete,
                 change_data,
                 socket,
                 context
               )

      updated_items = get_in(updated_socket.assigns, [:ash_ui, :lists, "comments-list", "items"])

      refute Enum.any?(updated_items, &(&1.id == first_comment.id))
      assert get_in(updated_socket.assigns, [:ash_ui, :lists, "comments-list", "total"]) == 1
    end
  end
end
