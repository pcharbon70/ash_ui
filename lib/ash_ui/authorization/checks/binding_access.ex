defmodule AshUI.Authorization.Checks.BindingAccess do
  @moduledoc false

  use Ash.Policy.SimpleCheck

  alias AshUI.Authorization.BindingPolicy
  alias AshUI.Authorization.Subject

  @impl true
  def describe(opts), do: "binding #{Keyword.get(opts, :mode, :read)} access"

  @impl true
  def match?(actor, %{subject: subject}, opts) do
    binding = Subject.to_data(subject)

    allowed =
      case Keyword.get(opts, :mode, :read) do
        :read -> BindingPolicy.can_read?(actor, binding)
        :manage -> BindingPolicy.can_manage?(actor, binding)
        _ -> false
      end

    {:ok, allowed}
  end
end
