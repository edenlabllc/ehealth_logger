if Code.ensure_loaded?(Plug) do
  defmodule EhealthLogger.Plug do
    @moduledoc """
    A Plug to log request information in JSON format.
    """
    alias Plug.Conn
    alias EhealthLogger.Plug.MetadataFormatter
    require Logger

    @behaviour Plug

    @impl true
    def init(opts) do
      level = Keyword.get(opts, :log, :info)
      client_version_header = Keyword.get(opts, :version_header, "x-api-version")
      metadata_formatter = Keyword.get(opts, :metadata_formatter, MetadataFormatter)
      exclude_routes = Keyword.get(opts, :exclude_routes, [])
      include_variables = Keyword.get(opts, :include_variables, ["id"])

      {level, metadata_formatter, exclude_routes, include_variables, client_version_header}
    end

    @impl true
    def call(conn, {level, metadata_formatter, exclude_routes, include_variables, client_version_header}) do
      start = System.monotonic_time()

      Conn.register_before_send(conn, fn conn ->
        latency = System.monotonic_time() - start

        metadata =
          metadata_formatter.build_metadata(
            conn,
            latency,
            exclude_routes,
            include_variables,
            client_version_header
          )

        Logger.log(level, "", metadata)
        conn
      end)
    end

    @doc false
    def get_header(conn, header) do
      case Conn.get_req_header(conn, header) do
        [] -> nil
        [val | _] -> val
      end
    end
  end
end
