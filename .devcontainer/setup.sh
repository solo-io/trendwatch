#!/bin/sh
# Runs INSIDE the container (via devcontainer.json postCreateCommand).
# Installs project dependencies and health-checks the services the container
# depends on. Health checks are non-fatal: they warn with clear hints instead
# of failing container setup.

# --- Python dependencies ------------------------------------------------------
echo "Installing Python dependencies..."
if pip install -r requirements.txt; then
	echo "Python dependencies installed"
else
	echo "ERROR: failed to install Python dependencies from requirements.txt" >&2
	exit 1
fi

# --- agentgateway -------------------------------------------------------------
echo "Installing agentgateway..."
if curl -sL https://agentgateway.dev/install | bash -s -- --version 1.5.0; then
	echo "agentgateway installed"
else
	echo "ERROR: failed to install agentgateway" >&2
	exit 1
fi

# --- LLM server (host) --------------------------------------------------------
# Works with any OpenAI-compatible server (LM Studio, Ollama, etc.).
if curl -sf --max-time 5 "$LLM_BASE_URL/models" >/dev/null 2>&1; then
	echo "LLM server reachable at $LLM_BASE_URL"
else
	echo "WARNING: LLM server not reachable at $LLM_BASE_URL from the container." >&2
	echo "  On the host, start your LLM server and make it listen on 0.0.0.0" >&2
	echo "  (not just localhost) so the container can reach it:" >&2
	echo "    - LM Studio: enable 'Serve on Local Network'" >&2
	echo "    - Ollama: set OLLAMA_HOST=0.0.0.0 and restart" >&2
fi

# --- Jaeger (sibling container) -----------------------------------------------
if curl -sf --max-time 5 "http://jaeger:16686" >/dev/null 2>&1; then
	echo "Jaeger reachable at http://jaeger:16686"
else
	echo "WARNING: Jaeger not reachable at http://jaeger:16686 from the container." >&2
	echo "  Ensure the 'jaeger' sibling container is running on the 'llm' network" >&2
	echo "  (started by .devcontainer/init-host.sh on the host)." >&2
fi
