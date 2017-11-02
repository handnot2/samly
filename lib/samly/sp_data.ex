defmodule Samly.SpData do
  require Logger
  alias Samly.ConfigError

  defstruct [
    id: nil,
    entity_id: :undefined,
    certfile: nil,
    keyfile: nil,
    contact_name: nil,
    contact_email: nil,
    org_name: nil,
    org_displayname: nil,
    org_url: nil,
    cert: nil,
    key: nil
  ]

  @type t :: %__MODULE__{
    id: nil | String.t,
    entity_id: nil | :undefined | String.t,
    certfile: nil | String.t,
    keyfile: nil | String.t,
    contact_name: nil | String.t,
    contact_email: nil | String.t,
    org_name: nil | String.t,
    org_displayname: nil | String.t,
    org_url: nil | String.t,
    cert: nil | binary,
    key: nil | tuple
  }

  @type id :: String.t

  @default_contact_name "Samly SP Admin"
  @default_contact_email "admin@samly"
  @default_org_name "Samly SP"
  @default_org_displayname "SAML SP built with Samly"
  @default_org_url "https://github.com/handnot2/samly"

  @spec load_service_providers(list(map)) :: %{required(id) => t}
  def load_service_providers(providers) do
    providers
    |>  Enum.map(&load_sp/1)
    |>  Enum.into(%{})
  end

  @spec load_sp(map) :: {String.t, t} | no_return
  defp load_sp(%{} = provider) do
    sp = %__MODULE__{
      id: Map.get(provider, :id, nil),
      entity_id: Map.get(provider, :entity_id, nil),
      certfile: Map.get(provider, :certfile, nil),
      keyfile: Map.get(provider, :keyfile, nil),
      contact_name: Map.get(provider, :contact_name, @default_contact_name),
      contact_email: Map.get(provider, :contact_email, @default_contact_email),
      org_name: Map.get(provider, :org_name, @default_org_name),
      org_displayname: Map.get(provider, :org_displayname, @default_org_displayname),
      org_url: Map.get(provider, :org_url, @default_org_url),
    }

    sp = %__MODULE__{sp
      | cert: load_cert(sp.certfile, sp.id),
        key: load_key(sp.keyfile, sp.id)
    }

    if sp.id == nil || sp.certfile == nil || sp.keyfile == nil do
      raise ConfigError, provider
    end

    {sp.id, sp}
  end

  defp load_key(file, label) do
    try do
      file |> :esaml_util.load_private_key()
    rescue
      _error ->
        Logger.error("[Samly] Failed load SP keyfile: #{label}:#{file}")
        nil
    end
  end

  defp load_cert(file, label) do
    try do
      file |> :esaml_util.load_certificate()
    rescue
      _error ->
        Logger.error("[Samly] Failed load SP certfile: #{label}:#{file}")
        nil
    end
  end
end
