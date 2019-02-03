defmodule Queue do
  @moduledoc """
  Очередь сообщений.
  Перед началом использования необходимо остановить
  текущий сервис.
  Выполнить инициализацию Mnesia с помощью команды `mix queue.setup`.
  """

  use Application

  @spec start(any(), any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
    Queue.Supervisor.start_link()
  end

  @doc """
  Добавить элемент в конец очереди.

  ### Параметры
  * `vals` - значение/значения, добавляемые в конец очереди.

  ### Пример
      iex> Queue.add(1)
      :ok

      iex> Queue.add([1,2,3,4,5,6])
      :ok
  """
  @spec add(any()) :: :ok
  defdelegate add(vals), to: Queue.Queue

  @doc """
  Получить элемент/элементы из очереди.

  ### Параметры
  * `limit` - количество получаемых элементов, по умолчанию 1.

  ### Возвращает
  Лист с элементами, каждый элемент представлен ассоциативном массивом (map)
  с ключами `id` и `value`. Если очередь пуста, атом `:empty`.

  ### Пример
      iex> Queue.get()
      :empty

      iex> :ok = Queue.add(123)
      iex> [%{id: id, value: value} | _T] = Queue.get()
      iex> value
      123
  """
  @spec get(integer) :: {:error, any} | Queue.DB.Jobs.result()
  defdelegate get(limit \\ 1), to: Queue.Queue

  @doc """
  Сообщить о неудачном выполнение. 
  Элементы будут возвращены в конец очереди.

  ### Параметры
  * `ids` - список id элементов, которые завершились не удачей.
  ID можно передавать и по одному.

  ### Возвращает
  Атом `:ok` в случае успеха, `{:error, reason}` в противном случае.

  ### Пример
      iex> Queue.add([1,2,3])
      iex> [%{id: id1, value: value1} | _T] = Queue.get()
      iex> value1
      1
      iex> [%{id: id2, value: value2} | _T] = Queue.get()
      iex> value2
      2
      iex> Queue.reject(id2)
      iex> [%{id: id3, value: value3} | _T] = Queue.get()
      iex> value3
      3
      iex> [%{id: id4, value: value4} | _T] = Queue.get()
      iex> value4
      2

      iex> Queue.add([1,2,3])
      iex> Queue.get(3) |> Enum.map(fn %{id: id} -> id end) |> Queue.reject
      iex> [%{id: id, value: value} | _T] = Queue.get()
      iex> value
      1
  """
  @spec reject(list(integer) | integer) :: :ok
  defdelegate reject(ids), to: Queue.Queue

  @doc """
  Сообщить об успешном выполнение. 
  Элементы будут удалены из очереди.

  ### Параметры
  * `ids` - список id элементов, которые завершились успехом.
  ID можно передавать и по одному.

  ### Возвращает
  Атом `:ok` в случае успеха, `{:error, reason}` в противном случае.

  ### Пример
      iex> Queue.add([1,2])
      iex> [%{id: id1, value: value1} | _T] = Queue.get()
      iex> value1
      1
      iex> [%{id: id2, value: value2} | _T] = Queue.get()
      iex> value2
      2
      iex> :ok = Queue.ack(id2)
      iex> Queue.get()
      :empty

      iex> Queue.add([1,2,3])
      iex> Queue.get(3) |> Enum.map(fn %{id: id} -> id end) |> Queue.reject
      iex> [%{id: id, value: value} | _T] = Queue.get()
      iex> value
      1
  """
  @spec ack(list(integer) | integer) :: :ok
  defdelegate ack(ids), to: Queue.Queue
end
