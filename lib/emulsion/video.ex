defmodule Emulsion.Video do
  use GenServer

  # :source is the original video we are working from
  @resourceTypes [:source, :video, :frame, :thumb_frame, :tween]
  @pathTypes [:browser, :disk]

  @videoFormat "webm"
  @operations [
    :split_video_into_frames, # splits the selected video into frames
    :generate_sequential_video, # generates a video from a range of frames
    :generate_tween_video, # generates a video from a folder of tween frames
    :generate_tween_frames, # use AI to generate the tween frames between two non-sequential frames
  ]

  def init(init_state) do
    {:ok, %{ working_file: "" }}
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def handle_call({:set_working_video, original_video_name, working_root}, _from, state) do
    full_path_to_video = GenServer.call(Emulsion.Files, {:get_file_path, original_video_name, :app_folder, :disk})
    # video_name = Path.join(working_root, vid_file)
    # file server needs to know the original video source and the root of the workign directory where it will write to
    result = GenServer.call(Emulsion.Files, {:set_workspace_folder, full_path_to_video, working_root, :disk})
    {:reply, true, %{state | working_file:  original_video_name}}
  end

  def handle_call({:split_video_into_frames}, _from, state) do
    frames_path = GenServer.call(Emulsion.Files, {:get_file_path, "", :frame_folder, :disk})
    thumbs_path = GenServer.call(Emulsion.Files, {:get_file_path, "", :thumbs_folder, :disk})
    video_path = GenServer.call(Emulsion.Files, {:get_original_video})
    IO.puts "paths are #{video_path} #{frames_path} #{thumbs_path}"
    with [] <- GenServer.call(Emulsion.Files, {:get_file_list, :frame_folder}) do
        IO.puts "i am splitting the video into frames and thumbs"
        Emulsion.ScriptRunner.execute_split_video_into_frames(video_path, frames_path)
        Emulsion.ScriptRunner.execute_split_video_into_thumbs(video_path, thumbs_path)
        # return the list of thumbs
        thumbs_list = GenServer.call(Emulsion.Files, {:get_file_list, :thumbs_folder, :browser})
        IO.inspect thumbs_list
        {:reply, thumbs_list, state}
    else
      _ ->
        IO.puts "for some reason I think they already exist?????"
        thumbs_list = GenServer.call(Emulsion.Files, {:get_file_list, :thumbs_folder, :browser})
        {:reply, thumbs_list, state}
    end
  end

  def handle_call({:list_resources, resource_type}, _from, state) do
    case resource_type do
      :source ->
        videos = GenServer.call(Emulsion.Files, {:get_file_list, :app_folder})
          |> Enum.filter(fn file -> Path.extname(file) == ".MOV" end)
        {:reply, videos, state}
      :video -> {:reply, GenServer.call(Emulsion.Files, {:get_file_list, :output_folder}), state}
      :frame -> {:reply, GenServer.call(Emulsion.Files, {:get_file_list, :frame_folder}), state}
      :thumb_frame -> {:reply, GenServer.call(Emulsion.Files, {:get_file_list, :thumbs_folder}), state}
      :tween -> {:reply, GenServer.call(Emulsion.Files, {:get_file_list, :tween_folder}), state}
      _ -> {:reply, {:error, "Invalid resource type"}, state}
    end
  end

  def handle_call({:get_resource, name, resource_type, path_type}, _from, state) do
    case resource_type do
      :source -> GenServer.call(Emulsion.Files, {:get_file_from_directory, name, path_type, :workspace_folder})
      :video -> GenServer.call(Emulsion.Files, {:get_file_from_directory, name, path_type, :output_folder})
      :frame -> GenServer.call(Emulsion.Files, {:get_file_from_directory, name, path_type, :frame_folder})
      :thumb_frame -> GenServer.call(Emulsion.Files, {:get_file_from_directory, name, path_type, :thumbs_folder})
      :tween -> GenServer.call(Emulsion.Files, {:get_file_from_directory, name, path_type, :tween_folder})
      _ -> {:error, "Invalid resource type"}
    end
  end

  def handle_call({:generate_tween_and_video, src_frame, dest_frame, tween_length}, _from, state) do
    # Generate the tween frames
    output_dir = GenServer.call(Emulsion.Files, {:get_file_path, "", :tween_folder, :disk})
    # get the src_framebase as just the file name without the extension
    src_framebase = Path.basename(src_frame, Path.extname(src_frame))
    dest_framebase = Path.basename(dest_frame, Path.extname(dest_frame))
    output_file = Path.join(output_dir, "#{src_framebase}_to_#{dest_framebase}.#{@videoFormat}")
    Emulsion.ScriptRunner.execute_generate_tween_video(src_frame, dest_frame, tween_length, output_file)
    {:reply, output_file, state}
  end

end
