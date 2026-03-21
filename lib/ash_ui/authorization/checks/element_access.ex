defmodule AshUI.Authorization.Checks.ElementAccess do
  @moduledoc false

  use Ash.Policy.SimpleCheck

  alias AshUI.Authorization.ElementPolicy
  alias AshUI.Authorization.Subject

  @impl true
  def describe(opts), do: "element #{Keyword.get(opts, :mode, :read)} access"

  @impl true
  def match?(actor, %{subject: subject}, opts) do
    element = Subject.to_data(subject)

    allowed =
      case Keyword.get(opts, :mode, :read) do
        :read -> ElementPolicy.can_read?(actor, element)
        :manage -> ElementPolicy.can_manage?(actor, element)
        _ -> false
      end

    {:ok, allowed}
  end
end
