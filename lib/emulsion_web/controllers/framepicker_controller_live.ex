defmodule EmulsionWeb.FramePickerControllerLive do
  use EmulsionWeb, :live_view
  use Phoenix.HTML
  import Ecto.Query, only: [from: 2]
  import Emulsion



  @modes [:select_source_frame, :select_dest_frame, :add_to_ghostidle, :select_continuous_frames]

  def mount(session, params, socket) do
    Phoenix.PubSub.subscribe(Emulsion.PubSub, "topic_files")
    files = GenServer.call(Emulsion.Video, {:list_resources, :source})
    {
      :ok,
      assign(socket,
        working_root: "e:/emulsion_workspace",
        mode: :select_initial_video,
        files: files,
        currentVideo: ""
      )
    }
  end


#   <button class="border-2 shadow-lg" phx-click="toggle_video_preview">
#   Toggle Video Preview
# </button>
# <div if={@videoPreviewVisible}>
#   <video id="video" controls autoplay src={"/file/" <> @videoPath}>
#   </video>
# </div>

  # when they select the initial video, make/set the workspace for that video
  # and populate the frame and thumb folders
  # set the mode to :select_source_frame
  def handle_event("select_initial_video", %{ "file" => file } = event, socket) do
    case GenServer.call(Emulsion.Video, {:set_working_video, file, socket.assigns.working_root }) do
      true ->
        IO.puts "gonna split"
        thumbFiles = GenServer.call(Emulsion.Video, {:split_video_into_frames})
        IO.puts "split yields #{inspect thumbFiles}"
        IO.inspect thumbFiles |> List.first
        {:noreply, socket |> assign(%{
          # mode: :want_to_select_source,
          mode: :select_source_frame,
          thumbFiles: thumbFiles,
          srcFrame: thumbFiles |> List.first,
          destFrame: thumbFiles |> List.last,
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

    srcFolderPath = Path.dirname(srcFramePath)
    output_dir = GenServer.call(Emulsion.Files, {:get_file_path, "", :output_folder, :disk})

    start_frame = srcFrameNumber
    number_of_frames = destFrameNumber - srcFrameNumber + 1
    outputVideoName = Path.join([output_dir, "#{srcFrameNumber}_thru_#{destFrameNumber}.webm"])
    pid = self()

    # call a Task.start_link that calls the script runner
    Task.start_link(fn ->
      Emulsion.ScriptRunner.execute_generate_sequential_video(
        srcFolderPath, start_frame, number_of_frames, outputVideoName
      )
      video_name = GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, outputVideoName})
      send(pid, {:sequence_generated, video_name})
    end)

    {:noreply, socket}
  end

  defp extract_frame_number(frame_path) do
    Regex.named_captures(~r/img_(?<frame_number>\d+)\.png$/, frame_path)["frame_number"]
    |> String.to_integer()
  end

  def handle_event("generate_tween", event, socket) do
    srcFrame = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, socket.assigns.srcFrame})
    destFrame = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, socket.assigns.destFrame})
    tweenLength = Map.get(socket.assigns, :tweenLength, "5")
    # make a call for this that wraps the GenServer cast and does the Task.start_link stuff
    # so that it can call back when the tween is done
    pid = self()
    # call a Task.start_link that calls the GenServer.cast
    Task.start_link(fn ->
      video_name = GenServer.call(Emulsion.Video, {:generate_tween_and_video, srcFrame, destFrame, tweenLength}, 999_999)
      basename = Path.basename(video_name)
      # convert the video name to one suitable fofr use in the browser with the '/file/' prefix
      video_name = GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, video_name})
      send(pid, {:tween_generated, video_name})
    end)
    {:noreply, socket}
  end

  def handle_info({:sequence_generated, video_name }, socket) do
    {:noreply, assign(socket, currentVideo: video_name)}
  end

  def handle_info({:tween_generated, video_name }, socket) do
    {:noreply, assign(socket, currentVideo: video_name)}
  end

  def handle_event("click_frame", %{ "frame" => frame } = event, socket) do
    # set either dst or src frame to
    if socket.assigns.mode == :select_source_frame do
      {:noreply, assign(socket, srcFrame: frame)}
    else
      {:noreply, assign(socket, destFrame: frame)}
    end
  end

end
