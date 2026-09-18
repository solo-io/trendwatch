# Introduction

This workshop helps you explore some of the agentic capabilities of [agentgateway](https://agentgateway.dev/).

The workshop is designed to be self-contained with a minimum of external dependencies.

## Prerequisites

This workshop runs inside a [Dev Container](https://containers.dev/).
The container comes preconfigured with everything the labs need, so you don't have to install these tools yourself:

- python3 (version 3.11) and the project's python dependencies
- [jq](https://jqlang.org/)
- the docker CLI
- the `agentgateway` binary
- a [Jaeger](https://www.jaegertracing.io/) tracing container (started automatically as a sibling container)

The container also presets the environment variables the agent reads (`LLM_BASE_URL`, `LLM_MODEL`, `MCP_URL`, and `OTEL_EXPORTER_OTLP_ENDPOINT`).

To open the workshop in the dev container, install the following on your machine:

- [Docker](https://www.docker.com/) (or Podman)
- [Visual Studio Code](https://code.visualstudio.com/) with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- An OpenAI-compatible LLM server running on your **host** machine (see the [LLM Provider](#llm-provider) section below)

## LLM Provider

The agent runs inside the dev container, but the LLM server runs on your **host** machine.
The container reaches the host through the `host.docker.internal` hostname, which is already baked into the preset `LLM_BASE_URL`.

!!! important "Listen on all interfaces"

    So the container can reach it, start your LLM server on the host bound to `0.0.0.0` (not just `localhost`):

    - **LM Studio**: enable "Serve on Local Network".
    - **Ollama**: set `OLLAMA_HOST=0.0.0.0` and restart the server.

=== "Local model"

    The dev container defaults to a local inference model reached at `http://host.docker.internal:1234/v1`, the default port for [LM Studio](https://lmstudio.ai/).
    You can also use [Ollama](https://ollama.com/); it listens on port `11434` by default, so adjust `LLM_BASE_URL` accordingly in the devcontainer.json file and rebuild the dev container.

    Using Ollama on a mac, you can install it with [homebrew](https://brew.sh/):

    ```shell
    brew install ollama
    ```

    For other platforms, consult the [Ollama docs](https://docs.ollama.com/linux) for the install instructions.

    Whichever server you choose, pull the [qwen3](https://ollama.com/library/qwen3) model so it matches the preset `LLM_MODEL`:

    ```shell
    ollama pull qwen3:8b
    ```

    Make sure that `qwen3:8b` is now showing in the local models list:

    ```shell
    ollama list
    ```

    From inside the dev container, send a test request to confirm the host's LLM is reachable and produces a response:

    ```shell
    curl -s $LLM_BASE_URL/chat/completions \
      -H "Content-Type: application/json" \
      -d '{"model":"qwen3:8b","messages":[{"role":"user","content":"say hi"}]}' | jq
    ```

=== "Remote model"

    If you'd rather not use a local model, here are some instructions for Google Gemini (no credit card is required for the free tier).

    !!! warning "Free-tier quota"

        The free tier is often not enough to complete every lab in this workshop.
        If you have your own Gemini API key, export that as `GEMINI_API_KEY` and skip minting a free key below.

    Mint a free key:

    - Open [Google AI Studio](https://aistudio.google.com/apikey) and sign in with a personal Google account.
    - Accept the Generative AI terms if prompted. Studio will create a default Cloud project for you.
    - Click Create API key. Prefer Create key in a new project if you just want a sandbox.

    Copy the key and configure the `GEMINI_API_KEY` environment variable:

    ```shell
    export GEMINI_API_KEY=<paste your key here>
    ```

    Gemini exposes an [OpenAI-compatible](https://ai.google.dev/gemini-api/docs/openai) endpoint.
    Send it targeting the "Flash-Lite" model, a generous model for experiments:

    ```shell
    curl -s https://generativelanguage.googleapis.com/v1beta/openai/chat/completions \
      -H "Authorization: Bearer $GEMINI_API_KEY" \
      -H "Content-Type: application/json" \
      -d '{"model":"gemini-3.5-flash-lite","messages":[{"role":"user","content":"say hi"}]}' | jq
    ```

## The agentic scenario: TrendWatch

TrendWatch is an AI agent that tells you what is hot in agentic AI today.
It leverages a set of MCP servers to read trending discussions, build and save a digest on the topics you care about, and can "publish" these digests.

Clone the GitHub repository for the project:

```shell
git clone https://github.com/solo-io/trendwatch.git
```

Open the project in VS Code:

```shell
code trendwatch
```

When VS Code prompts you (or from the Command Palette, run **Dev Containers: Reopen in Container**), reopen the folder in the dev container.
The first build takes a few minutes. Behind the scenes it:

- installs the project's python dependencies from `requirements.txt`,
- installs the `agentgateway` binary,
- starts the Jaeger tracing container as a sibling on a shared `llm` docker network,
- presets the agent's environment variables.

Once the container is ready, open a terminal in VS Code (it runs *inside* the container) for the rest of the workshop.

The code consists of an agent named "TrendWatch", and a set of example MCP servers, written in python.

Inspect the contents of the `agent/` and `mcp-servers/` subdirectories, to take account of the main project files:

```shell
ls -lF agent/ mcp-servers/
```

### Setup

The dev container has already prepared your environment, so there is no need to create a python virtual environment, install dependencies, or start Jaeger by hand.

For reference, the dev container performs the equivalent of the following steps for you:

- Installs the python dependencies: `pip install -r requirements.txt`
- Installs `agentgateway`.
- Runs the [Jaeger](https://www.jaegertracing.io/) tracing container:

    ```shell
    docker run -d --name jaeger \
      -p 16686:16686 -p 4317:4317 \
      jaegertracing/all-in-one:latest
    ```

You will use Jaeger to inspect distributed traces illustrating the call flows between the agent, the LLM, and MCP servers.

!!! note "Running outside the dev container"

    If you prefer to run the workshop without the dev container, you will need to perform those steps yourself: create and activate a python virtual environment (`python3 -m venv .venv` then `source .venv/bin/activate`, or `source .venv/bin/activate.fish` for the [fish shell](https://fishshell.com/)), install the dependencies, install `agentgateway`, start Jaeger, and export the environment variables described below.

### Configure and run the agent

Agents generally are configured with a System prompt, an LLM, and tools to accomplish a specific job.
The TrendWatch agent is configured to receive some of that information from environment variables, as follows:

- LLM_BASE_URL - the endpoint for making calls to the LLM.
- LLM_MODEL - the name of the model to target.
- MCP_URL - the URL for the MCP server whose tools the agent can call.

Let us walk through an example.

=== "Local model"

    In the dev container these three variables are **already set** for you:

    ```shell
    LLM_BASE_URL="http://host.docker.internal:1234/v1"
    LLM_MODEL="qwen3:8b"
    MCP_URL="stdio:./mcp-servers/trends_server.py"
    ```

    This configures the agent to call your host's LLM server (LM Studio on port `1234` by default; use `11434` for Ollama), to use the preconfigured `qwen3:8b` model, and to use the `trends_server` MCP server over the stdio transport (runs as a child process).

    Confirm they are set:

    ```shell
    echo "$LLM_BASE_URL $LLM_MODEL $MCP_URL"
    ```

    Try it out by running:

    ```shell
    python3 agent/trendwatch.py "what discussions are trending today?"
    ```

=== "Remote model"

    To target Gemini instead of a local model, override the preset variables in your terminal:

    ```shell
    export LLM_BASE_URL="https://generativelanguage.googleapis.com/v1beta/openai/"
    export LLM_MODEL="gemini-3.5-flash-lite"
    export LLM_API_KEY="$GEMINI_API_KEY"
    export MCP_URL="stdio:./mcp-servers/trends_server.py"
    ```

    Above, we configure the agent to call Gemini's [OpenAI-compatible](https://ai.google.dev/gemini-api/docs/openai) endpoint, to use the Flash-Lite model, and to use the `trends_server` MCP server over the stdio transport (runs as a child process). `LLM_API_KEY` is the Gemini key from the previous step.

    Try it out by running:

    ```shell
    python3 agent/trendwatch.py "what discussions are trending today?"
    ```

The agent outputs some logging information such as:

- Its configuration.
- The tools made visible to the model.
- Information for each "turn", including token consumption, tools called.

Ultimately, the agent outputs the response to the user, in this case the list of trending conversations.

In the first turn, the agent should respond with a tool request for `trending_discussions`.
The tool fetches and filters trending discussions pertaining to AI from HackerNews, then responds with the top 5 trending discussions.
In the second turn, the agent takes that information and presents it to the user.

## Summary

So far, we explored a local setup to run an agentic loop:  an agent has access to a local model and MCP servers, and can answer questions.  As the loop runs, the LLM is consulted, requests for specific tools to be called, and incorporates the responses to further reason about the user's query, and ultimately produces a response.

In the next sections, we explore the agentgateway project, and how it plays a crucial role as a proxy to both LLM and MCP traffic.