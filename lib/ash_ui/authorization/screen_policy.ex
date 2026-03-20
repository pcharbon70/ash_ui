defmodule AshUI.Authorization.ScreenPolicy do
  @moduledoc """
  Policy definitions for AshUI.Screen resource.

  Defines access control for screen viewing, mounting, and management.
  """

  alias AshUI.Authorization.Policies

  @doc """
  Defines policies for screen resource access.
  """
  def policies do
    [
      %Ash.Policy.Policy{description: "Users can view screens they have access to", policies: []},
      %Ash.Policy.Policy{description: "Users can mount screens they have access to", policies: []},
      %Ash.Policy.Policy{description: "Only admins can create screens", policies: []},
      %Ash.Policy.Policy{description: "Owners and admins can update screens", policies: []},
      %Ash.Policy.Policy{description: "Owners and admins can delete screens", policies: []}
    ]
  end

  @doc """
  Filter screens based on user access.
  """
  def filter_screens(user) do
    base_filter = [active: true]

    user_filter =
      case user do
        %{role: :admin} -> []
        %{id: user_id} -> [or: [[public: true], [owner_id: user_id]]]
        _ -> [public: true]
      end

    base_filter ++ user_filter
  end

  @doc """
  Check if user can mount a specific screen.
  """
  def can_mount?(user, screen) do
    cond do
      Policies.runtime_authorization_bypass?() -> true

      not Policies.user_active(user) -> false

      # Admins can mount any screen
      Policies.user_role(user, :admin) -> true

      # Public screens can be mounted by active users
      Map.get(screen, :public, false) -> true

      # Owners can mount their screens
      Policies.screen_owner(user, screen) -> true

      # Default deny
      true -> false
    end
  end
end
