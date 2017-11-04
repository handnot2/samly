# Samly

SAML 2.0 SP SSO made easy. This is a Plug library that can be used to enable SAML 2.0 Single Sign On in a Plug/Phoenix application.

[![Inline docs](http://inch-ci.org/github/handnot2/samly.svg)](http://inch-ci.org/github/handnot2/samly)

This library uses Erlang [`esaml`](https://github.com/handnot2/esaml) to provide
plug enabled routes.

## Setup

```elixir
# mix.exs

defp deps() do
  [
    # ...
    {:samly, "~> 0.8"},
  ]
end
```

If you are usig `Samly` v0.7.x, checkout: [`Migrating from v0.7.x to v0.8.0`](https://github.com/handnot2/samly/wiki/Migrate-Samly-v0.7.x-to-v0.8.0).

## Supervision Tree

Add `Samly.Provider` to your application supervision tree.

```elixir
# application.ex

children = [
  # ...
  worker(Samly.Provider, []),
]
```

## Router Change

Make the following change in your application router.

```elixir
# router.ex

# Add the following scope ahead of other routes
# Keep this as a top-level scope and **do not** add
# any plugs or pipelines explicitly to this scope.
scope "/sso" do
  forward "/", Samly.Router
end
```

## Certificate and Key for Samly

`Samly` needs a private key and a corresponding certificate. These are used when
communicating with the Identity Provider.

A convenient script, `gencert.sh`, is provided to generate the key and certificate.
Make sure `openssl` is available on your system. The name of the key file and
certificate file generated should be provided as part of the Samly configuration.

## Identity Provider Metadata

`Samly` expects information about the Identity Provider including information about
its SAML endpoints in an XML file. Most Identity Providers have some way of
exporting the IdP metadata in XML form. Some may provide a web UI to export/save
the XML locally. Others may provide a URL that can be used to fetch the metadata.

For example, `SimpleSAMLPhp` IdP provides a URL for the metadata. You can fetch
it using `wget`.

```
wget http://samly.idp:8082/simplesaml/saml2/idp/metadata.php -O idp_metadata.xml
```

If you are using the `SimpleSAMLPhp` administrative Web UI, login with you
admin credentials (`http://samly.idp:8082/simplesaml`). Go to the `Federation`
tab. At the top there will be a section titled "SAML 2.0 IdP Metadata". Click
on the `Show metadata` link. Copy the metadata XML from this page and save it
in a local file (`idp_metadata.xml` for example).

Make sure to save this XML file and provide the path to the saveed file in
`Samly` configuration.

## Identity Provider ID in Samly

`Samly` has the ability to support multiple Identity Providers. All IdPs that
`Samly` needs to talk to must have an identifier (idp_id). This IdP id will be
used in the service provider URLs. This is how `Samly` figures out which SAML
request corresponds to what IdP so that it can perform relevant validation checks
and process the requests/responses.

There are two options when it comes to how the idp_id is represented in the
Service Provider SAML URLs.

#### URL Path Segment

In this model, the idp_id is present as a URL path segment. Here is an
example URL: `http://do-good.org/sso/auth/signin/affiliates`. The idp_id
in this URL is "affiliates". If you have more than one IdP, only this last
part changes. The URLs for this model are:

| Description | URL |
|:----|:----|
| Sign-in button/link in Web UI | `/sso/auth/signin/affiliates` |
| Sign-out button/link in Web UI | `/sso/auth/signout/affiliates` |
| SP Metadata URL | `http://do-good.org/sso/sp/metadata/affiliates` |
| SAML Assertion Consumer Service | `http://do-good.org/sso/sp/consume/affiliates` |
| SAML SingleLogout Service | `http://do-good.org/sso/sp/logout/affiliates` |

The path segment model is the default one in `Samly`. If there is only one Identity Provider, use this mode.

> These URL routes are automatically created based on the configuration information and
> the above mentioned router scope definition.
>
> Use the Sign-in and Sign-out URLs shown above in your application's Web UI buttons/links.
> When the end-user clicks on these buttons/links, the HTTP `GET` request is handled by `Samly`
> which internally does a `POST` that in turn sends the appropriate SAML request to the IdP.

#### Subdomain in Host Name

In this model, the subdomain name is used as the idp_id. Here is an example URL: `http://ngo.do-good.org/sso/auth/signin`. Here "ngo" is the idp_id. The URLs supported by `Samly`
in this model look different.

| Description | URL |
|:----|:----|
| Sign-in button/link in Web UI | `/sso/auth/signin` |
| Sign-out button/link in Web UI | `/sso/auth/signout` |
| SP Metadata URL | `http://ngo.do-good.org/sso/sp/metadata` |
| SAML Assertion Consumer Service | `http://ngo.do-good.org/sso/sp/consume` |
| SAML SingleLogout Service | `http://ngo.do-good.org/sso/sp/logout` |

> Take a look at [`samly_howto`](https://github.com/handnot2/samly_howto) - a reference/demo
> application on how to use this library.
>
> Make sure to use HTTPS URLs in production deployments.

## Samly Configuration

```elixir
# config/dev.exs

config :samly, Samly.Provider,
  idp_id_from: :path_segment,
  service_providers: [
    %{
      id: "do-good-affiliates-sp",
      entity_id: "urn:do-good.org:affiliates-app",
      certfile: "path/to/samly/certfile.crt",
      keyfile: "path/to/samly/keyfile.pem",
      #contact_name: "Affiliates Admin",
      #contact_email: "affiliates-admin@do-good.org",
      #org_name: "Do Good",
      #org_displayname: "Goodly, No evil!",
      #org_url: "http://do-good.org"
    }
  ],
  identity_providers: [
    %{
      id: "affiliates",
      sp_id: "do-good-affiliates-sp",
      base_url: "http://do-good.org/sso",
      metadata_file: "idp_metadata.xml",
      #pre_session_create_pipeline: MySamlyPipeline,
      #use_redirect_for_req: false,
      #sign_requests: true,
      #sign_metadata: true,
      #signed_assertion_in_resp: true,
      #signed_envelopes_in_resp: true
    }
  ]
```

| Parameters | Description |
|:------------|:-----------|
| `idp_id_from` | _(optional)_`:path_segment` or `:subdomain`. Default is `:path_segment`. |
| **Service Provider Parameters** | |
| `id` | _(mandatory)_ |
| `identity_id` | _(optional)_ If omitted, the metadata URL will be used |
| `certfile` | _(optional)_ Defaults to "samly.crt" |
| `keyfile` | _(optional)_ Defaults to "samly.pem" |
| `contact_name` | _(optional)_ Technical contact name for the Service Provider |
| `contact_email` | _(optional)_ Technical contact email address |
| `org_name` | _(optional)_ SAML Service Provider (your app) Organization name |
| `org_displayname` | _(optional)_ SAML SP Organization displayname |
| `org_url` | _(optional)_ Service Provider Organization web site URL |
| **Identity Provider Parameters** | |
| `id` | _(mandatory)_ This will be the idp_id in the URLs |
| `sp_id` | _(mandatory)_ The service provider definition to be used with this Identity Provider definition |
| `base_url` | _(optional)_ If missing `Samly` will use the current URL to derive this. It is better to define this in production deployment. |
| `metadata_file` | _(mandatory)_ Path to the IdP metadata XML file obtained from the Identity Provider. |
| `pre_session_create_pipeline` | _(optional)_ Check the customization section. |
| `use_redirect_for_req` | _(optional)_ Default is `false`. When this is `false`, `Samly` will POST to the IdP SAML endpoints. |
| `signed_requests`, `signed_metadata` | _(optional)_ Default is `true`. |
| `signed_assertion_in_resp`, `signed_envelopes_in_resp` | _(optional)_ Default is `true`. When `true`, `Samly` expects the requests and responses from IdP to be signed. |

## SAML Assertion

Once authentication is completed successfully, IdP sends a "consume" SAML
request to `Samly`. `Samly` in turn performs its own checks (including checking
the integrity of the "consume" request). At this point, the SAML assertion
with the authenticated user subject and attributes is available.

The subject in the SAML assertion is tracked by `Samly` so that subsequent
logout/signout request, either service provider initiated or IdP initiated
would result in proper removal of the corresponding SAML assertion.

Use the `Samly.get_active_assertion` function to get the SAML assertion
for the currently authenticated user. This function will return `nil` if
the user is not authenticated.

> Avoid using the subject in the SAML assertion in UI. Depending on how the
> IdP is setup, this might be a randomly generated id.
>
> You should only rely on the user attributes in the assertion.
> As an application working with an IdP, you should know which attributes
> will be made available to your application and out of
> those attributes which one should be treated as the logged in userid/name.
> For example it could be "uid" or "email" depending on how the authentication
> source is setup in the IdP.

## Customization

`Samly` allows you to specify a Plug Pipeline if you need more control over
the authenticated user's attributes and/or do a Just-in-time user creation.
The Plug Pipeline is invoked after the user has successfully authenticated
with the IdP but before a session is created.

This is just a vanilla Plug Pipeline. The SAML assertion from
the IdP is made available in the Plug connection as a "private".
If you want to derive new attributes, create an Elixir map data (`%{}`)
and update the `computed` field of the SAML assertion and put it back
in the Plug connection private with `Conn.put_private` call.

Here is a sample pipeline that shows this:

```elixir
defmodule MySamlyPipeline do
  use Plug.Builder
  alias Samly.{Assertion}

  plug :compute_attributes
  plug :jit_provision_user

  def compute_attributes(conn, _opts) do
    assertion = conn.private[:samly_assertion]

    first_name = Map.get(assertion.attributes, "first_name")
    last_name  = Map.get(assertion.attributes, "last_name")

    computed = %{"full_name" => "#{first_name} #{last_name}"}

    assertion = %Assertion{assertion | computed: computed}

    conn
    |>  put_private(:samly_assertion, assertion)

    # If you have an error condition:
    # conn
    # |>  send_resp(404, "attribute mapping failed")
    # |>  halt()
  end

  def jit_provision_user(conn, _opts) do
    # your user creation here ...
    conn
  end
end
```

Make this pipeline available in your config:

```elixir
config :samly, Samly.Provider,
  identity_providers: [
    %{
      # ...
      pre_session_create_pipeline: MySamlyPipeline,
      # ...    
    }
  ]
```

## Security Related

+   `Samly` initiated sign-in/sign-out requests send `RelayState` to IdP and expect to get that back. Mismatched or missing `RelayState` in IdP responses to SP initiated requests will fail (with HTTP `403 access_denied`).
+   Besides the `RelayState`, the request and response `idp_id`s must match. Reponse is rejected if they don't.
+   OOTB SAML requests and responses are signed.
+   Signature digest method supported: `SHA256`.
    > Some Identity Providers may be using `SHA1` by default.
    > Make sure to configure the IdP to use `SHA256`. `Samly`
    > will reject (`access_denied`) IdP responses using `SHA1`.
+   `esaml` provides additional checks such as trusted certificate verification, recipient verification among others.
+   By default, `Samly` signs the SAML requests it sends to the Identity Provider. It also
    expects the SAML reqsponses to be signed (both assertion and envelopes). If your IdP is
    not configured to sign, you will have to explicitly turn them off in the configuration.
    It is highly recommended to turn signing on in production deployments.
+   Make sure to use HTTPS URLs in production deployments.

## FAQ

#### How to setup a SAML 2.0 IdP for development purposes?

Docker based setup of [`SimpleSAMLPhp`](https://simplesamlphp.org) is made available
at [`samly_simplesaml`](https://github.com/handnot2/samly_simplesaml) Git Repo.

```sh
git clone https://github.com/handnot2/samly_simplesaml
cd samly_simplesaml

# Ubuntu 16.04 based
./build.sh

# Follow along README.md (skip SAML Service Provider registration part for now)
# Edit setup/params/params.yml with appropriate information
# Add the IDP host name to your /etc/hosts resolving to 127.0.0.1
# 127.0.0.1 samly.idp
# Compose exposes and binds to port 8082 by default.

docker-compose up -d
docker-compose restart
```

You should have a working SAML 2.0 IdP that you can work with.

#### Any sample Phoenix application that shows how to use Samly?

Clone the [`samly_howto`](https://github.com/handnot2/samly_howto) Git Repo.

```sh
git clone https://github.com/handnot2/samly_howto

# Add the SP host name to your /etc/hosts resolving to 127.0.0.1
# 127.0.0.1 samly.howto

cd samly_howto

# Use gencert.sh to create a self-signed certificate for the SAML Service Provider
# embedded in your app (by `Samly`). We will register this and the `Samly` URLs
# with IdP shortly. Take a look at this script and adjust the certificate subject
# if needed.

./gencert.sh

# Get NPM assets

cd assets && npm install && cd ..

# Fetch the IdP metadata XML. `Samly` needs this to make sure that it can
# validate the request/responses to/from IdP.

wget http://samly.idp:8082/simplesaml/saml2/idp/metadata.php -O idp_metadata.xml

mix deps.get
mix compile

HOST=samly.howto PORT=4003 iex -S mix phx.server
```

> Important: Make sure that your have registered this application with
> the IdP before you explore this application using a browser.

Open `http://samly.howto:4003` in your browser and check out the app.

> It is recommended that you use the `SamlyHowto` application to
> sort out any configuration issues by making this demo application work
> successfully with your Identity Provider (IdP) before attempting your
> application.
>
> This demo application supports experimentation with multiple IdPs.

#### How to register the service provider with IdP

Complete the setup by registering `samly_howto` as a Service Provider with the IdP.

```sh
mkdir -p samly_simplesaml/setup/sp/samly_howto # use the correct path
cp samly.crt samly_simplesaml/setup/sp/samly_howto/sp.crt
cd samly_simplesaml
docker-compose restart
```

> The IdP related instructions are very specific to the docker based development
> setup of SimpleSAMLphp IdP. But similar ideas work for your own IdP setup.
