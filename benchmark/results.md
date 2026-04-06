Conjure benchmark
  description : dot product of two float lists
  args        : [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]

Phase 1 — generation (LLM + compile + first run)
Language                time
------------------------------
elixir               10.84 s
zig                   14.6 s
c                     5.39 s

Phase 2 — pure execution (1000 iterations, no generation)
Language                 min         avg         max   vs elixir
----------------------------------------------------------------
elixir              405.0 µs    639.2 µs     5.38 ms           —
zig                 404.0 µs    551.1 µs     1.78 ms       0.86x
c                   401.0 µs    541.6 µs     1.38 ms       0.85x
