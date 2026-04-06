defmodule Conjure do
  @moduledoc """
  LLM-generated code, compiled and run at runtime.

  The LLM writes it. The BEAM runs it. What could go wrong.

  ## Usage

      iex> Conjure.run("compute levenshtein distance between two strings", args: ["kitten", "sitting"])
      3

      iex> Conjure.run("add two integers", args: [3, 4], lang: :c)
      7

  ## Options

    * `:args`  - list of argument values to pass to the generated function (default: [])
    * `:lang`  - `:elixir`, `:zig`, or `:c` (default: `:elixir`)
    * `:model` - Ollama model name override
    * `:hint`  - extra hint appended to the prompt

  Generated code is written to `lib/conjure/generated/` and reused on subsequent calls
  (including across sessions, since it lives in `lib/` and is compiled by Mix on boot).
  """

  @doc """
  Delete all generated source files from `lib/conjure/generated/`.
  The next call to `run/2` will regenerate them from scratch.

  Note: already-loaded modules stay in the BEAM until the process restarts.
  """
  def reset! do
    dir = Path.join([File.cwd!(), "lib", "conjure", "generated"])

    deleted =
      Path.wildcard("#{dir}/**/*.{ex,c,h,zig}")
      |> Enum.map(fn path ->
        File.rm!(path)
        path
      end)

    IO.puts("[Conjure] Deleted #{length(deleted)} file(s).")
    :ok
  end

  def run(description, opts \\ []) do
    args  = Keyword.get(opts, :args, [])
    lang  = Keyword.get(opts, :lang, nil)
    model = Keyword.get(opts, :model, nil)
    hint  = Keyword.get(opts, :hint, nil)

    Conjure.Compiler.run(description, args, lang, model: model, hint: hint)
  end
end
