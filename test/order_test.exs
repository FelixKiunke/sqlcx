defmodule Sqlcx.OrderTest do
  use ExUnit.Case
  use ExCheck

  property :ordering_query_results do
    for_all {x, y} in {int(), int()} do
      {:ok, db} = Sqlcx.open(":memory:")
      :ok = Sqlcx.exec(db, "CREATE TABLE t (a INTEGER)")
      :ok = Sqlcx.exec(db, "INSERT INTO t (a) VALUES #{(x..y) |> Enum.map(&( "(#{&1})" )) |> Enum.join(",")}")
      Enum.sort(Enum.to_list(x..y)) == Enum.map(Sqlcx.query!(db, "SELECT a FROM t ORDER BY a"), &(&1[:a]))
    end
  end
end
