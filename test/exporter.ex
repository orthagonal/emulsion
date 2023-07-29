defmodule Emulsion.ExporterTest do
  use ExUnit.Case, async: true

  alias Emulsion.Exporter

  test "exports playgraph correctly" do
    {:ok, _pid} = Exporter.start_link([])

    playgraph = %{
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

    test_dir = "./test/exporter_test"

    File.rm_rf!(test_dir)

    assert :ok == Exporter.set_directory(test_dir)

    assert test_dir == Exporter.get_directory()

    File.mkdir_p!("./test/exporter_test_assets/subfolder")

    File.write!("./test/exporter_test_assets/subfolder/img_0547_to_img_0546.webm", "")

    assert :ok == Exporter.export_playgraph(playgraph)

    assert File.exists?("#{test_dir}/playgraph.playgraph")
    assert File.exists?("#{test_dir}/main/img_0547_to_img_0546.webm")
  end
end
