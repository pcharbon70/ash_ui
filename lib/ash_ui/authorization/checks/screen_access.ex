defmodule AshUI.Authorization.Checks.ScreenAccess do
  @moduledoc false

  use Ash.Policy.SimpleCheck

  alias AshUI.Authorization.ScreenPolicy
  alias AshUI.Authorization.Subject

  @impl true
  def describe(opts), do: "screen #{Keyword.get(opts, :mode, :read)} access"

  @impl true
  def match?(actor, %{subject: subject}, opts) do
    screen = Subject.to_data(subject)

    allowed =
      case Keyword.get(opts, :mode, :read) do
        :mount -> ScreenPolicy.can_mount?(actor, screen)
        :read -> ScreenPolicy.can_read?(actor, screen)
        :manage -> ScreenPolicy.can_manage?(actor, screen)
        _ -> false
      end

    {:ok, allowed}
  end
end
