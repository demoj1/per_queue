defmodule QueueTest do
  use ExUnit.Case
  doctest Queue

  setup do
    path = Application.get_env(:mnesia, :dir)

    if File.exists?(path) do
      File.rm_rf!(path)
    end

    File.mkdir_p!(path)
    Queue.DB.setup!()

    on_exit(fn ->
      if File.exists?(path) do
        File.rm_rf!(path)
      end
    end)
  end
end
