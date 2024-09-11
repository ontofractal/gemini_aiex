defmodule GeminiAI.Files do
  @moduledoc """
  A module for handling file operations with the Google AI file service.
  """

  defmodule ResponseFile do
    defstruct [
      :create_time,
      :display_name,
      :expiration_time,
      :mime_type,
      :name,
      :sha256_hash,
      :size_bytes,
      :state,
      :update_time,
      :uri
    ]

    def new(map) do
      %__MODULE__{
        create_time: map["createTime"],
        display_name: map["displayName"],
        expiration_time: map["expirationTime"],
        mime_type: map["mimeType"],
        name: map["name"],
        sha256_hash: map["sha256Hash"],
        size_bytes: String.to_integer(map["sizeBytes"]),
        state: map["state"],
        update_time: map["updateTime"],
        uri: map["uri"]
      }
    end
  end

  require Logger
  alias GeminiAI.Files.Response

  @base_url "https://generativelanguage.googleapis.com/upload/"

  @upload_schema [
    mime_type: [
      type: :string,
      doc: "The MIME type of the file"
    ],
    name: [
      type: :string,
      doc: "The name of the file in the Google AI file service"
    ],
    display_name: [
      type: :string,
      doc: "The display name of the file"
    ]
  ]


  @doc """
  Uploads a file to the Google AI file service.

  ## Examples

      iex> {:ok, file} = GeminiAI.Files.upload("path/to/image.jpg")
      iex> %GeminiAI.Files.Response{name: name, mimeType: mime_type} = file
      iex> String.starts_with?(name, "files/")
      true
  """
  @spec upload_file(Req.Request.t() | keyword(), String.t(), keyword()) ::
          {:ok, Response.t()} | {:error, any()}
  def upload_file(client, path, opts \\ []) do
    client = Req.merge(client, base_url: @base_url)

    with {:ok, validated_opts} <- NimbleOptions.validate(opts, @upload_schema),
         {:ok, file_stats} <- File.stat(path),
         mime_type <- validated_opts[:mime_type] || MIME.from_path(path),
         display_name <- validated_opts[:display_name] || Path.basename(path) do
      metadata = %{
        file: %{
          display_name: display_name
        }
      }

      {:ok, %Req.Response{} = response} =
        Req.post(client,
          url: "/v1beta/files",
          headers: [
            {"X-Goog-Upload-Protocol", "resumable"},
            {"X-Goog-Upload-Command", "start"},
            {"X-Goog-Upload-Header-Content-Length", to_string(file_stats.size)},
            {"X-Goog-Upload-Header-Content-Type", mime_type}
          ],
          json: metadata
        )

      [upload_url] = Req.Response.get_header(response, "x-goog-upload-url")
      file_body = File.read!(path)

      client_upload = Req.new(params: client.options.params)

      # Upload the actual bytes
      {:ok, %Req.Response{status: 200, body: %{"file" => file_data}}} =
        Req.post(
          client_upload,
          url: upload_url,
          headers: [
            {"Content-Length", to_string(file_stats.size)},
            {"X-Goog-Upload-Offset", "0"},
            {"X-Goog-Upload-Command", "upload, finalize"}
          ],
          body: file_body
        )

      {:ok, ResponseFile.new(file_data)}
    end
  end

  @doc """
  Lists files from the Google AI file service.

  ## Examples

      iex> {:ok, files} = GeminiAI.Files.list()
      iex> [%GeminiAI.Files.Response{} | _] = files
      iex> length(files) > 0
      true
  """
  @spec list(Req.Request.t() | keyword(), keyword()) :: {:ok, [Response.t()]} | {:error, any()}
  def list(client \\ new(), opts \\ []) do
    client
    |> Req.get(url: "/files", params: Map.new(opts))
    |> process_response(fn %{"files" => files} -> Enum.map(files, &Response.from_map/1) end)
  end

  @doc """
  Retrieves a specific file from the Google AI file service.

  ## Examples

      iex> {:ok, file} = GeminiAI.Files.get("files/sample-image")
      iex> %GeminiAI.Files.Response{name: "files/sample-image"} = file
      iex> is_binary(file.mimeType)
      true
  """
  @spec get(Req.Request.t() | keyword(), String.t()) :: {:ok, Response.t()} | {:error, any()}
  def get(client \\ new(), name) do
    name = if String.contains?(name, "/"), do: name, else: "files/#{name}"

    client
    |> Req.get(url: "/#{name}")
    |> process_response()
  end

  @doc """
  Deletes a specific file from the Google AI file service.

  ## Examples

      iex> GeminiAI.Files.delete("files/sample-image")
      :ok
  """
  @spec delete(Req.Request.t() | keyword(), String.t()) :: :ok | {:error, any()}
  def delete(client \\ new(), name) do
    name = if String.contains?(name, "/"), do: name, else: "files/#{name}"

    client
    |> Req.delete(url: "/#{name}")
    |> process_response(fn _ -> :ok end)
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
    Application.fetch_env!(:gemini_ai, :api_key)
  end

  defp process_response({:ok, %{status: 200, body: body}}, on_success \\ &Response.from_map/1) do
    {:ok, on_success.(body)}
  end

  defp process_response({:ok, %{status: status, body: body}}, _) do
    {:error, "HTTP #{status}: #{inspect(body)}"}
  end

  defp process_response({:error, _} = error, _), do: error
end
