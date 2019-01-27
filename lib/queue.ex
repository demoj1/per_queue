defmodule Queue do
  @moduledoc """
  Персистентная очередь сообщений. 
  Очередь реализована с использованием двух стеков.

  ### Пример
      iex> Queue.add(1)
      iex> Queue.add(2)
      iex> {val, _} = Queue.get()
      iex> val
      1
      iex> Queue.reject()
      iex> {val, _} = Queue.get()
      iex> val
      2
      iex> {val, _} = Queue.get()
      iex> val
      1
  """

  use GenServer
  require Record

  @doc """
  Структура стека.
  Представлена в виде записи, с полями:
    * `ref`  - уникальная ссылка текущего стека.
    * `val`  - текущее значение.
    * `pref` - ссылка на предыдущее значение стека.
  """
  @type stack :: record(:stack, ref: reference, val: any, prev: reference)
  Record.defrecord(:stack, ref: 0, val: nil, prev: nil)

  @doc """
  Структура очереди на основе двух стеков.
  Представлена в виде записи, с полями:
    * `ref` - уникальная сссылка текущей очереди.
    * `l`   - ссылка на левый стек.
    * `r`   - ссылка на правый стек.
  """
  @type t :: record(:queue, ref: reference, l: reference, r: reference)
  Record.defrecord(:queue, ref: 0, l: 0, r: 0)

  @l :left_stack
  @r :right_stack
  @queue :queue_table

  @spec start_link :: :ignore | {:error, any} | {:ok, pid}
  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @spec init(nil) :: {:ok, {reference, map}}
  def init(_opts) do
    :ets.new(@l, [:set, :protected, :named_table, {:keypos, stack(:ref) + 1}])
    :ets.new(@r, [:set, :protected, :named_table, {:keypos, stack(:ref) + 1}])
    :ets.new(@queue, [:set, :protected, :named_table, {:keypos, queue(:ref) + 1}])

    {l_ref, r_ref, queue_ref} = {make_ref(), make_ref(), make_ref()}

    :ets.insert(@l, stack(ref: l_ref))
    :ets.insert(@r, stack(ref: r_ref))
    :ets.insert(@queue, queue(ref: queue_ref, l: l_ref, r: r_ref))

    {:ok, {queue_ref, Map.new()}}
  end

  # -------- Call --------

  def handle_call({:add, val}, _from, {ref, jobs}) do
    [{_, _, l_ref, _} = queue] = :ets.lookup(@queue, ref)

    new_ref = make_ref()

    new_queue =
      queue(
        queue,
        l: push(@l, val, l_ref),
        ref: new_ref
      )

    :ets.insert_new(@queue, new_queue)
    {:reply, new_ref, {new_ref, jobs}}
  end

  def handle_call(:get, {pid, _}, {ref, jobs}) do
    [{_, _, l_ref, r_ref} = queue] = :ets.lookup(@queue, ref)
    {new_l_ref, new_r_ref} = rebalance(l_ref, r_ref)

    case pop(@r, new_r_ref) do
      :empty ->
        {:reply, {:empty, ref}, {ref, jobs}}

      {val, new_r_ref2} ->
        new_ref = make_ref()
        new_queue = queue(queue, ref: new_ref, l: new_l_ref, r: new_r_ref2)
        :ets.insert_new(@queue, new_queue)

        {:reply, {val, new_ref},
         {new_ref, Map.update(jobs, pid, [val], fn job_list -> [val | job_list] end)}}
    end
  end

  def handle_call(:ack, {pid, _}, {ref, jobs}) do
    {_, new_jobs} = Map.pop(jobs, pid)
    {:reply, :ok, {ref, new_jobs}}
  end

  def handle_call(:reject, {pid, _}, {ref, jobs}) do
    {job_list, new_jobs} = Map.pop(jobs, pid)

    case job_list do
      nil ->
        {:reply, :ok, {ref, jobs}}

      job_list ->
        [{_, _, l_ref, _} = queue] = :ets.lookup(@queue, ref)

        new_l_ref =
          Enum.reduce(job_list, l_ref, fn job, acc ->
            push(@l, job, acc)
          end)

        new_ref = make_ref()
        :ets.insert_new(@queue, queue(queue, ref: new_ref, l: new_l_ref))

        {:reply, new_ref, {new_ref, new_jobs}}
    end
  end

  def handle_call({:rollback, ref}, _, {_, jobs}) do
    {:reply, ref, {ref, jobs}}
  end

  def handle_call(request, _, state) do
    IO.puts("Unknown msg: #{inspect(request)}")
    {:reply, :ok, state}
  end

  # -------- External --------

  @doc """
  Добавить элемент в конец очереди.

  ### Параметры
  * `val` - значение, добавленное в конец очереди.

  ### Возвращает
  Ссылку на новую очередь.

  ### Пример
      iex> new_ref = Queue.add(1)
      iex> is_reference(new_ref)
      true
  """
  @spec add(any) :: reference
  def add(val) do
    GenServer.call(__MODULE__, {:add, val})
  end

  @doc """
  Получить элемент из очереди.

  ### Возвращает
  Элемент и ссылку `{val, new_ref}` на новую очередь.
  В случае если очередь пустая, будет возвращено `{:empty, new_ref}`.

  Элемент помещается во временный буфер и закрепляется за процессом, получившим его.
  В дальнейшим процесс может подтвердить выполнение работы: `ack/0` или 
  сообщить об ошибке обработки `reject/0`.

  ### Пример
      iex> {:empty, _} = Queue.get()
      iex> _ = Queue.add(1)
      iex> {val, _} = Queue.get()
      iex> val
      1
  """
  @spec get :: {any, reference}
  def get() do
    GenServer.call(__MODULE__, :get)
  end

  @doc """
  Подтвердить успешную обработку сообщения.
  После подтверждения, элемент пропадет из временого буфера.
  Откатит такой элемент уже будет не возможно.

  ### Пример
      iex> Queue.add(1)
      iex> Queue.get()
      iex> Queue.ack()
      :ok
  """
  @spec ack :: :ok
  def ack() do
    GenServer.call(__MODULE__, :ack)
  end

  @doc """
  Откатить все полученные элементы. 
  Элементы будут возвращены в конец очереди.

  ### Пример
      iex> Queue.add(1)
      iex> {val, _} = Queue.get()
      iex> val
      1
      iex> Queue.add(2)
      iex> _ = Queue.reject()
      iex> {val, _} = Queue.get
      iex> val
      2
      iex> {val, _} = Queue.get
      iex> val
      1
  """
  @spec reject :: :ok
  def reject() do
    GenServer.call(__MODULE__, :reject)
  end

  @doc """
  Откатит очередь к некоторму состоянию.

  ### Пример
      iex> q1 = Queue.add(1)
      iex> {val, _} = Queue.get
      iex> val
      1
      iex> Queue.rollback(q1)
      iex> {val, _} = Queue.get
      iex> val
      1
  """
  @spec rollback(reference) :: reference
  def rollback(ref) do
    GenServer.call(__MODULE__, {:rollback, ref})
  end

  # -------- Internal --------

  @spec push(atom | :ets.tid(), any, reference) :: reference
  defp push(tid, val, ref) do
    new_ref = make_ref()
    :ets.insert_new(tid, stack(ref: new_ref, val: val, prev: ref))

    new_ref
  end

  @spec pop(atom | :ets.tid(), reference) :: :empty | {any, reference}
  defp pop(tid, ref) do
    [{_, _, val, prev_ref}] = :ets.lookup(tid, ref)

    case :ets.lookup(tid, prev_ref) do
      [{_, _, prev_val, prev_ref2}] ->
        new_ref = make_ref()
        :ets.insert_new(tid, stack(ref: new_ref, val: prev_val, prev: prev_ref2))

        {val, new_ref}

      [] ->
        :empty
    end
  end

  @spec rebalance(reference, reference) :: {reference, reference}
  defp rebalance(l_ref, r_ref) do
    if not empty?(@r, r_ref) do
      {l_ref, r_ref}
    else
      transfer_to_right(l_ref, r_ref)
    end
  end

  @spec transfer_to_right(reference, reference) :: {reference, reference}
  defp transfer_to_right(l, r) do
    if empty?(@l, l) do
      {l, r}
    else
      {val, new_l_ref} = pop(@l, l)
      new_r_ref = push(@r, val, r)

      transfer_to_right(new_l_ref, new_r_ref)
    end
  end

  @spec empty?(atom | :ets.tid(), reference) :: boolean
  defp empty?(name, ref) do
    case :ets.lookup(name, ref) do
      [{:stack, _, nil, _}] -> true
      _ -> false
    end
  end
end
