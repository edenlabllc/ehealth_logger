if Code.ensure_loaded?(Ecto) do
  defmodule EhealthLogger.TelemetryHandler do
    defmacro __using__(opts) do
      quote do
        @prefix Keyword.get(unquote(opts), :prefix)

        def handle_event([@prefix, :repo, :query], time, entry, config) do
          EhealthLogger.Ecto.log(entry, :info)
        end
      end
    end
  end
end
