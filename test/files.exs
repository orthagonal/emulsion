defmodule EmulsionWeb.FilesTest do
  use EmulsionWeb.ConnCase

  @tag timeout: :infinity

  # test "sets and creates the working directory" do
  #   videoFile = "e:/intro/MVI_5945.MOV"
  #   res = GenServer.call(Emulsion.Files, :get_working_dir)
  #   GenServer.cast(Emulsion.Files, {:set_working_dir, videoFile})
  #   res = GenServer.call(Emulsion.Files, :get_working_dir)
  #   assert res == "e:/emulsion_workspace/MVI_5945"
  # end

  # test "takes a source video and makes a working dir for it" do
  #   videoFile = "e:/intro/MVI_5945.MOV"
  #   GenServer.cast(Emulsion.Files, {:set_working_dir, videoFile})
  #   res = GenServer.call(Emulsion.Files, :get_working_dir)
  #   IO.inspect res
  #   assert res == "e:/emulsion_workspace/MVI_5945"
  #   thumbs_dir = GenServer.call(Emulsion.Files, :get_thumbs_dir)
  #   assert thumbs_dir == "e:/emulsion_workspace/MVI_5945/thumbs"
  #   framesDir = GenServer.call(Emulsion.Files, :get_frames_dir)
  #   assert framesDir == "e:/emulsion_workspace/MVI_5945/frames"
  # end

    # test "can list out the files in the thumbs directory after setting the working path" do
    #   videoFile = "e:/intro/MVI_5852.MOV"
    #   GenServer.cast(Emulsion.Files, {:set_working_dir, videoFile})
    #   list_of_thumbs = GenServer.call(Emulsion.Files, {:get_list_of_thumbs})
    #   IO.inspect list_of_thumbs
    # end


  # test "can take in a thumb path in the browser form and convert it to a path that can be used in the shell" do
  #   videoFile = "e:/intro/MVI_5820.MOV"
  #   GenServer.cast(Emulsion.Files, {:set_working_dir, videoFile})
  #   filepath = "/file/thumbs/frame_0706.png"
  #   shellPath = GenServer.call(Emulsion.Files, {:browser_thumb_to_shell_thumb, filepath})
  #   IO.inspect shellPath
  # end

  # test "can take in two frame names with full paths and make a tween name file" do
  #   src_frame = "/c/GitHub/emulsion/frames/frame_0002.png"
  #   dest_frame = "/c/GitHub/emulsion/frames/frame_0338.png"
  #   tweenName = Emulsion.Files.make_tween_name(src_frame, dest_frame)
  #   IO.inspect tweenName
  # end
  # test "store ghostidle name, workingdirectory, generated tweens, generated video clips" do
  #   # filepath = "/file/thumbs/frame_0706.png"
  #   # shellPath = Emulsion.browserThumbToShellFrame(filepath)
  #   # IO.inspect shellPath
  # end
end
