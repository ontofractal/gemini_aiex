defmodule GeminiAI.Files do
  @moduledoc """
  A module for handling file operations with the Google AI file service.
  """

  @base_url "https://generativelanguage.googleapis.com/v1beta"

  @type t :: %__MODULE__{
          name: String.t(),
          mimeType: String.t(),
          size: non_neg_integer(),
          displayName: String.t(),
          createTime: String.t(),
          updateTime: String.t()
        }

  @doc """
  Uploads a file to the Google AI file service.

  ## Examples

      iex> GeminiAI.File.upload("path/to/image.jpg")
      {:ok, %GeminiAI.File{...}}

  """
  @spec upload(String.t(), keyword()) :: {:ok, t()} | {:error, any()}
  def upload(path, opts \\ []) do
    api_key = Application.fetch_env!(:gemini_ai, :api_key)
    url = "#{@base_url}/files"

    mime_type = opts[:mime_type] || MIME.from_path(path)
    name = opts[:name] || "files/#{Path.basename(path)}"
    display_name = opts[:display_name] || Path.basename(path)

    body = %{
      mimeType: mime_type,
      name: name,
      displayName: display_name
    }

    headers = [
      {"Content-Type", "application/json"}
    ]

    url
    |> Req.post(json: body, headers: headers, params: %{key: api_key})
    |> process_response(&from_response/1)
  end

  @doc """
  Lists files from the Google AI file service.

  ## Examples

      iex> GeminiAI.File.list()
      {:ok, [%GeminiAI.File{...}, ...]}

  """
  @spec list(keyword()) :: {:ok, [t()]} | {:error, any()}
  def list(opts \\ []) do
    api_key = Application.fetch_env!(:gemini_ai, :api_key)
    url = "#{@base_url}/files"

    params = Map.merge(%{key: api_key}, Map.new(opts))

    url
    |> Req.get(params: params)
    |> process_response(fn %{"files" => files} -> Enum.map(files, &from_response/1) end)
  end

  @doc """
  Retrieves a specific file from the Google AI file service.

  ## Examples

      iex> GeminiAI.File.get("files/sample-image")
      {:ok, %GeminiAI.File{...}}

  """
  @spec get(String.t()) :: {:ok, t()} | {:error, any()}
  def get(name) do
    api_key = Application.fetch_env!(:gemini_ai, :api_key)
    name = if String.contains?(name, "/"), do: name, else: "files/#{name}"
    url = "#{@base_url}/#{name}"

    url
    |> Req.get(params: %{key: api_key})
    |> process_response(&from_response/1)
  end

  @doc """
  Deletes a specific file from the Google AI file service.

  ## Examples

      iex> GeminiAI.File.delete("files/sample-image")
      :ok

  """
  @spec delete(String.t()) :: :ok | {:error, any()}
  def delete(name) do
    api_key = Application.fetch_env!(:gemini_ai, :api_key)
    name = if String.contains?(name, "/"), do: name, else: "files/#{name}"
    url = "#{@base_url}/#{name}"

    url
    |> Req.delete(params: %{key: api_key})
    |> process_response(fn _ -> :ok end)
  end

  defp process_response(result, on_success \\ & &1) do
    case result do
      {:ok, %{status: 200, body: body}} ->
        {:ok, on_success.(body)}

      {:ok, %{status: status, body: error_body}} ->
        {:error, "HTTP #{status}: #{inspect(error_body)}"}

      {:error, error} ->
        {:error, error}
    end
  end

  defp from_response(response) do
    struct(__MODULE__, response)
  end

  defstruct [:name, :mimeType, :size, :displayName, :createTime, :updateTime]
end
