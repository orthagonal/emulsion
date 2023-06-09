defmodule EmulsionWeb.FramePickerControllerLive do
  use EmulsionWeb, :live_view
  use Phoenix.HTML
  import Ecto.Query, only: [from: 2]
  import Emulsion

  @modes [:select_source_frame, :select_dest_frame, :add_to_ghostidle, :select_continuous_frames]

  def mount(session, params, socket) do
    Phoenix.PubSub.subscribe(Emulsion.PubSub, "topic_files")
    files = GenServer.call(Emulsion.Video, {:list_resources, :source}, :infinity)
    nodes = []#%{id: 1, label: "Node 1"}, %{id: 2, label: "Node 2"}]
    edges = []#%{from: 1, to: 2}]
    diagram = Jason.encode!(%{nodes: nodes, edges: edges})
    {
      :ok,
      assign(socket,
        working_root: "e:/emulsion_workspace",
        mode: :select_initial_video,
        files: files,
        current_video: "",
        diagram: diagram,
        saved_playgraph_filename: "",
        saved_playgraphs: [],
        selected_playgraph: "",
        selected_node_id: "", selected_edge_id: ""
      )
    }
  end

  def handle_event("update_export_file", %{"export_file" => export_file}, socket) do
    {:noreply, assign(socket, :export_file, export_file)}
  end

  def handle_event("export", _, socket) do
    Emulsion.Playgraph.export_playgraph(socket.assigns.export_file)
    {:noreply, socket}
  end


  @doc """
  list the playgraphs in the workspace
  """
  def handle_event("video_started", %{"video_name" => video_name}, socket) do
    # Handle video start event, maybe you want to log it or change some state
    {:noreply, socket}
  end

  # when they select the initial video, make/set the workspace for that video
  # and populate the frame and thumb folders
  # set the mode to :select_source_frame
  def handle_event("select_initial_video", %{ "file" => file } = event, socket) do
    case GenServer.call(Emulsion.Video, {:set_working_video, file, socket.assigns.working_root }) do
      true ->
        thumbFiles = GenServer.call(Emulsion.Video, {:split_video_into_frames}, :infinity)
        saved_playgraphs_path = Path.join([socket.assigns.working_root, "saved_playgraphs"])
        saved_playgraphs = Emulsion.Playgraph.get_saved_playgraphs(saved_playgraphs_path)
        selected_playgraph = saved_playgraphs |> List.first("")
        {:noreply, socket |> assign(%{
          # mode: :want_to_select_source,
          mode: :select_source_frame,
          thumbFiles: thumbFiles,
          srcFrame: thumbFiles |> List.first,
          destFrame: thumbFiles |> List.last,
          saved_playgraphs: saved_playgraphs,
          selected_playgraph: selected_playgraph,
        }
        )}
      false ->
        IO.puts "error setting working video"
        {:noreply, put_flash(socket, :error, "Error setting working video")}
    end
  end

  def handle_event("want_to_select_source", event, socket) do
    {:noreply, assign(socket, mode: :select_source_frame)}
  end

  def handle_event("want_to_select_dest", event, socket) do
    {:noreply, assign(socket, mode: :select_dest_frame)}
  end

  # handle the pubsub :operation_complete message
  def handle_info({:operation_complete, msg}, socket) do
    IO.inspect "operation complete"
    IO.inspect msg
      # thumbFiles: thumbFiles,
      # srcFrame: thumbFiles |> List.first,
      # destFrame: thumbFiles |> List.last,
      # selected_frames: [],
      # videoPath: "",
      # videoPreviewVisible: true
    {:noreply, socket}
  end

  # def handle_event("toggle_video_preview", event, socket) do
  #   {:noreply, assign(socket, videoPreviewVisible: !socket.assigns.videoPreviewVisible)}
  # end
  def handle_event("generate_sequence", event, socket) do
    srcFramePath = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, socket.assigns.srcFrame})
    destFramePath = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, socket.assigns.destFrame})

    srcFrameNumber = extract_frame_number(srcFramePath)
    destFrameNumber = extract_frame_number(destFramePath)

    IO.puts " the frame numbers is #{srcFrameNumber} thru #{destFrameNumber}"

    srcFolderPath = Path.dirname(srcFramePath)
    output_dir = GenServer.call(Emulsion.Files, {:get_file_path, "", :output_folder, :disk})

    start_frame = srcFrameNumber
    number_of_frames = destFrameNumber - srcFrameNumber + 1
    IO.puts "start frame is #{start_frame} and number of frames is #{number_of_frames}"
    outputVideoName = Path.join([output_dir, "#{srcFrameNumber}_thru_#{destFrameNumber}.webm"])
    pid = self()

    # call a Task.start_link that calls the script runner
    Task.start_link(fn ->
      Emulsion.ScriptRunner.execute_generate_sequential_video(
        srcFolderPath, start_frame, number_of_frames, outputVideoName
      )
      video_name = GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, outputVideoName})
      Emulsion.Playgraph.add_node(srcFramePath)
      Emulsion.Playgraph.add_node(destFramePath)
      Emulsion.Playgraph.add_edge(srcFramePath, destFramePath, outputVideoName |> Path.basename, outputVideoName)
      IO.puts "script runner ran fine"
      send(pid, {:sequence_generated, video_name})
    end)

    {:noreply, socket}
  end

  defp extract_frame_number(frame_path) do
    try do
      Regex.named_captures(~r/img_(?<frame_number>\d+)\.png$/, frame_path)["frame_number"]
      |> String.to_integer()
    rescue
      _ ->
        IO.puts "*****************************************************************"
        IO.puts "*I was unable to extract the frame number from #{frame_path}    *"
        IO.puts "*****************************************************************"
    end
  end

  @doc """
  Generate a tween video from the selected source and destination frames
  """
  def handle_event("generate_tween", event, socket) do
    srcFrame = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, socket.assigns.srcFrame})
    destFrame = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, socket.assigns.destFrame})
    tweenLength = Map.get(socket.assigns, :tweenLength, "5")
    # make a call for this that wraps the GenServer cast and does the Task.start_link stuff
    # so that it can call back when the tween is done
    pid = self()
    # call a Task.start_link that calls the GenServer.cast
    # Task.start_link(fn ->
    #   video_name = GenServer.call(Emulsion.Video, {:generate_tween_and_video, srcFrame, destFrame, tweenLength}, 999_999)
    #   basename = Path.basename(video_name)
    #   # convert the video name to one suitable fofr use in the browser with the '/file/' prefix
    #   video_name = GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, video_name})
    #   send(pid, {:tween_generated, video_name})
    # end)
    Task.start_link(fn ->
      video_name = GenServer.call(Emulsion.Video, {:generate_tween_and_video, srcFrame, destFrame, tweenLength}, 999_999)
      basename = Path.basename(video_name)
      # convert the video name to one suitable for use in the browser with the '/file/' prefix
      video_name = GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, video_name})
      # add nodes and edge to the graph
      Emulsion.Playgraph.add_node(srcFrame)
      Emulsion.Playgraph.add_node(destFrame)
      Emulsion.Playgraph.add_edge(srcFrame, destFrame, basename, video_name)
      send(pid, {:tween_generated, video_name})
    end)
    {:noreply, socket}
  end

  def handle_info({:sequence_generated, video_name }, socket) do
    nodes = GenServer.call(Emulsion.Playgraph, {:get_nodes})
    edges = GenServer.call(Emulsion.Playgraph, {:get_edges})
    newsocket =
      socket
      |> assign(current_video: video_name)
      |> push_event("update_graph", %{nodes: nodes, edges: edges})
    {:noreply, newsocket}
  end

  def handle_info({:tween_generated, video_name }, socket) do
    nodes = GenServer.call(Emulsion.Playgraph, {:get_nodes})
    edges = GenServer.call(Emulsion.Playgraph, {:get_edges})
    newsocket =
      socket
      |> assign(current_video: video_name)
      |> push_event("update_graph", %{nodes: nodes, edges: edges})
    {:noreply, newsocket}
  end

  def handle_event("click_frame", %{ "frame" => frame } = event, socket) do
    # set either dst or src frame to
    if socket.assigns.mode == :select_source_frame do
      {:noreply, assign(socket, srcFrame: frame)}
    else
      {:noreply, assign(socket, destFrame: frame)}
    end
  end

  # a hande shortcut to set the source frame to the current dest frame
  # makes it easy to build continuous paths through the video
  def handle_event("set_source_to_dest", event, socket) do
    {:noreply, assign(socket, srcFrame: socket.assigns.destFrame, mode: :select_dest_frame)}
  end

  def handle_event("update_saved_playgraph_filename", %{"saved_playgraph_filename" => filename}, socket) do
    {:noreply, assign(socket, :saved_playgraph_filename, filename)}
  end

  def handle_event("save", %{}, socket) do
    path = Path.join([socket.assigns.working_root, "saved_playgraphs", socket.assigns.saved_playgraph_filename])
    :ok = File.mkdir_p(Path.dirname(path))
    :ok = Emulsion.Playgraph.save(path)
    {:noreply, socket}
  end

  def handle_event("update_selected_playgraph", %{"selected_playgraph" => selected_playgraph}, socket) do
    {:noreply, assign(socket, :selected_playgraph, selected_playgraph)}
  end

  def handle_event("load", _params, socket) do
    playgraph_filename = socket.assigns.selected_playgraph
    file_path = Path.join([socket.assigns.working_root, "saved_playgraphs", playgraph_filename])
    IO.inspect file_path
    :ok = Emulsion.Playgraph.load(file_path)
    nodes = GenServer.call(Emulsion.Playgraph, {:get_nodes})
    edges = GenServer.call(Emulsion.Playgraph, {:get_edges})
    newsocket =
      socket
      |> push_event("update_graph", %{nodes: nodes, edges: edges})

    {:noreply, newsocket}
  end

  def handle_event("divide_by", %{"division_value" => division_value, "start_at" => start_at, "end_at" => end_at}, socket) do
    thumbFiles = socket.assigns.thumbFiles
    x = String.to_integer(division_value)
    i = if(start_at != "", do: String.to_integer(start_at), else: 0)
    j = if(end_at != "", do: String.to_integer(end_at), else: length(thumbFiles) - 1)
    pid = self()
    Task.start_link(fn ->
      while_frames_divide(i, i + x, thumbFiles, x, pid, j)
    end)

    {:noreply, socket}
  end

  defp while_frames_divide(_i, _j, _thumbFiles, _x, _pid, _max_j) when _j > _max_j, do: :ok

  defp while_frames_divide(i, j, thumbFiles, x, pid, max_j) do
      srcFrame = Enum.at(thumbFiles, i)
      destFrame = Enum.at(thumbFiles, j)

      # Get the actual frame file names using :get_frame_from_thumb
      srcFrame = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, srcFrame})
      destFrame = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, destFrame})

      Emulsion.Video.generate_tween_and_video(srcFrame, destFrame, "5")
      |> handle_tween_result(srcFrame, destFrame, pid)

      Emulsion.Video.generate_tween_and_video(destFrame, srcFrame, "5")
      |> handle_tween_result(destFrame, srcFrame, pid)

      while_frames_divide(i + x, j + x, thumbFiles, x, pid, max_j)
  end

  defp handle_tween_result(video_name, srcFrame, destFrame, pid) do
    video_name = GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, video_name})

    # Add nodes and edge to the graph
    Emulsion.Playgraph.add_node(srcFrame)
    Emulsion.Playgraph.add_node(destFrame)
    Emulsion.Playgraph.add_edge(srcFrame, destFrame, Path.basename(video_name), video_name)

    # Notify the LiveView process
    send(pid, {:tween_generated, video_name})
  end

  def handle_event("select_node", %{"node_id" => node_id}, socket) do
    IO.puts "this is the node_id: #{node_id}"
    {:noreply, assign(socket, selected_node_id: node_id)}
  end

  def handle_event("select_edge", %{"edge_id" => edge_id}, socket) do
    {:noreply, assign(socket, selected_edge_id: edge_id)}
  end

  def handle_event("tag_edge", %{  "edge_id" => edge_id, "tag" => tag }, socket) do
    Emulsion.Playgraph.tag_edge(edge_id, tag)
    IO.puts "display it"
    IO.inspect Emulsion.Playgraph.get_edges()
    {:noreply, socket}
  end

  def handle_event("idle_around_frame", %{"src_frame" => src_frame, "range" => range}, socket) do
    IO.puts "*********************************"
    IO.puts "idle_around_frame: #{src_frame}"
    IO.puts "*********************************"
    generate_idle_tween(src_frame, range, :forward)
    generate_idle_tween(src_frame, range, :backward)

    {:noreply, socket}
  end

  defp generate_idle_tween(src_frame, range, direction) when is_binary(range) do
    range = String.to_integer(range)
    generate_idle_tween(src_frame, range, direction)
  end

  defp generate_idle_tween(src_frame, range, direction) do
    frame_num = extract_frame_number(src_frame)
    frame_name = Path.basename(src_frame)

    pid = self()

    Task.start_link(fn ->
      case direction do
        :forward ->
          # forward to the new frame:
          dest_frame_num = frame_num + range
          dest_frame = String.replace(src_frame, "#{frame_num}", "#{dest_frame_num}")
          video_name = GenServer.call(Emulsion.Video, {:generate_tween_and_video, src_frame, dest_frame, "5"}, 999_999)
          basename = Path.basename(video_name)
          video_name = GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, video_name})
          Emulsion.Playgraph.add_node(dest_frame)
          Emulsion.Playgraph.add_edge(src_frame, dest_frame, basename, video_name)
          Emulsion.Playgraph.tag_edge(basename, "idle")
          send(pid, {:tween_generated, video_name})

          # and back to the original frame:
          video_name = GenServer.call(Emulsion.Video, {:generate_tween_and_video, dest_frame, src_frame, "5"}, 999_999)
          basename = Path.basename(video_name)
          video_name = GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, video_name})
          Emulsion.Playgraph.add_edge(dest_frame, src_frame, basename, video_name)
          Emulsion.Playgraph.tag_edge(basename, "idle")
          send(pid, {:tween_generated, video_name})

        :backward ->
          # forward to the new frame:
          dest_frame_num = frame_num - range
          dest_frame = String.replace(src_frame, "#{frame_num}", "#{dest_frame_num}")
          video_name = GenServer.call(Emulsion.Video, {:generate_tween_and_video, src_frame, dest_frame, "5"}, 999_999)
          basename = Path.basename(video_name)
          video_name = GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, video_name})
          Emulsion.Playgraph.add_node(dest_frame)
          Emulsion.Playgraph.add_edge(src_frame, dest_frame, basename, video_name)
          Emulsion.Playgraph.tag_edge(basename, "idle")
          send(pid, {:tween_generated, video_name})

          # and back to the original frame:
          video_name = GenServer.call(Emulsion.Video, {:generate_tween_and_video, dest_frame, src_frame, "5"}, 999_999)
          basename = Path.basename(video_name)
          video_name = GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, video_name})
          Emulsion.Playgraph.add_edge(dest_frame, src_frame, basename, video_name)
          Emulsion.Playgraph.tag_edge(basename, "idle")
          send(pid, {:tween_generated, video_name})
        end
    end)
  end

  def handle_event("idleize_all", %{"range" => range}, socket) do
    Task.start_link(fn ->
      # Get nodes
      nodes = GenServer.call(Emulsion.Playgraph, {:get_nodes})
      # Loop through the nodes
      Enum.each(nodes, fn node ->
        handle_event("idle_around_frame", %{"src_frame" => node["id"], "range" => range}, socket)
      end)
    end)
    {:noreply, socket}
  end
end
