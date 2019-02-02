defmodule Queue.DB do
  @moduledoc false
  @doc false
  require Logger

  defmodule Jobs do
    @moduledoc false
    @doc false

    use Memento.Table,
      attributes: [:id, :value, :status],
      index: [:status],
      type: :ordered_set,
      autoincrement: true

    @type result() :: %{required(:id) => integer, required(:value) => any}

    @spec add(list(any) | any) :: {:error, any} | {:ok, any}
    def add(values) when is_list(values) do
      Memento.Transaction.execute(fn ->
        values
        |> Enum.each(&Memento.Query.write(%Jobs{value: &1, status: :queued}))
      end)
    end

    def add(value) do
      add([value])
    end

    @spec get(integer) :: {:error, any} | {:ok, result}
    def get(limit \\ 1) when is_integer(limit) do
      Memento.Transaction.execute(fn ->
        case Memento.Query.select(Jobs, {:==, :status, :queued}, limit: limit, coerce: false) do
          :"$end_of_table" ->
            :empty

          {result, _} ->
            result
            |> Enum.map(&Memento.Query.Data.load/1)
            |> Enum.map(&%{&1 | status: :fetched})
            |> Enum.map(fn job ->
              Memento.Query.write(job)
              %{id: job.id, value: job.value}
            end)
        end
      end)
    end

    @spec ack(list(integer) | integer) :: {:error, any} | :ok
    def ack(ids) when is_list(ids) do
      Memento.transaction(fn ->
        ids |> Enum.each(&delete/1)
      end)
    end

    def ack(id) when is_integer(id) do
      ack([id])
    end

    @spec reject(list(integer) | integer) :: any
    def reject(ids) when is_list(ids) do
      Memento.transaction(fn ->
        jobs =
          ids
          |> Enum.map(&read/1)

        jobs |> Enum.each(&delete/1)

        jobs
        |> Enum.map(fn job -> job.value end)
        |> add
      end)
    end

    def reject(id) when is_integer(id) do
      reject([id])
    end

    @spec delete(integer | Jobs.t()) :: :ok
    defp delete(%{id: id}) when is_integer(id) do
      delete(id)
    end

    defp delete(id) when is_integer(id) do
      Memento.Query.delete(Jobs, id)
    end

    @spec read(integer) :: :ok | nil
    defp read(id) when is_integer(id) do
      Memento.Query.read(Jobs, id)
    end
  end

  @doc """
  Выполнить настройки Mnesia. В процессе выполнения настройки,
  Mnesia будет остановлена. 
  Создана новая нода (новая схема не будет создана, если уже существует).
  Создана новая таблица.
  Если находимся в тестовом окружение, то таблица будет создана в памяти.
  """
  @spec setup!(nodes :: list(node)) :: :ok
  def setup!(nodes \\ [node()]) do
    :mnesia.stop()
    :mnesia.create_schema([node()])
    :mnesia.start()

    if Mix.env() == :test do
      Memento.Table.create(Queue.DB.Jobs)
    else
      Memento.Table.create(Queue.DB.Jobs, disc_copies: nodes)
    end
  end
end
