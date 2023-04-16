#  I usually run these one at a time
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
  #   freq = 4
  #   res = GenServer.cast(Emulsion.Video, {:generate_tween_frames, start_frame, end_frame, freq})
  #   assert_receive {:operation_complete, %{} }, 120_000
  # end

  # test "can turn a tween frame dir into a tween video" do
  #   videoFile = "e:/intro/MVI_5820.MOV"
  #   Phoenix.PubSub.subscribe(Emulsion.PubSub, "topic_files")
  #   GenServer.cast(Emulsion.Files, {:set_working_dir, videoFile})
  #   start_frame = 2
  #   end_frame = 300
  #   res = GenServer.cast(Emulsion.Video, {:generate_tween_video, start_frame, end_frame})
  #   assert_receive {:operation_complete, %{} }, 120_000
  # end

  # test "can generate the frames for a tween and turn them into a video" do
  #   videoFile = "e:/intro/MVI_5820.MOV"
  #   Phoenix.PubSub.subscribe(Emulsion.PubSub, "topic_files")
  #   GenServer.cast(Emulsion.Files, {:set_working_dir, videoFile})
  #   start_frame = 2
  #   end_frame = 300
  #   freq = 4
  #   res = GenServer.cast(Emulsion.Video, {:generate_tween_video, start_frame, end_frame, freq})
  #   assert_receive {:operation_complete, %{} }, 120_000
  # end

  # test "execute_generate_tween_video" do
  #   videoFile = "e:/intro/MVI_5832.MOV"
  #   Phoenix.PubSub.subscribe(Emulsion.PubSub, "topic_files")
  #   GenServer.cast(Emulsion.Files, {:set_working_dir, videoFile})
  #   framesDir = GenServer.call(Emulsion.Files, :get_frames_dir)
  #   src_frame = Path.join(framesDir, "img_0001.png")
  #   dest_frame = Path.join(framesDir, "img_0306.png")
  #   tweenExp = 3
  #   output_dir = GenServer.call(Emulsion.Files, :get_output_dir)
  #   output_file = Path.join(output_dir, "tween.webm")
  #   result = Emulsion.ScriptRunner.execute_generate_tween_video(src_frame, dest_frame, tweenExp, output_file)
  #   IO.inspect result
  # end

  # test "get frame from thumb" do
  #   videoFile = "e:/intro/MVI_5832.MOV"
  #   GenServer.cast(Emulsion.Files, {:set_working_dir, videoFile})
  #   srcFrame = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, "/files/MVI_5832/thumbs/img_0001.png"})
  #   IO.inspect srcFrame
  # end
  # test "can generate a video from a playgraph" do
  #   res = Emulsion.generate_tween_video("./tween", "join.webm")
  #   IO.inspect res
  # end
end
