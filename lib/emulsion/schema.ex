# defmodule EmulsionWeb.Schema do
#   use Absinthe.Schema

#   # a frame is a single image
#   object :frame do
#     field :id, non_null(:id)
#     field :path, :string#, path to full sized file on disc
#     field :thumb, :string#, path to thumbnail file on disc
#     field :video, :video # video this belong sto
#     field :index, :integer#, count of the frame in the sequence
#     field :height, :integer, default_value: 1080
#     field :width, :integer, default_value: 1920
#   end

#   object :video do
#     field :id, non_null(:id)
#     field :path, :string # path to video file on disc
#     field :fps, :float # frames per second
#     field :duration, :float # duration in seconds
#   end

#   object :tween do
#     field :id, non_null(:id)
#     field :src, :frame # start frame
#     field :dest, :frame # dest frame
#     field :srcVideo, :video # origin video, the tween 'leads out' from this video
#     field :destVideo, :video # dest video, the tween 'leads to' this video
#     field :path, :string # path to image on disc
#   end

#   object :project do
#     field :id, non_null(:id)
#     field :name, :string # name as used in the url path
#     field :videos, list_of(:video) # list of videos in the project
#   end
# end


# # # defmodule EmulsionWeb.Schema.FrameController do
# # #   alias Emulsion.Frame #, as: Frame

# #   def all_frames(_root, _args, _info) do
# #     IO.puts "all_frames"
# #     Frame
# #     |> Emulsion.Repo.all()
# #     |> Enum.map(fn x -> x |> Map.from_struct() end)
# #   end
# # end

# #   query do
# #     IO.puts "query"
# #     field :all_frames, list_of(:frame) do
# #       resolve &EmulsionWeb.FrameController.all_frames/3
# #     end
# #     field :thumbs, list_of(:string) do
# #       resolve fn _root, _args, _info ->
# #         IO.puts "thumbs"
# #         # get a list of thumbnails in the working directory and display them
# #         thumbFiles = File.ls!(Path.join(Emulsion.working_dir(), "MVI_5830/thumbs"))
# #           |> Enum.map(fn x -> Path.join("/file/MVI_5830/thumbs", x) end)
# #         {:ok, thumbFiles}
# #       end
# #     end
# #   end
# # end


# # # try to make the schema match the existing ghostidle one


# # # a single frame of video
# # defmodule Frame do
# #   use Ecto.Schema
# #   import Ecto.Changeset

# #   schema "frames" do
# #     field :name, :string # file name of frame
# #     field :sequenceName, :string  # a seuqnece of frames shares a name
# #     field :sequenceIndex, :integer # index of frame relative to this sequence (first frame is 0)
# #     field :index, :integer # index of frame relative to all frames (first frame is n)
# #     field :path, :string # file path of frame
# #     field :thumb_path, :string #path to thumbnail
# #     field :width, :integer
# #     field :height, :integer
# #     field :fps, :float
# #     field :duration, :float
# #     field :created_at, :utc_datetime
# #     field :updated_at, :utc_datetime
# #   end

# #   def changeset(frame, attrs) do
# #     frame
# #     |> cast(attrs, [:name, :sequenceName, :sequenceIndex, :index, :path, :thumb_path, :width, :height, :fps, :duration, :created_at, :updated_at])
# #     # |> validate_required([:name, :path, :thumb_path, :width, :height, :fps, :duration, :created_at, :updated_at])
# #   end
# # end

# # # a generated sequence of frames between two frames
# # defmodule Tween do
# #   use Ecto.Schema
# #   import Ecto.Changeset

# #   schema "tweens" do
# #     belongs_to :start_frame, Frame
# #     belongs_to :end_frame, Frame
# #     field :sequenceName, :string # same as start_frame.sequenceName / end_frame.sequenceName
# #     field :pathToFrames, :string # path to generated frames, if nil frames aren't generated yet
# #     field :pathToVideo, :string # path to generated video, if nil video isn't generated yet
# #     field :frame_count, :integer
# #     field :created_at, :utc_datetime
# #     field :updated_at, :utc_datetime
# #   end

# #   def changeset(tween, attrs) do
# #     tween
# #     |> cast(attrs, [:start_frame, :end_frame, :frame_count, :created_at, :updated_at])
# #     # |> validate_required([:start_frame, :end_frame, :frame_count, :created_at, :updated_at])
# #   end
# # end

# # # a continuous sequence of frames
# # defmodule VideoClip do
# #   use Ecto.Schema
# #   import Ecto.Changeset

# #   schema "video_clips" do
# #     belongs_to :start_frame, Frame
# #     belongs_to :end_frame, Frame
# #     field :pathToVideo, :string # path to generated video, if nil video isn't generated yet
# #     field :frame_count, :integer
# #     field :fps, :float
# #     field :created_at, :utc_datetime
# #     field :updated_at, :utc_datetime
# #   end
# # end

# # defmodule Graph do
# #   use Ecto.Schema
# #   import Ecto.Changeset

# #   schema "graphs" do
# #     has_many :tweens, Tween
# #     has_many :video_clips, VideoClip
# #     field :created_at, :utc_datetime
# #     field :updated_at, :utc_datetime
# #   end
# # end



# # # # define types
# # # defmodule BlogWeb.Schema.ContentTypes do
# # #   use Absinthe.Schema.Notation

# # #   object :post do
# # #     field :id, :id
# # #     field :title, :string
# # #     field :body, :string
# # #   end
# # # end

# # # # define schema
# # # defmodule BlogWeb.Schema do
# # #   use Absinthe.Schema
# # #   import_types BlogWeb.Schema.ContentTypes

# # #   alias BlogWeb.Resolvers
# # #   query do
# # #     @desc "Get all posts"
# # #     field :posts, list_of(:post) do
# # #       resolve &Resolvers.Content.list_posts/3
# # #     end

# # #   end

# # # end

# # # # define resolvers
# # # defmodule BlogWeb.Resolvers.Content do

# # #   def list_posts(_parent, _args, _resolution) do
# # #     {:ok, Blog.Content.list_posts()}
# # #   end

# # # end


# # forward "/", Absinthe.Plug,
# # schema: BlogWeb.Schema
