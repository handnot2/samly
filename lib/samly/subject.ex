defmodule Samly.Subject do
  require Samly.Esaml
  alias Samly.Esaml

  defstruct [
    name: "",
    confirmation_method: :bearer,
    notonorafter: ""
  ]

  @type t :: %__MODULE__{
    name: String.t,
    confirmation_method: atom,
    notonorafter: String.t
  }

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
