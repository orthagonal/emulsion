defmodule Emulsion.Idioms do
  @moduledoc """
    Emulsion.Idioms

    This module contains idioms for Emulsion.
    Generate idle tween: generates one tween video transitioning from a source frame to a dest frame and then one transitioning back, can play on a infinite loop without break
    Idleify_frame:  generates idle tweens and also adds a 'exit' sequence to a new destination frame  This allows the player to 'idle' around a frame infinitely until the user chooses to move on.
  """

  alias Emulsion.Files
  alias Emulsion.Playgraph

  @doc """
  idle tweens are videos that go from a source frame to a dest frame and then back to the source frame
    this allows the player to 'idle' around a frame infinitely until the user chooses to move on.
  """
  def generate_idle_tween(src_frame, range, direction, tween_multiplier, force_build)
      when is_binary(range) do
    range = String.to_integer(range)
    generate_idle_tween(src_frame, range, direction, tween_multiplier, force_build)
  end

  def generate_idle_tween(src_frame, range, direction, tween_multiplier, force_build) do
    dest_frame = Files.get_frame(src_frame, direction, range)
    pid = self()

    handle_forward_tween(pid, src_frame, dest_frame, tween_multiplier, force_build)
    handle_backward_tween(pid, dest_frame, src_frame, tween_multiplier, force_build)
  end

  defp handle_forward_tween(pid, src_frame, dest_frame, tween_multiplier, force_build) do
    Task.start_link(fn ->
      generate_tweens(
        pid,
        src_frame,
        dest_frame,
        ["idle", "from_src"],
        tween_multiplier,
        force_build
      )
    end)
  end

  defp handle_backward_tween(pid, src_frame, dest_frame, tween_multiplier, force_build) do
    Task.start_link(fn ->
      generate_tweens(
        pid,
        src_frame,
        dest_frame,
        ["idle", "to_src"],
        tween_multiplier,
        force_build
      )
    end)
  end

  defp generate_tweens(pid, from_frame, to_frame, tag, tween_multiplier, force_build) do
    # add the two nodes to the playgraph first so that both edges can be added once they are generated
    Playgraph.add_node(from_frame)
    Playgraph.add_node(to_frame)

    video_name =
      GenServer.call(
        Emulsion.Video,
        {:generate_tween_and_video, from_frame, to_frame, tween_multiplier, force_build},
        999_999
      )
    video_name = GenServer.call(Files, {:convert_disk_path_to_browser_path, video_name})
    basename = Path.basename(video_name)

    Playgraph.add_edge(from_frame, to_frame, basename, video_name)
    Playgraph.tag_edge(basename, tag)

    send(pid, {:tween_generated, video_name})
  end

  def prepare_frames(current_frame, connect_frame) do
    from_frame_path = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, current_frame})
    to_frame_path = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, connect_frame})
    srcFrameNumber = Emulsion.Files.extract_frame_number(from_frame_path)
    destFrameNumber = Emulsion.Files.extract_frame_number(to_frame_path)

    {from_frame_path, to_frame_path, srcFrameNumber, destFrameNumber}
  end

  def generate_idle_tween(current_frame, idle_range, tween_multiplier, force_build) do
    from_frame_path = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, current_frame})

    Emulsion.Idioms.generate_idle_tween(
      from_frame_path,
      idle_range,
      :forward,
      force_build,
      tween_multiplier
    )
  end

  def prepare_for_task(srcFrameNumber, destFrameNumber, current_frame, connect_frame) do
    from_frame_path = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, current_frame})
    srcFolderPath = Path.dirname(from_frame_path)
    output_dir = GenServer.call(Emulsion.Files, {:get_file_path, "", :output_folder, :disk})

    start_frame = srcFrameNumber
    number_of_frames = destFrameNumber - srcFrameNumber + 1

    outputVideoName = Path.join([output_dir, "#{srcFrameNumber}_thru_#{destFrameNumber}.webm"])

    {srcFolderPath, start_frame, number_of_frames, outputVideoName}
  end

  @doc """
  `idleify_frame/4` generates tweens to/from nearby or similar frames. This allows the player to 'idle' around a frame infinitely until the user chooses to move on.
  """
  def idleify_frame(current_frame, idle_range, connect_frame, tween_multiplier, force_build, pid) do
    # Prepare the frames
    {from_frame_path, to_frame_path, srcFrameNumber, destFrameNumber} =
      prepare_frames(current_frame, connect_frame)

    # Generate the idle tween for the current frame
    generate_idle_tween(current_frame, idle_range, tween_multiplier, force_build)

    # Prepare the parameters for the task
    {srcFolderPath, start_frame, number_of_frames, outputVideoName} =
      prepare_for_task(srcFrameNumber, destFrameNumber, current_frame, connect_frame)

    # add the connect frame to the graph first
    Playgraph.add_node(to_frame_path)

    # if the destination frame is higher then we just cut out that section of frames instead of generating a tween
    # otherwise we will have to generate a tween to join the frames
    Task.start_link(fn ->
      if destFrameNumber > srcFrameNumber do
        Emulsion.ScriptRunner.execute_generate_sequential_video(
          srcFolderPath,
          start_frame,
          number_of_frames,
          outputVideoName
        )
      else
        # only generate one video
        Emulsion.Video.generate_tween_and_video(
          from_frame_path,
          to_frame_path,
          tween_multiplier,
          force_build
        )

        send(pid, {:tween_generated, outputVideoName})
      end

      video_name =
        GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, outputVideoName})

      Playgraph.add_edge(
        from_frame_path,
        to_frame_path,
        outputVideoName |> Path.basename(),
        video_name
      )

      Emulsion.Playgraph.tag_edge(outputVideoName |> Path.basename(), "next")
      send(pid, {:sequence_generated, outputVideoName})
    end)

    {:ok, pid}
  end

  @doc """
  `idle_to/3` creates an idle tween that goes from the `current_frame` to the `dest_frame` and then another that goes back from the `dest_frame` to the `current_frame`.
  """
  def idle_to(current_frame, dest_frame, tween_multiplier, force_build) do
    # Convert current and dest frames to their full paths
    current_frame_path = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, current_frame})
    dest_frame_path = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, dest_frame})

    # Generate idle tween from current frame to destination frame
    pid = self()
    handle_forward_tween(pid, current_frame_path, dest_frame_path, tween_multiplier, force_build)
    handle_backward_tween(pid, dest_frame_path, current_frame_path, tween_multiplier, force_build)
  end

  @doc """
  `idleify_blur_frame/4` creates an overlay frame using the frame before and after the `current_frame`.
  It then generates an idle tween for this overlay frame and finally creates a sequence from `src_frame` to `dest_frame`.
  """
  def idleify_blur_frame(current_frame, connect_frame, tween_multiplier, force_build, pid \\ self()) do
    # Get the paths of current, previous, and next frames
    current_frame_path = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, current_frame |> Path.basename})
    prev_frame_path = Emulsion.Files.get_previous_frame(current_frame_path)
    next_frame_path = Emulsion.Files.get_next_frame(current_frame_path)

    # # the frames and thumb paths
    frames_path = GenServer.call(Emulsion.Files, {:get_file_path, "", :frame_folder, :disk})
    thumbs_path = GenServer.call(Emulsion.Files, {:get_file_path, "", :thumbs_folder, :disk})
    # get the next-available filename
    frame_files = File.ls!(frames_path)
    # make the overlay frame be in the system temp folder
    # TODO: must fix this
    working_root = "e:/emulsion_workspace"
    overlay_frame_path = Path.join([working_root, Emulsion.Video.generate_next_filename(frame_files)])

    # overlay_frame_path = Path.join([frames_path, Emulsion.Video.generate_next_filename(frame_files)])

    # Generate the overlay frame using the Scriptrunner
    Emulsion.ScriptRunner.execute_overlay_frames(prev_frame_path, next_frame_path, overlay_frame_path)
    new_thumb_path = GenServer.call(Emulsion.Video, {:handle_upload, overlay_frame_path, working_root}) |> Path.basename
    # idle_to works off of the thumbs as input
    current_thumb_path = current_frame_path |> String.replace(frames_path, thumbs_path) |> Path.basename
    idle_to(current_thumb_path, new_thumb_path, tween_multiplier, force_build)
    # Create a sequence from the src frame to the dest frame

    if Emulsion.Files.extract_frame_number(current_frame) > Emulsion.Files.extract_frame_number(connect_frame) do
      Emulsion.ScriptRunner.execute_generate_sequential_video(current_frame, connect_frame, tween_multiplier)
    else
      Emulsion.Video.generate_tween_and_video(current_frame, connect_frame, tween_multiplier, force_build)
    end
    IO.puts "adding c onnect frame"
    IO.inspect connect_frame
    # the idle_to call should have added the other nodes:
    Playgraph.add_node(connect_frame)
    Playgraph.add_node(current_frame)
    IO.puts "adding edge from #{current_frame} to #{connect_frame}"
    Playgraph.add_edge(current_frame, connect_frame, "next", "next")
    IO.puts "i added that adge"
    IO.puts "i added that adge"
    IO.puts "i added that adge"
    IO.puts "i added that adge"
    IO.puts "i added that adge"
    send(pid, {:sequence_generated, "avideo.webm"})
    {:ok, pid}
  end
end
