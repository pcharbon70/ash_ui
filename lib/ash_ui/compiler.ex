defmodule AshUI.Compiler do
  @moduledoc """
  Compiler that converts Ash Resources to IUR structures.

  This module handles the compilation of Ash UI resources (Screen, Element, Binding)
  into the internal IUR (Intermediate UI Representation) format.
  """

  alias AshUI.Compilation.IUR
  alias AshUI.Resources.Screen
  alias AshUI.Resources.Element
  alias AshUI.Resources.Binding

  @doc """
  Compiles a screen resource to an IUR structure.

  ## Options
    * `:load_elements` - Whether to load associated elements (default: true)
    * `:load_bindings` - Whether to load associated bindings (default: true)
  """
  @spec compile(Screen.t() | String.t() | integer(), keyword()) ::
          {:ok, IUR.t()} | {:error, term()}
  def compile(screen, opts \\ [])

  def compile(screen_id, opts) when is_binary(screen_id) or is_integer(screen_id) do
    with {:ok, screen} <- AshUI.Domain.get(Screen, filter: [id: screen_id]) do
      compile(screen, opts)
    end
  end

  def compile(%Screen{} = screen, opts) do
    load_elements? = Keyword.get(opts, :load_elements, true)
    load_bindings? = Keyword.get(opts, :load_bindings, true)

    # Build root IUR from screen
    root_iur =
      IUR.new(:screen,
        id: screen.id,
        name: screen.name,
        attributes: %{
          "layout" => screen.layout,
          "route" => screen.route,
          "unified_dsl" => screen.unified_dsl
        },
        metadata: screen.metadata,
        version: "v#{screen.version}"
      )

    # Load and compile children elements
    root_iur =
      if load_elements? do
        case load_elements(screen) do
          {:ok, elements} -> compile_elements(root_iur, elements)
          {:error, _} -> root_iur
        end
      else
        root_iur
      end

    # Load and compile bindings
    root_iur =
      if load_bindings? do
        case load_bindings(screen) do
          {:ok, bindings} -> compile_bindings(root_iur, bindings)
          {:error, _} -> root_iur
        end
      else
        root_iur
      end

    # Validate the compiled IUR
    case IUR.validate(root_iur) do
      :ok -> {:ok, root_iur}
      error -> error
    end
  end

  # Load elements associated with a screen
  defp load_elements(%Screen{id: screen_id}) do
    elements =
      AshUI.Domain.read!(Element,
        filter: [screen_id: screen_id],
        sort: [position: :asc]
      )

    {:ok, elements}
  rescue
    error -> {:error, error}
  end

  # Load bindings associated with a screen
  defp load_bindings(%Screen{id: screen_id}) do
    bindings =
      AshUI.Domain.read!(Binding,
        filter: [screen_id: screen_id]
      )

    {:ok, bindings}
  rescue
    error -> {:error, error}
  end

  # Compile elements into IUR children
  defp compile_elements(root_iur, elements) do
    compiled_children =
      Enum.map(elements, fn element ->
        compile_element(element)
      end)

    %{root_iur | children: compiled_children}
  end

  # Compile a single element to IUR
  defp compile_element(%Element{} = element) do
    IUR.new(element.type,
      id: element.id,
      name: element.props["name"] || "element_#{element.id}",
      attributes: Map.put(element.props, "position", element.position),
      metadata: element.metadata,
      version: "v#{element.version || 1}"
    )
  end

  # Compile bindings into IUR bindings
  defp compile_bindings(root_iur, bindings) do
    compiled_bindings =
      Enum.map(bindings, fn binding ->
        compile_binding(binding)
      end)

    %{root_iur | bindings: compiled_bindings}
  end

  # Compile a single binding to IUR format
  defp compile_binding(%Binding{} = binding) do
    %{
      "id" => binding.id,
      "source" => binding.source,
      "target" => binding.target,
      "binding_type" => binding.binding_type,
      "transform" => binding.transform,
      "element_id" => binding.element_id,
      "screen_id" => binding.screen_id,
      "metadata" => binding.metadata
    }
  end
end
