defmodule Hologram.Template.Formatter do
  @moduledoc """
    A formatter for `~HOLO` sigil templates.

    Enable it by adding `Hologram.Template.Formatter` to the `plugins:` list
    in `.formatter.exs`
  """

  @behaviour Mix.Tasks.Format
  alias Hologram.Template.{Parser, Algebra}

  @impl Mix.Tasks.Format
  def features(_opts) do
    # Will `.holo` be a thing eventually?
    [sigils: [:HOLO], extensions: [".holo"]]
  end

  @impl Mix.Tasks.Format
  def format(contents, _opts) do
    contents
    |> Parser.parse_markup()
    |> parse_to_tree()
    |> to_algebra()
    |> Inspect.Algebra.format(80)
    |> IO.inspect()

    contents
  end

  @open_to_close %{block_start: :block_end, start_tag: :end_tag}
  @close_to_open Enum.reduce(@open_to_close, %{}, fn {k, v}, a -> Map.put(a, v, k) end)
  @openers Map.keys(@open_to_close)
  @closers Map.keys(@close_to_open)

  defp to_algebra({[], %{tree: tree}}) do
    Algebra.from_tree(tree)
  end

  defp to_algebra(improper),
    do: raise(MatchError, "Unexpected DOM tree results: #{inspect(improper)}")

  defp parse_to_tree(parse, context \\ %{tree: [], continue: [], in_block: nil})

  defp parse_to_tree([], context), do: {[], context}

  defp parse_to_tree([item | rest], ctx) do
    {todo, next_context} =
      case item do
        {block_type, bn} when block_type in @closers ->
          close_block(block_type, bn, rest, ctx)

        {:block_start, "else"} ->
          {rest, %{ctx | tree: Enum.concat(ctx.tree, [{:block_interior, "else"}])}}

        {block_type, block_info} when block_type in @openers ->
          open_block(block_info, rest, ctx)

        value ->
          {rest, %{ctx | tree: Enum.concat(ctx.tree, [value])}}
      end

    parse_to_tree(todo, next_context)
  end

  defp open_block(name, remaining, ctx) when is_binary(name) do
    open_block({name, ""}, remaining, ctx)
  end

  defp open_block({name, meta}, remaining, ctx) do
    {[], new_context} =
      parse_to_tree(remaining, %{tree: [], continue: [], in_block: {name, meta}})

    {new_context[:continue],
     %{tree: ctx.tree ++ new_context[:tree], continue: [], in_block: ctx.in_block}}
  end

  defp open_block(block_info, _remaining, _ctx) do
    raise(MatchError, "Unexpected parser output block #{inspect(block_info)}")
  end

  defp close_block(type, name, remaining, %{tree: tree, in_block: {name, meta}}) do
    {[], %{tree: [{@close_to_open[type], name, meta, tree}], continue: remaining}}
  end

  defp close_block(_type, name, _rem, _ctx) do
    raise(TokenMissingError, "Mismatched closing tag of #{name}")
  end
end
