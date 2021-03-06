defmodule Sqlcx.Server.StatementCacheTest do
  use ExUnit.Case

  alias Sqlcx.Server.StatementCache, as: S
  alias Sqlcx.Statement, as: Stmt

  test "basic happy path" do
    {:ok, db} = Sqlcx.open(":memory:")

    cache = S.new(db, 3)
    assert %S{cached_stmts: %{}, db: _, limit: 3, lru: [], size: 0} = cache

    {cache, stmt1a} = S.prepare(cache, "SELECT 42")
    assert %Stmt{column_names: [:"42"], column_types: [nil]} = stmt1a

    {cache, stmt2a} = S.prepare(cache, "SELECT 43", [db_timeout: 5_000])
    assert %Stmt{column_names: [:"43"], column_types: [nil]} = stmt2a

    {cache, stmt3} = S.prepare(cache, "SELECT 44")
    assert %Stmt{column_names: [:"44"], column_types: [nil]} = stmt3

    {cache, stmt1b} = S.prepare(cache, "SELECT 42", [db_timeout: 5_000])
    assert stmt1a == stmt1b # shouldn't have been purged

    {cache, stmt4} = S.prepare(cache, "SELECT 353")
    assert %Stmt{column_names: [:"353"], column_types: [nil]} = stmt4

    {_cache, stmt2b} = S.prepare(cache, "SELECT 42", [db_timeout: 5_000])
    refute stmt2a == stmt2b # should have been purged
  end

  test "relays error in prepare" do
    {:ok, db} = Sqlcx.open(":memory:")
    cache = S.new(db, 3)

    assert {:error, {:sqlite_error, 'near "bogus": syntax error'}}
      = S.prepare(cache, "bogus", [db_timeout: 5_000])
  end
end
