defmodule AshUI.Compilation.IUR do
  @moduledoc """
  Internal IUR (Intermediate UI Representation) struct for Ash UI.

  This is the Ash-internal format used during compilation before
  conversion to the canonical unified_iur format for rendering.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: atom(),
          name: String.t() | nil,
          attributes: map(),
          props: map(),
          children: [t()],
          bindings: [map()],
          metadata: map(),
          version: String.t()
        }

  defstruct [
    :id,
    :type,
    :name,
    attributes: %{},
    props: %{},
    children: [],
    bindings: [],
    metadata: %{},
    version: "1.0"
  ]

  @doc """
  Creates a new IUR struct with the given type and optional attributes.
  """
  @spec new(atom(), keyword()) :: t()
  def new(type, opts \\ []) do
    attributes = Keyword.get(opts, :attributes, %{})
    props = Keyword.get(opts, :props, attributes)
    children = Keyword.get(opts, :children, [])
    bindings = Keyword.get(opts, :bindings, [])
    metadata = Keyword.get(opts, :metadata, %{})
    id = Keyword.get(opts, :id)
    name = Keyword.get(opts, :name)
    version = Keyword.get(opts, :version, "1.0")

    %__MODULE__{
      id: id,
      type: type,
      name: name,
      attributes: attributes,
      props: props,
      children: children,
      bindings: bindings,
      metadata: metadata,
      version: version
    }
  end

  @doc """
  Adds a child element to the IUR.
  """
  @spec add_child(t(), t()) :: t()
  def add_child(%__MODULE__{children: children} = iur, child) do
    %{iur | children: children ++ [child]}
  end

  @doc """
  Adds a binding to the IUR.
  """
  @spec add_binding(t(), map()) :: t()
  def add_binding(%__MODULE__{bindings: bindings} = iur, binding) do
    %{iur | bindings: bindings ++ [binding]}
  end

  @doc """
  Sets an attribute on the IUR.
  """
  @spec put_attribute(t(), atom(), term()) :: t()
  def put_attribute(%__MODULE__{attributes: attributes, props: props} = iur, key, value) do
    %{
      iur
      | attributes: Map.put(attributes, key, value),
        props: Map.put(props, key, value)
    }
  end

  @doc """
  Validates that the IUR has required fields and correct types.
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{type: nil}) do
    {:error, "IUR type is required"}
  end

  def validate(%__MODULE__{type: type}) when not is_atom(type) do
    {:error, "IUR type must be an atom, got: #{inspect(type)}"}
  end

  def validate(%__MODULE__{attributes: attrs}) when not is_map(attrs) do
    {:error, "IUR attributes must be a map"}
  end

  def validate(%__MODULE__{props: props}) when not is_map(props) do
    {:error, "IUR props must be a map"}
  end

  def validate(%__MODULE__{children: children}) when not is_list(children) do
    {:error, "IUR children must be a list"}
  end

  def validate(%__MODULE__{}) do
    :ok
  end
end
