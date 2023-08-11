defmodule Emulsion.Video do
  use GenServer

  # :source is the original video we are working from
  @resourceTypes [:source, :video, :frame, :thumb_frame, :tween]
  @pathTypes [:browser, :disk]

  @videoFormat "webm"
  @operations [
    # splits the selected video into frames
    :split_video_into_frames,
    # generates a video from a range of frames
    :generate_sequential_video,
    # generates a video from a folder of tween frames
    :generate_tween_video,
    # use AI to generate the tween frames between two non-sequential frames
    :generate_tween_frames
  ]

  def init(init_state) do
    {:ok, %{working_file: ""}}
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def handle_call({:set_working_video, original_video_name, working_root}, _from, state) do
    full_path_to_video =
      GenServer.call(Emulsion.Files, {:get_file_path, original_video_name, :app_folder, :disk})

    # video_name = Path.join(working_root, vid_file)
    # file server needs to know the original video source and the root of the workign directory where it will write to
    result =
      GenServer.call(
        Emulsion.Files,
        {:set_workspace_folder, full_path_to_video, working_root, :disk}
      )

    {:reply, true, %{state | working_file: original_video_name}}
  end

  def generate_next_filename(frame_files) do
    # Extract frame numbers from filenames
    frame_numbers = Enum.map(frame_files, &Emulsion.Files.extract_frame_number/1)

    # Get the maximum frame number
    max_frame_number = Enum.max(frame_numbers)

    # Generate new filename for the next frame
    new_frame_number = max_frame_number + 1

    # Pad the new frame number to always be 4 digits
    padded_frame_number = String.pad_leading(Integer.to_string(new_frame_number), 4, "0")

    # Split one of the filenames to get the base name and the extension
    [base_name, _old_number, extension] = frame_files |> List.first() |> String.split(["_", "."])

    # Construct new filename
    "#{base_name}_#{padded_frame_number}.#{extension}"
end

  def handle_call({:handle_upload, image, working_root}, _from, state) do
    # 1. Get the paths
    frames_path = GenServer.call(Emulsion.Files, {:get_file_path, "", :frame_folder, :disk})
    thumbs_path = GenServer.call(Emulsion.Files, {:get_file_path, "", :thumbs_folder, :disk})

    # 2. Rename the image to be the next frame in the sequence
    frame_files = File.ls!(frames_path)
    new_file_name = generate_next_filename(frame_files)
    new_frame_path = Path.join([frames_path, new_file_name])
    File.cp(image, new_frame_path)

    # 3. Generate thumbnail and save it in thumbs folder
    new_thumb_path = Path.join([thumbs_path, Path.basename(new_frame_path)])
    Emulsion.ScriptRunner.execute_transform_image_to_thumb(new_frame_path, new_thumb_path)

    {:reply, new_thumb_path, state}
  end

  def handle_call({:split_video_into_frames}, _from, state) do
    frames_path = GenServer.call(Emulsion.Files, {:get_file_path, "", :frame_folder, :disk})
    thumbs_path = GenServer.call(Emulsion.Files, {:get_file_path, "", :thumbs_folder, :disk})
    video_path = GenServer.call(Emulsion.Files, {:get_original_video})

    with [] <- GenServer.call(Emulsion.Files, {:get_file_list, :frame_folder}) do
      IO.puts("i am splitting the video into frames and thumbs, launching external script now")
      Emulsion.ScriptRunner.execute_split_video_into_frames(video_path, frames_path)
      Emulsion.ScriptRunner.execute_split_video_into_thumbs(video_path, thumbs_path)
      # return the list of thumbs
      thumbs_list = GenServer.call(Emulsion.Files, {:get_file_list, :thumbs_folder, :browser})
      IO.inspect(thumbs_list)
      {:reply, thumbs_list, state}
    else
      _ ->
        IO.puts("I have already split the #{video_path}  video into frames and thumbs")
        thumbs_list = GenServer.call(Emulsion.Files, {:get_file_list, :thumbs_folder, :browser})
        {:reply, thumbs_list, state}
    end
  end

  def handle_call({:list_resources, resource_type}, _from, state) do
    case resource_type do
      :source ->
        videos =
          GenServer.call(Emulsion.Files, {:get_file_list, :app_folder})
          |> Enum.filter(fn file -> Path.extname(file) == ".MOV" end)

        {:reply, videos, state}

      :source_thumbs ->
        frames =
          GenServer.call(Emulsion.Files, {:get_file_list, :app_thumbs_folder})
          |> Enum.filter(fn file -> Path.extname(file) == ".png" end)

        {:reply, frames, state}

      :video ->
        {:reply, GenServer.call(Emulsion.Files, {:get_file_list, :output_folder}), state}

      :frame ->
        {:reply, GenServer.call(Emulsion.Files, {:get_file_list, :frame_folder}), state}

      :thumb_frame ->
        {:reply, GenServer.call(Emulsion.Files, {:get_file_list, :thumbs_folder}), state}

      :tween ->
        {:reply, GenServer.call(Emulsion.Files, {:get_file_list, :tween_folder}), state}

      _ ->
        {:reply, {:error, "Invalid resource type"}, state}
    end
  end

  def generate_tween_and_video(src_frame, dest_frame, tween_multiplier, force_build) do
    GenServer.call(
      __MODULE__,
      {:generate_tween_and_video, src_frame, dest_frame, tween_multiplier, force_build},
      999_999
    )
  end

  def handle_call({:generate_tween_and_video, src_frame, dest_frame, tween_multiplier, force_build}, _from, state) do
    # Generate the tween frames
    output_dir = GenServer.call(Emulsion.Files, {:get_file_path, "", :tween_folder, :disk})
    # get the src_framebase as just the file name without the extension
    src_framebase = Path.basename(src_frame, Path.extname(src_frame))
    dest_framebase = Path.basename(dest_frame, Path.extname(dest_frame))
    output_file = Path.join(output_dir, "#{src_framebase}_to_#{dest_framebase}.#{@videoFormat}")
    # if the tween already exists then notify and just return the file name:
    if force_build == "true" do
      # Delete the output file if it exists
      if File.exists?(output_file) do
        File.rm!(output_file)
      end
    end
    if File.exists?(output_file) do
      IO.puts("Tween already exists, returning #{output_file}")
      {:reply, output_file, state}
    else
      IO.puts("Tween does not exist, generating #{output_file}")
      Emulsion.ScriptRunner.execute_generate_tween_video(
        src_frame,
        dest_frame,
        tween_multiplier,
        output_file
      )
      {:reply, output_file, state}
    end
  end
end
