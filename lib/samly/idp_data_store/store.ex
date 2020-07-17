defmodule Samly.IdpDataStore.Store do
  alias Samly.IdpData
  alias Samly.SpData

  @doc """
  Called during GenServer init to initializes the store.

  Takes an optional list of `identity_providers` to populate the store from,
  and the already-configured map of `service_providers` data.
  """
  @callback init([map], %{SpData.id() => SpData.t()}) :: :ok | {:error, any()}

  @doc """
  Fetches the IdpData for the given Id from the store.
  """
  @callback get(binary) :: nil | IdpData.t()

  @doc """
  Saves the IdpData for the given Id into the store.
  Could be omitted by implementation. In that case, it should return `:unsupported`
  """
  @callback put(binary, IdpData.t()) :: :ok | :unsupported | {:error, any()}

  @doc """
  Removes the IdpData for the given Id from the store.
  Could be omitted by implementation. In that case, it should return `:unsupported`
  """
  @callback delete(binary) :: :ok | :unsupported | {:error, any()}
end
