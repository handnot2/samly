defmodule Samly.ConfigError do
  defexception [:message]

  def exception(data) do
    %__MODULE__{message: "invalid_config: #{inspect data}"}
  end
end
