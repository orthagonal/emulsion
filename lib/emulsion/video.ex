# high-level handler for Video assets
# includes fetching videos and frames from storage as well as video processing scripts and calls
# this should strive to abstract away concerns about the file system and file paths, etc
defmodule Emulsion.Video do
  use GenServer

  # :source is the original video we are working from
  @resourceTypes [:source, :video, :frame, :thumb_frame, :tween]
  @pathTypes [:browser, :disk]

  @operations [
    :split_video_into_frames, # splits the selected video into frames
    :generate_sequential_video, # generates a video from a range of frames
    :generate_tween_video, # generates a video from a folder of tween frames
    :generate_tween_frames, # use AI to generate the tween frames between two non-sequential frames
  ]


  def init(init_state) do
    {:ok, %{ working_dir: "" }}
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def handle_call({:get_resource, resourceType, pathType, resourceName}, _from, state) do
    # get the path to the resource
    # get the resource
    # return the resource
    {:reply, :ok, state}
  end


  # splits the selected video
  def handle_cast(:split_video_into_frames, state) do
    videoPath = GenServer.call(Emulsion.Files, :get_video_path)
    framesPath = GenServer.call(Emulsion.Files, :get_frames_dir)
    thumbsPath = GenServer.call(Emulsion.Files, :get_thumbs_dir)
    # check if there are already frames in the frames directory
    # if so, don't split the video
    case Emulsion.Files.frames_and_thumbs_exist? framesPath, thumbsPath do
      true ->
        IO.puts "frames already exist in #{framesPath}, not splitting video"
        GenServer.call(GenServer.whereis(Emulsion.NotifyWhenDone), {:skip_watching, :split_video_shell_operation, thumbsPath })
      false ->
        IO.puts "no frames in #{framesPath}, splitting video"
        # watch the frames path until it stops changing
        Emulsion.ScriptRunner.execute_split_video_into_frames(videoPath, framesPath)
        GenServer.call(GenServer.whereis(Emulsion.NotifyWhenDone), {:start_watching, :split_video_shell_operation, thumbsPath, thumbsPath})
        Emulsion.ScriptRunner.execute_split_video_into_thumbs(videoPath, thumbsPath)
    end
    {:noreply, state}
  end

  def handle_cast({:generate_sequential_video, start_frame, end_frame}, state) do
    working_dir = GenServer.call(Emulsion.Files, :get_working_dir)
    outputVideoName = Emulsion.Files.get_sequential_output_video_path(start_frame, end_frame, working_dir)
    # check if the file exists, if so don't generate it
    case File.exists?(outputVideoName) do
      true ->
        IO.puts "file #{outputVideoName} exists, not generating"
        GenServer.call(Emulsion.NotifyWhenDone, :abort_watching)
      false ->
        generate_video(start_frame, end_frame, working_dir, outputVideoName)
        GenServer.call(Emulsion.NotifyWhenDone, :abort_watching)
    end
    {:noreply, state}
  end

  # join raw frames into a video
  def generate_video(start_frame, end_frame, working_dir, outputVideoName) do
    number_of_frames = end_frame - start_frame
    path_to_frames = Emulsion.Files.frames_dir(working_dir)
    frame_base = Emulsion.Files.frame_base(path_to_frames)
    frame_base_with_path = Path.join([path_to_frames, frame_base])
    Emulsion.ScriptRunner.execute_generate_sequential_video(
      frame_base_with_path <> "%04d.png",
      "#{start_frame}",
      "#{number_of_frames}",
      outputVideoName
    )
  end

  # GENERATE TWEEN FRAMES
  def handle_cast({:generate_tween_frames, src_frame, dest_frame, freq}, state) do
    working_path = GenServer.call(Emulsion.Files, :get_working_dir)
    framePath = Emulsion.Files.get_image_for_frameNum(working_path, src_frame)
    framePath2 = Emulsion.Files.get_image_for_frameNum(working_path, dest_frame)
    IO.puts "generating tween frames from #{framePath} to #{framePath2}"
    # make a directory for the frames
    output_tween_dir = Emulsion.Files.get_path_to_tween_frames(working_path, src_frame, dest_frame)
    File.rm_rf(output_tween_dir)
    IO.puts "making tween frames directory: #{output_tween_dir}"
    File.mkdir_p!(output_tween_dir)
    # maybe some error handling?
    Emulsion.ScriptRunner.execute_generate_tween_frames(framePath, framePath2, freq, output_tween_dir)
    Phoenix.PubSub.broadcast(Emulsion.PubSub, "topic_files", {:operation_complete, %{} })
    {:noreply, state}
  end

  # calls a script that generates the tween frames and then joins them into a video
  # in one go
  def handle_cast({:generate_tween_and_video, src_frame, dest_frame, freq}, state) do
    tweenExp = 3
    output_dir = GenServer.call(Emulsion.Files, :get_output_dir)
    tweenName = Emulsion.Files.make_tween_name(src_frame, dest_frame) |> Emulsion.Files.add_video_extension
    output_file = Path.join(output_dir, tweenName)
    result = Emulsion.ScriptRunner.execute_generate_tween_video(src_frame, dest_frame, tweenExp, output_file)
    GenServer.cast(Emulsion.NotifyWhenCreated, { })
    {:noreply, state}
  end






  # i want this to bundle generate_tween_frames and generate_tween_video and only call the broadcast once
  # after both are done
  def handle_cast({:generate_tween, src_frame, dest_frame, freq}, state) do
    working_path = GenServer.call(Emulsion.Files, :get_working_dir)
    framePath = Emulsion.Files.get_image_for_frameNum(working_path, src_frame)
    framePath2 = Emulsion.Files.get_image_for_frameNum(working_path, dest_frame)
    IO.puts "generating tween starting with frames from #{framePath} to #{framePath2}"
    # make a directory for the frames
    output_tween_dir = Emulsion.Files.get_path_to_tween_frames(working_path, src_frame, dest_frame)
    File.rm_rf(output_tween_dir)
    IO.puts "making tween frames directory: #{output_tween_dir}"
    File.mkdir_p!(output_tween_dir)
    # maybe some error handling?
    Emulsion.ScriptRunner.execute_generate_tween_frames(framePath, framePath2, freq, output_tween_dir)
    generate_video(src_frame, dest_frame, working_path, output_tween_dir)
    Phoenix.PubSub.broadcast(Emulsion.PubSub, "topic_files", {:operation_complete, %{} })
    {:noreply, state}
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
    IO.puts "the path to tween frmaes is #{path_to_tween_frames}"
    # number of files in folder
    number_of_frames = File.ls!(path_to_tween_frames)
      |> Enum.filter(fn x -> String.ends_with?(x, ".png") end)
      |> Enum.count()
    # tween_base_with_path = Emulsion.Files.frame_base(path_to_tween_frames)#Path.join([path_to_tween_frames, "img"])
    tween_base_with_path = Path.join([path_to_tween_frames, "img"])
    IO.puts "making the tween base will be #{tween_base_with_path}"
    # use same function as making a sequential:
    Emulsion.ScriptRunner.execute_generate_sequential_video(
      tween_base_with_path <> "%d.png", # tween frames should not be zero padded
      0, # always start at 0 because each tween's frames are in their own dedicated folder
      number_of_frames + 1, # always end at the number of frames in the folder
      outputVideoName
    )

    # Emulsion.ScriptRunner.execute_join_tween_frames_to_video(
    #   tween_base_with_path <> "%d.png",  # todo make this dynamic
    #   number_of_frames,
    #   outputVideoName
    # )
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
