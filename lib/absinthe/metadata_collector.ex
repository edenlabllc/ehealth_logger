if Enum.all?([Absinthe, Plug], &Code.ensure_loaded?/1) do
  defmodule EhealthLogger.Absinthe.Metadata do
    @moduledoc """
    Provides functions to collect GraphQL request metadata from `Absinthe.Blueprint` structure.

    ## Usage:

      plug Absinthe.Plug,
        schema: MyApp.Schema,
        before_send: {EhealthLogger.Absinthe.Metadata, :put}

      plug :my_plug

      def my_plug(conn, _opts) do
        metadata = EhealthLogger.Absinthe.Metadata.get(conn)
        # %{operation_name: "FooQuery", variables: %{bar: "baz"}}

        conn
      end

    """

    import Absinthe.Blueprint, only: [current_operation: 1]

    alias Absinthe.Blueprint.{Document, Input}

    @conn_key :__absinthe_metadata__

    @simple_input_types [
      Input.Boolean,
      Input.Float,
      Input.Integer,
      Input.String,
      Input.Enum
    ]

    @spec put(Plug.Conn.t(), Absinthe.Blueprint.t()) :: Plug.Conn.t()
    def put(conn, bp)

    def put(%{private: private} = conn, %{operations: [_ | _]} = bp) do
      operation = current_operation(bp)

      metadata = %{
        operation_name: operation.name,
        variables: get_variables(operation)
      }

      private = Map.update(private, @conn_key, [metadata], &[metadata | &1])
      %{conn | private: private}
    end

    def put(conn, _), do: conn

    @spec get(Plug.Conn.t()) :: map | nil
    def get(conn), do: conn.private[@conn_key]

    @spec filter_variables([map, ...] | map, [binary]) :: map
    def filter_variables(metadata, include_variables)

    def filter_variables(metadata, include_variables) when is_list(metadata) do
      Enum.map(metadata, &filter_variables(&1, include_variables))
    end

    def filter_variables(%{variables: variables} = metadata, include_variables) do
      variables = for {key, _} = item <- variables, key in include_variables, do: item, into: %{}
      %{metadata | variables: variables}
    end

    @spec conn_key :: atom
    def conn_key, do: @conn_key

    defp get_variables(%Document.Operation{} = node), do: Enum.into(node.variable_definitions, %{}, &get_variables/1)
    defp get_variables(%Document.VariableDefinition{} = node), do: {node.name, serialize_input(node.provided_value)}

    defp serialize_input(%type{} = node) when type in @simple_input_types, do: node.value
    defp serialize_input(%Input.List{} = node), do: Enum.map(node.items, &serialize_input/1)
    defp serialize_input(%Input.Object{} = node), do: Enum.into(node.fields, %{}, &serialize_input/1)
    defp serialize_input(%Input.Field{} = node), do: {node.name, serialize_input(node.input_value)}
    defp serialize_input(%Input.Value{} = node), do: serialize_input(node.raw)
    defp serialize_input(%Input.RawValue{} = node), do: serialize_input(node.content)
    defp serialize_input(%Input.Null{}), do: nil
    defp serialize_input(other), do: other
  end
end
