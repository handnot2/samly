defmodule SamlyTest do
  use ExUnit.Case
  doctest Samly

  @test_opts [
    certfile: "test/data/test.crt",
    keyfile: "test/data/test.pem",
    idp_metadata_file: "test/data/idp_metadata.xml",
    base_url: "http://my.app:4000/sso"
  ]

  test "valid sp and idp config" do
    assert Samly.Provider.load_sp_idp_rec(@test_opts)
  end

  test "missing sp certfile" do
    opts = Keyword.drop(@test_opts, [:certfile])
    assert :error = Samly.Provider.load_sp_idp_rec(opts)
  end

  test "missing sp keyfile" do
    opts = Keyword.drop(@test_opts, [:keyfile])
    assert :error = Samly.Provider.load_sp_idp_rec(opts)
  end

  test "missing idp metadata" do
    opts = Keyword.drop(@test_opts, [:idp_metadata_file])
    assert :error = Samly.Provider.load_sp_idp_rec(opts)
  end

  test "invalid certfile" do
    opts = Keyword.put(@test_opts, :certfile, @test_opts[:keyfile])
    assert :error = Samly.Provider.load_sp_idp_rec(opts)
  end

  test "invalid keyfile" do
    opts = Keyword.put(@test_opts, :keyfile, @test_opts[:idp_metadata_file])
    assert :error = Samly.Provider.load_sp_idp_rec(opts)
  end
end
