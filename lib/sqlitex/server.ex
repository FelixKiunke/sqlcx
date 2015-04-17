defmodule Sqlitex.Server do
  use GenServer

  def start_link(db_path) do
    {:ok, db} = Sqlitex.open(db_path)
    GenServer.start_link(__MODULE__, db)
  end

  def handle_call({:exec, sql}, _from, db) do
    result = Sqlitex.exec(db, sql)
    {:reply, result, db}
  end

  def handle_call({:query, sql, opts}, _from, db) do
    rows = Sqlitex.query(db, sql, opts)
    {:reply, rows, db}
  end

  def handle_call(:stop, _from, db) do
    {:stop, :normal, Sqlitex.close(db), db}
  end

  ## Public API

  def exec(pid, sql) do
    GenServer.call(pid, {:exec, sql})
  end

  def query(pid, sql, opts \\ []) do
    GenServer.call(pid, {:query, sql, opts})
  end

  def stop(pid) do
    GenServer.call(pid, :stop)
  end
end