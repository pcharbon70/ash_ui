defmodule AshUI.Authorization.ElementPolicy do
  @moduledoc """
  Policy definitions for AshUI.Element resource.

  Defines access control for element visibility and modification.
  """

  alias AshUI.Authorization.Policies
  alias AshUI.Authorization.ScreenPolicy

  @doc """
  Defines policies for element resource access.
  """
  def policies do
    [
      %Ash.Policy.Policy{
        description: "Elements are visible if parent screen is accessible",
        policies: []
      },
      %Ash.Policy.Policy{
        description: "Can create elements if can modify parent screen",
        policies: []
      },
      %Ash.Policy.Policy{
        description: "Can update elements if can modify parent screen",
        policies: []
      },
      %Ash.Policy.Policy{
        description: "Can delete elements if can modify parent screen",
        policies: []
      },
      %Ash.Policy.Policy{description: "Respects element visibility conditions", policies: []}
    ]
  end

  def can_read?(user, element), do: visible?(user, element)
  def can_manage?(user, element), do: editable?(user, element)

  @doc """
  Check if element should be visible to user.
  """
  def visible?(user, element) do
    cond do
      Policies.runtime_authorization_bypass?() -> true
      not Policies.resource_active?(element) -> false
      # Admins see all elements
      Policies.user_role(user, :admin) -> true
      # User must be active
      not Policies.user_active(user) -> false
      not Policies.role_allowed?(user, element) -> false
      # Check element visibility conditions
      not meets_visibility_condition?(element, user) -> false
      # Check parent screen access
      not screen_accessible?(user, element) -> false
      # Default visible
      true -> true
    end
  end

  @doc """
  Check if element is editable by user.
  """
  def editable?(user, element) do
    cond do
      Policies.runtime_authorization_bypass?() -> true
      # Admins can edit all elements
      Policies.user_role(user, :admin) -> true
      # User must be active
      not Policies.user_active(user) -> false
      not Policies.role_allowed?(user, element) -> false
      # Check if element is explicitly read-only
      read_only?(element) -> false
      # Must own parent screen
      not screen_owned?(user, element) -> false
      # Default editable
      true -> true
    end
  end

  # Private functions

  defp screen_accessible?(user, element) do
    case loaded_screen(element) do
      %{} = screen -> ScreenPolicy.can_read?(user, screen)
      _ -> true
    end
  end

  defp screen_owned?(user, element) do
    case loaded_screen(element) do
      %{} = screen ->
        ScreenPolicy.can_manage?(user, screen)

      _ ->
        Policies.screen_owner(user, element) || Policies.unrestricted_resource?(element)
    end
  end

  defp loaded_screen(resource) do
    case Map.get(resource, :screen) || Map.get(resource, "screen") do
      %Ash.NotLoaded{} -> nil
      screen -> screen
    end
  end

  defp meets_visibility_condition?(element, user) do
    case Map.get(element, :visible_when) do
      nil ->
        true

      {field, value} ->
        # Check user field matches required value
        Map.get(user, field) == value

      condition when is_function(condition, 1) ->
        condition.(user)

      _ ->
        true
    end
  end

  defp read_only?(element) do
    Map.get(element, :read_only) || Map.get(element, "read_only") || false
  end
end
