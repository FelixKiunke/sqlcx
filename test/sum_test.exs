defmodule Sqlcx.SumTest do
  use ExUnit.Case
  use ExCheck

  property :sum_integers do
    for_all nums in such_that(ns in list(int()) when length(ns) > 0) do
      {:ok, db} = Sqlcx.open(":memory:")
      :ok = Sqlcx.exec(db, "CREATE TABLE t (a INTEGER)")
      Enum.each(nums, fn(num) ->
        :ok = Sqlcx.exec(db, "INSERT INTO t (a) VALUES (#{num})")
      end)
      [["SUM(a)": db_sum]] = Sqlcx.query!(db, "SELECT SUM(a) FROM t")
      enum_sum = Enum.reduce(nums, 0, &(&1 + &2))
      enum_sum == db_sum
    end
  end
end
