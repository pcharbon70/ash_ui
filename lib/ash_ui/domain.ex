defmodule AshUI.Domain do
  @moduledoc """
  AshUI domain containing all Ash UI resources.

  This domain defines the authorization and resource boundaries for the Ash UI system.
  """
  use Ash.Domain

  resources do
    resource AshUI.Resources.Screen
    resource AshUI.Resources.Element
    resource AshUI.Resources.Binding
  end
end
