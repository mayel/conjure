defmodule Conjure.Store do
  @moduledoc """
  Persists generated code to lib/conjure/generated/<lang>/<slug>.ex.

  These are real source files. Mix compiles them on the next run.
  The LLM's output becomes part of the codebase. That's the point.

  ## Cache lookup

  Generated modules carry `@moduledoc` (the original description) and
  `@conjure_lang`. Cache hits are found by scanning loaded Conjure.Generated.*
  modules for a matching moduledoc — the description IS the identity.
  """

  @prefix "Elixir.Conjure.Generated."
  @langs  [:elixir, :zig, :c]

  @doc """
  Find an already-loaded module matching this description and lang.
  Returns `{:ok, module}` or `:miss`.
  """
  def find_loaded(description, lang) do
    do_find(description, fn mod_lang -> mod_lang == lang end)
  end

  @doc """
  Find any already-loaded module matching this description, across all langs.
  Prefers :elixir > :zig > :c. Returns `{:ok, {module, lang}}` or `:miss`.
  """
  def find_loaded_any(description) do
    Enum.find_value(@langs, :miss, fn lang ->
      case find_loaded(description, lang) do
        {:ok, mod} -> {:ok, {mod, lang}}
        :miss      -> nil
      end
    end)
  end

  def slug(description, lang) do
    hash =
      :crypto.hash(:md5, "#{description}:#{lang}")
      |> Base.encode16(case: :lower)
      |> binary_part(0, 6)

    base =
      description
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "_")
      |> String.trim("_")
      |> String.slice(0, 50)
      |> String.trim_trailing("_")

    "#{base}_#{hash}"
  end

  def module_name(description, lang) do
    s = slug(description, lang)
    camel = s |> String.split("_") |> Enum.map(&String.capitalize/1) |> Enum.join()
    :"Elixir.Conjure.Generated.#{lang_module(lang)}.#{camel}"
  end

  def file_path(description, lang) do
    Path.join(generated_dir(lang), "#{slug(description, lang)}.ex")
  end

  def save(description, lang, module_source) do
    if Application.get_env(:conjure, :persist, true) do
      path = file_path(description, lang)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, module_source)
      path
    end
  end

  defp do_find(description, lang_filter) do
    result =
      :code.all_loaded()
      |> Enum.find(fn {mod, _} ->
        Atom.to_string(mod) |> String.starts_with?(@prefix) and
          conjure_match?(mod, description, lang_filter)
      end)

    case result do
      {mod, _} -> {:ok, mod}
      nil      -> :miss
    end
  end

  defp conjure_match?(mod, description, lang_filter) do
    function_exported?(mod, :__conjure__, 1) and
      mod.__conjure__(:description) == description and
      lang_filter.(mod.__conjure__(:lang))
  rescue
    _ -> false
  end

  defp generated_dir(lang) do
    Path.join([File.cwd!(), "lib", "conjure", "generated", to_string(lang)])
  end

  defp lang_module(:elixir), do: "Elixir"
  defp lang_module(:zig),    do: "Zig"
  defp lang_module(:c),      do: "C"

end
