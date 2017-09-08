defmodule Samly.Assertion do
  require Samly.Esaml
  alias Samly.Esaml
  alias Samly.Subject

  defstruct [
    version: "2.0",
    issue_instant: "",
    recipient: "",
    issuer: "",
    subject: %Subject{},
    conditions: [],
    attributes: [],
    authn: []
  ]

  @type t :: %__MODULE__{
    version: String.t,
    issue_instant: String.t,
    recipient: String.t,
    issuer: String.t,
    subject: Subject.t,
    conditions: Keyword.t,
    attributes: Keyword.t,
    authn: Keyword.t
  }

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
    proplist |> Enum.map(fn {k, v} -> {k, List.to_string(v)} end) |> Enum.into(%{})
  end
end
