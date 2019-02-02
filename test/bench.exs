count = 100
list = Enum.to_list(1..count)

Benchee.run(
  %{
    "multi_rw_reject_1k" => fn ->
      Queue.add(list)

      Queue.get(count)
      |> Enum.map(fn %{id: id} -> id end)
      |> Queue.reject()
    end,
    "multi_rw_ack_1k" => fn ->
      Queue.add(list)

      Queue.get(count)
      |> Enum.map(fn %{id: id} -> id end)
      |> Queue.ack()
    end
  },
  memory_time: 2
)
