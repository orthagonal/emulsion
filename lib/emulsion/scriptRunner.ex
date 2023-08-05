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
      log: false
    )
  end

  # calls the script that splits your video into individual thumbs
  def execute_split_video_into_thumbs(videoPath, thumbsPath) do
    Rambo.run(
      sequential_shell(),
      [
        thumbs_script(),
        videoPath |> path_for_sequential_shell,
        thumbsPath |> path_for_sequential_shell
      ],
      cd: "c:/GitHub/emulsion",
      log: false
    )
  end

  # calls the script that splits your video into individual thumbs
  def execute_extract_one_thumb_from_video(videoPath, thumbnail_path) do
    IO.puts("******")
    IO.inspect(videoPath |> path_for_sequential_shell)
    IO.inspect(thumbnail_path |> path_for_sequential_shell)

    IO.inspect(
      Rambo.run(
        sequential_shell(),
        [
          one_thumb_script(),
          videoPath |> path_for_sequential_shell,
          thumbnail_path |> path_for_sequential_shell
        ],
        cd: "c:/GitHub/emulsion"
      )
    )
  end

  # calls the script that joins a sequence of frames into a video
  def execute_generate_sequential_video(frameBase, start_frame, number_of_frames, outputVideoName) do
    File.rm(outputVideoName |> path_for_sequential_shell)

    args = [
      sequential_script(),
      frameBase |> path_for_sequential_shell,
      "#{start_frame}",
      "#{number_of_frames}",
      outputVideoName |> path_for_sequential_shell,
      ffmpeg_params
    ]

    Rambo.run(sequential_shell(), args, cd: "c:/GitHub/emulsion")
  end

  # calls the script that generates a tween between two frames
  def execute_generate_tween_frames(src_frame, dest_frame, tweenExp, output_dir) do
    IO.puts "execute generate tween frames"
    IO.inspect tweenExp
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
    IO.puts "execute generate tween video"
    src_frame = convert_if_needed(src_frame)
    dest_frame = convert_if_needed(dest_frame)

    cond do
      !File.exists?(src_frame) ->
        Phoenix.PubSub.broadcast(
          Emulsion.PubSub,
          "generate_tween_and_video",
          {:does_not_exist, src_frame}
        )

      !File.exists?(dest_frame) ->
        Phoenix.PubSub.broadcast(
          Emulsion.PubSub,
          "generate_tween_and_video",
          {:does_not_exist, dest_frame}
        )

      true ->
        Rambo.run("python.exe", [
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
        ])
    end
  end

  defp convert_if_needed(path) do
    if String.starts_with?(path, "/file") do
      Emulsion.Files.convert_browser_path_to_disk_path(path)
    else
      path
    end
  end
end
