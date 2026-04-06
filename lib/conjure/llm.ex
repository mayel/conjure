defmodule Conjure.LLM do
  require Logger

  def call!(prompt, opts \\ []) do
    model = opts[:model] || Application.get_env(:conjure, :default_ollama_model, "starcoder2:15b")
    base  = Application.get_env(:conjure, :ollama_url, "http://localhost:11434")

    Logger.info("[Conjure] Calling #{model} via Ollama...")

    with %{body: %{"response" => response}} when is_binary(response) <- Req.post!("#{base}/api/generate",
      json: %{model: model, prompt: prompt, stream: false},
      receive_timeout: 120_000
    ) do
      String.trim(response)
    else other ->
      IO.inspect(other)
      raise "Invalid response from Ollama ^^"
    end
  end
end
