defmodule Samly.Subject do
  @moduledoc """
  The subject in a SAML 2.0 Assertion.

  This is part of the `Samly.Assertion` struct. The `name` field in this struct should not
  be used any UI directly. It might be a temporary randomly generated
  ID from IdP. `Samly` internally uses this to deal with IdP initiated logout requests.
  """

  require Samly.Esaml
  alias Samly.Esaml

  defstruct name: "",
            name_qualifier: :undefined,
            sp_name_qualifier: :undefined,
            name_format: :undefined,
            confirmation_method: :bearer,
            notonorafter: "",
            in_response_to: ""

  @type t :: %__MODULE__{
          name: String.t(),
          name_qualifier: :undefined | String.t(),
          sp_name_qualifier: :undefined | String.t(),
          name_format: :undefined | String.t(),
          confirmation_method: atom,
          notonorafter: String.t(),
          in_response_to: String.t()
        }

  @doc false
  def from_rec(subject_rec) do
    Esaml.esaml_subject(
      name: name,
      name_qualifier: name_qualifier,
      sp_name_qualifier: sp_name_qualifier,
      name_format: name_format,
      confirmation_method: confirmation_method,
      notonorafter: notonorafter,
      in_response_to: in_response_to
    ) = subject_rec

    %__MODULE__{
      name: name |> List.to_string(),
      name_qualifier: to_string_or_undefined(name_qualifier),
      sp_name_qualifier: to_string_or_undefined(sp_name_qualifier),
      name_format: to_string_or_undefined(name_format),
      confirmation_method: confirmation_method,
      notonorafter: notonorafter |> List.to_string(),
      in_response_to: in_response_to |> List.to_string()
    }
  end

  @doc false
  def to_rec(subject) do
    Esaml.esaml_subject(
      name: String.to_charlist(subject.name),
      name_qualifier: from_string_or_undefined(subject.name_qualifier),
      sp_name_qualifier: from_string_or_undefined(subject.sp_name_qualifier),
      name_format: from_string_or_undefined(subject.name_format),
      confirmation_method: subject.confirmation_method,
      notonorafter: String.to_charlist(subject.notonorafter),
      in_response_to: String.to_charlist(subject.in_response_to)
    )
  end

  defp to_string_or_undefined(:undefined), do: :undefined
  defp to_string_or_undefined(s) when is_list(s), do: List.to_string(s)

  defp from_string_or_undefined(:undefined), do: :undefined
  defp from_string_or_undefined(s) when is_binary(s), do: String.to_charlist(s)
end
