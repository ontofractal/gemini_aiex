defmodule GeminiAI.FilesTest do
  use ExUnit.Case
  alias GeminiAI.Files

  setup do
    api_key = System.get_env("GEMINI_API_KEY")
    test_client = GeminiAI.new(api_key: api_key)
    %{test_client: test_client}
  end

  describe "upload_files/3" do
    test "uploads multiple files in parallel", %{test_client: test_client} do
      paths = [
        "test/fixtures/test.pdf",
        "test/fixtures/example.ogg"
      ]

      {:ok, files} = Files.upload_files(test_client, paths)
      assert length(files) == 2
      assert Enum.all?(files, &match?(%Files.ResponseFile{}, &1))
      assert Enum.all?(files, &(&1.display_name in ["test.pdf", "example.ogg"]))
    end

    test "handles errors gracefully", %{test_client: test_client} do
      paths = [
        "test/fixtures/test.pdf",
        "non_existent_file.pdf"
      ]

      assert {:error, _reason} = Files.upload_files(test_client, paths)
    end
  end
end
