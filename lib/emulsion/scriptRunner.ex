# handles all the callouts to the shell to execute scripts
# that currently handle the video processing
defmodule Emulsion.ScriptRunner do
  def sequential_shell do "bash" end
  # replace e: or c: with /mnt/e or /mnt/c if needed
  def path_for_sequential_shell(path) do
    path
    # |> String.replace("e:", "/e")
    # |> String.replace("c:", "/c")
    |> String.replace("e:", "/mnt/e")
    |> String.replace("c:", "/mnt/c")
  end
  def sequential_script do "./lib/scripts/extractVid.sh" end
  def tween_shell do "bash" end
  def tween_script do "./lib/scripts/gentween.sh" end
  def tween_video_script do "./lib/scripts/gentweenVideo.py" end
  def thumb_script do "./lib/scripts/thumbs.sh" end
  def join_script do "./lib/scripts/join.sh" end
  def split_script do "./lib/scripts/split.sh" end
  # def rife_dir do "/mnt/c/GitHub/rife/rife" end
  def rife_dir do "c:/GitHub/rife/rife" end


  def ffmpegJoinParams do "-c:v vp9 -s 1920x1080" end

  # calls the script that splits your video into individual frames
  def execute_split_video_into_frames(videoPath, framesPath) do
    IO.inspect "rambo execute_split_video_into_frames"
    IO.inspect split_script()
    IO.inspect videoPath |> path_for_sequential_shell
    IO.inspect framesPath |> path_for_sequential_shell
    Rambo.run(sequential_shell(), [
      split_script(),
      videoPath |> path_for_sequential_shell,
      framesPath |> path_for_sequential_shell
    ], cd: "c:/GitHub/emulsion", log: false)
  end

  # calls the script that splits your video into individual thumbs
  def execute_split_video_into_thumbs(videoPath, thumbsPath) do
    IO.inspect "execute_split_video_into_thumbs"
    IO.inspect videoPath
    IO.inspect thumbsPath
    Rambo.run(sequential_shell(), [
      thumb_script(),
      videoPath |> path_for_sequential_shell,
      thumbsPath |> path_for_sequential_shell
    ], cd: "c:/GitHub/emulsion", log: false)
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
      ffmpegJoinParams
    ]
    IO.inspect args
    Rambo.run(sequential_shell(), args, cd: "c:/GitHub/emulsion")
  end

  # calls the script that generates a tween between two frames
  def execute_generate_tween_frames(src_frame, dest_frame, tweenExp, output_dir) do
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
    File.rm(output_file)
    Rambo.run("python.exe", [
      tween_video_script(),
      "#{tween_exp}",      # $2 is the tween exponent (# of frames to generate)
      src_frame,           # $3 is the source frame
      dest_frame,          # $4 is the destination frame
      ffmpegJoinParams(), # $5 is the ffmpeg parameters
      output_file
    ])
  end
end
