defmodule Queue.Queue do
  @moduledoc false
  @doc false

  use GenServer
  require Logger

  @spec start_link :: :ignore | {:error, any} | {:ok, pid}
  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @spec init(any()) :: {:ok, nil}
  def init(_opts) do
    {:ok, nil}
  end

  # ---------Call---------

  def handle_cast({:add, vals}, state) do
    Queue.DB.Jobs.add(vals)

    {:noreply, state}
  end

  def handle_cast({:reject, ids}, state) do
    Queue.DB.Jobs.reject(ids)

    {:noreply, state}
  end

  def handle_cast({:ack, ids}, state) do
    Queue.DB.Jobs.ack(ids)

    {:noreply, state}
  end

  # ---------Cast---------

  def handle_call({:get, limit}, _from, state) do
    res =
      case Queue.DB.Jobs.get(limit) do
        {_, []} ->
          :empty

        {:ok, jobs} ->
          jobs
      end

    {:reply, res, state}
  end

  def handle_info(msg, state) do
    Logger.info("Undefined msg: #{inspect(msg)}")

    {:noreply, state}
  end

  # ---------External---------

  @spec add(any()) :: :ok
  def add(vals) when is_list(vals) do
    GenServer.cast(__MODULE__, {:add, vals})
  end

  def add(val) do
    add([val])
  end

  @spec get(integer) :: {:error, any} | Queue.DB.Jobs.result()
  def get(limit \\ 1) do
    GenServer.call(__MODULE__, {:get, limit})
  end

  @spec reject(list(integer) | integer) :: :ok
  def reject(ids) when is_list(ids) do
    GenServer.cast(__MODULE__, {:reject, ids})
  end

  def reject(id) do
    reject([id])
  end

  @spec ack(list(integer) | integer) :: :ok
  def ack(ids) when is_list(ids) do
    GenServer.cast(__MODULE__, {:ack, ids})
  end

  def ack(id) do
    ack([id])
  end
end
