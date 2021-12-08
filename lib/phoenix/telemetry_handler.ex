defmodule EhealthLogger.Phoenix.TelemetryHandler do
  @moduledoc false

  require Logger

  def handle_event(_, _, %{log: false}, _), do: :ok

  def handle_event([:phoenix, :error_rendered], _, %{reason: reason, stacktrace: stack}, _) do
    Logger.log(Logger.level(), "#{inspect(reason)}, #{inspect(stack)}")
    :ok
  end
end
