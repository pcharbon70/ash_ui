defmodule AshUI.Authorization.Checks.ElementAccess do
  @moduledoc """
  Ash policy check that routes element authorization through `ElementPolicy`.
  """

  use Ash.Policy.SimpleCheck

  alias AshUI.Authorization.ElementPolicy
  alias AshUI.Authorization.Subject

  @impl true
  @doc """
  Describes the element access mode being evaluated.
  """
  def describe(opts), do: "element #{Keyword.get(opts, :mode, :read)} access"

  @impl true
  @doc """
  Evaluates element access for the supplied actor and policy subject.
  """
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
