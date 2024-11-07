defmodule GeminiAI do
  @moduledoc """
  A client for interacting with Google AI models using the Req HTTP client.
  """

  alias GeminiAI.Response
  alias GeminiAI.Files

  @base_url "https://generativelanguage.googleapis.com/v1beta"

  @doc """
  Runs inference with a specified Google AI model.
  Generates content based on the given model and prompt, returning a structured Response.

  ## Examples

      iex> {:ok, response} = GeminiAI.generate_content("gemini-1.5-flash-latest", "Explain how AI works")
      iex> %GeminiAI.Response{candidates: [%GeminiAI.Response.Candidate{content: %GeminiAI.Response.Content{parts: [%GeminiAI.Response.Part{text: explanation}]}}]} = response
      iex> String.starts_with?(explanation, "AI, or Artificial Intelligence,")
      true

      iex> request_body = %{
      ...>   contents: [
      ...>     %{
      ...>       parts: [
      ...>         %{
      ...>           fileData: %{
      ...>             fileUri: "https://example.com/file.pdf",
      ...>             mimeType: "application/pdf"
      ...>           }
      ...>         },
      ...>         %{
      ...>           text: "Summarize this PDF."
      ...>         }
      ...>       ]
      ...>     }
      ...>   ]
      ...> }
      iex> {:ok, response} = GeminiAI.generate_content(client, "gemini-1.5-pro", request_body)
      iex> %GeminiAI.Response{candidates: [%GeminiAI.Response.Candidate{}]} = response
  """

  def generate_content(client \\ new(), model, prompt, _opts \\ [])

  def generate_content(client, model, prompt, _) when is_binary(prompt) do
    generate_content_request(client, model, %{contents: [%{parts: [%{text: prompt}]}]})
  end

  def generate_content(client, model, prompt, _) when is_map(prompt) do
    generate_content_request(client, model, prompt)
  end

  def generate_content(client, model, prompt, opts) do
    file_names = Keyword.get(opts, :file_names, [])

    parts =
      [%{text: prompt}] ++
        Enum.map(file_names, fn file_name ->
          {:ok, file} = Files.get(client, file_name)
          %{file_data: %{file_uri: file.uri, mime_type: file.mime_type}}
        end)

    generate_content_request(client, model, %{contents: [%{parts: parts}]})
  end

  defp generate_content_request(client, model, body) do
    post_request(client, "/models/#{model}:generateContent", body)
    |> case do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, Response.from_map(body)}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      error ->
        error
    end
  end

  def handle_response(response) do
    with {:ok, response} <- response,
         %GeminiAI.Response{candidates: [candidate]} <- response,
         %GeminiAI.Response.Candidate{content: %GeminiAI.Response.Content{parts: [part]}} <-
           candidate,
         %GeminiAI.Response.Part{text: text} <- part do
      {:ok, text}
    end
  end

  def post_request(client, url, body) do
    client
    |> Req.post(url: url, json: body)
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

  def upload_file(client, path, opts \\ []) do
    GeminiAI.Files.upload_file(client, path, opts)
  end

  def get_text(%Response{
        candidates: [
          %Response.Candidate{content: %Response.Content{parts: [%Response.Part{text: text}]}}
        ]
      }) do
    text
  end

  defp fetch_api_key do
    Application.fetch_env(:gemini_ai, :api_key)
  end

  defp process_response({:ok, %{status: 200, body: body}}), do: {:ok, Response.from_map(body)}

  defp process_response({:ok, %{status: status, body: body}}) do
    {:error, "HTTP #{status}: #{inspect(body)}"}
  end

  defp process_response({:error, _} = error), do: error
end
