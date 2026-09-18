# Proxy MCP traffic

In this lab, we update agentgateway's configuration to proxy MCP servers in addition to LLM models.
By default, agentgateway uses port 3000 for proxying MCP servers and 4000 for LLM traffic.

Review the following agentgateway configuration:

=== "Local model"

    ```shell
    cat configs/mcp-single.yaml
    ```

=== "Remote model"

    ```shell
    cat configs/mcp-single-gemini.yaml
    ```

In addition to the `llm` configuration, we now also have an `mcp` configuration with a single target:  the `trends_server` MCP server.

From one terminal, start agentgateway with the updated configuration file:

=== "Local model"

    ```shell
    agentgateway -f <(envsubst < configs/mcp-single.yaml)
    ```

=== "Remote model"

    Make sure `GEMINI_API_KEY` is still set in this terminal, then:

    ```shell
    agentgateway -f configs/mcp-single-gemini.yaml
    ```

In a second terminal, update the URL for the MCP server to target agentgateway on port 3000:

```shell
export MCP_URL=http://localhost:3000/mcp
```

Run the agent:

```shell
python3 agent/trendwatch.py "what is hot in agentic AI today?"
```

In the agentgateway logs, you should now see log entries for both calls to LLMs and for calls to MCP servers.
The log entries cite `listener=mcp`.  You should see an MCP tool discovery request follows by a `tools/list` request, both of which are standard initial tool discovery calls.

Ultimately you should see in the logs the `tools/call` to `gen_ai.tool.name=trending_discussions`.

Having a proxy in front of LLM and MCP calls helps you audit, and build a picture of interactions with agentic services.

## Observe distributed traces

Open the [Jaeger Dashboard](http://localhost:16686/){ target=_blank } you started earlier.
Click "Find Traces", listed should be a trace with 14 spans, representing a run of the `trendwatch` agent.
Click on the trace, and examine the spans, which include:

- The initial MCP tool discovery requests, followed by
- The first call to the LLM, then
- The call to the MCP tool "trending_discussions"
- The second turn call to the LLM, which produced the response to the user.

## Federate multiple MCP servers

In the first terminal, press `Ctrl+C` to terminate agentgateway.

Review the next configuration:

=== "Local model"

    ```shell
    cat configs/mcp-multiplex.yaml
    ```

=== "Remote model"

    ```shell
    cat configs/mcp-multiplex-gemini.yaml
    ```

Above, the main difference is the addition of two other MCP servers.
To the agent, agentgateway will look like a single MCP server that aggregates, or multiplexes all three backend MCP servers.

Restart agentgateway with the updated configuration file:

=== "Local model"

    ```shell
    agentgateway -f <(envsubst < configs/mcp-multiplex.yaml)
    ```

=== "Remote model"

    Make sure `GEMINI_API_KEY` is still set in this terminal, then:

    ```shell
    agentgateway -f configs/mcp-multiplex-gemini.yaml
    ```

In the second terminal, run the agent once more:

```shell
python3 agent/trendwatch.py "what is hot in agentic AI today?"
```

Note how the number of tools discovered is now ten (10), whereas previously we had only three (3) tools.
All the tools across the three MCP servers were aggregated into one.

## Filter the tool list

In the first terminal, press `Ctrl+C` to terminate agentgateway, and review the next configuration:

=== "Local model"

    ```shell
    cat configs/tool-filtering.yaml
    ```

=== "Remote model"

    ```shell
    cat configs/tool-filtering-gemini.yaml
    ```

The important difference is the added `mcpAuthorization` policy with three rules specified as [CEL (Common Expression Language) expressions](https://agentgateway.dev/docs/standalone/latest/reference/cel/){ target=_blank }.

The rules state that while any tools belonging to the `trends` or `workspace` MCP targets are authorized, only the `get_public_feed` tool from the `publish` target is authorized.

Confirm this.

In the first terminal, restart agentgateway with the updated configuration file:

=== "Local model"

    ```shell
    agentgateway -f <(envsubst < configs/tool-filtering.yaml)
    ```

=== "Remote model"

    Make sure `GEMINI_API_KEY` is still set in this terminal, then:

    ```shell
    agentgateway -f configs/tool-filtering-gemini.yaml
    ```

In the second terminal, re-run the agent:

```shell
python3 agent/trendwatch.py "what is hot in agentic AI today?"
```

The list of tools discovered is now eight (8), due to two of the tools getting filtered out.

## Summary

In this lab, we have seen how agentgateway can be made to proxy MCP servers in addition to LLMs.
We viewed a distributed tracing dashboard that helped us visualize the activity of the agent.

In the next scenario, we explore how agentgateway can help mitigate prompt injection attacks.