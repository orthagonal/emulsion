defmodule Emulsion.PlaygraphTest do
  use ExUnit.Case, async: true

  alias Emulsion.Playgraph

  @moduletag :capture_log

  setup do
    # {:ok, _} = Playgraph.start_link([])
    :ok
  end

  test ":export_playgraph exports playgraph and all its assets to a specified folder" do
    filename = "test.playgraph"
    folder_path = "./test/export_to"
    assets_path = Path.join(folder_path, "assets")

    # Stub out your nodes and edges here
    node1 = "node1"
    node2 = "node2"
    node3 = "node3"
    edge1 = %{"path" => "./test/data/test1.webm"}
    edge2 = %{"path" => "./test/data/test2.webm"}

    # Add nodes and edges
    assert :ok = Playgraph.add_node(node1)
    assert :ok = Playgraph.add_node(node2)
    assert :ok = Playgraph.add_node(node3)
    assert :ok = Playgraph.add_edge(node1, node2, "edge1", edge1["path"])
    assert :ok = Playgraph.add_edge(node2, node3, "edge2", edge2["path"])

    # Create directory if it doesn't exist
    File.mkdir_p(folder_path)

    # Save initial playgraph
    assert :ok = Playgraph.save(filename)

    # Ensure the directory is clean for the test
    File.rm_rf(assets_path)

    # # Call the function
    assert :ok = Playgraph.export_playgraph(folder_path)

    # Verify the .playgraph file is saved
    assert File.exists?(Path.join(folder_path, "main.playgraph"))

    # # Verify that assets directory is created
    assert File.dir?(assets_path)

    # Verify that the .webm files have been copied
    [edge1, edge2]
    |> Enum.map(& &1["path"])
    |> Enum.each(fn path ->
      assert File.exists?(Path.join(assets_path, Path.basename(path)))
    end)

    # # Clean up
    # File.rm_rf(folder_path)
  end
end
