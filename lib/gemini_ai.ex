defmodule GeminiAI do
  @moduledoc """
  A client for interacting with Google AI models using the Req HTTP client.
  """

  require Logger
  alias GeminiAI.Response
  alias GeminiAI.Files

  @base_url "https://generativelanguage.googleapis.com/v1beta"

  @generate_content_schema [
    inline_data: [
      type: {:map, :string, :string},
      doc: "Map of MIME type to base64 encoded data",
      default: %{}
    ],
    contents: [
      type: {:list, :map},
      doc: "List of content objects with parts and optional roles",
      required: false
    ],
    response_schema: [
      type: {:or, [{:map, :string, :any}, :map]},
      doc: "JSON schema for structured responses",
      required: false
    ]
  ]

  @doc """
  Runs inference with a specified Google AI model.
  Generates content based on the given model and prompt, returning a structured Response.

  ## Options
    * `:inline_data` - Map of MIME type to base64 encoded data. Example: `%{"audio/mp3" => "base64data"}`
    * `:contents` - List of content objects with parts and optional roles for chat-like interactions
    * `:response_schema` - JSON schema for structured responses

  ## Examples

      iex> {:ok, response} = GeminiAI.generate_content("gemini-1.5-flash-latest", "Explain how AI works")
      iex> %GeminiAI.Response{candidates: [%GeminiAI.Response.Candidate{content: %GeminiAI.Response.Content{parts: [%GeminiAI.Response.Part{text: explanation}]}}]} = response
      iex> String.starts_with?(explanation, "AI, or Artificial Intelligence,")
      true

      # With inline data
      iex> audio_data = File.read!("audio.mp3") |> Base.encode64()
      iex> {:ok, response} = GeminiAI.generate_content(
      ...>   client,
      ...>   "gemini-1.5-pro",
      ...>   "Describe this audio",
      ...>   inline_data: %{"audio/mp3" => audio_data}
      ...> )
      iex> %GeminiAI.Response{candidates: [%GeminiAI.Response.Candidate{}]} = response

      # With contents format for chat
      iex> contents = [
      ...>   %{role: "user", parts: [%{text: "Hello"}]},
      ...>   %{role: "model", parts: [%{text: "Hi! How can I help you today?"}]},
      ...>   %{role: "user", parts: [%{text: "What's the weather like?"}]}
      ...> ]
      iex> {:ok, response} = GeminiAI.generate_content(client, "gemini-1.5-pro", contents: contents)
  """

  def generate_content(client \\ new(), model, prompt, opts \\ [])

  def generate_content(client, model, prompt, opts) when is_binary(prompt) do
    log(:info, "Generating content with model: #{model}")
    validated_opts = validate_opts(opts)

    request_body =
      case validated_opts do
        %{contents: contents} when is_list(contents) ->
          %{contents: contents}
          |> maybe_add_generation_config(validated_opts)

        %{inline_data: inline_data} when map_size(inline_data) > 0 ->
          parts =
            Enum.map(inline_data, fn {mime_type, data} ->
              %{
                inline_data: %{
                  mime_type: mime_type,
                  data: data
                }
              }
            end) ++ [%{text: prompt}]

          %{contents: [%{parts: parts}]}
          |> maybe_add_generation_config(validated_opts)

        _ ->
          %{contents: [%{parts: [%{text: prompt}]}]}
          |> maybe_add_generation_config(validated_opts)
      end

    generate_content_request(client, model, request_body, validated_opts)
  end

  def generate_content(client, model, request_body, opts) when is_map(request_body) do
    validated_opts = validate_opts(opts)
    request_body = maybe_add_generation_config(request_body, validated_opts)
    generate_content_request(client, model, request_body, validated_opts)
  end

  defp validate_opts(opts) do
    NimbleOptions.validate!(opts, @generate_content_schema) |> Map.new()
  end

  defp generate_content_request(client, model, body, opts) do
    log(:debug, "Making request to Gemini API with model: #{model} with body: #{inspect(body)}")

    url = "#{@base_url}/models/#{model}:generateContent"

    client
    |> post_request(url, body)
    |> process_response(opts)
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
      retry: :transient
    )
  end

  def upload_file(client, path, opts \\ []) do
    GeminiAI.Files.upload_file(client, path, opts)
  end

  def upload_files(client, paths, opts \\ []) do
    GeminiAI.Files.upload_files(client, paths, opts)
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

  defp process_response({:ok, %{status: 200, body: body}}, opts) do
    log(:debug, "Successfully received response from Gemini API")

    response = Response.from_map(body)

    case opts do
      %{response_schema: schema} when is_map(schema) ->
        with %Response{candidates: [candidate]} <- response,
             %Response.Candidate{content: %Response.Content{parts: [%Response.Part{text: text}]}} <-
               candidate,
             {:ok, json} <- Jason.decode(text) do
          candidate = put_in(candidate.content.parts, [%Response.Part{text: json}])
          {:ok, %{response | candidates: [candidate]}}
        else
          _ -> {:ok, response}
        end

      _ ->
        {:ok, response}
    end
  end

  defp process_response({:ok, %{status: status, body: body}}, _opts) do
    log(:error, "Error response from Gemini API: HTTP #{status}")
    {:error, "HTTP #{status}: #{inspect(body)}"}
  end

  defp process_response({:error, _} = error, _opts) do
    log(:error, "Error making request to Gemini API: #{inspect(error)}")
    error
  end

  defp maybe_add_generation_config(request_body, %{response_schema: schema})
       when not is_nil(schema) do
    Map.put(request_body, :generationConfig, %{
      response_mime_type: "application/json",
      response_schema: schema
    })
  end

  defp maybe_add_generation_config(request_body, _), do: request_body

  defp log(level, message) do
    configured_level = Application.get_env(:geminiex, :log_level, :info)

    if should_log?(level, configured_level) do
      Logger.log(level, message)
    end
  end

  defp should_log?(level, configured_level) do
    level_priority = %{
      debug: 0,
      info: 1,
      warn: 2,
      error: 3
    }

    Map.get(level_priority, level, 4) >= Map.get(level_priority, configured_level, 1)
  end
end
