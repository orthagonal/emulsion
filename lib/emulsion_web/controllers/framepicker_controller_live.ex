defmodule EmulsionWeb.FramePickerControllerLive do
  use EmulsionWeb, :live_view
  use Phoenix.HTML
  import Ecto.Query, only: [from: 2]
  import Emulsion


  @video_src_folder "e:/intro"
  # @video_src_file "MVI_5820.MOV"

  @modes [:select_source_frame, :select_dest_frame, :add_to_ghostidle, :select_continuous_frames]

  # select modes should be:
  # 0 select continuous sequence as initial starting point then go to
  # 1 add to ghostidle
    # (selecting frames causes that frame to be added as an input/output connection for all other input/output frames)
    # connect mode determines the type of connection

  # 2 select src frame and select dst frame
    # specifically select
    # 2 bridge to external (select a frame as the output frame and select another frame as the input frame)

  # connect modes should be:
  # 1. flow-connect it by generating tween frames
  # 2. edit cut is just a cut to the next sequence
  # 3. fade out/in (can specify fade curve)

  def mount(session, params, socket) do
    # IO.inspect "mounting framepicker"
    # IO.inspect params
    # IO.inspect session
    # IO.inspect socket.assigns
    # thumbFiles = get_thumbs_from_directory()
    # thumbFiles = GenServer.call(Emulsion.Files, {:get_thumbs_from_directory})
    # if Map.has_key? session, "ghostidle_name" do

    # end
    # mode = :select_working_dir
    Phoenix.PubSub.subscribe(Emulsion.PubSub, "topic_files")

    { :ok, rawFiles } = File.ls(@video_src_folder)
    files = rawFiles |> Enum.filter(fn f -> String.ends_with?(f, ".MOV") end)
    {
      :ok,
      assign(socket,
        mode: :select_initial_video,
        video_src_folder: @video_src_folder,
        tweenLength: 4,
        files: files,
      )
    }
  end

  def handle_event("select_initial_video", event, socket) do
    GenServer.cast(Emulsion.Files, {:set_working_dir, Path.join([@video_src_folder, event["file"] ]) } )
    GenServer.cast(Emulsion.Video, :split_video_into_frames)
    IO.inspect "splitting video now"
    {:noreply, socket, }
  end

  # respond to events from the video server
  # format of msg is:
  # %{
  #   dir: "e:/emulsion_workspace/MVI_5852/frames",
  #   file_count: 351,
  #   watchname: "e:/emulsion_workspace?MVI_5852/frames",
  #   watchtype: :split_video_shell_operation
  # }

  def handle_info({:operation_complete, %{ watchtype: :split_video_shell_operation } = msg}, socket) do
    thumbFiles = GenServer.call(Emulsion.Files, {:get_list_of_thumbs})
    IO.inspect thumbFiles
    {
      :noreply,
      assign(socket, %{
        mode: :want_to_select_source,
        thumbFiles: thumbFiles,
        srcFrame: thumbFiles |> List.first,
        destFrame: thumbFiles |> List.last,
        selected_frames: [],
        videoPath: "",
        videoPreviewVisible: true
      })
    }
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

  def handle_event("want_to_select_source", event, socket) do
    {:noreply, assign(socket, mode: :select_source_frame)}
  end

  def handle_event("want_to_select_dest", event, socket) do
    {:noreply, assign(socket, mode: :select_dest_frame)}
  end

  # def handle_event("toggle_video_preview", event, socket) do
  #   {:noreply, assign(socket, videoPreviewVisible: !socket.assigns.videoPreviewVisible)}
  # end

  def handle_event("generate_tween", event, socket) do
    srcFrame = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, socket.assigns.srcFrame})
    destFrame = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, socket.assigns.destFrame})
    tweenLength = socket.assigns.tweenLength
    GenServer.cast(Emulsion.Video, {:generate_tween_and_video, srcFrame, destFrame, tweenLength})
    # how do i make it notify when the tween is done? this needs to have a pubsub listener for the
    # :operation_complete, {operationtype: "tweengeneration"} message or something like that
    {:noreply, socket}
    # {:noreply, assign(
    #   socket,
    #   mode: :select_source_frame,
    #   videoPath: tweenName |> Path.basename, # in browser don't include the full path
    # )}
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
