# handles all the callouts to the shell to execute scripts
# that currently handle the video processing
defmodule Emulsion.ScriptRunner do
  def sequential_shell do
    "bash"
  end

  # replace e: or c: with /mnt/e or /mnt/c if needed
  def path_for_sequential_shell(path) do
    path
    # |> String.replace("e:", "/e")
    # |> String.replace("c:", "/c")
    |> String.replace("e:", "/mnt/e")
    |> String.replace("c:", "/mnt/c")
  end

  def sequential_script do
    "./lib/scripts/extractVid.sh"
  end

  def overlay_script do
    "./lib/scripts/overlay_frames.sh"
  end

  def tween_shell do
    "bash"
  end

  def tween_script do
    "./lib/scripts/gentween.sh"
  end

  def tween_video_script do
    "./lib/scripts/gentweenVideo.py"
  end

  def thumbs_script do
    "./lib/scripts/thumbs.sh"
  end

  def one_thumb_script do
    "./lib/scripts/one_thumb.sh"
  end

  def join_script do
    "./lib/scripts/join.sh"
  end

  def split_script do
    "./lib/scripts/split.sh"
  end

  # def rife_dir do "/mnt/c/GitHub/rife/rife" end
  def rife_dir do
    "c:/GitHub/rife/rife"
  end

  def ffmpeg_params do
    "-c:v vp9 -s 1920x1080"
  end

  # calls the script that splits your video into individual frames
  def execute_split_video_into_frames(videoPath, framesPath) do
    Rambo.run(
      sequential_shell(),
      [
        split_script(),
        videoPath |> path_for_sequential_shell,
        framesPath |> path_for_sequential_shell
      ],
      cd: "c:/GitHub/emulsion",
      log: true
    )
  end

  # calls the script that splits your video into individual thumbs
  # this also works when videoPath is just a jpg or a png as well
  def execute_transform_image_to_thumb(videoPath, thumbsPath) do
    Rambo.run(
      sequential_shell(),
      [
        one_thumb_script(),
        videoPath |> path_for_sequential_shell,
        thumbsPath |> path_for_sequential_shell
      ],
      cd: "c:/GitHub/emulsion",
      log: true
    )
  end

  # calls the script that splits your video into individual thumbs
  # this also works when videoPath is just a jpg or a png as well
  def execute_split_video_into_thumbs(videoPath, thumbsPath) do
    Rambo.run(
      sequential_shell(),
      [
        thumbs_script(),
        videoPath |> path_for_sequential_shell,
        thumbsPath |> path_for_sequential_shell
      ],
      cd: "c:/GitHub/emulsion",
      log: true
    )
  end

  # calls the script that joins a sequence of frames into a video
  def execute_generate_sequential_video(frameBase, start_frame, number_of_frames, outputVideoName) do
    IO.puts "executing a seuqentaial"
    File.rm(outputVideoName |> path_for_sequential_shell)

    args = [
      sequential_script(),
      frameBase |> path_for_sequential_shell,
      "#{start_frame}",
      "#{number_of_frames}",
      outputVideoName |> path_for_sequential_shell,
      ffmpeg_params
    ]
    IO.inspect args
    Rambo.run(sequential_shell(), args, cd: "c:/GitHub/emulsion")
  end

  # calls the script that generates a tween between two frames
  def execute_generate_tween_frames(src_frame, dest_frame, tweenExp, output_dir) do
    IO.puts("execute generate tween frames")
    IO.inspect(tweenExp)

    Rambo.run(tween_shell(), [
      tween_script(),
      rife_dir(),
      "#{tweenExp}",
      src_frame,
      dest_frame,
      output_dir |> path_for_sequential_shell
    ])
  end

  # calls the script that generates a tween between two frames
  def execute_generate_tween_video(src_frame, dest_frame, tween_exp, output_file) do
    src_frame = convert_if_needed(src_frame)
    dest_frame = convert_if_needed(dest_frame)
    cond do
      !File.exists?(src_frame) ->
        IO.puts " WARNING src frame does not exist: #{src_frame}"
        Phoenix.PubSub.broadcast(
          Emulsion.PubSub,
          "generate_tween_and_video",
          {:does_not_exist, src_frame}
        )

      !File.exists?(dest_frame) ->
        IO.puts " WARNING dest frame does not exist: #{dest_frame}"
        Phoenix.PubSub.broadcast(
          Emulsion.PubSub,
          "generate_tween_and_video",
          {:does_not_exist, dest_frame}
        )

      true ->
        Rambo.run(
          "python.exe",
          [
            tween_video_script(),
            # $2 is the tween exponent (# of frames to generate)
            "#{tween_exp}",
            # $3 is the source frame
            src_frame,
            # $4 is the destination frame
            dest_frame,
            # $5 is the ffmpeg parameters
            ffmpeg_params(),
            output_file
          ],
          log: false
        )
    end
  end

  @doc """
  Calls the script that overlays two frames with a given opacity.
  Parameters:
    - `src_frame`: The path to the source frame.
    - `overlay_frame`: The path to the frame that will be overlaid.
    - `opacity`: The opacity value for the overlay (from 0 to 1).
    - `output_frame`: The path to save the resulting overlaid frame.
  """
  def execute_overlay_frames(src_frame, overlay_frame, output_frame,  opacity \\ "0.5") do
    Rambo.run(
      sequential_shell(),
      [
        overlay_script(),
        src_frame |> path_for_sequential_shell,
        overlay_frame |> path_for_sequential_shell,
        "#{opacity}",
        output_frame |> path_for_sequential_shell
      ],
      cd: "c:/github/emulsion",
      log: true
    )
  end

  defp convert_if_needed(path) do
    if String.starts_with?(path, "/file") do
      Emulsion.Files.convert_browser_path_to_disk_path(path)
    else
      path
    end
  end
end
