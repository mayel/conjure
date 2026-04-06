defmodule Conjure.Prompt do
  def build(description, arity, :elixir, hint) do
    arg_names = arg_names(arity)
    args_str  = Enum.join(arg_names, ", ")
    hint_str  = if hint, do: "\nHint: #{hint}", else: ""

    """
    You are an Elixir code generator. Return ONLY Elixir function definitions. No markdown, no module, no explanation.

    Task: #{description}
    Args (#{arity}): #{args_str}#{hint_str}

    Rules:
    - Define a public function named `run` with these exact args: (#{args_str})
    - You may add private `defp` helpers after
    - No `defmodule` wrapper, no markdown, no explanation

    Complete the following Elixir function (output only code, starting from `def`):
    def run(#{args_str}) do
    """
  end

  def build(description, arity, :zig, hint) do
    arg_names = arg_names(arity)
    args_str  = Enum.join(arg_names, ", ")
    hint_str  = if hint, do: "\nHint: #{hint}", else: ""

    """
    You are a Zig code generator. Return ONLY valid JSON, no markdown, no explanation.

    Task: #{description}
    Args (#{arity}): #{args_str}#{hint_str}

    Return JSON with exactly these keys:
      - "fn_code": all Zig function definitions — the main pub fn plus any private helper functions
      - "return_type": one of "i64", "f64", "bool" — the Elixir-compatible return type

    Rules:
    - The main entry function MUST be named `run`
    - Every parameter needs its own type: `pub fn run(arg0: T, arg1: T, ...) ReturnType`
    - Helper functions should be `fn` (private, no pub)
    - Use i64 for integers, f64 for floats, bool for booleans
    - No pointers, no slices, no allocators — keep it NIF-safe
    - Never use `/` for integer division — use @divTrunc(a, b) instead
    - Use explicit while loops with `var i: i64 = 0; while (i < n) : (i += 1) { ... }` syntax

    Return only JSON. Example with #{arity} arg(s):
    {"fn_code": "pub fn run(#{Enum.map_join(arg_names, ", ", &"#{&1}: i64")}) i64 { return #{Enum.at(arg_names, 0)}#{if arity > 1, do: " + " <> Enum.at(arg_names, 1), else: ""}; }", "return_type": "i64"}
    """
  end

  def build(description, arity, :c, hint) do
    arg_names = arg_names(arity)
    args_str  = Enum.join(arg_names, ", ")
    hint_str  = if hint, do: "\nHint: #{hint}", else: ""

    """
    You are a C code generator. Return ONLY valid JSON, no markdown, no explanation.

    Task: #{description}
    Args (#{arity}): #{args_str}#{hint_str}

    Return JSON with exactly these keys:
      - "fn_name": the name of the main entry function (snake_case)
      - "return_type": C return type of the main function — one of "int", "long", "double", "float"
      - "param_types": array of C types for each argument in order, e.g. ["int", "int"]
      - "source": ALL function implementations (main + optional static helpers), in dependency order

    Rules:
    - The main entry function MUST be named `run`
    - The main function MUST take exactly #{arity} argument(s) and return a single value (no output pointers)
    - Helper functions must be declared static and defined before the main function
    - No dynamic memory allocation
    - No external dependencies beyond <stdlib.h>, <string.h>, <math.h>
    - Do NOT include a header declaration for the main function in "source" — it will be generated separately

    Return only JSON. Example with helper:
    {"return_type": "int", "param_types": ["int", "int"], "source": "static int square(int x) { return x * x; }\nint run(int a, int b) { return square(a) + square(b); }"}
    """
  end

  def build_retry(description, arity, lang, hint, error) do
    original = build(description, arity, lang, hint)

    original <>
      """

      Your previous attempt failed to compile with this error:
      #{error}

      Fix the error and return only the corrected code/JSON. No explanation.
      """
  end

  def arg_names(arity), do: Enum.map(0..(arity - 1)//1, &"arg#{&1}")
end
