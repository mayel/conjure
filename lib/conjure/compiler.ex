defmodule Conjure.Compiler do
  require Logger

  alias Conjure.{LLM, Prompt, Store}
  alias Conjure.Backend.Elixir, as: ElixirBackend
  alias Conjure.Backend.Zig,    as: ZigBackend
  alias Conjure.Backend.C,      as: CBackend

  @moduledoc """
  Orchestrates the generate → compile → run pipeline.

  ## Caching

  Generated files land in `lib/conjure/generated/<lang>/`. Because they live in
  `lib/`, Mix compiles them automatically on the next `iex -S mix`. That means
  the cache is just the filesystem — no ETS, no database, no GenServer.

  Cache lookup scans loaded `Conjure.Generated.*` modules for one whose
  `@moduledoc` matches the description. The description IS the identity.

  The call order on any given invocation:

    1. Scan loaded modules for matching `@moduledoc` + `@conjure_lang`. Hit →
       call directly.
    2. Miss → call Ollama, compile at runtime via `Code.compile_string/1`,
       write the source to `lib/conjure/generated/`, call the new module.

  Retries: on compile error, the error is fed back to the LLM and the whole
  cycle repeats up to `:max_retries` times (config, default 2).
  """

  @doc """
  Generate, compile, and run code for the given description and args.

  If `lang` is nil, first checks whether any lang is already loaded for this
  description and uses that; otherwise defaults to `:elixir`.
  """
  def run(description, arg_values, lang, opts \\ []) do
    arity = length(arg_values)

    {mod, resolved_lang} = resolve(description, lang)

    case mod do
      nil ->
        new_mod = Store.module_name(description, resolved_lang)
        generate_compile_run(description, arg_values, resolved_lang, new_mod, arity, opts)

      loaded_mod ->
        Logger.info("[Conjure] #{inspect(loaded_mod)} already loaded.")
        apply(loaded_mod, :run, arg_values)
    end
  end

  # If lang specified, check that lang. If not, check all langs and fall back to :elixir.
  defp resolve(description, lang) when not is_nil(lang) do
    case Store.find_loaded(description, lang) do
      {:ok, mod} -> {mod, lang}
      :miss      -> {nil, lang}
    end
  end

  defp resolve(description, nil) do
    case Store.find_loaded_any(description) do
      {:ok, {mod, lang}} -> {mod, lang}
      :miss              -> {nil, :elixir}
    end
  end

  defp generate_compile_run(description, arg_values, lang, mod, arity, opts) do
    max_retries = Application.get_env(:conjure, :max_retries, 2)
    do_generate(description, arg_values, lang, mod, arity, opts[:model], opts[:hint], max_retries, nil)
  end

  defp do_generate(_description, _arg_values, _lang, _mod, _arity, _model, _hint, 0, last_error) do
    raise "Conjure failed after retries. Last error:\n#{last_error}"
  end

  defp do_generate(description, arg_values, lang, mod, arity, model, hint, retries_left, last_error) do
    prompt =
      if last_error,
        do: Prompt.build_retry(description, arity, lang, hint, last_error),
        else: Prompt.build(description, arity, lang, hint)

    raw     = LLM.call!(prompt, model: model)
    backend = backend_for(lang)

    case backend.compile(raw, mod, arity, description, lang) do
      {:ok, source} ->
        path = Store.save(description, lang, source)
        Logger.info("[Conjure] Generated code saved to #{path}")

        try do
          apply(mod, :run, arg_values)
        rescue
          e ->
            error = Exception.format(:error, e, __STACKTRACE__)
            Logger.warning("[Conjure] Runtime error (#{retries_left - 1} retries left).\nGenerated code:\n#{source}\nError:\n#{error}")
            File.rm(path)
            do_generate(description, arg_values, lang, mod, arity, model, hint, retries_left - 1, error)
        end

      {:error, error} ->
        Logger.warning("[Conjure] Compile failed (#{retries_left - 1} retries left).\nGenerated code:\n#{raw}\nError:\n#{error}")
        do_generate(description, arg_values, lang, mod, arity, model, hint, retries_left - 1, error)
    end
  end

  defp backend_for(:elixir), do: ElixirBackend
  defp backend_for(:zig),    do: ZigBackend
  defp backend_for(:c),      do: CBackend
end
