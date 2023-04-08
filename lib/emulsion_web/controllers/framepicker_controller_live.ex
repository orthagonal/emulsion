defmodule EmulsionWeb.FramePickerControllerLive do
  use EmulsionWeb, :live_view
  use Phoenix.HTML
  import Ecto.Query, only: [from: 2]
  import Emulsion

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
    IO.inspect "mounting framepicker"
    IO.inspect params
    IO.inspect session
    IO.inspect socket.assigns
    # thumbFiles = get_thumbs_from_directory()
    thumbFiles = GenServer.call(Emulsion.Files, {:get_thumbs_from_directory})
    # if Map.has_key? session, "ghostidle_name" do

    # end
    mode = :select_working_dir

    {
      :ok,
      assign(socket,
        thumbFiles: thumbFiles,
        srcFrame: thumbFiles |> List.first,
        destFrame: thumbFiles |> List.last,
        selected_frames: [],
        mode: :select_source_frame,
        videoPath: "",
        videoPreviewVisible: true
      )
    }
  end

  def handle_event("toggle_video_preview", event, socket) do
    {:noreply, assign(socket, videoPreviewVisible: !socket.assigns.videoPreviewVisible)}
  end

  def handle_event("select_working_directory", event, socket) do
    {:noreply, assign(socket, mode: :select_working_directory)}
  end

  # is important to return
  # def handle_event("generate_tween", event, socket) do
  #   IO.inspect "generating tween"
  #   tweenName = Emulsion.Disc.get_full_tween_path(socket.assigns.srcFrame, socket.assigns.destFrame)
  #   # export_tween(socket.assigns.srcFrame, socket.assigns.destFrame, tweenName)
  #   {:noreply, assign(
  #     socket,
  #     mode: :select_source_frame,
  #     videoPath: tweenName |> Path.basename, # in browser don't include the full path
  #   )}
  # end

  def handle_event("want_to_select_source", event, socket) do
    {:noreply, assign(socket, mode: :select_source_frame)}
  end
  def handle_event("want_to_select_dest", event, socket) do
    {:noreply, assign(socket, mode: :select_dest_frame)}
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
