# Conjure

You describe a function. An LLM hallucinates it. The BEAM compiles and runs it live in your runtime with no restart, no compile step, PR reviews, no deploy. The source also lands in your codebase for further use. Straight from user input into production. Probably fine?

```elixir
iex> Conjure.run("sum these integers", args: [1, 2, 3])
6

# Zig runs faster than elixir for some things:
iex> Conjure.run("sum integers from 1 to n", args: [1_000_000_000], lang: :zig)
500000000500000000

# or why not use C while we're here:
iex> Conjure.run("dot product of two float lists", args: [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], lang: :c)
32.0
```

## Why?

Every AI coding tool is doing some version of this. The difference is how many layers of shiny UI, "sandboxing", and permission dialogs stand between you and the moment an LLM's output actually executes. Conjure removes them all.

Software has spent decades building walls between users and raw execution. The stated reason is safety. The actual effect is that developers decide what users are allowed to want. 

Conjure explores what the opposite feels like. [Neal Stephenson asked this in 1999](https://web.stanford.edu/class/cs81n/command.txt). We still haven't figured it out.

Of course, the emperor has no clothes. You're running a model that [doesn't answer your request but just produces text in the shape of an answer](https://www.antipope.org/charlie/blog-static/2023/12/made-of-lies-and-more-lies.html), statistically resembling code written by whoever happened to be overrepresented in the training data. Sometimes that's `String.myers_difference("puppy", "kitten")`. Sometimes it's `System.cmd("rm", ["-rf", "/"])`. Conjure will compile and run either with equal enthusiasm.

Most AI coding workflows paper over this with a [reverse centaur](https://pluralistic.net/2025/12/05/pop-that-bubble/): the human reviews and rubber-stamps LLM output, absorbing responsibility for failures they were never equipped to catch. Conjure just removes the human from the loop entirely. Just pure honest vibe coding.

### The technical curiosity

[slopc](https://github.com/shorwood/slopc) does something similar in Rust. The question here was whether this could be pushed further, not just at compile time via macros, but *at runtime*: live code generation, compilation, and execution inside a running OTP node, with no restart. And not just Elixir code: thanks to [language interoperability tooling](https://elixir-lang.org/blog/2025/08/18/interop-and-portability/), the same trick works for Zig and C, so you can go from idea to halucinated code to computed result with a single `Conjure.run/2` runtime call.


## How it (sometimes) works

Call Conjure at runtime with a request, it asks Ollama to hallucinate some code, compiles that *into the running BEAM* via `Code.compile_string/1` or a Zigler NIF, and runs it. The source is written to `lib/conjure/generated/`.

On any subsequent call with the same request, the generated module is already in the BEAM (or Mix compiled it from disk on next startup). No LLM, no compile step. Just the previously hallucinated code.

On compile error, the error is fed back to the LLM and it tries again, up to `max_retries` times.


## Setup

```sh
ollama pull qwen3-coder:30b // or any hallucination engine of your choice
mix deps.get
brew install zig // or: mix zig.get (needed for :zig and :c backends)
iex -S mix
```


## Usage

```elixir
Conjure.run("description", args: [...]) 
Conjure.run("description", args: [...], lang: :zig)   # :elixir | :zig | :c
Conjure.run("description", args: [...], model: "qwen2.5-coder:7b")
```

If no `lang:` is given and a version is already cached, Conjure uses whichever one it finds, otherwise it generates one in Elixir by default.


## Language support

|           | how                       | when                      |
|-----------|---------------------------|---------------------------|
| `:elixir` | `Code.compile_string/1`   | default                   |
| `:zig`    | Zigler NIF, `~Z` block    | numeric work, tight loops |
| `:c`      | Zigler with `easy_c` NIF  | C algorithms, libc        |

