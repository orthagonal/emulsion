defmodule Emulsion.IdiomsTest do
  use ExUnit.Case

  alias Emulsion.Idioms
  alias Emulsion.Files
  alias Emulsion.Playgraph

  setup do
    # Initial state, clearing any nodes or edges
    Playgraph.reset()
    :ok
  end

  # describe "generate_idle_tween/3" do
  #   setup do
  #     :ok
  #   end

  #   @tag timeout: :infinity
  #   test "creates a tween and adds nodes and edges to the playgraph" do
  #     # set up the workspace
  #     videoFile = "e:/intro/MVI_5979.MOV"

  #     GenServer.call(
  #       Emulsion.Files,
  #       {:set_workspace_folder, videoFile, "e:/emulsion_workspace", :disk}
  #     )

  #     # Arrange
  #     # Replace this with a real frame file in your test environment
  #     src_frame = "/file/MVI_5979/frames/img_0341.png"
  #     range = 5
  #     direction = :forward

  #     # Precondition assertions: These should not exist before the function call
  #     refute Playgraph.node_exists?(src_frame)

  #     # Act
  #     Idioms.generate_idle_tween(src_frame, range, direction)

  #     # # Since we're dealing with real GenServers and async tasks, introduce a delay for operations to complete

  #     # Collect the generated tween from mailbox
  #     assert_receive {:tween_generated, tween_to_name}, 60_000

  #     # # Assertions
  #     assert is_binary(tween_to_name)

  #     assert_receive {:tween_generated, tween_from_name}, 60_000

  #     assert is_binary(tween_from_name)

  #     # Postcondition assertions: These should exist after the function call
  #     IO.inspect(Playgraph.get_nodes())
  #     IO.inspect(Playgraph.get_edges())
  #     # assert Playgraph.node_exists?(src_frame)
  #     # assert Playgraph.node_exists?(video_name)
  #     # assert Playgraph.edge_exists?(src_frame, video_name)
  #     # assert Playgraph.edge_exists?(video_name, src_frame)
  #     # assert Playgraph.edge_tagged?("idle:from_src", src_frame, video_name)
  #     # assert Playgraph.edge_tagged?("idle:to_src", video_name, src_frame)
  #   end
  # end

  describe "prepare_frames/2" do
    # test "returns the correct frame paths and numbers" do
    #   current_frame = "/file/MVI_5979/frames/img_0341.png"
    #   connect_frame = "/file/MVI_5979/frames/img_0300.png"

    #   {from_frame_path, to_frame_path, srcFrameNumber, destFrameNumber} =
    #     Idioms.prepare_frames(current_frame, connect_frame)

    #   IO.inspect(from_frame_path)
    #   IO.inspect(to_frame_path)
    #   IO.inspect(srcFrameNumber)
    #   IO.inspect(destFrameNumber)
    # end
  end

  describe "prepare_for_task/4" do
    # test "returns the correct preparation data" do
    #   current_frame = "/file/MVI_5979/frames/img_0341.png"
    #   connect_frame = "/file/MVI_5979/frames/img_0300.png"

    #   {from_frame_path, to_frame_path, srcFrameNumber, destFrameNumber} =
    #     Idioms.prepare_frames(current_frame, connect_frame)

    #   {srcFolderPath, start_frame, number_of_frames, outputVideoName} =
    #     Idioms.prepare_for_task(srcFrameNumber, destFrameNumber, current_frame, connect_frame)

    #   IO.inspect(srcFolderPath)
    #   IO.inspect(start_frame)
    #   IO.inspect(number_of_frames)
    #   IO.inspect(outputVideoName)
    # end
  end

  # describe "idleify_frame/4 when dest frame is lower and needs a tween join" do
  #   @tag timeout: :infinity
  #   test "completes without errors" do
  #     # Arrange
  #     current_frame = "/file/MVI_5979/frames/img_0555.png"
  #     idle_range = 5
  #     connect_frame = "/file/MVI_5979/frames/img_0535.png"
  #     pid = self()

  #     # Act
  #     result = Idioms.idleify_frame(current_frame, idle_range, connect_frame, pid)

  #     # Assert
  #     assert result == {:ok, pid}
  #     assert_receive {:tween_generated, tween_to_name}, 60_000
  #     assert_receive {:tween_generated, tween_from_name}, 60_000
  #     assert_receive {:tween_generated, video_name}, 60_000

  #     nodes = Playgraph.get_nodes()
  #     IO.inspect(nodes)
  #     assert Enum.any?(nodes, fn node -> node["name"] == current_frame end)
  #     assert Enum.any?(nodes, fn node -> node["name"] == connect_frame end)

  #     # # Check the edges of the playgraph
  #     edges = Playgraph.get_edges()

  #     # two edges for the idle tweens and one edge for the tween join
  #     assert(Enum.count(edges) == 3)
  #   end
  # end

  describe "idleify_frame/4 when dest frame is higher and needs a seq join" do
    @tag timeout: :infinity
    test "completes without errors" do
      # Arrange
      current_frame = "/file/MVI_5979/frames/img_0400.png"
      idle_range = 5
      connect_frame = "/file/MVI_5979/frames/img_0420.png"
      pid = self()

      # Act
      result = Idioms.idleify_frame(current_frame, idle_range, connect_frame, pid)

      # Assert
      assert result == {:ok, pid}
      assert_receive {:tween_generated, tween_to_name}, 60_000
      assert_receive {:tween_generated, tween_from_name}, 60_000
      assert_receive {:sequence_generated, video_name}, 60_000
      IO.puts("seq video_name: #{video_name}")
      nodes = Playgraph.get_nodes()
      # IO.inspect(nodes)
      # assert Enum.any?(nodes, fn node -> node["name"] == current_frame end)
      # assert Enum.any?(nodes, fn node -> node["name"] == connect_frame end)

      # # Check the edges of the playgraph
      edges = Playgraph.get_edges()

      IO.inspect(edges)
      # two edges for the idle tweens and one edge for the tween join
      # assert(Enum.count(edges) == 3)
    end
  end
end
