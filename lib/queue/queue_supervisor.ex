defmodule Queue.Supervisor do
  @moduledoc false
  @doc false

  use Supervisor

  @spec start_link() :: :ignore | {:error, any} | {:ok, pid}
  def start_link() do
    Queue.DB.setup!()
    Supervisor.start_link(__MODULE__, [])
  end

  @spec init(any) :: any
  def init(_) do
    children = [
      worker(Queue.Queue, [], restart: :permanent)
    ]

    supervise(children, strategy: :one_for_one)
  end
end
