defmodule AshUI.DSL.Element do
  @moduledoc """
  DSL extension for UI.Element resources.

  Provides the `ui_element` DSL block for element-specific configuration.
  """

  @doc """
  DSL section for element configuration.

  ## Options

  * `:type` - The widget type (button, input, text, image, etc.)
  * `:props` - Widget properties map
  * `:variants` - List of style variants

  ## Example

      ui_element do
        type :button
        props %{label: "Click Me", variant: :primary}
        variants [:large, :outline]
      end
  """
  def ui_element(opts \\ []) do
    opts
  end
end
