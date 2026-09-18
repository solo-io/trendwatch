# MCP Authentication

In this lab we explore how to configure MCP authentication and authorization in agentgateway, decoupling that concern from the business logic in the backend MCP server.

You will explore exposing a different set of tools to the user based on whether they're authenticated, and if authenticated, based on their role, obtained from the user's JWT token.

## Setup

For this lab, instead of configuring a full-fledge identity provider such as KeyCloak for the authentication, we provide pre-minted JWT tokens in the form of environment variables READER_JWT and PUBLISHER_JWT.

Follow these instructions to configure a simple stub server to serve the JWKS keyset in the background:

```shell
python3 scripts/fake_idp.py >/tmp/fake_idp.log 2>&1 &
```

The same process also writes the file `fake_idp.env` to load the JWT tokens as environment variables.

## A proxy configured with MCP Authentication & Authorization

Review the following agentgateway configuration:

=== "Local model"

    ```shell
    cat configs/mcp-identity.yaml
    ```

=== "Remote model"

    ```shell
    cat configs/mcp-identity-gemini.yaml
    ```

The configuration has both authentication and authorization sections.
The authentication mode is set to `optional`.
Whether a user is authenticated has a bearing on the interpretation of the authorization rules, some of which reference claims in the user's JWT token.
When the user is unauthenticated, those rules return "false" and certain tools are not available.

From one terminal, launch agentgateway:

=== "Local model"

    ```shell
    agentgateway -f <(envsubst < configs/mcp-identity.yaml)
    ```

=== "Remote model"

    Make sure `GEMINI_API_KEY` is still set in this terminal, then:

    ```shell
    agentgateway -f configs/mcp-identity-gemini.yaml
    ```

## Scenario 1: Unauthenticated user

In a second terminal, begin by loading the environment variables for the two JWT tokens:

```shell
source fake_idp.env
```

Start the agent with a request that demands access to certain tools that are not available to unauthenticated users:

```shell
python3 agent/trendwatch.py \
  "Build today's digest from the trending discussions, then call workspace_save_digest to write it to disk. Do not finish until you have saved it, and report the file path the tool returns."
```

The trending discussions will be obtained, but the agent will not be able to go any further:  it cannot call "save_digest".

## Scenario 2: User with read-only access

The MCP_TOKEN environment variable is used as the identity of the user making the request:

```shell
export MCP_TOKEN=$READER_JWT
```

Now we have a user that has access to more tools, the workspace tools are accessible, and so the agent should be able to fulfill the request:

```shell
python3 agent/trendwatch.py \
  "Build today's digest from the trending discussions, then call workspace_save_digest to write it to disk. Do not finish until you have saved it, and report the file path the tool returns."
```

You should be able to confirm that a "digest" file was written to the folder `out/`:

```shell
ls out/
```

If we ask the agent to "post the digest" which is a "publish" type of action however, the agent is unable to fulfill that request:

```shell
python3 agent/trendwatch.py "post that digest to social"
```

## Scenario 3: User with read-write access

Finally, set the identity of the caller to someone with "publisher" role or capability:

```shell
export MCP_TOKEN=$PUBLISHER_JWT
```

Now the agent will have access to all the tools, and should be able to perform a publish:

```shell
python3 agent/trendwatch.py \
  "Build today's digest from the trending discussions, get the single top trending AI related item from the trending discussions, then publish it by calling publish_post_to_social. Report only the exact JSON the tool returns, then call publish_get_public_feed and show me the feed to confirm the post landed."
```

## Summary

In this lab, authentication and authorization for a backend MCP server was configured at the proxy.
The benefit of employing a proxy is the ability to decouple the implementation of cross-cutting concerns such as security from the logic of the backend workload, be it an MCP server or some other type of backend.
No changes to the backend service were required to implement the security layer.