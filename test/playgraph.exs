defmodule Emulsion.PlaygraphTest do
  use ExUnit.Case
  alias Emulsion.Playgraph
  alias Jason, as: Json

  @tag timeout: :infinity

  # test "save and load playgraph" do
  #   # Prepare mock data
  #   mock_nodes = [
  #     %{
  #       "edges" => [],
  #       "id" => "e:/emulsion_workspace/MVI_5979/frames/img_0012.png",
  #       "label" => "img_0012.png",
  #       "name" => "e:/emulsion_workspace/MVI_5979/frames/img_0012.png"
  #     },
  #     %{
  #       "edges" => [],
  #       "id" => "e:/emulsion_workspace/MVI_5979/frames/img_0001.png",
  #       "label" => "img_0001.png",
  #       "name" => "e:/emulsion_workspace/MVI_5979/frames/img_0001.png"
  #     }
  #   ]

  #   mock_edges = [
  #     %{
  #       "destination" => "e:/emulsion_workspace/MVI_5979/frames/img_0001.png",
  #       "from" => "e:/emulsion_workspace/MVI_5979/frames/img_0012.png",
  #       "fromPath" => "/file/MVI_5979/frames/img_0012.png",
  #       "id" => "img_0012_to_img_0001.webm",
  #       "path" => "/file/MVI_5979/tweens/img_0012_to_img_0001.webm",
  #       "to" => "e:/emulsion_workspace/MVI_5979/frames/img_0001.png",
  #       "toPath" => "/file/MVI_5979/frames/img_0001.png"
  #     },
  #     %{
  #       "destination" => "e:/emulsion_workspace/MVI_5979/frames/img_0012.png",
  #       "from" => "e:/emulsion_workspace/MVI_5979/frames/img_0001.png",
  #       "fromPath" => "/file/MVI_5979/frames/img_0001.png",
  #       "id" => "1_thru_12.webm",
  #       "path" => "/file/MVI_5979/output/1_thru_12.webm",
  #       "to" => "e:/emulsion_workspace/MVI_5979/frames/img_0012.png",
  #       "toPath" => "/file/MVI_5979/frames/img_0012.png"
  #     }
  #   ]

  #   filepath = "./test/test_save.json"

  #   # Initialize Playgraph
  #   {_, _pid} = Playgraph.start_link([])
  #   mock_nodes |> Enum.each(fn node -> Playgraph.add_node(node["id"]) end)

  #   # Add edges
  #   for edge <- mock_edges do
  #     Playgraph.add_edge(edge["from"], edge["to"], edge["id"], "the_file.webm")
  #   end

  #   initial_nodes = Playgraph.get_nodes()
  #   initial_edges = Playgraph.get_edges()

  #   # Save state to file
  #   Playgraph.save(filepath)
  #   # Reset state
  #   Playgraph.reset()
  #   assert Playgraph.get_nodes() == []
  #   assert Playgraph.get_edges() == []

  #   # Load state from file
  #   load_result = Playgraph.load(filepath)
  #   assert load_result == :ok
  #   assert Playgraph.get_nodes() == initial_nodes
  #   assert Playgraph.get_edges() == initial_edges

  #   # # Cleanup
  #   File.rm(filepath)
  # end

  test "creates nodes and edges correctly", %{session: socket} do
    # Arrange
    current_frame = "frame1"
    idle_range = 5
    connect_frame = "frame6"

    event_payload = %{
      "current_frame" => current_frame,
      "idle_range" => idle_range,
      "connect_frame" => connect_frame
    }

    # Act
    # def handle_event("idleify_frame", %{"current_frame" => current_frame, "idle_range" => idle_range, "connect_frame" => connect_frame}, socket) do
    # EmulsionWeb.FramePickerControllerLive.handle_event("idleify_frame", event_payload, socket)

    # Allow the async task to finish
    :timer.sleep(1000)

    # Assert

    # Check that three nodes were created
    nodes = Playgraph.get_nodes()
    assert length(nodes) == 3
    assert Enum.any?(nodes, &(&1["name"] == current_frame))
    assert Enum.any?(nodes, &(&1["name"] == connect_frame))
    # assuming this is the frame created by idle_range
    assert Enum.any?(nodes, &(&1["name"] == "frame6"))

    # Check that source_frame has three edges: two connecting to/from tween frame and one leading to the connect_frame
    source_node = Enum.find(nodes, &(&1["name"] == current_frame))
    assert length(source_node["edges"]) == 3
    assert Enum.count(source_node["edges"], &(&1["to"] == "frame6")) == 2
    assert Enum.count(source_node["edges"], &(&1["to"] == connect_frame)) == 1
  end
end
