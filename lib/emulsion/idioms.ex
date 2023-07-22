defmodule Emulsion.Idioms do
  @moduledoc """
    Emulsion.Idioms
  
    This module contains idioms for Emulsion.
    Idleify_frame:  generates tweens to/from nearby or similar frames.  This allows the player to 'idle' around a frame infinitely until the user chooses to move on.
  """

  alias Emulsion.Files
  alias Emulsion.Playgraph

  def generate_idle_tween(src_frame, range, direction) when is_binary(range) do
    range = String.to_integer(range)
    generate_idle_tween(src_frame, range, direction)
  end

  def generate_idle_tween(src_frame, range, direction) do
    dest_frame = Files.get_frame(src_frame, direction, range)
    pid = self()

    case direction do
      :forward ->
        handle_forward_tween(pid, src_frame, dest_frame)
        # :backward -> handle_backward_tween(pid, src_frame, dest_frame)
    end
  end

  defp handle_forward_tween(pid, src_frame, dest_frame) do
    Task.start_link(fn ->
      generate_tween(pid, src_frame, dest_frame, "idle:from_src")
      generate_tween(pid, dest_frame, src_frame, "idle:to_src")
    end)
  end

  defp handle_backward_tween(pid, src_frame, dest_frame) do
    Task.start_link(fn ->
      generate_tween(pid, src_frame, dest_frame, "idle:from_src")
      generate_tween(pid, dest_frame, src_frame, "idle:to_src")
    end)
  end

  defp generate_tween(pid, from_frame, to_frame, tag) do
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
    IO.puts("i must add node #{to_frame}")
    IO.puts("i must add edge #{from_frame} -> #{to_frame}")
    Playgraph.add_edge(from_frame, to_frame, basename, video_name)
    Playgraph.tag_edge(basename, tag)

    send(pid, {:tween_generated, video_name})
  end

  @doc """
  `idleify_frame/4` generates tweens to/from nearby or similar frames. This allows the player to 'idle' around a frame infinitely until the user chooses to move on.
  """
  def idleify_frame(current_frame, idle_range, connect_frame, pid) do
    srcFramePath = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, current_frame})
    destFramePath = GenServer.call(Emulsion.Files, {:get_frame_from_thumb, connect_frame})
    srcFrameNumber = Emulsion.Files.extract_frame_number(srcFramePath)
    destFrameNumber = Emulsion.Files.extract_frame_number(destFramePath)

    generate_idle_tween(srcFramePath, idle_range, :forward)

    srcFolderPath = Path.dirname(srcFramePath)
    output_dir = GenServer.call(Emulsion.Files, {:get_file_path, "", :output_folder, :disk})

    start_frame = srcFrameNumber
    number_of_frames = destFrameNumber - srcFrameNumber + 1

    outputVideoName = Path.join([output_dir, "#{srcFrameNumber}_thru_#{destFrameNumber}.webm"])

    Task.start_link(fn ->
      Emulsion.ScriptRunner.execute_generate_sequential_video(
        srcFolderPath,
        start_frame,
        number_of_frames,
        outputVideoName
      )

      video_name =
        GenServer.call(Emulsion.Files, {:convert_disk_path_to_browser_path, outputVideoName})

      Emulsion.Playgraph.add_node(srcFramePath)
      Emulsion.Playgraph.add_node(destFramePath)

      Emulsion.Playgraph.add_edge(
        srcFramePath,
        destFramePath,
        outputVideoName |> Path.basename(),
        outputVideoName
      )

      Emulsion.Playgraph.tag_edge(outputVideoName, "next")
      send(pid, {:sequence_generated, video_name})
    end)

    {:ok, pid}
  end
end
