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
  def generate_idle_tween(src_frame, range, direction) when is_binary(range) do
    range = String.to_integer(range)
    generate_idle_tween(src_frame, range, direction)
  end

  def generate_idle_tween(src_frame, range, direction) do
    dest_frame = Files.get_frame(src_frame, direction, range)
    pid = self()

    # handle_forward_tween should only handle from src to dest
    handle_forward_tween(pid, src_frame, dest_frame)

    # handle_backward_tween should only handle from dest to src
    handle_backward_tween(pid, dest_frame, src_frame)
  end

  defp handle_forward_tween(pid, src_frame, dest_frame) do
    Task.start_link(fn ->
      generate_tweens(pid, src_frame, dest_frame, "idle:from_src")
    end)
  end

  defp handle_backward_tween(pid, src_frame, dest_frame) do
    Task.start_link(fn ->
      generate_tweens(pid, src_frame, dest_frame, "idle:to_src")
    end)
  end

  defp generate_tweens(pid, from_frame, to_frame, tag) do
    # add the two nodes to the playgraph first so that both edges can be added once they are generated
    Playgraph.add_node(from_frame)
    Playgraph.add_node(to_frame)

    video_name =
      GenServer.call(
        Emulsion.Video,
        {:generate_tween_and_video, from_frame, to_frame, "5"},
        999_999
      )

    video_name = GenServer.call(Files, {:convert_disk_path_to_browser_path, video_name})
    basename = Path.basename(video_name)

    Playgraph.add_node(to_frame)
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

  def generate_idle_tween(current_frame, idle_range) do
    from_frame_path = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, current_frame})
    Emulsion.Idioms.generate_idle_tween(from_frame_path, idle_range, :forward)
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
  def idleify_frame(current_frame, idle_range, connect_frame, pid) do
    # Prepare the frames
    {from_frame_path, to_frame_path, srcFrameNumber, destFrameNumber} =
      prepare_frames(current_frame, connect_frame)

    # Generate the idle tween for the current frame
    generate_idle_tween(current_frame, idle_range)

    # Prepare the parameters for the task
    {srcFolderPath, start_frame, number_of_frames, outputVideoName} =
      prepare_for_task(srcFrameNumber, destFrameNumber, current_frame, connect_frame)

    #  add the connect frame to the graph first
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
        Emulsion.Video.generate_tween_and_video(from_frame_path, to_frame_path, "5")
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
end
