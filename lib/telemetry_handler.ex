if Code.ensure_loaded?(Ecto) do
  defmodule EhealthLogger.TelemetryHandler do
    defmacro __using__(opts) do
      quote do
        @prefix Keyword.get(unquote(opts), :prefix)
        @repo Keyword.get(unquote(opts), :repo, :repo)

        def handle_event([@prefix, @repo, :query], time, entry, config) do
          EhealthLogger.TelemetryHandler.set_metadata(self())
          EhealthLogger.Ecto.log(entry, :info)
        end
      end
    end

    def set_metadata(pid) do
      case Keyword.get(Process.info(pid), :dictionary) do
        nil ->
          :ok

        process_dictionary ->
          cond do
            Keyword.has_key?(process_dictionary, :logger_metadata) ->
              :ok

            Keyword.has_key?(process_dictionary, :"$callers") ->
              Enum.find(process_dictionary[:"$callers"], fn caller_pid ->
                caller_dictionary = Keyword.get(Process.info(caller_pid), :dictionary)

                cond do
                  is_nil(caller_dictionary) ->
                    false

                  Keyword.has_key?(caller_dictionary, :logger_metadata) ->
                    case Keyword.get(caller_dictionary, :logger_metadata) do
                      {_, metadata} ->
                        Logger.metadata(metadata)

                      _ ->
                        false
                    end

                  true ->
                    false
                end
              end)

            true ->
              :ok
          end
      end
    end
  end
end
