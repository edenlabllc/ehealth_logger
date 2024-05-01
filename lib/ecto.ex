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
    import EhealthLogger.Config

    require Logger

    alias Ecto.UUID

    @doc """
    Logs query string with metadata from `Ecto.LogEntry` in with debug level.
    """
    @spec log(measurements :: map(), metadata :: map()) :: map()
    def log(measurements, %{query: query} = metadata),
      do: if(Enum.member?(ignoring_queries(), query), do: metadata, else: do_log(measurements, metadata))

    defp do_log(measurements, metadata) do
      {query, metadata} = build_telemetry_log(measurements, metadata)

      # The logger call will be removed at compile time if
      # `compile_time_purge_level` is set to higher than debug.
      Logger.debug(query, metadata)

      metadata
    end

    @doc """
    Overwritten to use JSON.

    Logs the given entry in the given level.
    """
    @spec log(measurements :: map(), metadata :: map(), level :: Logger.level()) :: map()
    def log(measurements, %{query: query} = metadata, level),
      do: if(Enum.member?(ignoring_queries(), query), do: metadata, else: do_log(measurements, metadata, level))

    defp do_log(measurements, metadata, level) do
      {query, metadata} = build_telemetry_log(measurements, metadata)

      # The logger call will not be removed at compile time,
      # because we use level as a variable
      Logger.log(level, query, metadata)

      metadata
    end

    defp build_telemetry_log(measurements, %{query: query, params: params}) do
      query_time = get_time(measurements, :query_time)
      decode_time = get_time(measurements, :decode_time)
      queue_time = get_time(measurements, :queue_time)
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

    defp get_time(measurements, key) do
      measurements
      |> Map.get(key)
      |> format_time()
    end

    defp format_time(nil),
      do: 0

    defp format_time(time),
      do: System.convert_time_unit(time, :native, :microsecond)

    defp format_params(params),
      do: Enum.map(params, &param_to_string/1)

    ## Helpers

    defp param_to_string({{_, _, _} = date, {h, m, s, _}}),
      do: NaiveDateTime.from_erl!({date, {h, m, s}})

    defp param_to_string({_, _, _} = date),
      do: Date.from_erl!(date)

    defp param_to_string(value) when is_list(value),
      do: Enum.map(value, &param_to_string/1)

    defp param_to_string(value) do
      if is_binary(value) and String.valid?(value) do
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
