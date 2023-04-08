# handles all the video processing scripts and calls
# this should strive to abstract away concerns about the file system and file paths
defmodule Emulsion.Video do
  use GenServer

  # def rife_dir do "/mnt/c/GitHub/rife/rife" end
  def rife_dir do "c:/GitHub/rife/rife" end
  def sequential_shell do "bash" end
  # replace e: or c: with /mnt/e or /mnt/c if needed
  def path_for_sequential_shell(path) do
    path
    |> String.replace("e:", "/mnt/e")
    |> String.replace("c:", "/mnt/c")
  end
  def sequential_script do "./lib/scripts/extractVid.sh" end
  def tween_shell do "bash" end
  def tween_script do "./lib/scripts/gentween.sh" end
  def join_script do "./lib/scripts/join.sh" end
  def split_script do "./lib/scripts/split.sh" end


  def init(init_state) do
    {:ok, %{ working_dir: "" }}
  end
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def ffmpegJoinParams do "-c:v vp8 -s 1920x1080" end

  # splits the selected video
  def handle_cast(:split_video_into_frames, state) do
    result = split_video_into_frames()
    {:noreply, state}
  end

  def split_video_into_frames() do
    videoPath = GenServer.call(Emulsion.Files, :get_video_path)
    framesPath = GenServer.call(Emulsion.Files, :get_frames_dir)
    # watch the frames path
    watcher_pid = GenServer.whereis(Emulsion.NotifyWhenDone)
    GenServer.call(watcher_pid, {:start_watching, framesPath})
    result = execute_split_video_into_frames(
      sequential_shell,
      [split_script, videoPath |> path_for_sequential_shell, framesPath |> path_for_sequential_shell],
      cd: "c:/GitHub/emulsion"
    )
  end
  # can split any video to any path, can be used by anyone
  def execute_split_video_into_frames(shellToUse, args, opts ) do
    Rambo.run(shellToUse, args, opts)
  end

  # get the video sequence from start_frame to end_frame as a playable movie
  def handle_cast({:generate_sequential_video, start_frame, end_frame}, state) do
    working_dir = GenServer.call(Emulsion.Files, :get_working_dir)
    outputVideoName = Emulsion.Files.get_sequential_output_video_path(start_frame, end_frame, working_dir)
    # check if the file exists, if so don't generate it
    case File.exists?(outputVideoName) do
      true ->
        IO.puts "file #{outputVideoName} exists, not generating"
        GenServer.call(Emulsion.NotifyWhenDone, :abort_watching)
      false ->
        number_of_frames = end_frame - start_frame
        path_to_frames = Emulsion.Files.frames_dir(working_dir)
        frame_base = Emulsion.Files.frame_base(path_to_frames)
        frame_base_with_path = Path.join([path_to_frames, frame_base])
        args = [
          sequential_script,
          frame_base_with_path <> "%04d.png" |> path_for_sequential_shell,  # todo make this dynamic
          "#{start_frame}",
          "#{number_of_frames}",
          outputVideoName |> path_for_sequential_shell
        ]
        result = Rambo.run(sequential_shell, args)
        IO.inspect result
    end
    {:noreply, state}
  end

  # GENERATE TWEEN FRAMES
  def handle_cast({:generate_tween_frames, src_frame, dest_frame, freq}, state) do
    working_path = GenServer.call(Emulsion.Files, :get_working_dir)
    framePath = Emulsion.Files.get_image_for_frameNum(working_path, src_frame)
    framePath2 = Emulsion.Files.get_image_for_frameNum(working_path, dest_frame)
    # make a directory for the frames
    output_tween_dir = Emulsion.Files.get_path_to_tween_frames(working_path, src_frame, dest_frame)
    File.rm_rf(output_tween_dir)
    IO.puts "making tween frames directory: #{output_tween_dir}"
    File.mkdir_p!(output_tween_dir)
    # maybe some error handling?
    generate_tween_frames(framePath, framePath2, freq, output_tween_dir |> path_for_sequential_shell)
    Phoenix.PubSub.broadcast(Emulsion.PubSub, "topic_files", {:operation_complete, %{} })
    {:noreply, state}
  end

  def generate_tween_frames(src_frame, dest_frame, tweenlength, frame_dir) do
    # call out to rife to generate the tween frames
    result = Rambo.run(tween_shell, [tween_script, rife_dir, "#{tweenlength}", src_frame, dest_frame, frame_dir ])
    IO.inspect result
  end

  def handle_cast({:generate_tween_video, start_frame, end_frame}, state) do
    working_path = GenServer.call(Emulsion.Files, :get_working_dir)
    output_tween_video = Emulsion.Files.get_output_tween_video(working_path, start_frame, end_frame)
    # get the directory for the source tween frames and path for an output video:
    join_tween_video(start_frame, end_frame, output_tween_video)
    Phoenix.PubSub.broadcast(Emulsion.PubSub, "topic_files", {:operation_complete, %{} })
    {:noreply, state}
  end

  def join_tween_video(start_frame, end_frame, outputVideoName) do
    working_path = GenServer.call(Emulsion.Files, :get_working_dir)
    path_to_tween_frames = Emulsion.Files.get_path_to_tween_frames(working_path, start_frame, end_frame)

    # number of files in folder
    number_of_frames = File.ls!(path_to_tween_frames)
      |> Enum.filter(fn x -> String.ends_with?(x, ".png") end)
      |> Enum.count()

    tween_base_with_path = Path.join([path_to_tween_frames, "img"])

    args = [
      sequential_script,
      tween_base_with_path <> "%d.png" |> path_for_sequential_shell,  # todo make this dynamic
      "0", # tween start at frame 0 and includes all frames in this tween folder
      "#{number_of_frames + 1}",
      outputVideoName |> path_for_sequential_shell
    ]
    result = Rambo.run(sequential_shell, args)
  end

  # def generate_tween_video(tweenPath, outPath, opts \\ []) do
  #   # get number of .png frames in the tweenPath
  #   tweenCount = File.ls!(tweenPath)
  #     |> Enum.filter(fn x -> String.ends_with?(x, ".png") end)
  #     |> Enum.count()
  #   # call out to ffmpeg to generate the video from the frames
  #   result = Rambo.run(sequential_shell, [join_script, tweenPath, Integer.to_string(tweenCount), ffmpegJoinParams, outPath])
  #   IO.inspect result
  # end

  # def export_tween(src_frame, dest_frame, exportName) do
  #   src_frame = src_frame |> browserThumbToShellFrame
  #   dest_frame = dest_frame |> browserThumbToShellFrame
  #   # clear files from tween dir
  #   File.rm_rf("./tween")
  #   File.mkdir("./tween")
  #   generate_tween_frames(src_frame, dest_frame, 3, "./tween")
  #   generate_tween_video("./tween", exportName)
  # end

end
