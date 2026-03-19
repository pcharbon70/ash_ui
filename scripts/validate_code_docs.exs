#!/usr/bin/env elixir

defmodule AshUI.CodeDocsValidator do
  @moduledoc false

  def main(argv) do
    files =
      argv
      |> Enum.reject(&(&1 == "--"))
      |> Enum.uniq()

    if files == [] do
      IO.puts("Skipping code-doc validation: no candidate Elixir source files.")
      :ok
    else
      violations =
        files
        |> Enum.flat_map(&validate_file/1)
        |> Enum.sort_by(fn %{file: file, line: line} -> {file, line} end)

      if violations == [] do
        IO.puts("Code-doc validation passed.")
        :ok
      else
        IO.puts("Code-doc validation failed.")

        Enum.each(violations, fn %{file: file, line: line, message: message} ->
          IO.puts("FAIL: #{file}:#{line} #{message}")
        end)

        :error
      end
    end
  end

  defp validate_file(file) do
    with {:ok, source} <- File.read(file),
         {:ok, ast} <- Code.string_to_quoted(source, columns: true, token_metadata: true) do
      {_ast, violations} =
        Macro.prewalk(ast, [], fn
          {:defmodule, meta, [name_ast, [do: body]]} = node, acc ->
            module_name = Macro.to_string(name_ast)
            module_violations = validate_module(file, module_name, meta, body)
            {node, module_violations ++ acc}

          node, acc ->
            {node, acc}
        end)

      violations
    else
      {:error, {line, error, token}} ->
        [
          %{
            file: file,
            line: line || 1,
            message: "could not parse file (#{error_message(error, token)})"
          }
        ]
    end
  end

  defp validate_module(file, module_name, module_meta, body) do
    expressions = block_to_list(body)

    moduledoc_violations = validate_moduledoc(file, module_name, module_meta, expressions)
    public_doc_violations = validate_public_function_docs(file, module_name, expressions)

    moduledoc_violations ++ public_doc_violations
  end

  defp validate_moduledoc(file, module_name, module_meta, expressions) do
    moduledoc_values =
      expressions
      |> Enum.flat_map(fn expr ->
        case module_attribute(expr, :moduledoc) do
          {:ok, value, _line} -> [value]
          :error -> []
        end
      end)

    module_line = module_meta[:line] || 1

    cond do
      moduledoc_values == [] ->
        [
          %{
            file: file,
            line: module_line,
            message: "#{module_name} is missing @moduledoc"
          }
        ]

      Enum.any?(moduledoc_values, &(&1 == false)) ->
        [
          %{
            file: file,
            line: module_line,
            message: "#{module_name} uses @moduledoc false; module docs are required"
          }
        ]

      true ->
        []
    end
  end

  defp validate_public_function_docs(file, module_name, expressions) do
    {_, _, violations} =
      Enum.reduce(expressions, {%{}, MapSet.new(), []}, fn expr, {pending_attrs, seen, acc} ->
        cond do
          match?({:ok, _, _}, module_attribute(expr, :doc)) ->
            {:ok, doc_value, doc_line} = module_attribute(expr, :doc)
            {Map.put(pending_attrs, :doc, {:doc, doc_value, doc_line}), seen, acc}

          match?({:ok, _, _}, module_attribute(expr, :impl)) ->
            {:ok, impl_value, impl_line} = module_attribute(expr, :impl)
            {Map.put(pending_attrs, :impl, {:impl, impl_value, impl_line}), seen, acc}

          public_function_definition?(expr) ->
            {name, arity, line} = public_function_signature(expr)
            signature = {name, arity}

            if MapSet.member?(seen, signature) do
              {%{}, seen, acc}
            else
              updated_seen = MapSet.put(seen, signature)
              updated_acc = enforce_doc_for_signature(acc, file, module_name, name, arity, line, pending_attrs)
              {%{}, updated_seen, updated_acc}
            end

          module_attribute_expression?(expr) ->
            {pending_attrs, seen, acc}

          true ->
            {%{}, seen, acc}
        end
      end)

    violations
  end

  defp enforce_doc_for_signature(acc, file, module_name, name, arity, line, pending_attrs) do
    signature = "#{module_name}.#{name}/#{arity}"
    pending_doc = Map.get(pending_attrs, :doc)
    pending_impl = Map.get(pending_attrs, :impl)

    case pending_doc do
      nil ->
        [
          %{
            file: file,
            line: line,
            message: "#{signature} is missing @doc"
          }
          | acc
        ]

      {:doc, false, _doc_line} ->
        if impl_callback_attribute?(pending_impl) do
          acc
        else
          [
            %{
              file: file,
              line: line,
              message:
                "#{signature} uses @doc false without @impl callback annotation; public function docs are required"
            }
            | acc
          ]
        end

      _ ->
        acc
    end
  end

  defp impl_callback_attribute?({:impl, value, _line}) when value != false, do: true
  defp impl_callback_attribute?(_), do: false

  defp public_function_definition?({:def, _meta, _args}), do: true
  defp public_function_definition?({:defdelegate, _meta, _args}), do: true
  defp public_function_definition?(_), do: false

  defp public_function_signature({:def, meta, [head | _rest]}), do: head_signature(head, meta)
  defp public_function_signature({:defdelegate, meta, [head | _rest]}), do: head_signature(head, meta)

  defp head_signature({:when, _meta, [head, _guards]}, fallback_meta), do: head_signature(head, fallback_meta)

  defp head_signature({name, _meta, args}, fallback_meta) when is_atom(name) do
    arity =
      case args do
        nil -> 0
        arg_list when is_list(arg_list) -> length(arg_list)
      end

    {name, arity, fallback_meta[:line] || 1}
  end

  defp head_signature(_head, fallback_meta), do: {:unknown, 0, fallback_meta[:line] || 1}

  defp module_attribute({:@, _meta, [{name, attr_meta, [value]}]}, expected_name)
       when name == expected_name do
    {:ok, value, attr_meta[:line] || 1}
  end

  defp module_attribute(_, _expected_name), do: :error

  defp module_attribute_expression?({:@, _meta, [{name, _attr_meta, _args}]}) when is_atom(name), do: true
  defp module_attribute_expression?(_), do: false

  defp block_to_list({:__block__, _meta, expressions}) when is_list(expressions), do: expressions
  defp block_to_list(nil), do: []
  defp block_to_list(expression), do: [expression]

  defp error_message(error, token) do
    message =
      case error do
        :missing_terminator -> "missing terminator"
        :syntax_error -> "syntax error"
        _ -> to_string(error)
      end

    if token do
      "#{message}: #{inspect(token)}"
    else
      message
    end
  end
end

case AshUI.CodeDocsValidator.main(System.argv()) do
  :ok -> System.halt(0)
  :error -> System.halt(1)
end
