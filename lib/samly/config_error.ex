defmodule Samly.ConfigError do
  @moduledoc false

  defexception [:message]

  @spec exception(map) :: Exception.t()
  def exception(data) when is_map(data) do
    %__MODULE__{message: "invalid_config: #{inspect(data)}"}
  end
end
