if Code.ensure_loaded?(Plug) do
  defmodule EhealthLogger.Plug.MetadataFormatter do
    @moduledoc """
    This formatter builds a metadata which is natively supported by Google Cloud Logger:

      * `httpRequest` - see [LogEntry#HttpRequest](https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#HttpRequest);
      * `client.api_version` - version of API that was requested by a client;
      * `phoenix.controller` - Phoenix controller that processed the request;
      * `phoenix.action` - Phoenix action that processed the request;
      * `absinthe.operation_name` - Name of the executed GraphQL operation;
      * `absinthe.variables` - Variables that was passed to GraphQL operation;
      * `node.hostname` - node hostname;
      * `node.pid` - Erlang VM process identifier.
    """
    import Jason.Helpers, only: [json_map: 1]

    @nanoseconds_in_second System.convert_time_unit(1, :second, :nanosecond)

    @doc false
    def build_metadata(conn, latency, exclude_routes, include_variables, client_version_header) do
      request_metadata(conn, latency, exclude_routes) ++
        client_metadata(conn, client_version_header) ++
        phoenix_metadata(conn) ++
        absinthe_metadata(conn, include_variables) ++
        node_metadata()
    end

    defp request_metadata(conn, latency, exclude_routes) do
      latency_seconds = native_to_seconds(latency)

      [
        httpRequest:
          json_map(
            requestMethod: conn.method,
            requestUrl: request_url(conn, exclude_routes),
            status: conn.status,
            userAgent: LoggerJSON.PlugUtils.get_header(conn, "user-agent"),
            remoteIp: remote_ip(conn),
            referer: LoggerJSON.PlugUtils.get_header(conn, "referer"),
            latency: latency_seconds
          )
      ]
    end

    defp native_to_seconds(nil) do
      nil
    end

    defp native_to_seconds(native) do
      System.convert_time_unit(native, :native, :nanosecond) / @nanoseconds_in_second
    end

    defp request_url(%{request_path: "/"} = conn, _), do: "#{conn.scheme}://#{conn.host}/"

    defp request_url(conn, exclude_routes) do
      request_path =
        Enum.reduce_while(exclude_routes, conn.request_path, fn exlude_route, acc ->
          if Regex.match?(exlude_route, acc), do: {:halt, "/[HIDDEN]"}, else: {:cont, acc}
        end)

      "#{conn.scheme}://#{Path.join(conn.host, request_path)}"
    end

    defp remote_ip(conn) do
      LoggerJSON.PlugUtils.get_header(conn, "x-forwarded-for") || to_string(:inet_parse.ntoa(conn.remote_ip))
    end

    defp client_metadata(conn, client_version_header) do
      if api_version = LoggerJSON.PlugUtils.get_header(conn, client_version_header) do
        [client: json_map(api_version: api_version)]
      else
        []
      end
    end

    defp phoenix_metadata(%{private: %{phoenix_controller: controller, phoenix_action: action}}) do
      [phoenix: json_map(controller: controller, action: action)]
    end

    defp phoenix_metadata(_conn) do
      []
    end

    if Code.ensure_loaded?(Absinthe) do
      alias EhealthLogger.Absinthe.Metadata

      @absinthe_metadata_key Metadata.conn_key()

      defp absinthe_metadata(%{private: %{@absinthe_metadata_key => metadata}} = conn, include_variables) do
        [absinthe: Metadata.filter_variables(metadata, include_variables)]
      end
    end

    defp absinthe_metadata(conn, _), do: []

    defp node_metadata do
      {:ok, hostname} = :inet.gethostname()

      vm_pid =
        case Integer.parse(System.get_pid()) do
          {pid, _units} -> pid
          _ -> nil
        end

      [node: json_map(hostname: to_string(hostname), vm_pid: vm_pid)]
    end
  end
end
