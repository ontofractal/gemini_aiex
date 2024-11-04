defmodule GeminiexTest do
  use ExUnit.Case
  # doctest Geminiex

  setup_all do
    api_key = System.get_env("GEMINI_API_KEY")
    test_client = GeminiAI.new(api_key: api_key)
    %{test_client: test_client}
  end

  describe "generate_content/2" do
    test "generate_content/2", %{test_client: test_client} do
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

    @tag :this
    test "generates content based on uploaded file", %{test_client: test_client} do
      pdf_path = "test/fixtures/test.pdf"

      {:ok, uploaded_file} = GeminiAI.upload_file(test_client, pdf_path)

      request_body =
        %{
          contents: [
            %{
              parts: [
                %{
                  text: "Return all the text in the PDF file."
                },
                %{
                  file_data: %{
                    mime_type: uploaded_file.mime_type,
                    file_uri: uploaded_file.uri
                  }
                }
              ]
            }
          ]
        }

      {:ok, response} =
        GeminiAI.generate_content(test_client, "gemini-1.5-flash-latest", request_body)

      assert %GeminiAI.Response{candidates: [candidate]} = response

      assert %GeminiAI.Response.Candidate{content: %GeminiAI.Response.Content{parts: [part]}} =
               candidate

      assert %GeminiAI.Response.Part{text: summary} = part
      assert String.contains?(summary, "This is a test PDF document.")
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
