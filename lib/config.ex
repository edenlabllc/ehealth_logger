defmodule EhealthLogger.Config do
  @moduledoc """
  This module handles fetching values from the config
  """

  def ignoring_queries do
    Application.get_env(:ehealth_logger, :ignoring_queries, ~w(begin commit rollback))
  end
end
