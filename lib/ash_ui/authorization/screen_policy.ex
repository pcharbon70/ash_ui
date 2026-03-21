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
  Check if user can read a specific screen.
  """
  def can_read?(user, screen) do
    cond do
      Policies.runtime_authorization_bypass?() -> true
      not Policies.resource_active?(screen) -> false
      not Policies.user_active(user) -> false
      Policies.user_role(user, :admin) -> true
      not Policies.role_allowed?(user, screen) -> false
      Policies.screen_owner(user, screen) -> true
      Policies.public_resource?(screen) -> true
      Policies.unrestricted_resource?(screen) -> true
      true -> false
    end
  end

  @doc """
  Check if user can mount a specific screen.
  """
  def can_mount?(user, screen) do
    can_read?(user, screen)
  end

  @doc """
  Check if user can manage a specific screen.
  """
  def can_manage?(user, screen) do
    cond do
      Policies.runtime_authorization_bypass?() -> true
      not Policies.user_active(user) -> false
      Policies.user_role(user, :admin) -> true
      not Policies.role_allowed?(user, screen) -> false
      Policies.screen_owner(user, screen) -> true
      Policies.unrestricted_resource?(screen) -> true
      true -> false
    end
  end
end
