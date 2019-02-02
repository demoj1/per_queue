defmodule Mix.Tasks.Queue.Setup do
  @moduledoc """
  Mix task выполняющий инициализацию структуры Mnesia.
  """

  use Mix.Task

  @shortdoc "Инициализировать хранилище данных Mnesia"

  @doc false
  def run(_) do
    path = Application.get_env(:mnesia, :dir)

    unless File.exists?(path) do
      File.mkdir_p!(path)
    end

    Queue.DB.setup!()
  end
end
