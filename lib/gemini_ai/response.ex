defmodule GeminiAI.Response do
  @moduledoc """
  Defines structured types for Gemini AI API responses with snake_case keys.
  """

  defmodule Part do
    @moduledoc "Represents a part of the content"
    use TypedStruct

    typedstruct do
      field(:text, String.t())
      field(:inline_data, map())
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
    field(:usage_metadata, UsageMetadata.t())
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
      candidates: map_candidates(response["candidates"]),
      usage_metadata: map_usage_metadata(response["usageMetadata"])
    }
  end

  defp map_candidates(nil), do: []
  defp map_candidates(candidates), do: Enum.map(candidates, &map_candidate/1)

  defp map_candidate(candidate) do
    %Candidate{
      content: map_content(candidate["content"]),
      finish_reason: candidate["finishReason"] || "UNSPECIFIED",
      index: candidate["index"] || 0,
      safety_ratings: map_safety_ratings(candidate["safetyRatings"])
    }
  end

  defp map_content(content) do
    %Content{
      parts: map_parts(content["parts"]),
      role: content["role"] || "model"
    }
  end

  defp map_parts(nil), do: []
  defp map_parts(parts), do: Enum.map(parts, &map_part/1)

  defp map_part(part) do
    %Part{
      text: part["text"],
      inline_data: part["inlineData"]
    }
  end

  defp map_safety_ratings(nil), do: []
  defp map_safety_ratings(ratings), do: Enum.map(ratings, &map_safety_rating/1)

  defp map_safety_rating(rating) do
    %SafetyRating{
      category: rating["category"],
      probability: rating["probability"]
    }
  end

  defp map_usage_metadata(nil), do: nil

  defp map_usage_metadata(metadata) do
    %UsageMetadata{
      candidates_token_count: metadata["candidatesTokenCount"] || 0,
      prompt_token_count: metadata["promptTokenCount"] || 0,
      total_token_count: metadata["totalTokenCount"] || 0
    }
  end
end
