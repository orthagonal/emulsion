defmodule EmulsionWeb.FramePickerControllerLive do
  use EmulsionWeb, :live_view
  use Phoenix.HTML
  import Ecto.Query, only: [from: 2]
  import Emulsion

  @modes [:select_source_frame, :select_dest_frame, :add_to_ghostidle, :select_continuous_frames]

  def mount(session, params, socket) do
    Phoenix.PubSub.subscribe(Emulsion.PubSub, "topic_files")
    files = GenServer.call(Emulsion.Video, {:list_resources, :source}, :infinity)
    # %{id: 1, label: "Node 1"}, %{id: 2, label: "Node 2"}]
    nodes = []
    # %{from: 1, to: 2}]
    edges = []
    diagram = Jason.encode!(%{nodes: nodes, edges: edges})

    # if they already selected a video in the previous session use that
    # and set initial mode to select_src_frame
    current_video =
      case Emulsion.Repo.one(Emulsion.SavedState) do
        nil -> ""
        saved_state -> saved_state.initial_video
      end

    mode = if current_video == "", do: :select_initial_video, else: :select_source_frame

    socket =
      assign(socket,
        assets_path: "",
        title: "",
        working_root: "e:/emulsion_workspace",
        mode: mode,
        files: files,
        current_video: current_video,
        diagram: diagram,
        saved_playgraph_filename: "",
        saved_playgraphs: [],
        selected_playgraph: "",
        selected_node_id: "",
        selected_edge_id: "",
        tween_multiplier: 5,
        force_build: false,
        uploaded_files: []
      )
      |> allow_upload(:image, accept: ~w(.jpg .jpeg .png), max_entries: 1)

    if current_video != "" do
      socket = setup_workspace(current_video, socket)
      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  defp setup_workspace(file, socket) do
    case GenServer.call(Emulsion.Video, {:set_working_video, file, socket.assigns.working_root}) do
      true ->
        IO.puts("SET WORKING VIDEO TO #{file}")
        thumbFiles = GenServer.call(Emulsion.Video, {:split_video_into_frames}, :infinity)
        saved_playgraphs_path = Path.join([socket.assigns.working_root, "saved_playgraphs"])
        saved_playgraphs = Emulsion.Playgraph.get_saved_playgraphs(saved_playgraphs_path)
        selected_playgraph = saved_playgraphs |> List.first("")

        socket
        |> assign(%{
          mode: :select_source_frame,
          thumbFiles: thumbFiles,
          srcFrame: thumbFiles |> List.first(),
          destFrame: thumbFiles |> List.last(),
          saved_playgraphs: saved_playgraphs,
          selected_playgraph: selected_playgraph
        })

      false ->
        IO.puts("error setting working video")
        IO.puts("error setting working video")
        IO.puts("error setting working video")
        put_flash(socket, :error, "Error setting working video")
    end
  end

  def handle_event("idle_to", params, socket) do

  end

  # this barebones function must exist for liveview to handle the file upload
  # automagically
  def handle_event("validate_upload", params, socket) do
    {:noreply, socket}
  end

  @doc """
    reset the workspace
  """
  def handle_event("reset", _value, socket) do
    case Emulsion.Repo.one(Emulsion.SavedState) do
      nil -> :ok
      saved_state -> Emulsion.Repo.delete(saved_state)
    end

    # Reset socket assigns
    {:noreply, assign(socket, :mode, :select_initial_video)}
  end

  # when they select the initial video, make/set the workspace for that video
  # and populate the frame and thumb folders
  # set the mode to :select_source_frame
  def handle_event("select_initial_video", %{"file" => file} = event, socket) do
    # Save the selected initial video
    saved_state = Emulsion.Repo.one(Emulsion.SavedState)

    changeset =
      Emulsion.SavedState.changeset(saved_state || %Emulsion.SavedState{}, %{initial_video: file})

    case Emulsion.Repo.insert_or_update(changeset) do
      {:ok, _saved_state} ->
        IO.puts("success")

      {:error, _changeset} ->
        IO.puts("FAILED")
        # handle this error as you see fit
        {:noreply, socket}
    end

    {:noreply, setup_workspace(file, socket)}
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

  def handle_event("want_to_select_source", event, socket) do
    {:noreply, assign(socket, mode: :select_source_frame)}
  end

  def handle_event("want_to_select_dest", event, socket) do
    {:noreply, assign(socket, mode: :select_dest_frame)}
  end

  def handle_event("import_external_frame", params, socket) do
    # handles writing and thumbnailing the imported frame
    uploaded_files =
      consume_uploaded_entries(socket, :image, fn %{path: path}, _entry ->
        new_thumb_path =
          GenServer.call(Emulsion.Video, {:handle_upload, path, socket.assigns.working_root})
        {:ok, new_thumb_path}
      end)

    # update the thumbs list:
    thumbs_list = GenServer.call(Emulsion.Files, {:get_file_list, :thumbs_folder, :browser})

    {:noreply,
     assign(
       socket,
       %{
         uploaded_files: &(&1 ++ uploaded_files),
         thumbFiles: thumbs_list
       }
     )}
  end

  #   {:noreply, socket}
  # end
  def handle_info({:blur_sequence_generated, msg}, socket) do
    IO.puts "BLUR SEQUENCE GENERATED"

    nodes = P
    {:noreply, socket}
  end

  # handle the pubsub :operation_complete message
  def handle_info({:operation_complete, msg}, socket) do
    IO.inspect("operation complete")
    IO.inspect(msg)
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
  def handle_event("generate_sequence", _event, socket) do
    srcFramePath = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, socket.assigns.srcFrame})
    destFramePath = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, socket.assigns.destFrame})

    pid = self()

    Task.start_link(fn ->
      Emulsion.Video.generate_sequence(srcFramePath, destFramePath, pid)
    end)

    {:noreply, socket}
  end

  def handle_event("update_force_build", params, socket) do
    force_build = Map.get(params, "force_build", false)
    {:noreply, assign(socket, force_build: force_build)}
  end

  def handle_event("update_tween_multiplier", params, socket) do
    tween_multiplier = Map.get(params, "tween_multiplier", 5)
    tween_multiplier_number = tween_multiplier
    {:noreply, assign(socket, tween_multiplier: tween_multiplier_number)}
  end

  @doc """
  Generate a tween video from the selected source and destination frames
  """
  def handle_event("generate_tween", event, socket) do
    srcFrame = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, socket.assigns.srcFrame})
    destFrame = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, socket.assigns.destFrame})
    IO.puts "generating tween"
    IO.puts "generating tween"
    IO.puts "generating tween"
    IO.puts "generating tween"
    IO.inspect srcFrame
    IO.inspect destFrame

    tween_multiplier_number = Map.get(socket.assigns, :tween_multiplier, 5)

    tween_multiplier =
      if is_integer(tween_multiplier_number) do
        Integer.to_string(tween_multiplier_number)
      else
        tween_multiplier_number
      end

    force_build = Map.get(socket.assigns, :force_build, false)
    # make a call for this that wraps the GenServer cast and does the Task.start_link stuff
    # so that it can call back when the tween is done
    pid = self()
    # call a Task.start_link that calls the GenServer.cast
    Task.start_link(fn ->
      video_name =
        GenServer.call(
          Emulsion.Video,
          {:generate_tween_and_video, srcFrame, destFrame, tween_multiplier, force_build},
          999_999
        )

      basename = Path.basename(video_name)
      # convert the video name to one suitable for use in the browser with the '/file/' prefix

      video_name =
        GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, video_name})

      # add nodes and edge to the graph
      Emulsion.Playgraph.add_node(srcFrame)
      Emulsion.Playgraph.add_node(destFrame)
      Emulsion.Playgraph.add_edge(srcFrame, destFrame, basename, video_name)
      send(pid, {:tween_generated, video_name})
    end)

    {:noreply, socket}
  end

  def handle_info({:sequence_generated, video_name}, socket) do
    IO.puts "sequence was generated"
    IO.puts "sequence was generated"
    IO.puts "sequence was generated"
    IO.puts "sequence was generated"
    nodes = GenServer.call(Emulsion.Playgraph, {:get_nodes})
    edges = GenServer.call(Emulsion.Playgraph, {:get_edges})
    IO.inspect nodes
    IO.inspect edges
    newsocket =
      socket
      |> assign(current_video: video_name, nodes: nodes, edges: edges)
      |> push_event("update_graph", %{nodes: nodes, edges: edges})
      IO.puts "updated new nodes"
    {:noreply, newsocket}
  end

  def handle_info({:tween_generated, video_name}, socket) do
    nodes = GenServer.call(Emulsion.Playgraph, {:get_nodes})
    edges = GenServer.call(Emulsion.Playgraph, {:get_edges})

    newsocket =
      socket
      |> assign(current_video: video_name)
      |> push_event("update_graph", %{nodes: nodes, edges: edges})

    IO.puts("pushed event")
    {:noreply, newsocket}
  end

  def handle_event("click_frame", %{"frame" => frame} = event, socket) do
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

  def handle_event(
        "update_saved_playgraph_filename",
        %{"saved_playgraph_filename" => filename},
        socket
      ) do
    {:noreply, assign(socket, :saved_playgraph_filename, filename)}
  end

  def handle_event("save", %{}, socket) do
    path =
      Path.join([
        socket.assigns.working_root,
        "saved_playgraphs",
        socket.assigns.saved_playgraph_filename
      ])

    :ok = File.mkdir_p(Path.dirname(path))
    :ok = Emulsion.Playgraph.save(path)
    {:noreply, socket}
  end

  def handle_event(
        "update_selected_playgraph",
        %{"selected_playgraph" => selected_playgraph},
        socket
      ) do
    {:noreply, assign(socket, :selected_playgraph, selected_playgraph)}
  end

  def handle_event("load", _params, socket) do
    playgraph_filename = socket.assigns.selected_playgraph
    file_path = Path.join([socket.assigns.working_root, "saved_playgraphs", playgraph_filename])
    IO.inspect(file_path)
    :ok = Emulsion.Playgraph.load(file_path)
    nodes = GenServer.call(Emulsion.Playgraph, {:get_nodes})
    edges = GenServer.call(Emulsion.Playgraph, {:get_edges})

    newsocket =
      socket
      |> push_event("update_graph", %{nodes: nodes, edges: edges})

    {:noreply, newsocket}
  end

  defp handle_tween_result(video_name, srcFrame, destFrame, pid) do
    IO.puts("handling tween result")
    video_name = GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, video_name})
    IO.inspect(video_name)
    # Add nodes and edge to the graph
    Emulsion.Playgraph.add_node(srcFrame)
    Emulsion.Playgraph.add_node(destFrame)
    Emulsion.Playgraph.add_edge(srcFrame, destFrame, Path.basename(video_name), video_name)

    # Notify the LiveView process
    send(pid, {:tween_generated, video_name})
  end

  def handle_event("select_node", %{"node_id" => node_id}, socket) do
    IO.puts("this is the node_id: #{node_id}")
    {:noreply, assign(socket, selected_node_id: node_id)}
  end

  def handle_event("select_edge", %{"edge_id" => edge_id}, socket) do
    {:noreply, assign(socket, selected_edge_id: edge_id)}
  end

  def handle_event("tag_edge", %{"edge_id" => edge_id, "tag" => tag}, socket) do
    Emulsion.Playgraph.tag_edge(edge_id, tag)
    IO.puts("display it")
    IO.inspect(Emulsion.Playgraph.get_edges())
    {:noreply, socket}
  end

  def handle_event("delete_edge", %{"edge_id" => edge_id}, socket) do
    # Call the Playgraph's :delete_edge handler:
    {:ok, _result} = GenServer.call(Emulsion.Playgraph, {:delete_edge, edge_id})

    # Do any further processing if needed, and update the socket:
    {:noreply, socket}
  end

  def handle_event("idle_around_frame", %{"src_frame" => src_frame, "range" => range}, socket) do
    IO.puts("*********************************")
    IO.puts("idle_around_frame: #{src_frame}")
    IO.puts("*********************************")
    Emulsion.Idioms.generate_idle_tween(src_frame, range, :forward)
    Emulsion.Idioms.generate_idle_tween(src_frame, range, :backward)

    {:noreply, socket}
  end

  def handle_event("idleize_all", %{"range" => range}, socket) do
    Task.start_link(fn ->
      # Get nodes
      nodes = GenServer.call(Emulsion.Playgraph, {:get_nodes})
      # sort the nodes from lowest first
      nodes = Enum.sort_by(nodes, fn node -> node["id"] end)
      # Loop through the nodes
      Enum.each(nodes, fn node ->
        handle_event("idle_around_frame", %{"src_frame" => node["id"], "range" => range}, socket)
      end)
    end)

    {:noreply, socket}
  end

  def handle_event("idleify_blur_frame", params, socket) do
    Emulsion.Idioms.idleify_blur_frame(socket.assigns.srcFrame, socket.assigns.destFrame, socket.assigns.tween_multiplier, socket.assigns.force_build, self())
    {:noreply, socket}
  end

  def handle_event(
        "idleify_frame",
        %{
          "current_frame" => current_frame,
          "idle_range" => idle_range,
          "connect_frame" => connect_frame
        },
        socket
      ) do
    force_build = socket.assigns.force_build
    tween_multiplier = socket.assigns.tween_multiplier

    case Emulsion.Idioms.idleify_frame(
           current_frame,
           idle_range,
           connect_frame,
           tween_multiplier,
           force_build,
           self()
         ) do
      {:ok, _} ->
        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("export_all", %{"assets_path" => assets_path, "title" => title}, socket) do
    # Get the playgraph from the playgraph server
    playgraph = Emulsion.Playgraph.get_playgraph()

    # Define templates
    # TODO: make a selector to choose whichtemplates to export
    templates = %{
      html_template: "core_trunk_template.html",
      # js_template: "core_script.js",
      js_template: "webgpu_core_script.js",
      playgraph_template: "core_playgraph.js"
    }

    # Call Exporter.export_all
    Emulsion.Exporter.export_all(title, playgraph, templates, assets_path)

    {:noreply, assign(socket, assets_path: assets_path, title: title)}
  end

  def handle_event("regenerate_video", %{"from" => from, "to" => to, "edge_type" => edge_type}, socket) do
    case edge_type do
      "tween" ->
        Emulsion.Video.generate_tween_and_video(from, to, socket.assigns.tween_multiplier, true)
      "sequence" ->
        IO.puts "JJJJJ"
        IO.puts "JJJJJ"
        IO.puts "JJJJJ"
        # regenerate_sequence(from, to)
      _ ->
          IO.puts "I ODONT KNOW WHAT TO DO"
          IO.puts "I ODONT KNOW WHAT TO DO"
          IO.puts "I ODONT KNOW WHAT TO DO"
          IO.puts "I ODONT KNOW WHAT TO DO"
          IO.puts "I ODONT KNOW WHAT TO DO"
        # Handle other edge types or an error scenario
        {:noreply, socket}
    end
    {:noreply, socket}
  end

  def handle_event("regenerate_video", %{"edge_id" => edge_id, "edge_type" => "sequence"}, socket) do
    # call the regenerate_sequences function
    # IO.puts "this is a sequence regenerate"
    # IO.puts "this is a sequence regenerate"
    # IO.inspect socket.assigns
    # Emulsion.Video.regenerate_sequences(%{edges: [%{id: edge_id}]})
    {:noreply, socket}
  end
end
