defmodule Emulsion.Files do
  use GenServer

  # contains the source videos that we will be working from
  @appDir "e:/intro"

  @resourceTypes [
    :app_folder,
    :workspace_folder,
    :frame_folder,
    :thumbs_folder,
    :tween_folder,
    :output_folder
  ]

  # dir structure looks like:
  # workspace_folder
  #   frame_folder
  #   thumbs_folder
  #   tween_folders (one for each tween we generate)
  #   output_folder

  @pathTypes [:browser, :disk]

  @operations [
    :set_workspace_folder,
    # returns a list of files in a directory
    :get_file_list,
    # returns the path to a file in a directory
    :get_file_path
  ]

  def init(init_state) do
    {:ok,
     %{
       path_to_original_video: "",
       workspace_folder: "",
       video_folder: "",
       working_root: ""
     }}
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def handle_call({:set_working_root, path_to_working_root}, _from, state) do
    {:reply, true, %{state | working_root: path_to_working_root}}
  end

  def handle_call(
        {:set_workspace_folder, path_to_original_video, working_root, path_type},
        _from,
        state
      ) do
    workspace_folder =
      Path.join([
        working_root,
        Path.basename(path_to_original_video, Path.extname(path_to_original_video))
      ])

    video_folder = workspace_folder |> String.replace(working_root, "") |> String.replace("/", "")

    case path_type do
      :disk ->
        if File.exists?(workspace_folder) do
          {:reply, workspace_folder,
           %{
             state
             | path_to_original_video: path_to_original_video,
               workspace_folder: workspace_folder,
               video_folder: video_folder
           }}
        else
          # create the directory structure
          setup_workspace(workspace_folder)

          {:reply, workspace_folder,
           %{
             state
             | path_to_original_video: path_to_original_video,
               workspace_folder: workspace_folder,
               video_folder: video_folder
           }}
        end

      _ ->
        {:error, "Invalid path type"}
    end
  end

  def handle_call({:get_original_video}, _from, state) do
    {:reply, state.path_to_original_video, state}
  end

  def handle_call({:get_file_list, folder_type}, _from, state) do
    path = get_folder_path(state, folder_type)

    case path do
      :error ->
        {:error, "Invalid folder type"}

      _ ->
        IO.puts("get_file_list #{path}")
        {:reply, File.ls!(path), state}
    end
  end

  def handle_call({:get_file_list, folder_type, path_type}, _from, state) do
    path = get_folder_path(state, folder_type)
    IO.inspect(state)

    case path do
      :error ->
        {:error, "Invalid folder type"}

      _ ->
        case path_type do
          :disk ->
            {:reply, File.ls!(path), state}

          :browser ->
            list = File.ls!(path)

            paths =
              for file <- list,
                  do:
                    Path.join(["/file", state.video_folder, print_folder_type(folder_type), file])

            {:reply, paths, state}

          _ ->
            {:error, "Invalid path type"}
        end
    end
  end

  def handle_call({:get_file_path, filename, folder_type, path_type}, _from, state) do
    handle_call({:get_file_path, filename, folder_type, path_type, nil}, _from, state)
  end

  def handle_call({:get_file_path, filename, folder_type, path_type, tween_id}, _from, state) do
    path = get_folder_path(state, folder_type, tween_id)

    case path do
      :error ->
        {:error, "Invalid folder type or tween id"}

      _ ->
        case path_type do
          :disk -> {:reply, Path.join([path, filename]), state}
          :browser -> {:reply, "/file" <> Path.join(["/#{folder_type}", "/", filename]), state}
          _ -> {:error, "Invalid path type"}
        end
    end
  end

  def handle_call({:get_frame_from_thumb, thumb_path}, _from, state) do
    frame_path = convert_thumb_path_to_frame_path(thumb_path, state)
    {:reply, frame_path, state}
  end

  def convert_browser_path_to_disk_path(browser_path) do
    GenServer.call(__MODULE__, {:convert_browser_path_to_disk_path, browser_path})
  end

  def handle_call({:convert_disk_path_to_browser_path, disk_path}, _from, state) do
    # Replace backslashes with forward slashes
    forward_slash_path = String.replace(disk_path, "\\", "/")
    # Extract workspace folder from state
    workspace_folder = state.workspace_folder
    # If workspace_folder is present in disk_path, replace it. Else, return disk_path as is.
    browser_path =
      cond do
        workspace_folder != nil and workspace_folder != "" and
            String.contains?(forward_slash_path, workspace_folder) ->
              # Replace workspace_folder with /file/video_folder
             String.replace(forward_slash_path, workspace_folder, "/file/#{state.video_folder}")
        true ->
          forward_slash_path
      end
    {:reply, browser_path, state}
  end

  def handle_call({:convert_browser_path_to_disk_path, browser_path}, _from, state) do
    # Replace '/file/' with workspace_folder at the beginning of the path
    disk_path = String.replace_prefix(browser_path, "/file/", "#{state.workspace_folder}/")
    # Remove duplicate directory name
    disk_path =
      Enum.join(
        disk_path
        |> String.split("/", trim: true)
        |> Enum.dedup(),
        "/"
      )

    # Return the converted disk_path
    {:reply, disk_path, state}
  end

  defp convert_thumb_path_to_frame_path(thumb_path, state) do
    # If path is already in the correct format
    if String.starts_with?(thumb_path, "/file/") and String.contains?(thumb_path, "/frames/") do
      thumb_path
    else
      # Existing logic
      relative_thumb_path = String.replace(thumb_path, ~r{^/file/\w+/thumbs/}, "")
      frame_folder = get_folder_path(state, :frame_folder)
      Path.join([frame_folder, relative_thumb_path])
    end
  end

  defp print_folder_type(type) when is_binary(type) do
    type
  end

  defp print_folder_type(type) do
    case type do
      # :app_folder -> @appDir
      # :workspace_folder -> state.workspace_folder
      :frame_folder -> "frames"
      :thumbs_folder -> "thumbs"
      :output_folder -> "output"
      _ -> :error
    end
  end

  defp get_folder_path(state, folder_type, _tween_id \\ nil) do
    case folder_type do
      :app_folder -> @appDir
      :app_thumbs_folder -> Path.join([@appDir, "thumbs"])
      :workspace_folder -> state.workspace_folder
      :frame_folder -> Path.join([state.workspace_folder, "frames"])
      :thumbs_folder -> Path.join([state.workspace_folder, "thumbs"])
      :tween_folder -> Path.join([state.workspace_folder, "tweens"])
      :output_folder -> Path.join([state.workspace_folder, "output"])
      _ -> :error
    end
  end

  defp setup_workspace(workspace_folder) do
    File.mkdir_p(Path.join([workspace_folder, "frames"]))
    File.mkdir_p(Path.join([workspace_folder, "thumbs"]))
    File.mkdir_p(Path.join([workspace_folder, "output"]))
    File.mkdir_p(Path.join([workspace_folder, "tweens"]))
    :ok
  end

  @doc """
  the app thumbs or source thumbs are just the first frame of the original raw
  source videos you will be drawing from
  """
  def handle_call({:get_app_thumbs, files}, _from, state) do
    thumbnail_folder = Path.join([state.working_root, "source_thumbs"])

    # Generate thumbnails for each video file if they do not exist
    thumbnails =
      Enum.map(files, fn file ->
        base_name = Path.rootname(file)
        thumbnail_path = Path.join([thumbnail_folder, "#{base_name}.png"])

        unless File.exists?(thumbnail_path) do
          file_path = Path.join([@appDir, file])
          Emulsion.ScriptRunner.execute_extract_one_thumb_from_video(file_path, thumbnail_path)
          Phoenix.PubSub.broadcast(Emulsion.PubSub, "thumbnail_created", {file, thumbnail_path})
        end

        thumbnail_path
      end)

    {:reply, thumbnails, state}
  end

  @doc """
  helper to call the above with just one file at a time
  """
  def get_first_frame_thumbnail(file) do
    GenServer.call(__MODULE__, {:get_app_thumbs, [file]})
    |> hd()
  end

  def extract_frame_number(frame_path) do
    try do
      Regex.named_captures(~r/img_(?<frame_number>\d+)\.png$/, frame_path)["frame_number"]
      |> String.to_integer()
    rescue
      _ ->
        IO.puts("*****************************************************************")
        IO.puts("*I was unable to extract the frame number from #{frame_path}    *")
        IO.puts("*****************************************************************")
    end
  end

  @doc """
  get the pathname for the frame that is 'distance' from the source_frame
  direction can be one of either :forward or :backward
  """
  def get_frame(source_frame, direction, distance) do
    source_frame_number = extract_frame_number(source_frame)

    target_frame_number =
      if direction == :forward do
        source_frame_number + distance
      else
        source_frame_number - distance
      end

    String.replace(source_frame, "#{source_frame_number}", "#{target_frame_number}")
  end
end
