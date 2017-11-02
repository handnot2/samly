defmodule Samly.ConfigError do
  defexception [:message]

  @spec exception(map) :: Exception.t
  def exception(data) when is_map(data) do
    %__MODULE__{message: "invalid_config: #{inspect data}"}
  end
end
