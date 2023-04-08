defmodule Emulsion.Repo do
  use Ecto.Repo,
    otp_app: :emulsion,
    adapter: Ecto.Adapters.Postgres
end
