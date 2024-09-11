defmodule GeminiAI.Files do
  @moduledoc """
  A module for handling file operations with the Google AI file service.
  """

  alias GeminiAI.Files.Response

  @base_url "https://generativelanguage.googleapis.com/v1beta"

  @doc """
  Uploads a file to the Google AI file service.

  ## Examples

      iex> {:ok, file} = GeminiAI.Files.upload("path/to/image.jpg")
      iex> %GeminiAI.Files.Response{name: name, mimeType: mime_type} = file
      iex> String.starts_with?(name, "files/")
      true
  """
  @spec upload(Req.Request.t() | keyword(), String.t(), keyword()) ::
          {:ok, Response.t()} | {:error, any()}
  def upload(client \\ new(), path, opts \\ []) do
    mime_type = opts[:mime_type] || MIME.from_path(path)
    name = opts[:name] || "files/#{Path.basename(path)}"
    display_name = opts[:display_name] || Path.basename(path)

    body = %{
      mimeType: mime_type,
      name: name,
      displayName: display_name
    }

    client
    |> Req.post(url: "/files", json: body)
    |> process_response()
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
