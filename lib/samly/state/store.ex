defmodule Samly.State.Store do
  @moduledoc """
  Specification for Samly state stores.
  """
  alias Plug.Conn
  alias Samly.Assertion

  @typedoc """
  Options passed during the store initialization.
  """
  @type opts :: Plug.opts()

  @typedoc """
  IdP identifier associated with the assertion.
  """
  @type idp_id :: binary

  @typedoc """
  SAML `nameid` returned by IdP.
  """
  @type name_id :: binary

  @typedoc """
  The `name_id` should not be used independent of the `idp_id`. It is within the scope of `idp_id`.
  Together these form the assertion key.
  """
  @type assertion_key :: {idp_id(), name_id()}

  @doc """
  Initializes the store.

  The options returned from this function will be given
  to `get_assertion/3`, `put_assertion/4` and `delete_assertion/3`.
  """
  @callback init(opts()) :: opts() | no_return()

  @doc """
  Returns a Samly assertion if present in the store.

  Returns `nil` if the assertion for the given key is not present in the store.
  """
  @callback get_assertion(Conn.t(), assertion_key(), opts()) :: Assertion.t() | nil

  @doc """
  Saves the given SAML assertion in the store.

  May raise an error if there is a failure. An authenticated session should not be
  established in that case.
  """
  @callback put_assertion(Conn.t(), assertion_key(), Assertion.t(), opts()) ::
              Conn.t() | no_return()

  @doc """
  Removes the given SAML assertion from the store.

  May raise an error if there is a failure. An authenticated session must be terminated
  after calling this.
  """
  @callback delete_assertion(Conn.t(), assertion_key(), opts()) :: Conn.t() | no_return()
end
