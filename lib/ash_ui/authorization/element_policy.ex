defmodule AshUI.Authorization.ElementPolicy do
  @moduledoc """
  Policy definitions for AshUI.Element resource.

  Defines access control for element visibility and modification.
  """

  alias AshUI.Authorization.Policies

  @doc """
  Defines policies for element resource access.
  """
  def policies do
    [
      %Ash.Policy.Policy{description: "Elements are visible if parent screen is accessible", policies: []},
      %Ash.Policy.Policy{description: "Can create elements if can modify parent screen", policies: []},
      %Ash.Policy.Policy{description: "Can update elements if can modify parent screen", policies: []},
      %Ash.Policy.Policy{description: "Can delete elements if can modify parent screen", policies: []},
      %Ash.Policy.Policy{description: "Respects element visibility conditions", policies: []}
    ]
  end

  @doc """
  Check if element should be visible to user.
  """
  def visible?(user, element) do
    cond do
      Policies.runtime_authorization_bypass?() -> true

      # Admins see all elements
      Policies.user_role(user, :admin) -> true

      # User must be active
      not Policies.user_active(user) -> false

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

      # Check if element is explicitly read-only
      Map.get(element, :read_only, false) -> false

      # Must own parent screen
      not screen_owned?(user, element) -> false

      # Default editable
      true -> true
    end
  end

  # Private functions

  defp screen_accessible?(user, element) do
    # In production, would check if user can access parent screen
    true
  end

  defp screen_owned?(user, element) do
    # In production, would check if user owns parent screen
    true
  end

  defp element_visible?(element) do
    # Check if element has visibility condition
    case Map.get(element, :visible_when) do
      nil -> true
      condition when is_function(condition, 0) -> condition.()
      condition when is_boolean(condition) -> condition
      _ -> true
    end
  end

  defp meets_visibility_condition?(element, user) do
    case Map.get(element, :visible_when) do
      nil -> true
      {field, value} ->
        # Check user field matches required value
        Map.get(user, field) == value
      condition when is_function(condition, 1) -> condition.(user)
      _ -> true
    end
  end
end
