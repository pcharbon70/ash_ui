defmodule AshUI.DSL.Screen do
  @moduledoc """
  DSL extension for UI.Screen resources.

  Provides the `ui_screen` DSL block for screen-specific configuration.
  """
  @doc """
  DSL section for screen configuration.

  ## Options

  * `:layout` - The layout type for the screen (default, bare, modal, panel)
  * `:route` - The route path for the screen
  * `:metadata` - Additional metadata map

  ## Example

      ui_screen do
        layout :dashboard
        route "/dashboard"
        metadata %{title: "Dashboard"}
      end
  """
  @spec [ @keyword [ {:name, :type} ] ]
        Ash.Dsl.Entity.entity?(...
  def ui_screen(opts \\ []) do
    # DSL implementation for screen configuration
    # This will be expanded to use Spark DSL
    opts
  end
end
