defmodule QueueApplication do
  use Application

  def start(_type, _args) do
    Queue.Supervisor.start_link()
  end
end
