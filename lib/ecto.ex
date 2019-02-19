if Code.ensure_loaded?(Ecto) do
  defmodule EhealthLogger.Ecto do
    @moduledoc """
    Implements the behaviour of `Ecto.LogEntry` and sends query as a string
    to Logger with additional metadata:

      * query.execution_time_μs - the time spent executing the query in microseconds;
      * query.decode_time_μs - the time spent decoding the result in microseconds (it may be 0);
      * query.queue_time_μs - the time spent to check the connection out in microseconds (it may be 0);
      * query.duration_μs - time the query taken (sum of `query_time`, `decode_time` and `queue_time`);
      * connection_pid - the connection process that executed the query;
      * ansi_color - the color that should be used when logging the entry.

    For more information see [LogEntry](https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/log_entry.ex)
    source code.
    """
    require Logger
    alias Ecto.UUID

    @doc """
    Logs query string with metadata from `Ecto.LogEntry` in with debug level.
    """
    @spec log(entry :: Ecto.LogEntry.t()) :: Ecto.LogEntry.t()
    def log(entry) do
      {query, metadata} = query_and_metadata(entry)

      # The logger call will be removed at compile time if
      # `compile_time_purge_level` is set to higher than debug.
      Logger.debug(query, metadata)

      entry
    end

    @doc """
    Overwritten to use JSON.

    Logs the given entry in the given level.
    """
    @spec log(entry :: Ecto.LogEntry.t(), level :: Logger.level()) :: Ecto.LogEntry.t()
    def log(entry, level) do
      {query, metadata} = query_and_metadata(entry)

      # The logger call will not be removed at compile time,
      # because we use level as a variable
      Logger.log(level, query, metadata)

      entry
    end

    defp query_and_metadata(%{
           query: query,
           params: params,
           query_time: query_time,
           decode_time: decode_time,
           queue_time: queue_time
         }) do
      query_time = format_time(query_time)
      decode_time = format_time(decode_time)
      queue_time = format_time(queue_time)
      params = format_params(params)

      metadata = [
        query: %{
          params: params,
          execution_time_μs: query_time,
          decode_time_μs: decode_time,
          queue_time_μs: queue_time,
          latency_μs: query_time + decode_time + queue_time
        }
      ]

      {query, metadata}
    end

    defp format_time(nil), do: 0
    defp format_time(time), do: System.convert_time_unit(time, :native, :microsecond)

    defp format_params(params) do
      Enum.map(params, &param_to_string/1)
    end

    ## Helpers

    defp param_to_string({{_, _, _} = date, {h, m, s, _}}) do
      NaiveDateTime.from_erl!({date, {h, m, s}})
    end

    defp param_to_string({_, _, _} = date) do
      Date.from_erl!(date)
    end

    defp param_to_string(value) when is_list(value) do
      Enum.map(value, &param_to_string/1)
    end

    defp param_to_string(value) when is_map(value) do
      inspect(value)
    end

    defp param_to_string(value) do
      if String.valid?(value) do
        value
      else
        case UUID.load(value) do
          {:ok, uuid} -> uuid
          _ -> inspect(value)
        end
      end
    end
  end
end
