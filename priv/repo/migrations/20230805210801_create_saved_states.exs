defmodule Emulsion.Repo.Migrations.CreateSavedStates do
  use Ecto.Migration

  def change do
    create table(:saved_states) do
      add :initial_video, :string

      timestamps()
    end
  end
end
