defmodule Samly.SpData do
  @moduledoc false

  require Logger
  require Samly.Esaml
  alias Samly.SpData

  defstruct id: "",
            entity_id: "",
            certfile: "",
            keyfile: "",
            contact_name: "",
            contact_email: "",
            org_name: "",
            org_displayname: "",
            org_url: "",
            cert: :undefined,
            key: :undefined,
            valid?: true

  @type t :: %__MODULE__{
          id: binary(),
          entity_id: binary(),
          certfile: binary(),
          keyfile: binary(),
          contact_name: binary(),
          contact_email: binary(),
          org_name: binary(),
          org_displayname: binary(),
          org_url: binary(),
          cert: :undefined | binary(),
          key: :undefined | :RSAPrivateKey,
          valid?: boolean()
        }

  @type id :: binary

  @default_contact_name "Samly SP Admin"
  @default_contact_email "admin@samly"
  @default_org_name "Samly SP"
  @default_org_displayname "SAML SP built with Samly"
  @default_org_url "https://github.com/handnot2/samly"

  @spec load_providers(list(map)) :: %{required(id) => t}
  def load_providers(prov_configs) do
    prov_configs
    |> Enum.map(&load_provider/1)
    |> Enum.filter(fn sp_data -> sp_data.valid? end)
    |> Enum.map(fn sp_data -> {sp_data.id, sp_data} end)
    |> Enum.into(%{})
  end

  @spec load_provider(map) :: %SpData{} | no_return
  def load_provider(%{} = opts_map) do
    sp_data = %__MODULE__{
      id: Map.get(opts_map, :id, ""),
      entity_id: Map.get(opts_map, :entity_id, ""),
      certfile: Map.get(opts_map, :certfile, ""),
      keyfile: Map.get(opts_map, :keyfile, ""),
      contact_name: Map.get(opts_map, :contact_name, @default_contact_name),
      contact_email: Map.get(opts_map, :contact_email, @default_contact_email),
      org_name: Map.get(opts_map, :org_name, @default_org_name),
      org_displayname: Map.get(opts_map, :org_displayname, @default_org_displayname),
      org_url: Map.get(opts_map, :org_url, @default_org_url)
    }

    sp_data |> set_id(opts_map) |> load_cert(opts_map) |> load_key(opts_map)
  end

  @spec set_id(%SpData{}, map()) :: %SpData{}
  defp set_id(%SpData{} = sp_data, %{} = opts_map) do
    case Map.get(opts_map, :id, "") do
      "" ->
        Logger.error("[Samly] Invalid SP Config: #{inspect(opts_map)}")
        %SpData{sp_data | valid?: false}

      id ->
        %SpData{sp_data | id: id}
    end
  end

  @spec load_cert(%SpData{}, map()) :: %SpData{}
  defp load_cert(%SpData{certfile: ""} = sp_data, _) do
    %SpData{sp_data | cert: :undefined}
  end

  defp load_cert(%SpData{certfile: certfile} = sp_data, %{} = opts_map) do
    try do
      cert = :esaml_util.load_certificate(certfile)
      %SpData{sp_data | cert: cert}
    rescue
      _error ->
        Logger.error("[Samly] Failed load SP certfile: #{inspect(opts_map)}")
        %SpData{sp_data | valid?: false}
    end
  end

  @spec load_key(%SpData{}, map()) :: %SpData{}
  defp load_key(%SpData{keyfile: ""} = sp_data, _) do
    %SpData{sp_data | key: :undefined}
  end

  defp load_key(%SpData{keyfile: keyfile} = sp_data, %{} = opts_map) do
    try do
      key = :esaml_util.load_private_key(keyfile)
      %SpData{sp_data | key: key}
    rescue
      _error ->
        Logger.error("[Samly] Failed load SP keyfile: #{inspect(opts_map)}")
        %SpData{sp_data | key: :undefined, valid?: false}
    end
  end
end
