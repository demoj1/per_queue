# Queue

Персистентная очередь, на основе Mnesia.

# Инструкция по установке

Чтобы использовать Queue в своем проекте, отредактируйте файл mix.exs и добавьте Queue в
1.
```elixir
  def application do
    [
      ...,
      extra_applications: [:logger, :queue]
    ]
  end
```

2.
```elixir
  defp deps do
    [
      ...,
      {:queue, "https://github.com/dmitrydprog/per_queue", tag: "0.2.0"}
    ]
  end
```

3.
После этого, выполните mix task `mix queue.setup`, для инициализации Mnesia.

# Прочее

[Документация](https://dmitrydprog.github.io/per_queue/Queue.html#content)
|
[Пример работы](https://github.com/dmitrydprog/per_queue/blob/master/example/worker.ex)
