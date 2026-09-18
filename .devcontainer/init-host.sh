#!/bin/sh
# Runs on the HOST (via devcontainer.json initializeCommand) before the devcontainer starts.
# Uses podman if available, otherwise docker. All steps are idempotent.
set -e

CLI=$(command -v podman || command -v docker)

# Ensure the shared "llm" network exists so sibling containers can reach each other by name.
$CLI network inspect llm >/dev/null 2>&1 || $CLI network create llm

# Ensure the Jaeger sibling container is running: create it if missing, start it if stopped.
if $CLI container inspect jaeger >/dev/null 2>&1; then
	if [ "$($CLI container inspect -f '{{.State.Running}}' jaeger)" != "true" ]; then
		$CLI start jaeger
	fi
else
	$CLI run -d --name jaeger --network=llm \
		-p 16686:16686 -p 4317:4317 \
		jaegertracing/all-in-one:latest
fi

