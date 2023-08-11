defmodule Emulsion.ScriptRunnerTest do
  use ExUnit.Case

  alias Absinthe.Middleware.Async
  alias Emulsion.ScriptRunner

  # describe "overlay tests" do
  #     test "overlay" do
  #       # "id" => "./test/exporter_test_assets/subfolder/img_0667.png",
  #       result = ScriptRunner.execute_overlay_frames("./test/exporter_test_assets/videoA.png", "./test/exporter_test_assets/videoB.png", "./test/export_to/overlay.png")
  #       assert {:ok, _} = result
  #     end
  #   end

  describe "idleify_blur_frame/5" do
    @tag timeout: :infinity
    test "generates overlay frame and processes video sequence correctly" do
      videoFile = "e:/intro/MVI_5833.MOV"
      res =
        GenServer.call(
          Emulsion.Files,
          {:set_workspace_folder, videoFile, "e:/emulsion_workspace", :disk}
        )

        current_frame = "e:/emulsion_workspace/MVI_5833/frames/img_0010.png"
        connect_frame = "e:/emulsion_workspace/MVI_5833/frames/img_0220.png"
        # current_frame = "img_0010.png"
      # connect_frame = "img_0220.png"

      tween_multiplier = "3"
      force_build = true
      pid = self()
      # Act
      {:ok, returned_pid} =
        Emulsion.Idioms.idleify_blur_frame(
          current_frame,
          connect_frame,
          tween_multiplier,
          force_build,
          pid
        )

      # Assert
      # sleep for 10 seconds to allow process to finish
      Process.sleep(120_000)

      assert_receive {:blur_sequence_generated, overlay_frame_path}
      assert_receive {:tween_generated, video_name}

      IO.puts "DONE!!!"
      IO.inspect overlay_frame_path
      IO.inspect video_name

      # # Add more assertions based on your expectations for this function
      assert returned_pid == pid

      # You might also want to assert that certain files exist at the end of this process,
      # that the generated overlay frame path is as expected, etc.
    end
  end
end
