defmodule LoggerJSON.Phoenix.Instruments do
  @moduledoc false

  require Logger

  @deprecated "Phoenix.Instruments are removed since 1.5.0 version"
  def phoenix_error_render(:start, _compile, %{log_level: false}), do: :ok

  def phoenix_error_render(:start, _, %{log_level: level} = runtime) do
    %{reason: reason, stacktrace: stack} = runtime
    Logger.log(level, "#{inspect(reason)}, #{inspect(stack)}")
    :ok
  end

  def phoenix_error_render(:stop, _time_diff, :ok), do: :ok
end
