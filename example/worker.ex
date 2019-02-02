defmodule ExampleSupervisor do
  def start do
    consumers = for _ <- 1..10, do: spawn_link(ExampleWorkerConsumer, :loop, [])
    producers = for _ <- 1..5, do: spawn_link(ExmapleWorkerProducer, :loop, [])
  end
end

defmodule ExampleWorkerConsumer do
  require Logger

  def loop do
    case Queue.get() do
      [%{id: id, value: value}] ->
        case do_work(value) do
          :success ->
            Queue.ack(id)

          :failure ->
            Queue.reject(id)
        end

      :empty ->
        Logger.debug("Empty queue")
        Process.sleep(1000)
    end

    loop
  end

  def do_work(job) do
    Logger.debug("Work with #{inspect(job)}")
    Process.sleep(:rand.uniform(300) + 100)

    if :rand.uniform(2) == 1 do
      Logger.debug("Job #{inspect(job)} complete success")
      :success
    else
      Logger.debug("Job #{inspect(job)} complete failure")
      :failure
    end
  end
end

defmodule ExmapleWorkerProducer do
  def loop do
    Queue.add(make_ref())
    Process.sleep(:rand.uniform(300) + 100)
    loop
  end
end
