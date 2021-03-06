defmodule Sqlcx.Config do
  @moduledoc false

  @default_call_timeout 5_000
  @default_db_timeout 5_000
  @default_db_chunk_size 5_000

  def call_timeout(opts \\ []) do
    Keyword.get(opts, :call_timeout,
      Keyword.get(opts, :timeout, # backward compatibility with the :timeout parameter
        Application.get_env(:sqlcx, :call_timeout, @default_call_timeout)))
  end

  def db_timeout(opts \\ []) do
    Keyword.get(opts, :db_timeout, Application.get_env(:sqlcx, :db_timeout, @default_db_timeout))
  end

  def db_chunk_size(opts \\ []) do
    Keyword.get(opts, :db_chunk_size, Application.get_env(:sqlcx, :db_chunk_size, @default_db_chunk_size))
  end

  def db_password(opts \\ []) do
    Keyword.get(opts, :db_password, Application.get_env(:sqlcx, :db_password, nil))
  end
end
