# Expose OpenAPI as MCP tools

In this lab, you will experiment with yet another interesting feature of agentgateway:  its ability to [expose OpenAPI endpoints as MCP tools](https://agentgateway.dev/docs/standalone/latest/integrations/mcp/servers/openapi/){ target=_blank }.

## Unauthenticated tool calls

Review the following, trimmed, OpenAPI specification for the GitHub API:

```shell
cat configs/github-search.openapi.json
```

The specification exposes three API calls:

- `search_repositories`
- `get_repository`
- `get_rate_limit`

Next, review the agentgateway configuration:

=== "Local model"

    ```shell
    cat configs/no-github-token.yaml
    ```

=== "Remote model"

    ```shell
    cat configs/no-github-token-gemini.yaml
    ```

Above, note how the mcp target using an `openapi` stanza, which references the OpenAPI specification.

In one terminal, start agentgateway:

=== "Local model"

    ```shell
    agentgateway -f <(envsubst < configs/no-github-token.yaml)
    ```

=== "Remote model"

    Make sure `GEMINI_API_KEY` is still set in this terminal, then:

    ```shell
    agentgateway -f configs/no-github-token-gemini.yaml
    ```

In a second terminal, run the agent with the query about the GitHub rate limit:

```shell
python3 agent/trendwatch.py "what is my GitHub rate limit?"
```

You should receive an answer about the rate limit being 60 requests per hour.
This is the unauthenticated rate limit.

## Authenticated tool call

Agentgateway provides a mechanism to [configure a backend target with credentials](https://agentgateway.dev/docs/standalone/latest/documentation/configuration/security/backend-authn/key/){ target=_blank }.
In this case, we wish to send a Personal Access Token to the GitHub API backend.

In the first terminal, press `Ctrl+C` to terminate agentgateway.

Review the agentgateway configuration:

=== "Local model"

    ```shell
    cat configs/credential-injection.yaml
    ```

=== "Remote model"

    ```shell
    cat configs/credential-injection-gemini.yaml
    ```

The main thing to note is the static key configured under `backendAuth`: the key is configured to the value of the environment variable GITHUB_TOKEN.

### Create a GitHub token

Visit GitHub [Personal access tokens](https://github.com/settings/personal-access-tokens){ target=_blank } and generate a new token for yourself:

- Give it a name
- For "Repository access", just select "Public repositories"
- No need to add any permissions
- Click "Generate token"

Copy the generated token to your clipboard so that you can configure the requisite environment variable:

```shell
export GITHUB_TOKEN="<paste your token here>"
```

Start the agentgateway with this configuration:

=== "Local model"

    ```shell
    agentgateway -f <(envsubst < configs/credential-injection.yaml)
    ```

=== "Remote model"

    Make sure `GEMINI_API_KEY` is still set in this terminal, then:

    ```shell
    agentgateway -f configs/credential-injection-gemini.yaml
    ```

In the second terminal, repeat the query, the question now is in the context of the credentials represented by the supplied key:

```shell
python3 agent/trendwatch.py "what is my GitHub rate limit?"
```

The reply should indicate that the rate limit is more generous for an authenticated user: 5000 requests per hour.

## Summary

In this lab, you've seen how easily agentgateway exposes an MCP server from an OpenAPI specification.
It supports a variety of backend authentication mechanisms; read more about it [here](https://agentgateway.dev/docs/standalone/latest/documentation/configuration/security/backend-authn/){ target=_blank }.