# defmodule EmulsionWeb.PageControllerTest do
#   use EmulsionWeb.ConnCase

#   test "GET /", %{conn: conn} do
#     conn = get(conn, ~p"/")
#     assert html_response(conn, 200) =~ "Peace of mind from prototype to production"
#   end
# end


defmodule EmulsionWeb.VideoProcessingTest do
  use EmulsionWeb.ConnCase

  @tag timeout: :infinity

  # test "splits a video into files" do
  #   videoFile = "e:/intro/MVI_5820.MOV"
  #   GenServer.cast(Emulsion.Files, {:set_working_dir, videoFile})
  #   # get the frames dir:
  #   framesDir = GenServer.call(Emulsion.Files, :get_frames_dir)
  #   # watch it for file changes:
  #   Phoenix.PubSub.subscribe(Emulsion.PubSub, "topic_files")
  #   res = GenServer.cast(Emulsion.Video, :split_video_into_frames)
  #   assert_receive {:operation_complete, %{} }, 120_000
  # end

  # test "can export a range of frames as a video" do
  #   # delete the temp.webm file if it exists
  #   videoFile = "e:/intro/MVI_5820.MOV"
  #   Phoenix.PubSub.subscribe(Emulsion.PubSub, "topic_files")
  #   GenServer.cast(Emulsion.Files, {:set_working_dir, videoFile})

  #   # to clean out whatever was in there last, it won't fail if it doesn't exist
  #   # workingDir = GenServer.call(Emulsion.Files, :get_working_dir)
  #   # outputDir = Emulsion.Files.output_dir(workingDir)
  #   # File.rm_rf(outputDir)

  #   GenServer.cast(Emulsion.Files, {:set_working_dir, videoFile})
  #   res = GenServer.cast(Emulsion.Video, {:generate_sequential_video, 12, 80})
  #   IO.inspect res
  #   assert_receive {:operation_complete, %{} }, 120_000
  # end

  # test "can generate the frames for a tween" do
  #   videoFile = "e:/intro/MVI_5820.MOV"
  #   Phoenix.PubSub.subscribe(Emulsion.PubSub, "topic_files")
  #   GenServer.cast(Emulsion.Files, {:set_working_dir, videoFile})
  #   start_frame = 2
  #   end_frame = 300
  #   freq = 3
  #   res = GenServer.cast(Emulsion.Video, {:generate_tween_frames, start_frame, end_frame, freq})
  #   assert_receive {:operation_complete, %{} }, 120_000
  # end

  # test "can turn a tween frame dir into a tween video" do
  #   videoFile = "e:/intro/MVI_5820.MOV"
  #   Phoenix.PubSub.subscribe(Emulsion.PubSub, "topic_files")
  #   GenServer.cast(Emulsion.Files, {:set_working_dir, videoFile})
  #   start_frame = 2
  #   end_frame = 300
  #   freq = 3
  #   res = GenServer.cast(Emulsion.Video, {:generate_tween_video, start_frame, end_frame})
  #   assert_receive {:operation_complete, %{} }, 120_000
  # end

  # test "can generate a video from a playgraph" do
  #   res = Emulsion.generate_tween_video("./tween", "join.webm")
  #   IO.inspect res
  # end
end
