defmodule Emulsion.SavedState do
  @moduledoc """
    Emulsion.SavedState

    This module contains the SavedState schema, so
    previous state of the editor can be saved and restored.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "saved_states" do
    field :initial_video, :string

    timestamps()
  end

  @doc false
  def changeset(saved_state, attrs) do
    saved_state
    |> cast(attrs, [:initial_video])
    |> validate_required([:initial_video])
  end
end
