#!/usr/bin/env bash
# Run Terraform via the official Docker image when `terraform` is not installed on the host.
# Forwards TF_VAR_* from the current environment into the container (required for make demo / apply).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${TERRAFORM_IMAGE:-hashicorp/terraform:1.9.0}"

TF_ENV=$(mktemp)
cleanup() { rm -f "$TF_ENV"; }
trap cleanup EXIT

ENV_ARGS=()
if env | grep -q '^TF_VAR_'; then
	# docker --env-file expects KEY=VALUE lines (same as `env` output for assigned vars).
	env | grep '^TF_VAR_' >"$TF_ENV"
	ENV_ARGS=(--env-file "$TF_ENV")
fi

# The socket is root:docker (mode 660). The container runs as host uid:gid without the
# docker group, so Terraform cannot use the API unless we add the socket's GID.
GROUP_ADD=()
if [[ -S /var/run/docker.sock ]]; then
	SOCK_GID="$(stat -c '%g' /var/run/docker.sock 2>/dev/null || true)"
	if [[ -n "${SOCK_GID:-}" ]]; then
		GROUP_ADD=(--group-add "$SOCK_GID")
	fi
fi

exec docker run --rm -i \
	-u "$(id -u):$(id -g)" \
	"${GROUP_ADD[@]}" \
	"${ENV_ARGS[@]}" \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v "${ROOT}:/project" \
	-w /project \
	"${IMAGE}" "$@"
