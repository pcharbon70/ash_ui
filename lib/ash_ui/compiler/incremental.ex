defmodule AshUI.Compiler.Incremental do
  @moduledoc """
  Incremental compilation support for Ash UI.

  Tracks resource dependencies and selectively recompiles only
  affected resources when things change.
  """

  require Logger

  alias AshUI.Compiler
  alias AshUI.Resources.Screen
  alias AshUI.Resources.Element
  alias AshUI.Resources.Binding

  @type dependency_graph :: %{
          screen_to_elements: %{String.t() => [String.t()]},
          element_to_screen: %{String.t() => String.t()},
          element_to_bindings: %{String.t() => [String.t()]},
          binding_to_element: %{String.t() => String.t()}
        }

  @doc """
  Builds dependency graph for a screen and its resources.

  ## Examples

      {:ok, graph} = AshUI.Compiler.Incremental.build_dependencies(screen)
  """
  @spec build_dependencies(Screen.t()) :: {:ok, dependency_graph()} | {:error, term()}
  def build_dependencies(%Screen{} = screen) do
    graph = %{
      screen_to_elements: %{},
      element_to_screen: %{},
      element_to_bindings: %{},
      binding_to_element: %{}
    }

    # Load elements and build relationships
    with {:ok, elements} <- load_screen_elements(screen),
         graph <- build_element_dependencies(graph, screen, elements),
         graph <- build_binding_dependencies(graph, elements) do
      detect_circular_dependencies(graph)
    end
  end

  @doc """
  Recompiles a screen after a resource change.

  Only recompiles if the changed resource affects the screen.

  ## Parameters
    * `screen_id` - ID of the screen to recompile
    * `changed_resource` - The resource that changed (:element, :binding)
    * `changed_id` - ID of the changed resource
    * `opts` - Compilation options

  ## Examples

      {:ok, iur} = AshUI.Compiler.Incremental.recompile_on_change(
        "screen-1",
        :element,
        "element-1"
      )
  """
  @spec recompile_on_change(String.t(), atom(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def recompile_on_change(screen_id, changed_resource, changed_id, opts \\ []) do
    with {:ok, screen} <- load_screen(screen_id, opts),
         {:ok, graph} <- build_dependencies(screen),
         true <- affects_screen?(graph, changed_resource, changed_id, screen_id) do
      # Invalidate cache for screen
      Compiler.invalidate_cache(screen_id)

      # Recompile screen
      Compiler.compile(screen, Keyword.put(opts, :use_cache, false))
    else
      false ->
        # Change doesn't affect screen, return cached version
        Compiler.compile(screen_id, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Recompiles multiple screens after resource changes.

  Efficiently handles multiple changes with selective recompilation.

  ## Examples

      {:ok, results} = AshUI.Compiler.Incremental.recompile_batch([
        {:screen, "screen-1", :element, "element-1"},
        {:screen, "screen-2", :binding, "binding-1"}
      ])
  """
  @spec recompile_batch([tuple()], keyword()) :: {:ok, map()} | {:error, term()}
  def recompile_batch(changes, opts \\ []) when is_list(changes) do
    # Group changes by screen
    by_screen = Enum.group_by(changes, fn {:screen, screen_id, _, _} -> screen_id end)

    results =
      Enum.reduce(by_screen, %{}, fn {screen_id, changes_for_screen}, acc ->
        # Get the last change for each screen (most recent)
        latest_change = List.last(changes_for_screen)

        case latest_change do
          {:screen, ^screen_id, resource, resource_id} ->
            case recompile_on_change(screen_id, resource, resource_id, opts) do
              {:ok, iur} -> Map.put(acc, screen_id, iur)
              {:error, _} -> acc
            end
        end
      end)

    {:ok, results}
  end

  @doc """
  Checks if a resource change affects a screen.

  ## Examples

      affects = AshUI.Compiler.Incremental.affects_screen?(graph, :element, "element-1", "screen-1")
  """
  @spec affects_screen?(dependency_graph(), atom(), String.t(), String.t()) :: boolean()
  def affects_screen?(graph, :element, element_id, screen_id) do
    # Element affects screen if it's a child of the screen
    Map.get(graph.element_to_screen, element_id) == screen_id
  end

  def affects_screen?(graph, :binding, binding_id, screen_id) do
    # Binding affects screen if its element is a child of the screen
    case Map.get(graph.binding_to_element, binding_id) do
      nil -> false
      element_id -> Map.get(graph.element_to_screen, element_id) == screen_id
    end
  end

  def affects_screen?(_graph, _resource, _id, _screen_id), do: true

  @doc """
  Gets all resources that depend on a given resource.

  ## Examples

      {:ok, dependents} = AshUI.Compiler.Incremental.get_dependents(graph, :element, "element-1")
  """
  @spec get_dependents(dependency_graph(), atom(), String.t()) :: {:ok, [map()]}
  def get_dependents(graph, :element, element_id) do
    screen_id = Map.get(graph.element_to_screen, element_id)
    binding_ids = Map.get(graph.element_to_bindings, element_id, [])

    dependents = []

    dependents =
      if screen_id do
        [%{type: :screen, id: screen_id} | dependents]
      else
        dependents
      end

    dependents =
      Enum.reduce(binding_ids, dependents, fn binding_id, acc ->
        [%{type: :binding, id: binding_id, element_id: element_id} | acc]
      end)

    {:ok, dependents}
  end

  @doc """
  Detects circular dependencies in the dependency graph.

  ## Returns
    * `:ok` - No circular dependencies
    * `{:error, cycles}` - Circular dependencies found

  ## Examples

      case AshUI.Compiler.Incremental.detect_circular_dependencies(graph) do
        :ok -> :no_cycles
        {:error, cycles} -> # handle cycles
      end
  """
  @spec detect_circular_dependencies(dependency_graph()) :: :ok | {:error, [map()]}
  def detect_circular_dependencies(graph) do
    cycles = find_cycles(graph)

    case cycles do
      [] -> :ok
      _ -> {:error, cycles}
    end
  end

  # Private functions

  defp load_screen(screen_id, opts) do
    actor = Keyword.get(opts, :actor)
    tenant = Keyword.get(opts, :tenant)

    case Ash.get(Screen, screen_id, actor: actor, tenant: tenant) do
      {:ok, screen} -> {:ok, screen}
      {:error, reason} -> {:error, {:screen_not_found, reason}}
    end
  end

  defp load_screen_elements(%Screen{id: screen_id}) do
    case Ash.read(Element, filter: [screen_id: screen_id], sort: [position: :asc]) do
      {:ok, elements} -> {:ok, elements}
      {:error, _} -> {:ok, []}
    end
  end

  defp build_element_dependencies(graph, screen, elements) do
    {element_to_screen, screen_to_elements} =
      Enum.reduce(elements, {%{}, %{screen.id => []}}, fn element, {e_to_s, s_to_e} ->
        {
          Map.put(e_to_s, element.id, screen.id),
          Map.update!(s_to_e, screen.id, fn ids -> [element.id | ids] end)
        }
      end)

    %{graph | element_to_screen: element_to_screen, screen_to_elements: screen_to_elements}
  end

  defp build_binding_dependencies(graph, elements) do
    {element_to_bindings, binding_to_element} =
      Enum.reduce(elements, {%{}, %{}}, fn element, {e_to_b, b_to_e} ->
        bindings = get_element_bindings(element)
        binding_ids = Enum.map(bindings, & & &1.id)

        updated_e_to_b =
          if binding_ids == [] do
            e_to_b
          else
            Map.put(e_to_b, element.id, binding_ids)
          end

        updated_b_to_e =
          Enum.reduce(binding_ids, b_to_e, fn binding_id, acc ->
            Map.put(acc, binding_id, element.id)
          end)

        {updated_e_to_b, updated_b_to_e}
      end)

    %{graph | element_to_bindings: element_to_bindings, binding_to_element: binding_to_element}
  end

  defp get_element_bindings(%Element{id: element_id}) do
    case Ash.read(Binding, filter: [element_id: element_id]) do
      {:ok, bindings} -> bindings
      {:error, _} -> []
    end
  end

  defp find_cycles(graph) do
    # Use depth-first search to find cycles
    visited = MapSet.new()
    rec_stack = MapSet.new()

    find_cycles_in_nodes(graph, visited, rec_stack, Map.keys(graph.screen_to_elements))
  end

  defp find_cycles_in_nodes(_graph, _visited, _rec_stack, []), do: []

  defp find_cycles_in_nodes(graph, visited, rec_stack, [node | rest]) do
    if MapSet.member?(rec_stack, node) do
      # Found a cycle
      [%{type: :screen, id: node, cycle: true}]
    else
      if MapSet.member?(visited, node) do
        find_cycles_in_nodes(graph, visited, rec_stack, rest)
      else
        visited = MapSet.put(visited, node)
        rec_stack = MapSet.put(rec_stack, node)

        # Check children (elements)
        children = Map.get(graph.screen_to_elements, node, [])
        child_cycles = find_cycles_in_nodes(graph, visited, rec_stack, children)

        # Continue with rest
        rest_cycles = find_cycles_in_nodes(graph, visited, MapSet.delete(rec_stack, node), rest)

        child_cycles ++ rest_cycles
      end
    end
  end
end
