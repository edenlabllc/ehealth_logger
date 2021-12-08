defmodule EhealthLogger.Phoenix.TelemetryHandler do
  @moduledoc """
  Log level is taken from endpoint configuration from the configuration of `render_errors`. The conf key is `level`.
  Default value is `debug`, so by default these logs are ignored in prod env.
  """

  require Logger

  def handle_event(_, _, %{log: false}, _), do: :ok

  def handle_event([:phoenix, :error_rendered], _, %{log: level, reason: reason, stacktrace: stack}, _) do
    Logger.log(level, "#{inspect(reason)}, #{inspect(stack)}")
    :ok
  end
end
