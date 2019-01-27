defmodule QueueTest do
  use ExUnit.Case
  doctest Queue

  setup_all do
    {_, ref} = Queue.get()
    %{ref: ref}
  end

  setup context do
    new_ref = Queue.rollback(context.ref)
    %{ref: new_ref}
  end
end
