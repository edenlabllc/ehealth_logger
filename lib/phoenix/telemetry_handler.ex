defmodule EhealthLogger.Phoenix.TelemetryHandler do
  @moduledoc false
  require Logger

  @default_sensitive_headers [
    "authorization",
    "api-key",
    "x-custom-psk",
    "x-consumer-metadata",
    "cookie",
    "set-cookie",
    "x-consumer-id"
  ]

  def handle_event(_, _, %{log: false}, _), do: :ok

  def handle_event([:phoenix, :error_rendered], _, %{reason: reason, stacktrace: stack, kind: level}, _) do
    filtered_reason = filter_sensitive_data(reason)
    Logger.log(level, "#{inspect(filtered_reason)}, #{inspect(stack)}")
    :ok
  end

  defp filter_sensitive_data(reason) when is_struct(reason) do
    case Map.has_key?(reason, :conn) do
      true ->
        conn = reason.conn
        filtered_conn = filter_conn_headers(conn)
        Map.put(reason, :conn, filtered_conn)

      false ->
        reason
    end
  end

  defp filter_sensitive_data(reason), do: reason

  defp filter_conn_headers(conn) do
    sensitive_headers = get_sensitive_headers()

    filtered_headers =
      Enum.map(conn.req_headers, fn {name, value} ->
        if String.downcase(name) in sensitive_headers do
          {name, "[FILTERED]"}
        else
          {name, value}
        end
      end)

    %{conn | req_headers: filtered_headers}
  end

  defp get_sensitive_headers, do: Application.get_env(:ehealth_logger, :filter_headers, @default_sensitive_headers)
end
