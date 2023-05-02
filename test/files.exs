defmodule Emulsion.FilesTest do
  use ExUnit.Case
  alias Emulsion.Files

  test "set_workspace_folder should set the workspace folder" do
    {:ok, state} = Files.init(%{})
    assert state == %{workspace_folder: ""}

    # Test valid disk path
    { :ok, new_state } = Files.handle_call({:set_workspace_folder, "/tmp/test", :disk}, nil, state)
    assert new_state == %{workspace_folder: "/tmp/test"}

    # Test valid browser path
    { :ok, new_state } = Files.handle_call({:set_workspace_folder, "/test", :browser}, nil, state)
    assert new_state == %{workspace_folder: "/test"}

    # Test invalid path type
    { :error, _ } = Files.handle_call({:set_workspace_folder, "/test", :invalid}, nil, state)
  end

  test "get_file_list should return a list of files in a directory" do
    {:ok, state} = Files.init(%{})
    { :ok, new_state } = Files.handle_call({:set_workspace_folder, "/tmp/test", :disk}, nil, state)
    File.write!("/tmp/test/test.txt", "")

    { :ok, file_list } = Files.handle_call({:get_file_list, :workspace_folder}, nil, new_state)
    # make sure it contains "test.txt"
    assert Enum.member?(file_list, "test.txt")

    File.write!("/tmp/test/frames/test.txt", "")
    { :ok, frame_list } = Files.handle_call({:get_file_list, :frame_folder}, nil, new_state)
    # make sure it contains "test.txt"
    assert Enum.member?(file_list, "test.txt")

  end

  test "get_file_path should return the path to a file in a directory" do
    {:ok, state} = Files.init(%{})
    { :ok, new_state } = Files.handle_call({:set_workspace_folder, "/tmp/test", :disk}, nil, state)
    File.write!("/tmp/test/test.txt", "")

    { :ok, file_path } = Files.handle_call({:get_file_path, "test.txt", :workspace_folder, :disk}, nil, new_state)
    IO.inspect(file_path)
    assert file_path == "/tmp/test/test.txt"

    { :ok, file_path } = Files.handle_call({:get_file_path, "test.txt", :workspace_folder, :browser}, nil, new_state)
    assert file_path == "/file/workspace_folder/test.txt"
  end
end
