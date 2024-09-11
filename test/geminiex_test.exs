defmodule GeminiexTest do
  use ExUnit.Case
  # doctest Geminiex

  setup do
    api_key = System.get_env("GEMINI_API_KEY")
    test_client = GeminiAI.new(api_key: api_key)
    %{test_client: test_client}
  end

  test "generate_content/2", %{test_client: test_client} do
    {:ok, response} = GeminiAI.generate_content(
             test_client,
             "gemini-1.5-flash-latest",
             "Return this exact string without the backticks: `hello world`"
           )

    %GeminiAI.Response{candidates: [candidate]} = response
    %GeminiAI.Response.Candidate{content: %GeminiAI.Response.Content{parts: [part]}} = candidate
    %GeminiAI.Response.Part{text: text} = part

    assert String.trim( text) == "hello world"

  describe "upload_file/3" do
    @tag :this
    test "uploads a PDF file successfully", %{test_client: test_client} do
      pdf_path = "test/fixtures/test.pdf"

      assert {:ok, response} = GeminiAI.upload_file(test_client, pdf_path)
      assert response.display_name == "test.pdf"
    end
  end
end
