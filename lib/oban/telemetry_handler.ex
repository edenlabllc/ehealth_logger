defmodule EhealthLogger.Oban.TelemetryHandler do
  @moduledoc false

  require Logger

  def handle_event(
        [:oban, :job, :exception],
        _measurements,
        %{reason: reason, stacktrace: stacktrace, kind: level},
        _opts
      ) do
    Logger.log(level, "#{inspect(reason)}, #{inspect(stacktrace)}")
    :ok
  end
end
