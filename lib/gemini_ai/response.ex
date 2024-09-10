defmodule GeminiAI.Response do
  @moduledoc """
  Defines structured types for Gemini AI API responses with snake_case keys.
  """

  defmodule Part do
    @moduledoc "Represents a part of the content"
    use TypedStruct

    typedstruct do
      field(:text, String.t(), enforce: true)
    end
  end

  defmodule Content do
    @moduledoc "Represents the content of a candidate"
    use TypedStruct

    typedstruct do
      field(:parts, [Part.t()], enforce: true)
      field(:role, String.t(), enforce: true)
    end
  end

  defmodule SafetyRating do
    @moduledoc "Represents a safety rating"
    use TypedStruct

    typedstruct do
      field(:category, String.t(), enforce: true)
      field(:probability, String.t(), enforce: true)
    end
  end

  defmodule Candidate do
    @moduledoc "Represents a candidate response"
    use TypedStruct

    typedstruct do
      field(:content, Content.t(), enforce: true)
      field(:finish_reason, String.t(), enforce: true)
      field(:index, non_neg_integer(), enforce: true)
      field(:safety_ratings, [SafetyRating.t()], enforce: true)
    end
  end

  defmodule UsageMetadata do
    @moduledoc "Represents usage metadata"
    use TypedStruct

    typedstruct do
      field(:candidates_token_count, non_neg_integer(), enforce: true)
      field(:prompt_token_count, non_neg_integer(), enforce: true)
      field(:total_token_count, non_neg_integer(), enforce: true)
    end
  end

  @moduledoc "Represents the complete Gemini AI response"
  use TypedStruct

  typedstruct do
    field(:candidates, [Candidate.t()], enforce: true)
    field(:usage_metadata, UsageMetadata.t(), enforce: true)
  end

  @doc """
  Converts a map response from the Gemini AI API into a structured Response with snake_case keys.

  ## Examples

      iex> response = %{
      ...>   "candidates" => [
      ...>     %{
      ...>       "content" => %{
      ...>         "parts" => [%{"text" => "AI explanation"}],
      ...>         "role" => "model"
      ...>       },
      ...>       "finishReason" => "STOP",
      ...>       "index" => 0,
      ...>       "safetyRatings" => [
      ...>         %{"category" => "HARM_CATEGORY_SEXUALLY_EXPLICIT", "probability" => "NEGLIGIBLE"}
      ...>       ]
      ...>     }
      ...>   ],
      ...>   "usageMetadata" => %{
      ...>     "candidatesTokenCount" => 478,
      ...>     "promptTokenCount" => 4,
      ...>     "totalTokenCount" => 482
      ...>   }
      ...> }
      iex> GeminiAI.Response.from_map(response)
      %GeminiAI.Response{
        candidates: [
          %GeminiAI.Response.Candidate{
            content: %GeminiAI.Response.Content{
              parts: [%GeminiAI.Response.Part{text: "AI explanation"}],
              role: "model"
            },
            finish_reason: "STOP",
            index: 0,
            safety_ratings: [
              %GeminiAI.Response.SafetyRating{
                category: "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                probability: "NEGLIGIBLE"
              }
            ]
          }
        ],
        usage_metadata: %GeminiAI.Response.UsageMetadata{
          candidates_token_count: 478,
          prompt_token_count: 4,
          total_token_count: 482
        }
      }
  """
  @spec from_map(map()) :: t()
  def from_map(response) do
    %__MODULE__{
      candidates: Enum.map(response["candidates"], &map_candidate/1),
      usage_metadata: map_usage_metadata(response["usageMetadata"])
    }
  end

  defp map_candidate(candidate) do
    %Candidate{
      content: map_content(candidate["content"]),
      finish_reason: candidate["finishReason"],
      index: candidate["index"],
      safety_ratings: Enum.map(candidate["safetyRatings"], &map_safety_rating/1)
    }
  end

  defp map_content(content) do
    %Content{
      parts: Enum.map(content["parts"], &map_part/1),
      role: content["role"]
    }
  end

  defp map_part(part) do
    %Part{text: part["text"]}
  end

  defp map_safety_rating(rating) do
    %SafetyRating{
      category: rating["category"],
      probability: rating["probability"]
    }
  end

  defp map_usage_metadata(metadata) do
    %UsageMetadata{
      candidates_token_count: metadata["candidatesTokenCount"],
      prompt_token_count: metadata["promptTokenCount"],
      total_token_count: metadata["totalTokenCount"]
    }
  end
end
