defmodule ReadPlayersBench do
  use Benchfella

  bench "read players into keyword lists" do
    Sqlcx.with_db('test/fixtures/golfscores.sqlite3', fn(db) ->
      db |> Sqlcx.query("SELECT * FROM players", into: [])
    end)
  end

  bench "read players into maps" do
    Sqlcx.with_db('test/fixtures/golfscores.sqlite3', fn(db) ->
      db |> Sqlcx.query("SELECT * FROM players", into: %{})
    end)
  end
end
