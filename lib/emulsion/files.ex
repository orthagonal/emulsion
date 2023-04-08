# handles all file operations
# provides functions for resolving filenames and directories
# as well as genserver services for storing state about the current workspace as it exists on disk
defmodule Emulsion.Files do
  use GenServer

  # specify using lowercase
  @frameExtension ".png"

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
  def get_full_tween_path srcFrame, dstFrame do
    tweenName = Path.join([working_dir_browser(), make_tween_name(srcFrame, dstFrame) <> ".webm"])
  end
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
  def get_path_to_tween_frames(working_path, start_frame, end_frame) do
    Path.join([working_path, "#{start_frame}_to_#{end_frame}"])
  end
  def get_output_tween_video(working_path, src_frame, dest_frame) do
    Path.join([
      output_dir(working_path),
      "#{make_tween_name(src_frame, dest_frame)}.#{video_extension()}"
    ])
  end

  # convert a thumb from the browser to its full sized path in the shell
  def browserThumbToShellFrame(videoPath, thumb) do
    Path.join([frames_dir(videoPath), String.replace(thumb, "/file/thumbs/", "")])
  end

  # convert a windows path to linux path
  # really really need to sort this out so it 'just works' in both places
  # probably just have _convert_for_sequential_shell etc
  def windows_to_linux_path path do
    String.replace(path, "\\", "/")
    |> String.replace("e:", "/e")
  end

  # get the 'basis' name of the frames in the frames directory
  # used by ffmpeg
  # myimg_12345.png -> myimg_
  # myimg12345.png -> myimg
  # frame_0001.png -> frame_
  def frame_base framePath do
    # get the first file in the frames directory
    firstFileInDirectory = File.ls!(framePath) |> List.first()
    Path.basename(firstFileInDirectory)
      |> String.split("_") |> List.first()
      # split and remove after the first number
      |> String.replace(~r/\d.*/, "")
  end

  # turn a frame number into the full path for that frame png in the frame dir
  def get_image_for_frameNum(working_path, frameNum) do
    framesDir = frames_dir(working_path)
    frameFileName = frame_base(framesDir) <> String.pad_leading("#{frameNum}", 4, "0") <> @frameExtension
    Path.join([framesDir, frameFileName ])
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

  # set the working directory to a specific video`
  # right now a 'working directory' corresponds to a single video file
  def handle_cast({:set_working_dir, videoPath}, state) do
    # get the name of the video file
    # make a directory for the video
    File.mkdir(working_dir(videoPath))
    # make a directory for the frames
    File.mkdir(frames_dir(videoPath))
    # make a directory for the thumbs
    File.mkdir(thumbs_dir(videoPath))
    # make a directory for all output videos
    File.mkdir(output_dir(videoPath))

    newState = Map.merge(state, %{
      working_dir: working_dir(videoPath),
      frames_dir: frames_dir(videoPath),
      thumbs_dir: thumbs_dir(videoPath),
      output_dir: output_dir(videoPath),
      videoPath: videoPath
    })
    {:noreply, newState}
  end

  # get the current working directory
  def handle_call(:get_working_dir, _from, state) do
    dir = state |> Map.get(:working_dir) |> working_dir
    {:reply, dir, state }
  end

  # get the path to the original video file that is currently being worked on
  def handle_call(:get_video_path, _from, state) do
    {:reply, state |> Map.get(:videoPath), state }
  end

  # get the path to the frames directory for the video that is currently being worked on
  # this is a directory with all the frames of the video in an image format
  def handle_call(:get_frames_dir, _from, state) do
    dir = state |> Map.get(:working_dir) |> frames_dir
    {:reply, dir, state }
  end

  def handle_call(:get_output_dir, _from, state) do
    dir = state |> Map.get(:working_dir) |> output_dir
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


  # gets list of frames from the frames directory
  def get_thumbs_from_directory(videoName) do
    # get a list of thumbnails in the working directory and display them
    File.ls!(thumbs_dir(videoName)) |> Enum.map(fn x -> Path.join(["/file/", "thumbs/", x]) end)
  end

  # get the path to the thumbs directory for the video that is currently being worked on
  # this is a directory with all the frames of the video in an image format
  # but smaller
  def handle_call(:get_thumbs_dir, _from, state) do
    dir = state |> Map.get(:working_dir) |> thumbs_dir
    {:reply, dir, state }
  end

  # list the thumbs for this
  def handle_call(:get_list_of_thumbs, _from, state) do
    dir = state |> Map.get(:working_dir) |> get_thumbs_from_directory
    {:reply, dir, state }
  end

  def handle_call({:browser_thumb_to_shell_thumb, thumb}, _from, state) do
    {:reply, browserThumbToShellFrame(state.videoPath, thumb), state }
  end
end


# genserver that watches a directory every @interval seconds.
# and broadcasts when it's done updating
# used as a callback mechanism for the external calls to ffmpeg
defmodule Emulsion.NotifyWhenDone do
  use GenServer

  @interval 2000

  def init(init_state) do
    {:ok, %{ watchname: "", dir: "", file_count: 0 }}
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def handle_call({ :start_watching, dir}, _from, state) do
    Process.send_after(self(), :cycle_watcher, @interval)

    {:reply, true, %{ state | dir: dir, file_count: 0, watchname: dir }}
  end

  # when you don't need something
  def handle_call(:abort_watching, _from, state) do
    Phoenix.PubSub.broadcast(Emulsion.PubSub, "topic_files", {:operation_complete, %{} })
    {:stop, :normal, state}
  end

  def handle_info(:cycle_watcher, state) do
    # get the number of files in the directory
    file_count = File.ls!(state.dir) |> Enum.count()
    # if the number of files has changed, send a message to the main process
    if file_count != state.file_count do
      IO.puts "file process still running"
      Process.send_after(self(), :cycle_watcher, @interval)
      {:noreply, %{ state | file_count: file_count } }
    else
      IO.puts "file process is finished"
      Phoenix.PubSub.broadcast(Emulsion.PubSub, "topic_files", {:operation_complete, %{} })
      # stop the watcher
      {:stop, :normal, state}
    end
  end
end
