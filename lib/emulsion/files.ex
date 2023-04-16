# handles all file operations
# provides functions for resolving filenames and directories
# as well as genserver services for storing state about the current workspace as it exists on disk
defmodule Emulsion.Files do
  use GenServer

  @resourceTypes [:workspace_folder, :frame_folder, :thumbs_folder, :tween_folder :output_folder]
  # dir structure looks like:
  # workspace_folder
  #   frame_folder
  #   thumbs_folder
  #   tween_folders (one for each tween we generate)
  #   output_folder

  @pathTypes [:browser, :disk]

  @operations [
    :set_workspace_folder,
    :get_file_list, # returns a list of files in a directory
    :get_file_from_directory, # returns a file from a directory
  ]

  # specify using lowercase
  @frameExtension ".png"

  # i'll use this to select files
  def list_dir(dir) do
    dir
    |> Path.expand()
    |> File.ls!()
  end

  # functions for resolving filenames and directories
  # anyone can call these directly
  def app_dir do "e:/GitHub/emulsion" end
  # todo get this from env var in config
  def workspace_root do "e:/emulsion_workspace" end
  def working_dir(videoPath) do Path.join(workspace_root, get_vid_dir(videoPath)) end
  def get_vid_dir(videoPath) do
    Path.basename(videoPath)
      |> String.split(".")
      |> List.first()
  end
  def working_dir_browser do "/e/emulsion_workspace" end
  def frames_dir(videoPath) do Path.join(working_dir(videoPath), "frames") end
  def thumbs_dir(videoPath) do Path.join(working_dir(videoPath), "thumbs") end
  def output_dir(videoPath) do Path.join(working_dir(videoPath), "output") end

  def video_extension do "webm" end
  def frame_extension do "png" end

  def add_video_extension base do base <> "." <> video_extension end

  # make a tween name for a source and a destination frame
  def make_tween_name(src_frame, dest_frame) when is_integer(src_frame) and is_integer(dest_frame) do
    "#{src_frame}_to_#{dest_frame}"
  end
  def make_tween_name(src_frame, dest_frame) do
    src_base = Path.basename(src_frame)
      |> String.downcase(:default)
      |> String.replace(@frameExtension, "")
      |> String.replace("frame_", "")
    dest_base = Path.basename(dest_frame) |> String.downcase() |> String.replace(@frameExtension, "") |> String.replace("frame_", "")
    tween_name = src_base <> "_to_" <> dest_base
  end
  def get_path_to_tween_frames(working_path, start_frame, end_frame) when is_integer(start_frame) and is_integer(end_frame) do
    Path.join([working_path, "#{start_frame}_to_#{end_frame}"])
  end

  def get_path_to_tween_frames(working_path, start_frame, end_frame) do
    # strip out everything except the index of the img
    # images are in img_0001.png format
    start_frame_as_integer = start_frame
      |> Path.basename()
      |> String.replace(@frameExtension, "")
      |> String.replace("frame_", "")
    end_frame_as_integer = end_frame
      |> Path.basename()
      |> String.replace(@frameExtension, "")
      |> String.replace("frame_", "")
    Path.join([working_path, make_tween_name(start_frame_as_integer, end_frame_as_integer)])
  end

  def get_output_tween_video(working_path, src_frame, dest_frame) do
    Path.join([
      output_dir(working_path),
      "#{make_tween_name(src_frame, dest_frame)}.#{video_extension()}"
    ])
  end

  # convert a thumb from the browser to its full sized path in the shell
  # def browserThumbToShellFrame(videoPath, thumb) do
  #   Path.join([frames_dir(videoPath), String.replace(thumb, "/file/thumbs/", "")])
  # end

  # convert a windows path to linux path
  # really really need to sort this out so it 'just works' in both places
  # probably just have _convert_for_sequential_shell etc
  def windows_to_linux_path path do
    String.replace(path, "\\", "/")
    |> String.replace("e:", "/e")
  end

  # todo?  this bleeds file
  def frames_and_thumbs_exist? videoPath, thumbsPath do
    File.ls!(videoPath) |> Enum.count() > 0 and File.ls!(thumbsPath) |> Enum.count() > 0
  end

  # get the 'basis' name of the frames in the frames directory
  # used by ffmpeg
  # myimg_12345.png -> myimg_
  # myimg12345.png -> myimg
  # frame_0001.png -> frame_
  def frame_base framePath do
    # get the first file in the frames directory
    firstFileInDirectory = File.ls!(framePath) |> List.first() |> Path.basename()
    case String.contains?(firstFileInDirectory, "_") do
      true ->
        base = firstFileInDirectory
          |> String.split("_") |> List.first()
          # split and remove after the first number
          |> String.replace(~r/\d.*/, "")
        # add it back to the end
        base <> "_"
      false -> firstFileInDirectory
        |> String.replace(~r/\d.*/, "")
    end
  end

  # actual genserver stuff, used by clients to store state about the current workspace
  def init(init_state) do
    {:ok, %{ working_dir: "" }}
  end
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def handle_call(:get_app_dir, _from, state) do
    {:reply, app_dir(), state}
  end


  # get the current working directory
  def handle_call({:get_working_dir}, _from, state) do
    dir = state |> Map.get(:workspace_folder) |> working_dir
    {:reply, dir, state }
  end
  def handle_call(:get_working_dir, _from, state) do
    dir = state |> Map.get(:workspace_folder) |> working_dir
    {:reply, dir, state }
  end

  # translates a frame from a thumbnail
  def handle_call({:get_frame_from_thumb, thumbBrowserPath}, _from, state) do
    # browser path looks like "/file/MVI_blahblah/thumbs/img_0001.png"
    # change it to be the frames directory in the working directory
    working_dir = state |> Map.get(:workspace_folder)
    result = Path.join([working_dir, "frames", Path.basename(thumbBrowserPath)])
    {:reply, result, state}
  end

  # get the path to the original video file that is currently being worked on
  def handle_call(:get_video_path, _from, state) do
    {:reply, state |> Map.get(:videoPath), state }
  end

  # get the path to the frames directory for the video that is currently being worked on
  # this is a directory with all the frames of the video in an image format
  def handle_call(:get_frames_dir, _from, state) do
    dir = state |> Map.get(:workspace_folder) |> frames_dir
    {:reply, dir, state }
  end

  def handle_call(:get_output_dir, _from, state) do
    dir = state |> Map.get(:workspace_folder) |> output_dir
    {:reply, dir, state }
  end


  # to get the name of a sequential output video,  a subsection of video that starts at one frame
  # and ends at another, later frame
  def handle_call({:get_sequential_output_video_path, start_frame, end_frame}, _from, state) do
    {:reply, get_sequential_output_video_path(start_frame, end_frame, state.working_dir), state }
  end
  def get_sequential_output_video_name(start_frame, end_frame) do
    "#{start_frame}_#{end_frame}.webm"
  end
  def get_sequential_output_video_path(start_frame, end_frame, working_dir) do
    Path.join([output_dir(working_dir), get_sequential_output_video_name(start_frame, end_frame)])
  end

  # these translate an image number to a frame number
  def get_image_for_frameNum(working_path, frame_number) when is_binary(frame_number) do
    IO.puts "getting binary frame #{frame_number}"
    framesDir = frames_dir(working_path)
    IO.puts "framesDir: #{framesDir}"
    frameFileName = frame_base(framesDir) <> frame_number
    Path.join([framesDir, frameFileName ])
  end
  def get_image_for_frameNum(working_path, frame_number) when is_integer(frame_number) do
    IO.puts "getting integer frame #{frame_number}"
    framesDir = frames_dir(working_path)
    IO.puts "framesDir: #{framesDir}"
    frameFileName = frame_base(framesDir) <> String.pad_leading("#{frame_number}", 4, "0") #<> @frameExtension
    Path.join([framesDir, frameFileName ])
  end

  # turn a frame number into the full path for that frame png in the frame dir
  # def get_image_for_frameNum(working_path, frameNum) do
  #   framesDir = frames_dir(working_path)
  #   frameFileName = frame_base(framesDir) <> String.pad_leading("#{frameNum}", 4, "0") #<> @frameExtension
  #   Path.join([framesDir, frameFileName ])
  # end
  def browserThumbToShellFrame(videoPath, thumb) do
    directory_of_thumb = fn thumb -> Path.dirname(thumb) end
    Path.join([frames_dir(videoPath), String.replace(thumb, directory_of_thumb )])
  end

  # get the path to the thumbs directory for the video that is currently being worked on
  # this is a directory with all the frames of the video in an image format
  # but smaller
  def handle_call(:get_thumbs_dir, _from, state) do
    dir = state |> Map.get(:workspace_folder) |> thumbs_dir
    {:reply, dir, state }
  end

  # list the thumbs for this, using browser friendly format
  def handle_call({:get_list_of_thumbs}, _from, state) do
    dir = state |> Map.get(:workspace_folder) #|> get_thumbs_from_directory
    path_to_thumbs = Path.join([dir, "thumbs"])
    thumbs = File.ls!(path_to_thumbs) |> Enum.map(fn x -> Path.join(["/file", get_vid_dir(dir), "thumbs", x]) end)
    {:reply, thumbs, state }
  end

  def handle_call({:browser_thumb_to_shell_thumb, thumb}, _from, state) do
    {:reply, browserThumbToShellFrame(state.videoPath, thumb), state }
  end
end
