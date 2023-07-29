defmodule Emulsion.ExporterTest do
  use ExUnit.Case, async: true

  @playgraph %{
    "nodes" => [
      %{
        "edges" => [],
        "id" => "./test/exporter_test_assets/subfolder/img_0667.png",
        "label" => "img_0667.png",
        "name" => "./test/exporter_test_assets/subfolder/img_0667.png"
      },
      %{
        "edges" => [
          %{
            "destination" => "./test/exporter_test_assets/subfolder/img_0546.png",
            "from" => "./test/exporter_test_assets/subfolder/img_0547.png",
            "fromPath" => "/file/img_0547.png",
            "id" => "img_0547_to_img_0546.webm",
            "path" => "./test/exporter_test_assets/subfolder/img_0547_to_img_0546.webm",
            "tags" => ["to_src", "idle"],
            "to" => "./test/exporter_test_assets/subfolder/img_0546.png",
            "toPath" => "/file/img_0546.png"
          }
        ],
        "id" => "./test/exporter_test_assets/subfolder/img_0547.png",
        "label" => "img_0547.png",
        "name" => "./test/exporter_test_assets/subfolder/img_0547.png"
      }
      # truncated for brevity
    ]
  }
  alias Emulsion.Exporter

  # test "exports playgraph correctly" do
  #   {:ok, _pid} = Exporter.start_link([])

  #    test_dir = "./test/exporter_test"

  #   File.rm_rf!(test_dir)

  #   assert :ok == Exporter.set_directory(test_dir)

  #   assert test_dir == Exporter.get_directory()

  #   File.mkdir_p!("./test/exporter_test_assets/subfolder")

  #   File.write!("./test/exporter_test_assets/subfolder/img_0547_to_img_0546.webm", "")

  #   assert :ok == Exporter.export_playgraph(@playgraph)

  #   assert File.exists?("#{test_dir}/playgraph.playgraph")
  #   assert File.exists?("#{test_dir}/main/img_0547_to_img_0546.webm")
  # end


  # test "exports player correctly" do
  #   {:ok, _pid} = Exporter.start_link([])

  #   title = "My Game"
  #   templates = %{
  #     html_template: "core_template.html",
  #     js_template: "core_script.js"
  #   }

  #   test_dir = "./test/export_to"

  #   File.rm_rf!(test_dir)
  #   assert :ok == Exporter.set_directory(test_dir)

  #   assert :ok == Exporter.export_player(title, @playgraph, templates)

  #   assert File.exists?("#{test_dir}/player.html")
  # end


  @output_path "test/export_to"

  test "exports all assets correctly" do
    File.rm_rf!(@output_path)

    {:ok, _pid} = Exporter.start_link([])
    # Set the directory
    Exporter.set_directory(@output_path)

    # Setup your data here (title, playgraph, templates, etc.)
    title = "My Game Title"
    templates = %{html_template: "core_template.html", js_template: "core_script.js"} # Your templates

    # Call the function
    Exporter.export_all(title, @playgraph, templates, @output_path)

    # Assertions
    assert File.exists?("#{@output_path}/playgraph.playgraph")
    assert File.exists?("#{@output_path}/player.html")

    # You can also add other assertions to check the content of the files,
    # existence of other assets, etc.

    # Cleanup (if necessary)
  end
end
