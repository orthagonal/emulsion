defmodule Emulsion.PlaygraphTest do
  use ExUnit.Case
  alias Emulsion.Playgraph
  alias Jason, as: Json

  test "save and load playgraph" do
    # Prepare mock data
    mock_nodes = [
      %{
        "edges" => [],
        "id" => "e:/emulsion_workspace/MVI_5979/frames/img_0012.png",
        "label" => "img_0012.png",
        "name" => "e:/emulsion_workspace/MVI_5979/frames/img_0012.png"
      },
      %{
        "edges" => [],
        "id" => "e:/emulsion_workspace/MVI_5979/frames/img_0001.png",
        "label" => "img_0001.png",
        "name" => "e:/emulsion_workspace/MVI_5979/frames/img_0001.png"
      }
    ]
    mock_edges = [
      %{
        "destination" => "e:/emulsion_workspace/MVI_5979/frames/img_0001.png",
        "from" => "e:/emulsion_workspace/MVI_5979/frames/img_0012.png",
        "fromPath" => "/file/MVI_5979/frames/img_0012.png",
        "id" => "img_0012_to_img_0001.webm",
        "path" => "/file/MVI_5979/tweens/img_0012_to_img_0001.webm",
        "to" => "e:/emulsion_workspace/MVI_5979/frames/img_0001.png",
        "toPath" => "/file/MVI_5979/frames/img_0001.png"
      },
      %{
        "destination" => "e:/emulsion_workspace/MVI_5979/frames/img_0012.png",
        "from" => "e:/emulsion_workspace/MVI_5979/frames/img_0001.png",
        "fromPath" => "/file/MVI_5979/frames/img_0001.png",
        "id" => "1_thru_12.webm",
        "path" => "/file/MVI_5979/output/1_thru_12.webm",
        "to" => "e:/emulsion_workspace/MVI_5979/frames/img_0012.png",
        "toPath" => "/file/MVI_5979/frames/img_0012.png"
      }
    ]

    filepath = "./test/test_save.json"

    # Initialize Playgraph
    {_, _pid} = Playgraph.start_link([])
    mock_nodes |> Enum.each(fn node -> Playgraph.add_node(node["id"]) end)

    # Add edges
    for edge <- mock_edges do
      Playgraph.add_edge(edge["from"], edge["to"], edge["id"], "the_file.webm")
    end
    initial_nodes = Playgraph.get_nodes()
    initial_edges = Playgraph.get_edges()

    # Save state to file
    Playgraph.save(filepath)
    # Reset state
    Playgraph.reset()
    assert Playgraph.get_nodes() == []
    assert Playgraph.get_edges() == []

    # Load state from file
    load_result = Playgraph.load(filepath)
    assert load_result == :ok
    assert Playgraph.get_nodes() == initial_nodes
    assert Playgraph.get_edges() == initial_edges

    # # Cleanup
    File.rm(filepath)
  end
end
