defmodule Sqlcx.Server do
  @moduledoc """
  Sqlcx.Server provides a GenServer to wrap an sqlcipher db.
  This makes it easy to share a SQLCipher database between multiple processes without worrying about concurrency issues.
  You can also register the process with a name so you can query by name later.

  ## Unsupervised Example
  ```
  iex> {:ok, pid} = Sqlcx.Server.start_link(":memory:", [name: :example])
  iex> Sqlcx.Server.exec(pid, "CREATE TABLE t (a INTEGER, b INTEGER)")
  :ok
  iex> Sqlcx.Server.exec(pid, "INSERT INTO t (a, b) VALUES (1, 1), (2, 2), (3, 3)")
  :ok
  iex> Sqlcx.Server.query(pid, "SELECT * FROM t WHERE b = 2")
  {:ok, [[a: 2, b: 2]]}
  iex> Sqlcx.Server.query(:example, "SELECT * FROM t ORDER BY a LIMIT 1", into: %{})
  {:ok, [%{a: 1, b: 1}]}
  iex> Sqlcx.Server.query_rows(:example, "SELECT * FROM t ORDER BY a LIMIT 2")
  {:ok, %{rows: [[1, 1], [2, 2]], columns: [:a, :b], types: [:INTEGER, :INTEGER]}}
  iex> Sqlcx.Server.prepare(:example, "SELECT * FROM t")
  {:ok, %{columns: [:a, :b], types: [:INTEGER, :INTEGER]}}
    # Subsequent queries using this exact statement will now operate more efficiently
    # because this statement has been cached.
  iex> Sqlcx.Server.prepare(:example, "INVALID SQL")
  {:error, {:sqlite_error, 'near "INVALID": syntax error'}}
  iex> Sqlcx.Server.stop(:example)
  :ok
  iex> :timer.sleep(10) # wait for the process to exit asynchronously
  iex> Process.alive?(pid)
  false

  ```

  ## Supervised Example
  ```
  import Supervisor.Spec

  children = [
    worker(Sqlcx.Server, ["priv/my_db.db", [name: :my_db])
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
  ```
  """

  use GenServer

  alias Sqlcx.Config
  alias Sqlcx.Server.StatementCache, as: Cache
  alias Sqlcx.Statement

  @doc """
  Starts a SQLCipher Server (GenServer) instance.

  In addition to the options that are typically provided to `GenServer.start_link/3`,
  you can also specify:

  - `stmt_cache_size: (positive_integer)` to override the default limit (20) of statements
    that are cached when calling `prepare/3`.
  - `db_timeout: (positive_integer)` to override `:esqlcipher`'s default timeout of 5000 ms for
    interactions with the database. This can also be set in `config.exs` as `config :sqlcx, db_timeout: 5_000`.
  - `db_chunk_size: (positive_integer)` to override `:esqlcipher`'s default chunk_size of 5000 rows
    to read from native sqlite and send to erlang process in one bulk.
    This can also be set in `config.exs` as `config :sqlcx, db_chunk_size: 5_000`.
  """
  def start_link(db_path, opts \\ []) do
    stmt_cache_size = Keyword.get(opts, :stmt_cache_size, 20)
    config = [
      db_timeout: Config.db_timeout(opts),
      db_chunk_size: Config.db_chunk_size(opts),
      db_password: Config.db_password(opts)
    ]
    GenServer.start_link(__MODULE__, {db_path, stmt_cache_size, config}, opts)
  end

  ## GenServer callbacks

  def init({db_path, stmt_cache_size, config})
    when is_integer(stmt_cache_size) and stmt_cache_size > 0
  do
    case Sqlcx.open(db_path, config) do
      {:ok, db} ->
        # Remove the password from config since it's only needed for opening db.
        conf = Keyword.delete(config, :db_password)

        {:ok, {db, __MODULE__.StatementCache.new(db, stmt_cache_size), conf}}
      {:error, reason} -> {:stop, reason}
    end
  end

  def handle_call({:exec, sql}, _from, {db, stmt_cache, config}) do
    result = Sqlcx.exec(db, sql, config)
    {:reply, result, {db, stmt_cache, config}}
  end

  def handle_call({:rekey, password, opts}, _from, {db, stmt_cache, config}) do
    result = Sqlcx.rekey(db, password, Keyword.merge(config, opts))
    {:reply, result, {db, stmt_cache, config}}
  end

  def handle_call({:query, sql, opts}, _from, {db, stmt_cache, config}) do
    case query_impl(sql, stmt_cache, Keyword.merge(config, opts)) do
      {:ok, result, new_cache} -> {:reply, {:ok, result}, {db, new_cache, config}}
      err -> {:reply, err, {db, stmt_cache, config}}
    end
  end

  def handle_call({:query_rows, sql, opts}, _from, {db, stmt_cache, config}) do
    case query_rows_impl(sql, stmt_cache, Keyword.merge(config, opts)) do
      {:ok, result, new_cache} -> {:reply, {:ok, result}, {db, new_cache, config}}
      err -> {:reply, err, {db, stmt_cache, config}}
    end
  end

  def handle_call({:prepare, sql}, _from, {db, stmt_cache, config}) do
    case prepare_impl(sql, stmt_cache, config) do
      {:ok, result, new_cache} -> {:reply, {:ok, result}, {db, new_cache, config}}
      err -> {:reply, err, {db, stmt_cache, config}}
    end
  end

  def handle_call({:create_table, name, table_opts, cols}, _from, {db, stmt_cache, config}) do
    result = Sqlcx.create_table(db, name, table_opts, cols, config)
    {:reply, result, {db, stmt_cache, config}}
  end

  def handle_call({:set_update_hook, pid, opts}, _from, {db, stmt_cache, config}) do
    result = Sqlcx.set_update_hook(db, pid, Keyword.merge(config, opts))
    {:reply, result, {db, stmt_cache, config}}
  end

  def handle_call({:with_transaction, fun}, _from, {db, _stmt_cache, _config} = state) do
    pid = self()
    Process.put({:state, pid}, state)
    result = Sqlcx.with_transaction(db, fn _db -> fun.(pid) end)
    {:reply, result, Process.delete({:state, pid})}
  end

  def handle_cast(:stop, {db, stmt_cache, config}) do
    {:stop, :normal, {db, stmt_cache, config}}
  end

  def terminate(_reason, {db, _stmt_cache, config}) do
    Sqlcx.close(db, config)
    :ok
  end

  ## Public API

  @doc """
  Same as `Sqlcx.exec/3` but using the shared db connections saved in the GenServer state.

  Returns the results otherwise.
  """
  def exec(pid, sql, opts \\ []) do
    call(pid, {:exec, sql}, opts)
  end

  @doc """
  Change the password used to encrypt the database.
  """
  def rekey(pid, password, opts \\ []) do
    GenServer.call(pid, {:rekey, password, opts}, opts)
  end

  @doc """
  Same as `Sqlcx.Query.query/3` but using the shared db connections saved in the GenServer state.

  Returns the results otherwise.
  """
  def query(pid, sql, opts \\ []) do
    call(pid, {:query, sql, opts}, opts)
  end

  @doc """
  Same as `Sqlcx.Query.query_rows/3` but using the shared db connections saved in the GenServer state.

  Returns the results otherwise.
  """
  def query_rows(pid, sql, opts \\ []) do
    call(pid, {:query_rows, sql, opts}, opts)
  end

  def set_update_hook(server_pid, notification_pid, opts \\ []) do
    call(server_pid, {:set_update_hook, notification_pid, opts}, opts)
  end

  @doc """
  Prepares a SQL statement for future use.

  This causes a call to [`sqlite3_prepare_v2`](https://sqlite.org/c3ref/prepare.html)
  to be executed in the Server process. To protect the reference to the corresponding
  [`sqlite3_stmt` struct](https://sqlite.org/c3ref/stmt.html) from misuse in other
  processes, that reference is not passed back. Instead, prepared statements are
  cached in the Server process. If a subsequent call to `query/3` or `query_rows/3`
  is made with a matching SQL statement, the prepared statement is reused.

  Prepared statements are purged from the cache when the cache exceeds a preset
  limit (20 statements by default).

  Returns summary information about the prepared statement.
  `{:ok, %{columns: [:column1_name, :column2_name,... ], types: [:column1_type, ...]}}`
  on success or `{:error, {:reason_code, 'SQLite message'}}` if the statement
  could not be prepared.
  """
  def prepare(pid, sql, opts \\ []) do
    call(pid, {:prepare, sql}, opts)
  end

  def create_table(pid, name, table_opts \\ [], cols) do
    call(pid, {:create_table, name, table_opts, cols}, [])
  end

  def stop(pid) do
    GenServer.cast(pid, :stop)
  end

  @doc """
    Runs `fun` inside a transaction. If `fun` returns without raising an exception,
    the transaction will be commited via `commit`. Otherwise, `rollback` will be called.

    Be careful if `fun` might take a long time to run. The function is executed in the
    context of the server and therefore blocks other requests until it's finished.

    ## Examples
      iex> {:ok, server} = Sqlcx.Server.start_link(":memory:")
      iex> Sqlcx.Server.with_transaction(server, fn(db) ->
      ...>   Sqlcx.Server.exec(db, "create table foo(id integer)")
      ...>   Sqlcx.Server.exec(db, "insert into foo (id) values(42)")
      ...> end)
      iex> Sqlcx.Server.query(server, "select * from foo")
      {:ok, [[{:id, 42}]]}
  """
  def with_transaction(pid, fun, opts \\ []) do
    case call(pid, {:with_transaction, fun}, opts) do
      {:rescued, error, trace} ->
        Kernel.reraise(error, trace)

      other ->
        other
    end
  end

  ## Helpers
  defp call(nil, _command, _opts) do
    throw :no_such_process
  end

  defp call(atom, command, opts) when is_atom(atom) do
    call(Process.whereis(atom), command, opts)
  end

  defp call(pid, command, opts) when is_pid(pid) do
    if pid == self() do
      key = {:state, pid}
      state = Process.get(key)
      case command do
        {:with_transaction, fun} ->
          {db, _stmt_cache, _config} = state
          {:ok, fun.(db)}
        _other ->
          {:reply, result, state} = handle_call(command, nil, state)
          Process.put(key, state)
          result
      end
    else
      GenServer.call(pid, command, Config.call_timeout(opts))
    end
  end

  defp query_impl(sql, stmt_cache, opts) do
    with {%Cache{} = new_cache, stmt} <- Cache.prepare(stmt_cache, sql, opts),
         {:ok, stmt} <- Statement.bind_values(stmt, Keyword.get(opts, :bind, []), opts),
         {:ok, rows} <- Statement.fetch_all(stmt, opts),
    do: {:ok, rows, new_cache}
  end

  defp query_rows_impl(sql, stmt_cache, opts) do
    with {%Cache{} = new_cache, stmt} <- Cache.prepare(stmt_cache, sql, opts),
         {:ok, stmt} <- Statement.bind_values(stmt, Keyword.get(opts, :bind, []), opts),
         {:ok, rows} <- Statement.fetch_all(stmt, Keyword.put(opts, :into, :raw_list)),
    do: {:ok,
         %{rows: rows, columns: stmt.column_names, types: stmt.column_types},
         new_cache}
  end

  defp prepare_impl(sql, stmt_cache, opts) do
    with {%Cache{} = new_cache, stmt} <- Cache.prepare(stmt_cache, sql, opts),
    do: {:ok, %{columns: stmt.column_names, types: stmt.column_types}, new_cache}
  end
end