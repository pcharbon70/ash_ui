defmodule AshUI.Authorization.Checks.BindingAccess do
  @moduledoc """
  Ash policy check that routes binding authorization through `BindingPolicy`.
  """

  use Ash.Policy.SimpleCheck

  alias AshUI.Authorization.BindingPolicy
  alias AshUI.Authorization.Subject

  @impl true
  @doc """
  Describes the binding access mode being evaluated.
  """
  def describe(opts), do: "binding #{Keyword.get(opts, :mode, :read)} access"

  @impl true
  @doc """
  Evaluates binding access for the supplied actor and policy subject.
  """
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
