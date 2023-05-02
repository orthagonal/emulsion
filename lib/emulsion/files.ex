defmodule Emulsion.Files do
  use GenServer

  # contains the source videos that we will be working from
  @appDir "e:/intro"


  @resourceTypes [:app_folder, :workspace_folder, :frame_folder, :thumbs_folder, :tween_folder, :output_folder]
  # dir structure looks like:
  # workspace_folder
  #   frame_folder
  #   thumbs_folder
  #   tween_folders (one for each tween we generate)
  #   output_folder

  @pathTypes [:browser, :disk]

  @operations [
    :set_workspace_folder,
    :get_file_list, # returns a list of files in a directory
    :get_file_path, # returns the path to a file in a directory
  ]

  def init(init_state) do
    {:ok, %{
      path_to_original_video: "",
      workspace_folder: "",
      video_folder: ""
    }}
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def handle_call({:set_workspace_folder, path_to_original_video, working_root, path_type}, _from, state) do
    workspace_folder = Path.join([working_root, Path.basename(path_to_original_video, Path.extname(path_to_original_video))])
    video_folder = workspace_folder |> String.replace(working_root, "") |> String.replace("/", "")
    case path_type do
      :disk -> if File.exists?(workspace_folder) do
                 {:reply, workspace_folder, %{ state |
                    path_to_original_video: path_to_original_video,
                    workspace_folder: workspace_folder,
                    video_folder: video_folder
                  }}
               else
                 # create the directory structure
                 setup_workspace(workspace_folder)
                 {:reply, workspace_folder, %{state |
                    path_to_original_video: path_to_original_video,
                    workspace_folder: workspace_folder,
                    video_folder: video_folder
                  }}
               end
      _ -> {:error, "Invalid path type"}
    end
  end

  def handle_call({:get_original_video}, _from, state) do
    {:reply, state.path_to_original_video, state}
  end

  def handle_call({:get_file_list, folder_type}, _from, state) do
    IO.puts "get_file_list"
    IO.puts "get_file_list"
    IO.inspect state
    path = get_folder_path(state, folder_type)
    case path do
      :error -> {:error, "Invalid folder type"}
      _ ->
        IO.puts "get_file_list #{path}"
        {:reply, File.ls!(path), state}
    end
  end

  def handle_call({:get_file_list, folder_type, path_type}, _from, state) do
    path = get_folder_path(state, folder_type)
    IO.inspect state
    case path do
      :error -> {:error, "Invalid folder type"}
      _ ->
        case path_type do
          :disk ->
            {:reply, File.ls!(path), state}
          :browser ->
            list = File.ls!(path)
            paths = for file <- list, do: Path.join(["/file", state.video_folder, print_folder_type(folder_type), file])
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
      :error -> {:error, "Invalid folder type or tween id"}
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

  def handle_call({:convert_disk_path_to_browser_path, disk_path}, _from, state) do
    # Replace backslashes with forward slashes
    forward_slash_path = String.replace(disk_path, "\\", "/")

    # Extract workspace folder from state
    workspace_folder = state.workspace_folder

    # Replace workspace_folder with /file/video_folder
    browser_path = String.replace(forward_slash_path, workspace_folder, "/file/#{state.video_folder}")

    {:reply, browser_path, state}
  end

  defp convert_thumb_path_to_frame_path(thumb_path, state) do
    relative_thumb_path = String.replace(thumb_path, ~r{^/file/\w+/thumbs/}, "")
    frame_folder = get_folder_path(state, :frame_folder)
    Path.join([frame_folder, relative_thumb_path])
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
end
