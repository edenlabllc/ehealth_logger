defmodule EhealthLogger.Formatter do
  @moduledoc """
  EHealth logger formatter.
  """

  import LoggerJSON.Formatter.{MapBuilder, DateTime, Message, Metadata, RedactorEncoder}
  require Jason.Helpers

  @behaviour LoggerJSON.Formatter

  @processed_metadata_keys ~w(pid file line function module application)a

  @impl true
  def format(%{level: level, meta: meta, msg: msg}, opts) do
    opts = Keyword.new(opts)
    encoder_opts = Keyword.get(opts, :encoder_opts, [])
    metadata_keys_or_selector = Keyword.get(opts, :metadata, [])
    metadata_selector = update_metadata_selector(metadata_keys_or_selector, @processed_metadata_keys)
    redactors = Keyword.get(opts, :redactors, [])

    message =
      format_message(msg, meta, %{
        binary: &format_binary_message/1,
        structured: &format_structured_message/1,
        crash: &format_crash_reason(&1, &2, meta)
      })

    line =
      %{
        time: utc_time(meta),
        severity: Atom.to_string(level),
        log: encode(message, redactors)
      }
      |> Map.merge(format_metadata(meta, metadata_selector))
      |> Jason.encode_to_iodata!(encoder_opts)

    [line, "\n"]
  end

  @doc false
  def format_binary_message(binary) do
    IO.chardata_to_string(binary)
  end

  @doc false
  def format_structured_message(map) when is_map(map) do
    map
  end

  def format_structured_message(keyword) do
    Enum.into(keyword, %{})
  end

  @doc false
  def format_crash_reason(binary, _reason, _meta) do
    IO.chardata_to_string(binary)
  end

  defp format_metadata(md, md_keys) do
    md
    |> take_metadata(md_keys)
    |> maybe_put(:error, format_process_crash(md))
    |> maybe_put(:sourceLocation, format_source_location(md))
  end

  defp format_process_crash(md) do
    if crash_reason = Keyword.get(md, :crash_reason) do
      initial_call = Keyword.get(md, :initial_call)

      Jason.Helpers.json_map(
        initial_call: format_initial_call(initial_call),
        reason: format_crash_reason(crash_reason)
      )
    end
  end

  defp format_initial_call(nil), do: nil

  defp format_initial_call({module, function, arity}),
    do: format_function(module, function, arity)

  defp format_crash_reason({:throw, reason}) do
    Exception.format(:throw, reason)
  end

  defp format_crash_reason({:exit, reason}) do
    Exception.format(:exit, reason)
  end

  defp format_crash_reason({%{} = exception, stacktrace}) do
    Exception.format(:error, exception, stacktrace)
  end

  defp format_crash_reason({exception, stacktrace}) do
    Exception.format(:error, exception, stacktrace)
  end

  # Description can be found in Google Cloud Logger docs;
  # https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#LogEntrySourceLocation
  defp format_source_location(metadata) do
    file = Keyword.get(metadata, :file)
    line = Keyword.get(metadata, :line, 0)
    function = Keyword.get(metadata, :function)
    module = Keyword.get(metadata, :module)

    Jason.Helpers.json_map(
      file: file,
      line: line,
      function: format_function(module, function)
    )
  end

  defp format_function(nil, function), do: function
  defp format_function(module, function), do: "#{module}.#{function}"
  defp format_function(module, function, arity), do: "#{module}.#{function}/#{arity}"
end
