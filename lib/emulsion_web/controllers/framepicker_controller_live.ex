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

  # respond to events from the video server
  # format of msg is:
  # %{
  #   dir: "e:/emulsion_workspace/MVI_5852/frames",
  #   file_count: 351,
  #   watchname: "e:/emulsion_workspace?MVI_5852/frames",
  #   watchtype: :split_video_shell_operation
  # }

  # def handle_info({:operation_complete, %{ watchtype: :split_video_shell_operation } = msg}, socket) do
  #   thumbFiles = GenServer.call(Emulsion.Files, {:get_list_of_thumbs})
  #   IO.inspect thumbFiles
  #   {
  #     :noreply,
  #     assign(socket, %{
  #       mode: :want_to_select_source,
  #       thumbFiles: thumbFiles,
  #       srcFrame: thumbFiles |> List.first,
  #       destFrame: thumbFiles |> List.last,
  #       selected_frames: [],
  #       videoPath: "",
  #       videoPreviewVisible: true
  #     })
  #   }
  # end

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
    Regex.named_captures(~r/img_(?<frame_number>\d+)\.png$/, frame_path)["frame_number"]
    |> String.to_integer()
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
end
