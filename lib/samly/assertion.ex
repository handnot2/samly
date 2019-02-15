defmodule Samly.Assertion do
  @moduledoc """
  SAML assertion returned from IDP upon successful user authentication.

  The assertion attributes returned by the IdP are available in `attributes` field
  as a map. Any computed attributes (using a Plug Pipeline by way of configuration)
  are available in `computed` field as map.

  The attributes can be accessed directly from `attributes` or `computed` maps.
  The `Samly.get_attribute/2` function can be used as well. This function will
  first look at the `computed` attributes. If the request attribute is not present there,
  it will check in `attributes` next.
  """

  require Samly.Esaml
  alias Samly.{Esaml, Subject}

  @type attr_name_t :: String.t()
  @type attr_value_t :: String.t() | [String.t()]

  defstruct version: "2.0",
            issue_instant: "",
            recipient: "",
            issuer: "",
            subject: %Subject{},
            conditions: %{},
            attributes: %{},
            authn: %{},
            computed: %{},
            idp_id: ""

  @type t :: %__MODULE__{
          version: String.t(),
          issue_instant: String.t(),
          recipient: String.t(),
          issuer: String.t(),
          subject: Subject.t(),
          conditions: map,
          attributes: %{required(attr_name_t()) => attr_value_t()},
          authn: map,
          computed: %{required(attr_name_t()) => attr_value_t()},
          idp_id: String.t()
        }

  @doc false
  def from_rec(assertion_rec) do
    Esaml.esaml_assertion(
      version: version,
      issue_instant: issue_instant,
      recipient: recipient,
      issuer: issuer,
      subject: subject_rec,
      conditions: conditions,
      attributes: attributes,
      authn: authn
    ) = assertion_rec

    %__MODULE__{
      version: List.to_string(version),
      issue_instant: List.to_string(issue_instant),
      recipient: List.to_string(recipient),
      issuer: List.to_string(issuer),
      subject: Subject.from_rec(subject_rec),
      conditions: conditions |> stringize(),
      attributes: attributes |> stringize(),
      authn: authn |> stringize()
    }
  end

  defp stringize(proplist) do
    proplist
    |> Enum.map(fn
      {k, []} ->
        {to_string(k), ""}

      {k, values} when is_list(values) and is_list(hd(values)) ->
        {to_string(k), Enum.map(values, fn v -> List.to_string(v) end)}

      {k, v} when is_list(v) ->
        {to_string(k), List.to_string(v)}
    end)
    |> Enum.into(%{})
  end
end
