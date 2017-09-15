# Samly

A Plug library to enable SAML 2.0 Single Sign On in a Plug/Phoenix application.

[![Inline docs](http://inch-ci.org/github/handnot2/samly.svg)](http://inch-ci.org/github/handnot2/samly)

This library uses Erlang [`esaml`](https://github.com/handnot2/esaml) to provide
plug enabled routes. So, it is constrained by `esaml` capabilities - only Service
Provider initiated login is supported. The logout operation can be either IdP
initiated or SP initiated.

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

#### How to register the service provider with IdP

Complte the setup by registering `samly_howto` as a Service Provider with the
IdP.

```sh
mkdir -p samly_simplesaml/setup/sp/samly_howto # use the correct path
cp samly.crt samly_simplesaml/setup/sp/samly_howto/sp.crt
cd samly_simplesaml
docker-compose restart
```

> The IdP related instructions are very specific to the docker based development
> setup of SimpleSAMLphp IdP. But similar ideas work for your own IdP setup.

#### How do I enable Samly in my application?

The short of it is:

+   Add `Samly` to your `mix.exs`
+   Include `Samly` in your supervision tree
+   Include route forwarding to your `router.ex`
+   Use `/sso/auth/signin` and `/soo/auth/signout` relative URIs in your UI
    with optional `target_url` query parameter
+   Config changes in your config files or environment variable as appropriate
+   Use `Samly.get_active_assertion` function to get authenticated user
    information
+   Register this application with the IdP

That covers it for the basics. If you need to use different attribute names
(from what the IdP provides), derive/compute new attributes or do Just-in-time
user provisioning, create your own Plug Pipeline and make that available to
`Samly` using a config setting. Check out the `SAML Assertion` section for
specifics.

## Setup

```elixir
# mix.exs

defp deps() do
  [
    # ...
    {:samly, "~> 0.6"},
  ]  
end
```

## Configuration

#### Router

Make the following change in your application router.

```elixir
# router.ex

# Add the following scope in front of other routes
scope "/sso" do
  forward "/", Samly.Router
end
```

#### Supervision Tree

Add `Samly.Provider` to your application supervision tree.

```elixir
# application.ex

children = [
  # ...
  worker(Samly.Provider, []),
]
```
#### Configuration Parameters

The configuration information needed for `Samly` can be specified in as shown here:

```elixir
# config/dev.exs

config :samly, Samly.Provider,
  base_url: "http://samly.howto:4003/sso",
  #pre_session_create_pipeline: MySamlyPipeline,
  certfile: "path/to/service/provider/certificate/file",
  keyfile: "path/to/corresponding/private/key/file",
  idp_metadata_file: "path/to/idp/metadata/xml/file"
```

If these are not specified in the config file, `Samly` relies on the environment
variables described below.

#### Environment Variables

| Variable | Description  |
|:-------------------- |:-------------------- |
| SAMLY_CERTFILE | Path to the X509 certificate file. Defaults to `samly.crt` |
| SAMLY_KEYFILE  | Path to the private key for the certificate. Defaults to `samly.pem` |
| SAMLY_IDP_METADATA_FILE | Path to the SAML IDP metadata XML file. Defaults to `idp_metadata.xml` |
| SAMLY_BASE_URL | Set this to the base URL for your application (include `/sso`) |

#### Generating Self-Signed Certificate and Key Files for Samly

Make sure `openssl` is available on your system. Use the `gencert.sh` script
to generate the certificate and key files needed to send and recieve
signed SAML requests. As mentioned in FAQ change certificate subject in the
script if needed.

#### SAML IdP Metadata

This should be an XML file that contains information on the IdP
`SingleSignOnService` and `SingleLogoutService` endpoints, IdP Certificate and
other metadata information. When `Samly` is used to work with
[`SimpleSAMLPhp`](https://simplesamlphp.org), the following command can be used to
fetch the metadata:

```sh
wget http://samly.idp:8082/simplesaml/saml2/idp/metadata.php -O idp_metadata.xml
```

Make sure to use the host and port in the above IdP metadata URL.

It is possible to use the admin web console for `SimpleSAMLphp` to get this metadata.
Use the browser to reach the admin web console (`http://samly.idp:8082/simplesaml`).
Use the `SimpleSAMLphp` admin credentials to login. Go to the `Federation` tab.
At the top there will be a section titled "SAML 2.0 IdP Metadata". Click on the
`Show metadata` link. Copy the metadata XML from this page and create
`idp_metadata.xml` file with that content.

## Sign in and Sign out

Use `Samly.get_active_assertion` API. This API will return `Samly.Assertion` structure
if the user is authenticated. If not it return `nil`.

Use `/sso/auth/signin` and `/sso/auth/signout` as relative URIs in your UI login and
logout links or buttons.

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

    first_name = Map.get(assertion.attributes, :first_name)
    last_name  = Map.get(assertion.attributes, :last_name)

    computed = %{full_name: "#{first_name} #{last_name}"}

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
  pre_session_create_pipeline: MySamlyPipeline
```

> Important: If you think you have a Plug Pipeline but don't find the computed
> attributes in the assertion returned by `Samly.get_active_assertion`, make
> sure the above config setting is specified.
