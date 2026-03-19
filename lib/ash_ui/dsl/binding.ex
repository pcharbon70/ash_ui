defmodule AshUI.DSL.Binding do
  @moduledoc """
  DSL extension for UI.Binding resources.

  Provides the `ui_binding` DSL block for binding configuration.
  """

  @doc """
  DSL section for binding configuration.

  ## Options

  * `:source` - Ash resource path (e.g., "MyApp.Accounts.User.name")
  * `:target` - Element property path (e.g., "element.value")
  * `:binding_type` - Type of binding (:value, :list, :action)
  * `:transform` - Transformation rules map

  ## Example

      ui_binding do
        source "MyApp.Accounts.User.name"
        target "element.value"
        binding_type :value
        transform %{default: "Anonymous"}
      end
  """
  def ui_binding(opts \\ []) do
    opts
  end
end
