if Code.ensure_loaded?(Ecto) do
  defmodule EhealthLogger.TelemetryHandler do
    defmacro __using__(opts) do
      quote do
        @otp_app Keyword.get(unquote(opts), :otp_app)

        def handle_event([@otp_app, :repo, :query], time, entry, config) do
          EhealthLogger.Ecto.log(entry, :info)
        end
      end
    end
  end
end
