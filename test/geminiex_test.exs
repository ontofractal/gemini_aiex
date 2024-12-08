defmodule GeminiexTest do
  use ExUnit.Case
  # doctest Geminiex

  setup_all do
    api_key = System.get_env("GEMINI_API_KEY")
    test_client = GeminiAI.new(api_key: api_key)
    %{test_client: test_client}
  end

  describe "generate_content/4" do
    test "generates text content", %{test_client: test_client} do
      {:ok, response} =
        GeminiAI.generate_content(
          test_client,
          "gemini-1.5-flash-latest",
          "Return this exact string without the backticks: `hello world`"
        )

      %GeminiAI.Response{candidates: [candidate]} = response
      %GeminiAI.Response.Candidate{content: %GeminiAI.Response.Content{parts: [part]}} = candidate
      %GeminiAI.Response.Part{text: text} = part

      assert String.trim(text) == "hello world"
    end

    test "generates content with chat-like format", %{test_client: test_client} do
      contents = [
        %{role: "user", parts: [%{text: "Hello"}]},
        %{role: "model", parts: [%{text: "Hi! How can I help you today?"}]},
        %{role: "user", parts: [%{text: "What's 2+2?"}]}
      ]

      {:ok, response} =
        GeminiAI.generate_content(
          test_client,
          "gemini-1.5-flash-latest",
          nil,
          contents: contents
        )

      assert %GeminiAI.Response{candidates: [candidate]} = response

      assert %GeminiAI.Response.Candidate{content: %GeminiAI.Response.Content{parts: [part]}} =
               candidate

      assert %GeminiAI.Response.Part{text: text} = part
      assert is_binary(text)
      assert String.contains?(String.downcase(text), "4")
    end

    test "generates content with mixed parts", %{test_client: test_client} do
      image_data =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

      contents = [
        %{
          parts: [
            %{text: "What's in this image?"},
            %{
              inline_data: %{
                mime_type: "image/png",
                data: image_data
              }
            }
          ]
        }
      ]

      {:ok, response} =
        GeminiAI.generate_content(
          test_client,
          "gemini-1.5-flash-latest",
          nil,
          contents: contents
        )

      assert %GeminiAI.Response{candidates: [candidate]} = response

      assert %GeminiAI.Response.Candidate{content: %GeminiAI.Response.Content{parts: [part]}} =
               candidate

      assert %GeminiAI.Response.Part{text: text} = part
      assert is_binary(text)
    end

    test "generates content with inline audio data", %{test_client: test_client} do
      audio_data = File.read!("test/fixtures/sample-3.ogg") |> Base.encode64()

      {:ok, response} =
        GeminiAI.generate_content(
          test_client,
          "gemini-1.5-flash",
          "Is there any speech in this audio? Answer with 'yes' or 'no'.",
          inline_data: %{"audio/ogg" => audio_data}
        )

      assert %GeminiAI.Response{candidates: [candidate]} = response

      assert %GeminiAI.Response.Candidate{content: %GeminiAI.Response.Content{parts: [part]}} =
               candidate

      assert %GeminiAI.Response.Part{text: text} = part
      assert String.trim(String.downcase(text)) in ["yes", "no"]
    end

    test "generates content with multiple inline data", %{test_client: test_client} do
      audio_data = File.read!("test/fixtures/sample-3.ogg") |> Base.encode64()

      image_data =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

      {:ok, response} =
        GeminiAI.generate_content(
          test_client,
          "gemini-1.5-flash",
          "Please describe these contents.",
          inline_data: %{
            "audio/ogg" => audio_data,
            "image/png" => image_data
          }
        )

      assert %GeminiAI.Response{candidates: [candidate]} = response

      assert %GeminiAI.Response.Candidate{content: %GeminiAI.Response.Content{parts: [part]}} =
               candidate

      assert %GeminiAI.Response.Part{text: text} = part
      assert is_binary(text)
    end

    test "raises error with invalid inline data", %{test_client: test_client} do
      assert_raise NimbleOptions.ValidationError, fn ->
        GeminiAI.generate_content(
          test_client,
          "gemini-1.5-flash",
          "Please describe this content.",
          inline_data: %{"audio/ogg" => 123}
        )
      end
    end
  end

  describe "upload_file/3" do
    test "uploads a PDF file successfully", %{test_client: test_client} do
      pdf_path = "test/fixtures/test.pdf"

      assert {:ok, response} = GeminiAI.upload_file(test_client, pdf_path)
      assert response.display_name == "test.pdf"
    end
  end
end
