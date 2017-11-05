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
            confirmation_method: :bearer,
            notonorafter: ""

  @type t :: %__MODULE__{
          name: String.t(),
          confirmation_method: atom,
          notonorafter: String.t()
        }

  @doc false
  def from_rec(subject_rec) do
    Esaml.esaml_subject(
      name: name,
      confirmation_method: confirmation_method,
      notonorafter: notonorafter
    ) = subject_rec

    %__MODULE__{
      name: name |> List.to_string(),
      confirmation_method: confirmation_method,
      notonorafter: notonorafter |> List.to_string()
    }
  end
end
