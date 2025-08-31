defmodule Hologram.Template.Algebra do
  @moduledoc """
  The `Inspect.Algebra` for Hologram templates
  """
  import Inspect.Algebra

  def from_tree(tree, doc \\ empty())
  def from_tree([], doc), do: doc

  def from_tree([node | rest], doc) do
    IO.inspect(node)
    from_tree(rest, glue(doc, from_node(node)))
  end

  defp from_node(node)

  defp from_node({:start_tag, tag, attrs, subtree}) do
    this_tag = string("<#{tag}#{from_attrs(attrs)}>")
    subtree = from_tree(subtree)
    end_tag = string("</#{tag}>")

    glue(glue(this_tag, subtree), end_tag)
  end

  defp from_node({:block_start, tag, exp, subtree}) do
    this_tag = string("{%#{tag}#{from_expression(exp)}}")
    subtree = from_tree(subtree)
    end_tag = string("{/#{tag}}")

    glue(glue(this_tag, subtree), end_tag)
  end

  defp from_node({:block_interior, tag}) do
    string("{%#{tag}}")
  end

  defp from_node({:text, t}) do
    string(String.trim(t))
  end

  defp from_node({:expression, e}) do
    string(tighten_expression(e))
  end

  defp from_attrs(attrs, acc \\ [])
  defp from_attrs([], []), do: ""
  defp from_attrs([], acc), do: " #{acc |> Enum.reverse() |> Enum.join(" ")}"

  defp from_attrs([{key, value} | rest], acc) do
    from_attrs(rest, ["#{key}=#{attr_value(value)}" | acc])
  end

  defp attr_value(text: t) do
    "\"#{String.trim(t)}\""
  end

  defp from_expression(""), do: ""
  defp from_expression(e), do: " #{tighten_expression(e)}"

  defp tighten_expression(estr) do
    # Tighten up the tuple spacing
    tighter = estr |> String.trim_leading("{") |> String.trim_trailing("}") |> String.trim()
    "{#{tighter}}"
  end
end
