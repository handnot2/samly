defmodule SamlyIdpDataTest do
  use ExUnit.Case
  require Samly.Esaml
  alias Samly.{Esaml, IdpData, SpData}

  @sp_config1 %{
    id: "sp1",
    entity_id: "urn:test:sp1",
    certfile: "test/data/test.crt",
    keyfile: "test/data/test.pem"
  }

  @sp_config2 %{
    id: "sp2",
    certfile: "test/data/test.crt",
    keyfile: "test/data/test.pem"
  }

  @sp_config3 %{
    id: "sp3",
    keyfile: "test/data/test.pem"
  }

  @sp_config4 %{
    id: "sp4",
    certfile: "test/data/test.crt"
  }

  @sp_config5 %{
    id: "sp5"
  }

  @idp_config1 %{
    id: "idp1",
    sp_id: "sp1",
    base_url: "http://samly.howto:4003/sso",
    metadata_file: "test/data/idp_metadata.xml"
  }

  @idp_config2 %{
    id: "idp2",
    sp_id: "sp2",
    base_url: "http://samly.howto:4003/sso",
    metadata_file: "test/data/idp_metadata.xml"
  }

  setup context do
    sp_data1 = SpData.load_provider(@sp_config1)
    sp_data2 = SpData.load_provider(@sp_config2)
    sp_data3 = SpData.load_provider(@sp_config3)
    sp_data4 = SpData.load_provider(@sp_config4)
    sp_data5 = SpData.load_provider(@sp_config5)

    [
      sps: %{
        sp_data1.id => sp_data1,
        sp_data2.id => sp_data2,
        sp_data3.id => sp_data3,
        sp_data4.id => sp_data4,
        sp_data5.id => sp_data5
      }
    ]
    |> Enum.into(context)
  end

  test "valid-idp-config-1", %{sps: sps} do
    %IdpData{} = idp_data = IdpData.load_provider(@idp_config1, sps)
    assert idp_data.valid?
  end

  # verify defaults
  test "valid-idp-config-2", %{sps: sps} do
    %IdpData{} = idp_data = IdpData.load_provider(@idp_config1, sps)
    refute idp_data.use_redirect_for_req
    assert idp_data.sign_requests
    assert idp_data.sign_metadata
    assert idp_data.signed_assertion_in_resp
    assert idp_data.signed_envelopes_in_resp
  end

  test "valid-idp-config-3", %{sps: sps} do
    idp_config =
      Map.merge(@idp_config1, %{
        use_redirect_for_req: false,
        sign_requests: true,
        sign_metadata: true,
        signed_assertion_in_resp: true,
        signed_envelopes_in_resp: true
      })

    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    refute idp_data.use_redirect_for_req
    assert idp_data.sign_requests
    assert idp_data.sign_metadata
    assert idp_data.signed_assertion_in_resp
    assert idp_data.signed_envelopes_in_resp
  end

  test "valid-idp-config-4", %{sps: sps} do
    idp_config =
      Map.merge(@idp_config1, %{
        use_redirect_for_req: true,
        sign_requests: false,
        sign_metadata: false,
        signed_assertion_in_resp: false,
        signed_envelopes_in_resp: false
      })

    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    assert idp_data.use_redirect_for_req
    refute idp_data.sign_requests
    refute idp_data.sign_metadata
    refute idp_data.signed_assertion_in_resp
    refute idp_data.signed_envelopes_in_resp
  end

  test "valid-idp-config-5", %{sps: sps} do
    idp_config = %{@idp_config1 | base_url: nil}
    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    assert idp_data.valid?
    assert idp_data.base_url == nil
  end

  test "valid-idp-config-6", %{sps: sps} do
    idp_config = Map.put(@idp_config1, :pre_session_create_pipeline, MyPipeline)
    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    assert idp_data.valid?
    assert idp_data.pre_session_create_pipeline == MyPipeline
  end

  test "valid-idp-config-7", %{sps: sps} do
    idp_config = %{@idp_config1 | metadata_file: "test/data/azure_fed_metadata.xml"}
    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    assert idp_data.valid?
  end

  test "valid-idp-config-8", %{sps: sps} do
    idp_config = %{@idp_config1 | metadata_file: "test/data/onelogin_idp_metadata.xml"}
    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    assert idp_data.valid?
  end

  test "valid-idp-config-9", %{sps: sps} do
    idp_config = %{@idp_config1 | metadata_file: "test/data/shibboleth_idp_metadata.xml"}
    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    assert idp_data.valid?
  end

  test "valid-idp-config-10", %{sps: sps} do
    idp_config = %{@idp_config1 | metadata_file: "test/data/simplesaml_idp_metadata.xml"}
    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    assert idp_data.valid?
  end

  test "valid-idp-config-11", %{sps: sps} do
    idp_config = %{@idp_config1 | metadata_file: "test/data/testshib_metadata.xml"}
    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    assert idp_data.valid?
  end

  test "url-test-1", %{sps: sps} do
    idp_config = %{@idp_config1 | metadata_file: "test/data/shibboleth_idp_metadata.xml"}
    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    assert idp_data.valid?

    Esaml.esaml_idp_metadata(
      login_location: sso_url,
      logout_location: slo_url
    ) = idp_data.esaml_idp_rec

    assert sso_url |> List.to_string() |> String.ends_with?("/SAML2/POST/SSO")
    assert slo_url |> List.to_string() |> String.ends_with?("/SAML2/POST/SLO")
  end

  test "url-test-2", %{sps: sps} do
    idp_config = %{@idp_config1 | metadata_file: "test/data/shibboleth_idp_metadata.xml"}
    idp_config = Map.put(idp_config, :use_redirect_for_req, true)
    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    assert idp_data.valid?

    Esaml.esaml_idp_metadata(
      login_location: sso_url,
      logout_location: slo_url
    ) = idp_data.esaml_idp_rec

    assert sso_url |> List.to_string() |> String.ends_with?("/SAML2/Redirect/SSO")
    assert slo_url |> List.to_string() |> String.ends_with?("/SAML2/Redirect/SLO")
  end

  test "sp entity_id test-1", %{sps: sps} do
    %IdpData{} = idp_data = IdpData.load_provider(@idp_config2, sps)
    assert idp_data.valid?
    Esaml.esaml_sp(entity_id: entity_id) = idp_data.esaml_sp_rec
    assert entity_id == :undefined
  end

  @tag :skip
  test "invalid-idp-config-1", %{sps: sps} do
    idp_config = %{@idp_config1 | id: ""}
    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    refute idp_data.valid?
  end

  test "invalid-idp-config-2", %{sps: sps} do
    idp_config = %{@idp_config1 | sp_id: "unknown-sp"}
    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    refute idp_data.valid?
  end

  test "valid-idp-config-signing-turned-off", %{sps: sps} do
    idp_config =
      Map.merge(@idp_config1, %{
        sp_id: "sp5",
        use_redirect_for_req: true,
        sign_requests: false,
        sign_metadata: false
      })

    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    assert idp_data.valid?
  end

  test "invalid-idp-config-signing-on-cert-missing", %{sps: sps} do
    idp_config =
      Map.merge(@idp_config1, %{
        sp_id: "sp3",
        use_redirect_for_req: true,
        sign_requests: true,
        sign_metadata: false
      })

    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    refute idp_data.valid?
  end

  test "invalid-idp-config-signing-on-key-missing", %{sps: sps} do
    idp_config =
      Map.merge(@idp_config1, %{
        sp_id: "sp4",
        use_redirect_for_req: true,
        sign_requests: true,
        sign_metadata: false
      })

    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    refute idp_data.valid?
  end

  test "nameid-format-in-metadata-but-not-config-should-use-metadata", %{sps: sps} do
    %IdpData{} = idp_data = IdpData.load_provider(@idp_config1, sps)
    assert idp_data.nameid_format == ~c"urn:oasis:names:tc:SAML:2.0:nameid-format:transient"
  end

  test "nameid-format-in-config-but-not-metadata-should-use-config", %{sps: sps} do
    idp_config =
      Map.merge(@idp_config1, %{
        metadata_file: "test/data/shibboleth_idp_metadata.xml",
        nameid_format: :email
      })

    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    assert idp_data.nameid_format == ~c"urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
  end

  test "nameid-format-in-metadata-and-config-should-use-config", %{sps: sps} do
    idp_config =
      Map.merge(@idp_config1, %{
        nameid_format: :persistent
      })

    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    assert idp_data.nameid_format == ~c"urn:oasis:names:tc:SAML:2.0:nameid-format:persistent"
  end

  test "nameid-format-in-neither-metadata-nor-config-should-be-unknown", %{sps: sps} do
    idp_config =
      Map.merge(@idp_config1, %{
        metadata_file: "test/data/shibboleth_idp_metadata.xml"
      })

    %IdpData{} = idp_data = IdpData.load_provider(idp_config, sps)
    assert idp_data.nameid_format == :unknown
  end
end
