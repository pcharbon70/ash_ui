defmodule BasicDashboard do
  @moduledoc """
  Minimal Ash UI example seed module.
  """

  alias AshUI.DSL.Builder
  alias AshUI.Domain
  alias AshUI.Resources.Binding
  alias AshUI.Resources.Element
  alias AshUI.Resources.Screen

  def seed! do
    {:ok, screen} =
      Domain.create(Screen,
        attrs: %{
          name: "basic_dashboard",
          route: "/dashboard",
          layout: :column,
          unified_dsl:
            Builder.column(
              spacing: 12,
              children: [
                Builder.text("Basic Dashboard", size: 24, weight: :bold),
                Builder.input("display_name", placeholder: "Enter your name", bind_to: "user-name"),
                Builder.button("Save", on_click: "save-profile")
              ]
            )
            |> Builder.to_store(),
          metadata: %{"title" => "Basic Dashboard"}
        }
      )

    {:ok, input} =
      Domain.create(Element,
        attrs: %{
          screen_id: screen.id,
          type: :textinput,
          props: %{"label" => "Display name"},
          position: 0
        }
      )

    {:ok, button} =
      Domain.create(Element,
        attrs: %{
          screen_id: screen.id,
          type: :button,
          props: %{"label" => "Save"},
          variants: [:primary],
          position: 1
        }
      )

    {:ok, _value_binding} =
      Domain.create(Binding,
        attrs: %{
          screen_id: screen.id,
          element_id: input.id,
          binding_type: :value,
          target: "value",
          source: %{"resource" => "User", "field" => "name", "id" => "current-user"}
        }
      )

    {:ok, _action_binding} =
      Domain.create(Binding,
        attrs: %{
          screen_id: screen.id,
          element_id: button.id,
          binding_type: :action,
          target: "submit",
          source: %{"resource" => "User", "action" => "save_profile"},
          transform: %{
            "params" => %{
              "display_name" => {"event", "display_name"},
              "actor_id" => {"context", "user_id"}
            }
          }
        }
      )

    screen
  end
end
