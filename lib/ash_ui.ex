defmodule AshUI do
  @moduledoc """
  AshUI is a declarative UI framework built on Ash Framework.

  It provides:
  - Database-driven UI definitions stored as Ash Resources
  - unified-ui DSL integration for UI components
  - Phoenix LiveView runtime integration
  - Policy-based authorization for UI access
  """

  @doc """
  Returns the Ash domain that owns the Ash UI resources.
  """
  def domain do
    AshUI.Domain
  end
end
