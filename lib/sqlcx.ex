defmodule Sqlcx do
  @type connection :: {:connection, reference(), reference()}
  @type string_or_charlist :: string_or_charlist
  @type sqlite_error :: {:error, {:sqlite_error, charlist}}

  @moduledoc """
  Sqlcx gives you a way to create and query SQLCipher (encrypted SQLite) databases.

  ## Basic Example

  ```
  iex> {:ok, db} = Sqlcx.open(":memory:")
  iex> Sqlcx.exec(db, "CREATE TABLE t (a INTEGER, b INTEGER, c INTEGER)")
  :ok
  iex> Sqlcx.exec(db, "INSERT INTO t VALUES (1, 2, 3)")
  :ok
  iex> Sqlcx.query(db, "SELECT * FROM t")
  {:ok, [[a: 1, b: 2, c: 3]]}
  iex> Sqlcx.query(db, "SELECT * FROM t", into: %{})
  {:ok, [%{a: 1, b: 2, c: 3}]}

  ```

  ## Configuration

  Sqlcx uses the Erlang library [esqlcipher](https://github.com/FelixKiunke/esqlcipher)
  which accepts a timeout parameter for almost all interactions with the database.
  The default value for this timeout is 5000 ms. Many functions in Sqlcx accept
  a `:db_timeout` option that is passed on to the esqlcipher calls and also defaults
  to 5000 ms. If required, this default value can be overridden globally with the
  following in your `config.exs`:

  ```
  config :sqlcx, db_timeout: 10_000 # or other positive integer number of ms
  ```

  Another esqlcipher parameter is :db_chunk_size.
  This is a count of rows to read from native sqlcipher and send to erlang process in one bulk.
  For example, consider a table `mytable` that has 1000 rows. We make the query to get all rows with `db_chunk_size: 500` parameter:
  ```
  Sqlcx.query(db, "select * from mytable", db_chunk_size: 500)
  ```
  in this case all rows will be passed from native sqlcipher OS thread to the erlang process in two passes.
  Each pass will contain 500 rows.
  This parameter decrease overhead of transmitting rows from native OS sqlcipher thread to the erlang process by
  chunking list of result rows.
  Please, decrease this value if rows are heavy. Default value is 5000.
  If you’re in doubt what to do with this parameter, just leave it as is.
  The default value will be ok in almost all cases.
  ```
  config :sqlcx, db_chunk_size: 500 # if most of the database rows are heavy
  ```
  """

  alias Sqlcx.Config

  @spec close(connection) :: :ok
  @spec close(connection, Keyword.t) :: :ok
  def close(db, opts \\ []) do
    :esqlcipher.close(db, Config.db_timeout(opts))
  end

  @spec open(string_or_charlist) :: {:ok, connection} | {:error, {atom, charlist}}
  @spec open(string_or_charlist, Keyword.t) :: {:ok, connection} | {:error, {atom, charlist}}
  def open(path, opts \\ []) do
    case Config.db_password(opts) do
      nil -> :esqlcipher.open(to_charlist(path), Config.db_timeout(opts))
      password ->
        :esqlcipher.open_encrypted(to_charlist(path), password, Config.db_timeout(opts))
    end
  end

  @spec rekey(connection, String.t) :: :ok | sqlite_error
  @spec rekey(connection, String.t, Keyword.t) :: :ok | sqlite_error
  def rekey(db, password, opts \\ []) do
    :esqlcipher.rekey(password, db)
  end

  def with_db(path, fun, opts \\ []) do
    with {:ok, db} <- open(path, opts) do
      res = fun.(db)
      close(db, opts)
      res
    end
  end

  @doc """
  Sets a PID to receive notifications about table updates.

  Messages will come in the shape of:
  `{action, table, rowid}`

  * `action` -> `:insert | :update | :delete`
  * `table` -> charlist of the table name. Example: `'posts'`
  * `rowid` -> internal immutable rowid index of the row.
               This is *NOT* the `id` or `primary key` of the row.
  See the [official docs](https://www.sqlite.org/c3ref/update_hook.html).
  """
  @spec set_update_hook(connection, pid, Keyword.t()) :: :ok | {:error, term()}
  def set_update_hook(db, pid, opts \\ []) do
    :esqlcipher.set_update_hook(pid, db, Config.db_timeout(opts))
  end

  @doc """
  Send a raw SQL statement to the database

  This function is intended for running fully-complete SQL statements.
  No query preparation, or binding of values takes place.
  This is generally useful for things like re-playing a SQL export back into the database.
  """
  @spec exec(connection, string_or_charlist) :: :ok | sqlite_error
  @spec exec(connection, string_or_charlist, Keyword.t) :: :ok | sqlite_error
  def exec(db, sql, opts \\ []) do
    :esqlcipher.exec(sql, db, Config.db_timeout(opts))
  end

  @doc "A shortcut to `Sqlcx.Query.query/3`"
  @spec query(Sqlcx.connection, string_or_charlist) :: {:ok, [keyword]} | {:error, term()}
  @spec query(Sqlcx.connection, string_or_charlist, [Sqlcx.Query.query_option]) :: {:ok, [keyword]} | {:error, term()}
  def query(db, sql, opts \\ []), do: Sqlcx.Query.query(db, sql, opts)

  @doc "A shortcut to `Sqlcx.Query.query!/3`"
  @spec query!(Sqlcx.connection, string_or_charlist) :: [keyword]
  @spec query!(Sqlcx.connection, string_or_charlist, [Sqlcx.Query.query_option]) :: [Enum.t]
  def query!(db, sql, opts \\ []), do: Sqlcx.Query.query!(db, sql, opts)

  @doc "A shortcut to `Sqlcx.Query.query_rows/3`"
  @spec query_rows(Sqlcx.connection, string_or_charlist) :: {:ok, %{}} | sqlite_error
  @spec query_rows(Sqlcx.connection, string_or_charlist, [Sqlcx.Query.query_option]) :: {:ok, %{}} | sqlite_error
  def query_rows(db, sql, opts \\ []), do: Sqlcx.Query.query_rows(db, sql, opts)

  @doc "A shortcut to `Sqlcx.Query.query_rows!/3`"
  @spec query_rows!(Sqlcx.connection, string_or_charlist) :: %{}
  @spec query_rows!(Sqlcx.connection, string_or_charlist, [Sqlcx.Query.query_option]) :: %{}
  def query_rows!(db, sql, opts \\ []), do: Sqlcx.Query.query_rows!(db, sql, opts)

  @doc """
  Create a new table `name` where `table_opts` is a list of table constraints
  and `cols` is a keyword list of columns. The following table constraints are
  supported: `:temp` and `:primary_key`. Example:

  **[:temp, {:primary_key, [:id]}]**

  Columns can be passed as:
  * name: :type
  * name: {:type, constraints}

  where constraints is a list of column constraints. The following column constraints
  are supported: `:primary_key`, `:not_null` and `:autoincrement`. Example:

  **id: :integer, name: {:text, [:not_null]}**

  """
  def create_table(db, name, table_opts \\ [], cols, call_opts \\ []) do
    stmt = Sqlcx.SqlBuilder.create_table(name, table_opts, cols)
    exec(db, stmt, call_opts)
  end

  @doc """
    Runs `fun` inside a transaction. If `fun` returns without raising an exception,
    the transaction will be commited via `commit`. Otherwise, `rollback` will be called.

    ## Examples
      iex> {:ok, db} = Sqlcx.open(":memory:")
      iex> Sqlcx.with_transaction(db, fn(db) ->
      ...>   Sqlcx.exec(db, "create table foo(id integer)")
      ...>   Sqlcx.exec(db, "insert into foo (id) values(42)")
      ...> end)
      iex> Sqlcx.query(db, "select * from foo")
      {:ok, [[{:id, 42}]]}
  """
  @spec with_transaction(Sqlcx.connection, (Sqlcx.connection -> any()), Keyword.t) :: any
  def with_transaction(db, fun, opts \\ []) do
    with :ok <- exec(db, "begin", opts),
      {:ok, result} <- apply_rescuing(fun, [db]),
      :ok <- exec(db, "commit", opts)
    do
      {:ok, result}
    else
      err ->
        :ok = exec(db, "rollback", opts)
        err
    end
  end

 ## Private Helpers

 defp apply_rescuing(fun, args) do
    try do
      {:ok, apply(fun, args)}
    rescue
      error -> {:rescued, error, __STACKTRACE__}
    end
  end
end
