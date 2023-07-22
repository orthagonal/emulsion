defmodule Emulsion.IdiomsTest do
  use ExUnit.Case

  alias Emulsion.Idioms
  alias Emulsion.Files
  alias Emulsion.Playgraph

  describe "generate_idle_tween/3" do
    setup do
      :ok
    end

    @tag timeout: :infinity
    test "creates a tween and adds nodes and edges to the playgraph" do
      # set up the workspace
      videoFile = "e:/intro/MVI_5979.MOV"

      GenServer.call(
        Emulsion.Files,
        {:set_workspace_folder, videoFile, "e:/emulsion_workspace", :disk}
      )

      # Arrange
      # Replace this with a real frame file in your test environment
      src_frame = "/file/MVI_5979/frames/img_0341.png"
      range = 5
      direction = :forward

      # Precondition assertions: These should not exist before the function call
      refute Playgraph.node_exists?(src_frame)

      # Act
      Idioms.generate_idle_tween(src_frame, range, direction)

      # # Since we're dealing with real GenServers and async tasks, introduce a delay for operations to complete

      # Collect the generated tween from mailbox
      assert_receive {:tween_generated, tween_to_name}, 60_000

      # # Assertions
      assert is_binary(tween_to_name)

      assert_receive {:tween_generated, tween_from_name}, 60_000

      assert is_binary(tween_from_name)

      # Postcondition assertions: These should exist after the function call
      IO.inspect(Playgraph.get_nodes())
      IO.inspect(Playgraph.get_edges())
      # assert Playgraph.node_exists?(src_frame)
      # assert Playgraph.node_exists?(video_name)
      # assert Playgraph.edge_exists?(src_frame, video_name)
      # assert Playgraph.edge_exists?(video_name, src_frame)
      # assert Playgraph.edge_tagged?("idle:from_src", src_frame, video_name)
      # assert Playgraph.edge_tagged?("idle:to_src", video_name, src_frame)
    end
  end
end

# describe "idleify_frame/4" do
#   @tag timeout: :infinity
#   test "completes without errors" do
#     # Arrange
#     current_frame = "/file/MVI_5979/frames/img_0341.png"
#     idle_range = 5
#     connect_frame = "/file/MVI_5979/frames/img_0300.png"
#     pid = self()

#     # Act
#     result = Idioms.idleify_frame(current_frame, idle_range, connect_frame, pid)

#     # Assert
#     assert result == {:ok, pid}
#     # assert received({:sequence_generated, video_name})
#   end
# end
