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

  @list_schema [
    page_size: [
      type: :integer,
      doc: "The maximum number of files to return"
    ],
    page_token: [
      type: :string,
      doc: "A page token received from a previous list call"
    ]
  ]

  @doc """
  Uploads a file to the Google AI file service using a resumable upload protocol.

  ## Examples

      iex> {:ok, file} = GeminiAI.Files.upload_file("path/to/file.pdf")
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
      {:ok, %Req.Response{} = response} =
        Req.post(client,
          url: "/v1beta/files",
          headers: [
            {"X-Goog-Upload-Protocol", "resumable"},
            {"X-Goog-Upload-Command", "start"},
            {"X-Goog-Upload-Header-Content-Length", to_string(file_stats.size)},
            {"X-Goog-Upload-Header-Content-Type", mime_type}
          ],
          json: %{
            file: %{
              display_name: display_name
            }
          }
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
  def list(client, opts \\ []) do
    with {:ok, validated_opts} <- NimbleOptions.validate(opts, @list_schema) do
      client
      |> Req.get(url: "/files", params: Map.new(validated_opts))
      |> process_response(fn %{"files" => files} -> files end)
    end
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
  def get(client, name) do
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
  def delete(client, name) do
    name = if String.contains?(name, "/"), do: name, else: "files/#{name}"

    client
    |> Req.delete(url: "/#{name}")
    |> process_response(fn _ -> :ok end)
  end

  @doc """
  Uploads multiple files in parallel to the Google AI file store.

  ## Examples

      iex> paths = ["path/to/file1.pdf", "path/to/file2.jpg"]
      iex> {:ok, files} = GeminiAI.Files.upload_files(client, paths)
      iex> length(files) == 2
      true
  """
  @spec upload_files(Req.Request.t() | keyword(), [String.t()], keyword()) ::
          {:ok, [ResponseFile.t()]} | {:error, any()}
  def upload_files(client, paths, opts \\ []) do
    result =
      Task.async_stream(
        paths,
        fn path -> upload_file(client, path, opts) end,
        ordered: true
      )
      |> Enum.reduce_while(
        {:ok, []},
        fn
          {:ok, {:ok, file}}, {:ok, acc} -> {:cont, {:ok, [file | acc]}}
          {:ok, {:error, reason}}, _ -> {:halt, {:error, reason}}
          {:exit, reason}, _ -> {:halt, {:error, reason}}
        end
      )

    case result do
      {:ok, files} -> {:ok, Enum.reverse(files)}
      {:error, _} = error -> error
    end
  end

  @spec process_response({:ok, Req.Response.t()} | {:error, any()}, (map() -> any())) ::
          {:ok, any()} | {:error, any()}
  defp process_response({:ok, %{status: 200, body: body}}, on_success \\ & &1) do
    {:ok, on_success.(body)}
  end

  defp process_response({:ok, %{status: status, body: body}} = response, _) do
    Logger.error("HTTP #{status}: #{inspect(body)}")
    {:error, "HTTP #{status}: #{inspect(body)}"}
  end

  defp process_response({:error, _} = error, _), do: error
end
