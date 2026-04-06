defmodule ConjureTest do
  use ExUnit.Case

  alias Conjure.{Prompt, Store}

  describe "Conjure.Store.slug/2" do
    test "produces stable slugs" do
      assert Store.slug("add two integers", :elixir) == Store.slug("add two integers", :elixir)
    end

    test "differentiates by lang" do
      refute Store.slug("add two integers", :elixir) == Store.slug("add two integers", :c)
    end

    test "slugifies description" do
      slug = Store.slug("Compute Levenshtein Distance!", :elixir)
      assert slug =~ ~r/^compute_levenshtein_distance_/
    end
  end

  describe "Conjure.Store.module_name/2" do
    test "returns an atom" do
      mod = Store.module_name("add two integers", :elixir)
      assert is_atom(mod)
    end

    test "scoped under Conjure.Generated.Elixir" do
      mod = Store.module_name("add two integers", :elixir)
      assert mod |> Atom.to_string() |> String.starts_with?("Elixir.Conjure.Generated.Elixir.")
    end

    test "scoped under Conjure.Generated.C for :c" do
      mod = Store.module_name("add two integers", :c)
      assert mod |> Atom.to_string() |> String.starts_with?("Elixir.Conjure.Generated.C.")
    end
  end

  describe "Conjure.Prompt.build/4" do
    test "elixir prompt asks for named function" do
      prompt = Prompt.build("add two numbers", 2, :elixir, nil)
      assert prompt =~ "def run(arg0, arg1)"
      assert prompt =~ "defp"
    end

    test "zig prompt asks for JSON" do
      prompt = Prompt.build("add two numbers", 2, :zig, nil)
      assert prompt =~ "JSON"
      assert prompt =~ "fn_code"
      assert prompt =~ "run"
    end

    test "c prompt asks for JSON" do
      prompt = Prompt.build("add two numbers", 2, :c, nil)
      assert prompt =~ "JSON"
      assert prompt =~ "fn_name"
      assert prompt =~ "header"
      assert prompt =~ "source"
    end

    test "retry prompt includes error" do
      prompt = Prompt.build_retry("add", 1, :elixir, nil, "undefined function foo/0")
      assert prompt =~ "undefined function foo/0"
      assert prompt =~ "Fix the error"
    end

    test "hint is appended" do
      prompt = Prompt.build("something", 1, :elixir, "use recursion")
      assert prompt =~ "use recursion"
    end
  end

  describe "Conjure.Backend.Elixir.compile/5" do
    test "compiles named function definitions" do
      mod = :"Conjure.Generated.Elixir.TestAdd#{System.unique_integer([:positive])}"
      result = Conjure.Backend.Elixir.compile("def run(arg0, arg1), do: arg0 + arg1", mod, 2, "add", :elixir)
      assert {:ok, source} = result
      assert source =~ "defmodule"
      assert apply(mod, :run, [3, 4]) == 7
    end

    test "returns error for invalid code" do
      mod = :"Conjure.Generated.Elixir.TestBad#{System.unique_integer([:positive])}"
      result = Conjure.Backend.Elixir.compile("this is not valid elixir !!!###", mod, 0, "bad", :elixir)
      assert {:error, _} = result
    end
  end
end
