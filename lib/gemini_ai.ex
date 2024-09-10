defmodule GeminiAI do
  @moduledoc """
  A client for interacting with Google AI models using the Req HTTP client.
  """

  @base_url "https://generativelanguage.googleapis.com/v1beta"

  @doc """
  Runs inference with a specified Google AI model.
  Generates content based on the given model and prompt.

  ## Examples

      iex> GeminiAI.generate_content("gemini-1.5-flash-latest", "Explain how AI works")
      {:ok, %{...}}
  """
  @spec generate_content(String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def generate_content(client \\ new(), model, prompt) do
    client
    |> IO.inspect()
    |> Req.post(
      url: "/models/#{model}:generateContent",
      json: %{
        contents: [
          %{
            parts: [
              %{text: prompt}
            ]
          }
        ]
      }
    )
    |> process_response()
  end

  def new(opts \\ []) do
    api_key = Keyword.get_lazy(opts, :api_key, &fetch_api_key/0)

    Req.new(
      base_url: @base_url,
      params: [key: api_key],
      retry: :transient,
      json: true
    )
  end

  defp fetch_api_key do
    Application.fetch_env(:gemini_ai, :api_key)
  end

  defp process_response({:ok, %{status: 200, body: body}}), do: {:ok, body}

  defp process_response({:ok, %{status: status, body: body}}) do
    {:error, "HTTP #{status}: #{inspect(body)}"}
  end

  defp process_response({:error, _} = error), do: error
end
