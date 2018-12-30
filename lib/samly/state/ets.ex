defmodule Samly.State.ETS do
  @moduledoc """
  Stores SAML assertion in ETS.

  This provider creates an ETS table (during initialization) to keep the
  authenticated SAML assertions from IdP. The ETS table name in the
  configuration is optional.

  ## Options

  +   `:table` - ETS table name (optional)
                 Value must be an atom

  Do not rely on how the state is stored in the ETS table.

  ## Configuration Example

      config :samly, Samly.State,
        opts: [table: :my_ets_table]

  This can be used as an example when creating custom stores based on
  redis, memcached, database etc.
  """

  alias Samly.Assertion

  @behaviour Samly.State.Store

  @assertions_table :samly_assertions_table

  @impl Samly.State.Store
  def init(opts) do
    assertions_table = Keyword.get(opts, :table, @assertions_table)
    if is_atom(assertions_table) == false do
      raise "Samly.State.ETS table name must be an atom: #{inspect assertions_table}"
    end
    if :ets.info(assertions_table) == :undefined do
      :ets.new(assertions_table, [:set, :public, :named_table])
    end
    assertions_table
  end

  @impl Samly.State.Store
  def get_assertion(_conn, assertion_key, assertions_table) do
    case :ets.lookup(assertions_table, assertion_key) do
      [{^assertion_key, %Assertion{} = assertion}] -> assertion
      _ -> nil
    end
  end

  @impl Samly.State.Store
  def put_assertion(conn, assertion_key, assertion, assertions_table) do
    :ets.insert(assertions_table, {assertion_key, assertion})
    conn
  end

  @impl Samly.State.Store
  def delete_assertion(conn, assertion_key, assertions_table) do
    :ets.delete(assertions_table, assertion_key)
    conn
  end
end
