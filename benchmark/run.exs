# Run with:
#   mix run benchmark/run.exs
#
# Override description and args:
#   CONJURE_DESC="dot product of two float lists" \
#   CONJURE_ARGS="[[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]" \
#   mix run benchmark/run.exs

Application.put_env(:conjure, :persist, false)

description = System.get_env("CONJURE_DESC", "dot product of two float lists")
args        = System.get_env("CONJURE_ARGS", "[[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]") |> Code.eval_string() |> elem(0) |> List.wrap()
all_langs   = [:elixir, :zig, :c]
iterations  = 1_000

fmt_us = fn us ->
  cond do
    us >= 1_000_000 -> "#{Float.round(us / 1_000_000, 2)} s"
    us >= 1_000     -> "#{Float.round(us / 1_000, 2)} ms"
    true            -> "#{Float.round(us * 1.0, 1)} µs"
  end
end


IO.puts("""
Conjure benchmark
  description : #{description}
  args        : #{inspect(args)}
""")

# --- Phase 1: generation (LLM + compile + first run) ---

IO.puts("Phase 1 — generation (LLM + compile + first run)")
IO.puts(String.pad_trailing("Language", 16) <> String.pad_leading("time", 12))
IO.puts(String.duplicate("-", 30))

gen_results =
  Map.new(all_langs, fn lang ->
    t0 = System.monotonic_time(:microsecond)
    Conjure.run(description, args: args, lang: lang)
    elapsed = System.monotonic_time(:microsecond) - t0

    IO.puts(String.pad_trailing("#{lang}", 16) <> String.pad_leading(fmt_us.(elapsed), 12))

    {lang, elapsed}
  end)

IO.puts("")

# --- Phase 2: pure execution, all langs already loaded ---

IO.puts("Phase 2 — pure execution (#{iterations} iterations, no generation)")

exec_results =
  Enum.map(all_langs, fn lang ->
    times_us =
      Enum.map(1..iterations, fn _ ->
        t0 = System.monotonic_time(:microsecond)
        Conjure.run(description, args: args, lang: lang)
        System.monotonic_time(:microsecond) - t0
      end)

    {lang, Enum.min(times_us), Enum.sum(times_us) / iterations, Enum.max(times_us)}
  end)

{_, _, baseline_avg, _} = hd(exec_results)

IO.puts(String.pad_trailing("Language", 16) <>
        String.pad_leading("min", 12) <>
        String.pad_leading("avg", 12) <>
        String.pad_leading("max", 12) <>
        String.pad_leading("vs elixir", 12))
IO.puts(String.duplicate("-", 64))

for {lang, min_us, avg_us, max_us} <- exec_results do
  ratio     = Float.round(avg_us / baseline_avg, 2)
  ratio_str = if ratio == 1.0, do: "—", else: "#{ratio}x"
  IO.puts(String.pad_trailing("#{lang}", 16) <>
          String.pad_leading(fmt_us.(min_us), 12) <>
          String.pad_leading(fmt_us.(avg_us), 12) <>
          String.pad_leading(fmt_us.(max_us), 12) <>
          String.pad_leading(ratio_str, 12))
end

IO.puts("""

(Zig/C NIFs run outside the BEAM scheduler, so wall time is the honest number there.)
""")
