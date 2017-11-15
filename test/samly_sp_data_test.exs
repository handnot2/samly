defmodule SamlySpDataTest do
  use ExUnit.Case
  alias Samly.SpData

  @sp_config1 %{
    id: "sp1",
    entity_id: "urn:test:sp1",
    certfile: "test/data/test.crt",
    keyfile: "test/data/test.pem"
  }

  test "valid-sp-config-1" do
    %SpData{} = sp_data = SpData.load_provider(@sp_config1)
    assert sp_data.valid?
  end

  test "invalid-sp-config-1" do
    sp_config = %{@sp_config1 | id: ""}
    %SpData{} = sp_data = SpData.load_provider(sp_config)
    refute sp_data.valid?
  end

  test "invalid-sp-config-2" do
    sp_config = %{@sp_config1 | certfile: ""}
    %SpData{} = sp_data = SpData.load_provider(sp_config)
    refute sp_data.valid?
  end

  test "invalid-sp-config-3" do
    sp_config = %{@sp_config1 | keyfile: ""}
    %SpData{} = sp_data = SpData.load_provider(sp_config)
    refute sp_data.valid?
  end

  test "invalid-sp-config-4" do
    sp_config = %{@sp_config1 | certfile: "non-existent.crt"}
    %SpData{} = sp_data = SpData.load_provider(sp_config)
    refute sp_data.valid?
  end

  test "invalid-sp-config-5" do
    sp_config = %{@sp_config1 | keyfile: "non-existent.pem"}
    %SpData{} = sp_data = SpData.load_provider(sp_config)
    refute sp_data.valid?
  end

  test "invalid-sp-config-6" do
    sp_config = %{@sp_config1 | certfile: "test/data/test.pem"}
    %SpData{} = sp_data = SpData.load_provider(sp_config)
    refute sp_data.valid?
  end

  @tag :skip
  test "invalid-sp-config-7" do
    sp_config = %{@sp_config1 | keyfile: "test/data/test.crt"}
    %SpData{} = sp_data = SpData.load_provider(sp_config)
    refute sp_data.valid?
  end
end
