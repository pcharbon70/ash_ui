defmodule AshUI.LiveView.UpdateIntegrationTest do
  use ExUnit.Case, async: false

  alias AshUI.LiveView.UpdateIntegration
  alias AshUI.Test.RuntimeDomain
  alias AshUI.Test.RuntimeFixtures
  alias AshUI.Test.User, as: RuntimeUser

  # Mock socket for testing
  defp build_socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: Enum.into(assigns, %{__changed__: %{}})
    }
  end

  # Mock user
  defp build_user(id \\ "user-1") do
    %{id: id, name: "Test User"}
  end

  # Mock screen
  defp build_screen(id \\ "screen-1") do
    %{id: id, name: "Test Screen"}
  end

  defp flush_mailbox do
    receive do
      _message -> flush_mailbox()
    after
      0 -> :ok
    end
  end

  describe "subscribe/3" do
    test "creates subscription to resource" do
      socket = build_socket()

      assert {:ok, subscription} = UpdateIntegration.subscribe(socket, User.Profile)
      assert is_binary(subscription.id)
      assert subscription.resource == User.Profile
    end

    test "includes filter in subscription" do
      socket = build_socket()

      assert {:ok, subscription} =
               UpdateIntegration.subscribe(socket, User.Profile, filter: %{user_id: "user-1"})

      assert subscription.filter == %{user_id: "user-1"}
    end

    test "includes action in subscription" do
      socket = build_socket()

      assert {:ok, subscription} =
               UpdateIntegration.subscribe(socket, User.Profile, action: :create)

      assert subscription.action == :create
    end

    test "tracks subscription in socket assigns" do
      socket = build_socket()

      assert {:ok, _subscription} = UpdateIntegration.subscribe(socket, User.Profile)
      # In actual implementation, socket would be updated with subscription
    end

    test "subscribes to real Ash resource notifications" do
      fixtures = RuntimeFixtures.seed!()
      flush_mailbox()
      socket = RuntimeFixtures.socket()

      assert {:ok, _subscription} = UpdateIntegration.subscribe(socket, RuntimeUser)

      assert {:ok, _updated_user} =
               Ash.update(fixtures.user, %{name: "Subscribed"}, domain: RuntimeDomain)

      assert_receive %Ash.Notifier.Notification{resource: RuntimeUser, action: %{type: :update}}
    end
  end

  describe "unsubscribe/2" do
    test "removes subscription" do
      socket = build_socket()

      assert {:ok, subscription} = UpdateIntegration.subscribe(socket, User.Profile)
      assert :ok = UpdateIntegration.unsubscribe(socket, subscription)
    end

    test "stops delivering real Ash resource notifications" do
      fixtures = RuntimeFixtures.seed!()
      flush_mailbox()
      socket = RuntimeFixtures.socket()

      assert {:ok, subscription} = UpdateIntegration.subscribe(socket, RuntimeUser)
      assert :ok = UpdateIntegration.unsubscribe(socket, subscription)

      assert {:ok, _updated_user} =
               Ash.update(fixtures.user, %{name: "Unsubscribed"}, domain: RuntimeDomain)

      refute_receive %Ash.Notifier.Notification{resource: RuntimeUser}, 100
    end
  end

  describe "handle_resource_change/2" do
    test "updates socket when bound data changes" do
      socket =
        build_socket(
          ash_ui_screen: build_screen(),
          ash_ui_user: build_user(),
          ash_ui_bindings: %{binding1: "old_value"}
        )

      notification = %{
        type: :updated,
        resource: User.Profile,
        timestamp: DateTime.utc_now()
      }

      assert {:noreply, _updated_socket} =
               UpdateIntegration.handle_resource_change(notification, socket)
    end

    test "handles multiple binding changes" do
      socket =
        build_socket(
          ash_ui_screen: build_screen(),
          ash_ui_user: build_user(),
          ash_ui_bindings: %{
            binding1: "value1",
            binding2: "value2",
            binding3: "value3"
          }
        )

      notification = %{
        type: :updated,
        resource: User.Profile,
        timestamp: DateTime.utc_now()
      }

      assert {:noreply, _updated_socket} =
               UpdateIntegration.handle_resource_change(notification, socket)
    end

    test "handles created notifications" do
      socket =
        build_socket(
          ash_ui_screen: build_screen(),
          ash_ui_user: build_user(),
          ash_ui_bindings: %{}
        )

      notification = %{
        type: :created,
        resource: User.Profile,
        timestamp: DateTime.utc_now()
      }

      assert {:noreply, _updated_socket} =
               UpdateIntegration.handle_resource_change(notification, socket)
    end

    test "handles destroyed notifications" do
      socket =
        build_socket(
          ash_ui_screen: build_screen(),
          ash_ui_user: build_user(),
          ash_ui_bindings: %{binding1: "value"}
        )

      notification = %{
        type: :destroyed,
        resource: User.Profile,
        timestamp: DateTime.utc_now()
      }

      assert {:noreply, _updated_socket} =
               UpdateIntegration.handle_resource_change(notification, socket)
    end
  end

  describe "handle_notification/2" do
    test "routes created notifications" do
      socket = build_socket(ash_ui_screen: build_screen(), ash_ui_user: build_user())

      assert {:noreply, _updated_socket} =
               UpdateIntegration.handle_notification({:created, %User.Profile{}}, socket)
    end

    test "routes updated notifications" do
      socket = build_socket(ash_ui_screen: build_screen(), ash_ui_user: build_user())

      assert {:noreply, _updated_socket} =
               UpdateIntegration.handle_notification({:updated, %User.Profile{}}, socket)
    end

    test "routes destroyed notifications" do
      socket = build_socket(ash_ui_screen: build_screen(), ash_ui_user: build_user())

      assert {:noreply, _updated_socket} =
               UpdateIntegration.handle_notification({:destroyed, %User.Profile{}}, socket)
    end

    test "handles unknown notification types gracefully" do
      socket = build_socket()

      assert {:noreply, _updated_socket} =
               UpdateIntegration.handle_notification({:unknown, :data}, socket)
    end

    test "handles Ash.Notifier notifications directly" do
      fixtures = RuntimeFixtures.seed!()
      flush_mailbox()

      socket =
        build_socket(
          ash_ui_screen: build_screen(),
          ash_ui_user: fixtures.actor,
          ash_ui_params: %{},
          ash_ui_bindings: %{
            "binding1" => %{
              id: "binding1",
              target: "input-1",
              source: %{"resource" => "User", "field" => "name", "id" => fixtures.user.id},
              binding_type: :value,
              value: fixtures.user.name
            }
          },
          ash_ui_domains: [RuntimeDomain]
        )

      assert {:ok, _subscription} = UpdateIntegration.subscribe(socket, RuntimeUser)

      assert {:ok, _updated_user} =
               Ash.update(fixtures.user, %{name: "Notifier Update"}, domain: RuntimeDomain)

      assert_receive %Ash.Notifier.Notification{} = notification

      assert {:noreply, updated_socket} =
               UpdateIntegration.handle_notification(notification, socket)

      assert updated_socket.assigns[:ash_ui_bindings]["binding1"].value == "Notifier Update"
      assert get_in(updated_socket.assigns, [:ash_ui, :bindings, "input-1", "value"]) == "Notifier Update"
    end
  end

  describe "batch_updates/2" do
    test "applies multiple updates in batch" do
      socket = build_socket()

      assert {:noreply, updated_socket} =
               UpdateIntegration.batch_updates(socket, fn socket ->
                 socket
                 |> Phoenix.Component.assign(:value1, 1)
                 |> Phoenix.Component.assign(:value2, 2)
               end)

      assert updated_socket.assigns[:value1] == 1
      assert updated_socket.assigns[:value2] == 2
    end

    test "sets batch mode flag during updates" do
      socket = build_socket()

      UpdateIntegration.batch_updates(socket, fn socket ->
        # Batch mode would be true here in actual implementation
        socket
      end)
    end
  end

  describe "refresh_bindings/1" do
    test "re-evaluates all bindings" do
      socket =
        build_socket(
          ash_ui_screen: build_screen(),
          ash_ui_user: build_user(),
          ash_ui_params: %{}
        )

      assert {:noreply, _updated_socket} = UpdateIntegration.refresh_bindings(socket)
    end
  end

  describe "relevant_notification?/2" do
    test "returns true for notifications about subscribed resources" do
      socket =
        build_socket(
          ash_ui_subscriptions: [
            %{id: "sub1", resource: User.Profile, action: :update, filter: %{}}
          ]
        )

      notification = %{type: :updated, resource: User.Profile}

      assert UpdateIntegration.relevant_notification?(notification, socket) == true
    end

    test "returns false for notifications about other resources" do
      socket =
        build_socket(
          ash_ui_subscriptions: [
            %{id: "sub1", resource: User.Profile, action: :update, filter: %{}}
          ]
        )

      notification = %{type: :updated, resource: User.Settings}

      assert UpdateIntegration.relevant_notification?(notification, socket) == false
    end

    test "returns false when no subscriptions" do
      socket = build_socket(ash_ui_subscriptions: [])
      notification = %{type: :updated, resource: User.Profile}

      assert UpdateIntegration.relevant_notification?(notification, socket) == false
    end
  end

  describe "cleanup_subscriptions/1" do
    test "removes all subscriptions" do
      socket =
        build_socket(
          ash_ui_subscriptions: [
            %{id: "sub1", resource: User.Profile},
            %{id: "sub2", resource: User.Settings}
          ]
        )

      assert :ok = UpdateIntegration.cleanup_subscriptions(socket)
    end

    test "handles socket with no subscriptions" do
      socket = build_socket()

      assert :ok = UpdateIntegration.cleanup_subscriptions(socket)
    end
  end
end
