defmodule Sqlcx.StatementTest do
  use ExUnit.Case, async: true
  doctest Sqlcx.Statement

  test "fetch_all! works" do
    {:ok, db} = Sqlcx.open(":memory:")

    result = db
              |> Sqlcx.Statement.prepare!("PRAGMA user_version;")
              |> Sqlcx.Statement.fetch_all!(db_timeout: 1_000)

    assert result == [[user_version: 0]]
  end

  test "fetch_all! works with db_chunk_size" do
    {:ok, db} = Sqlcx.open(":memory:")

    result = db
              |> Sqlcx.Statement.prepare!("PRAGMA user_version;")
              |> Sqlcx.Statement.fetch_all!(db_timeout: 1_000, db_chunk_size: 1_000)

    assert result == [[user_version: 0]]
  end

  test "RETURNING pseudo-syntax returns id from a single row insert" do
    {:ok, db} = Sqlcx.open(":memory:")

    Sqlcx.exec(db, "CREATE TABLE x(id INTEGER PRIMARY KEY AUTOINCREMENT, str)")

    stmt = Sqlcx.Statement.prepare!(db, "INSERT INTO x(str) VALUES (?1) "
                                          <> ";--RETURNING ON INSERT x,id")

    rows = Sqlcx.Statement.fetch_all!(stmt, db_timeout: 1_000)
    assert rows == [[id: 1]]
  end

  test "RETURNING pseudo-syntax returns id from a single row insert as a raw list" do
    {:ok, db} = Sqlcx.open(":memory:")

    Sqlcx.exec(db, "CREATE TABLE x(id INTEGER PRIMARY KEY AUTOINCREMENT, str)")

    stmt = Sqlcx.Statement.prepare!(db, "INSERT INTO x(str) VALUES (?1) "
                                          <> ";--RETURNING ON INSERT x,id")

    rows = Sqlcx.Statement.fetch_all!(stmt, into: :raw_list)
    assert rows == [[1]]
  end

  test "RETURNING pseudo-syntax returns id from a multi-row insert" do
    {:ok, db} = Sqlcx.open(":memory:")

    Sqlcx.exec(db, "CREATE TABLE x(id INTEGER PRIMARY KEY AUTOINCREMENT, str)")

    stmt = Sqlcx.Statement.prepare!(db, "INSERT INTO x(str) VALUES ('x'),('y'),('z') "
                                          <> ";--RETURNING ON INSERT x,id")

    rows = Sqlcx.Statement.fetch_all!(stmt, db_timeout: 1_000)
    assert rows == [[id: 1], [id: 2], [id: 3]]
  end

  test "RETURNING pseudo-syntax returns id from a multi-row insert as a raw list" do
    {:ok, db} = Sqlcx.open(":memory:")

    Sqlcx.exec(db, "CREATE TABLE x(id INTEGER PRIMARY KEY AUTOINCREMENT, str)")

    stmt = Sqlcx.Statement.prepare!(db, "INSERT INTO x(str) VALUES ('x'),('y'),('z') "
                                          <> ";--RETURNING ON INSERT x,id")

    rows = Sqlcx.Statement.fetch_all!(stmt, db_timeout: 1_000, into: :raw_list)
    assert rows == [[1], [2], [3]]
  end

  test "RETURNING pseudo-syntax doesn't mask error when query fails" do
    {:ok, db} = Sqlcx.open(":memory:")

    Sqlcx.exec(db, "CREATE TABLE x(id INTEGER PRIMARY KEY AUTOINCREMENT, str)")
    Sqlcx.exec(db, "CREATE UNIQUE INDEX x_str ON x(str)")

    Sqlcx.exec(db, "INSERT INTO x(str) VALUES ('x'),('y'),('z')")

    stmt = Sqlcx.Statement.prepare!(db, "INSERT INTO x(str) VALUES ('x') "
                                          <> ";--RETURNING ON INSERT x,id")

    result = Sqlcx.Statement.fetch_all(stmt, db_timeout: 1_000, into: :raw_list)
    assert result == {:error, {:constraint, 'UNIQUE constraint failed: x.str'}}
  end

  test "custom query timeouts are passed through to esqlcipher" do
    {:ok, db} = Sqlcx.open(":memory:")

    {:error, reason, _} = catch_throw(
      db
      |> Sqlcx.Statement.prepare!("""
        WITH RECURSIVE r(i) AS (
          VALUES(0)
          UNION ALL
          SELECT i FROM r
          LIMIT 1000000
        )
        SELECT i FROM r WHERE i = 1
      """)
      |> Sqlcx.Statement.fetch_all!(db_timeout: 1)
    )

    assert reason == :timeout
  end

  test "prepare! raise" do
    {:ok, db} = Sqlcx.open(":memory:")

    assert_raise Sqlcx.Statement.PrepareError, fn ->
      Sqlcx.Statement.prepare!(db, "SELECT * FROMMMM TABLE;")
    end
  end

  test "build_values error" do
    {:ok, db} = Sqlcx.open(":memory:")

    :ok = Sqlcx.exec(db, "CREATE TABLE bv (id INTEGER PRIMARY KEY);")

    result = db
              |> Sqlcx.Statement.prepare!("SELECT * FROM bv")
              |> Sqlcx.Statement.bind_values([1])

    assert result == {:error, :args_wrong_length}
  end

  test "build_values! ok" do
    {:ok, db} = Sqlcx.open(":memory:")

    :ok = Sqlcx.exec(db, "CREATE TABLE bv (id INTEGER PRIMARY KEY);")

    assert {:ok, _stmt} = db
              |> Sqlcx.Statement.prepare!("SELECT * FROM bv WHERE id = ?1")
              |> Sqlcx.Statement.bind_values([1])
  end

  test "build_values! raise" do
    {:ok, db} = Sqlcx.open(":memory:")

    :ok = Sqlcx.exec(db, "CREATE TABLE bv (id INTEGER PRIMARY KEY);")

    assert_raise Sqlcx.Statement.BindValuesError, fn ->
      db
      |> Sqlcx.Statement.prepare!("SELECT * FROM bv")
      |> Sqlcx.Statement.bind_values!([1])
    end
  end

  test "fetch_all! raise" do
    {:ok, db} = Sqlcx.open(":memory:")

    :ok = Sqlcx.exec(db, "CREATE TABLE bv (id INTEGER PRIMARY KEY);")
    :ok = Sqlcx.exec(db, "BEGIN TRANSACTION;")

    assert_raise Sqlcx.Statement.FetchAllError, fn ->
      db
      |> Sqlcx.Statement.prepare!("BEGIN TRANSACTION;")
      |> Sqlcx.Statement.fetch_all!(db_timeout: 1_000)
    end
  end

  test "exec! raise" do
    {:ok, db} = Sqlcx.open(":memory:")

    :ok = Sqlcx.exec(db, "CREATE TABLE bv (id INTEGER PRIMARY KEY);")
    :ok = Sqlcx.exec(db, "BEGIN TRANSACTION;")

    assert_raise Sqlcx.Statement.ExecError, fn ->
      db
      |> Sqlcx.Statement.prepare!("BEGIN TRANSACTION;")
      |> Sqlcx.Statement.exec!(db_timeout: 1_000)
    end
  end

end
