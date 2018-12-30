# CHANGELOG

### v0.10.0 (WIP)

+   Issue: #31 - Support for Cowboy 2.x
    Uptake `esaml` v4.0.0 which includes support for Cowboy 2.x.
    If support for Cowboy 1.x is needed, you need an override with
    `esaml` v3.6.x in your application `mix.exs` file.

+   Issue: #32 - Support for custom State Storage
    Includes support for ETS and Plug Sessions based authenticated SAML
    assertion storage. It is possible to create custom stores by
    implementing `Samly.State.Store`.

+   Issue: #34 - Included filename in error messages
    Include metadata/cert/key filenames when there is an error relevant to
    those files.

### v0.9.3

+   Uptake `esaml` v3.6.0 that includes fixes for schema validation errors.

### v0.9.2

+   PR merged fixing reopened Issue #16 (from @peterox)

### v0.9.1

+   Remove the need for supplying certicate and key files if the requests are
    not signed (Issue #16). Useful during development when the corresponding
    Identity Provider is setup for unsigned requests/responses. Use signing
    for production deployments. The defaults expect signed requests/responses.

### v0.9.0

+   Issue: #12. Support for IDP initiated SSO flow.

+   Original auth request ID when returned in auth response is made available
    in the assertion subject (SP initiated SSO flows). For IDP initiated
    SSO flows, this will be an empty string.

+   Issue: #14. Remove built-in referer check.
    Not specific to `Samly`. It is better handled by the consuming application.

### v0.8.4

+   Shibboleth Single Logout session match related fix. Uptake `esaml v3.3.0`.

### v0.8.3

+   Generates SP metadata XML that passes XSD validation

### v0.8.2

+   Handle namespaces in Identity Provider Metadata XML file

### v0.8.0

+   Added support for multiple Identity Providers. Check issue: #4.
    Instructions for migrating from v0.7.x available in github project wiki.

### v0.7.2

+   Added `use_redirect_for_idp_req` config parameter. By default `Samly` uses HTTP POST when sending requests to IdP. Set this config parameter to `true` if HTTP redirection should be used instead.

### v0.7.1

+   Added config option (`entity_id`). OOTB uses metadata URI as entity ID. Can be specified (`urn` entity ID for example) to override the default.

### v0.7.0

+   Added config options to control if requests and/or responses are signed or not

### v0.6.3

+   Added Inch CI
+   Corresponding doc updates

### v0.6.2

+   Doc updates
+   Config handling changes and corresponding tests

### v0.6.1

+   `target_url` query parameter form url encoded

### v0.6.0

+   Plug Pipeline config `:pre_session_create_pipeline`
+   Computed attributes available in `Samly.Assertion`
+   Updates to `Samly.Provider` `base_url` config handling
