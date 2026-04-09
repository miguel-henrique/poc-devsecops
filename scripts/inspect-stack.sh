#!/usr/bin/env bash
# Reimprime o resumo de inspeção (containers + comandos úteis) sem rodar Terraform.
# Uso: ./scripts/inspect-stack.sh   (na raiz do repositório, com .env presente)
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=dev-up-logs.sh
source "${REPO_ROOT}/scripts/dev-up-logs.sh"
cd "$REPO_ROOT"
if [[ ! -f "${REPO_ROOT}/.env" ]]; then
	echo "Crie .env a partir de .env.example antes." >&2
	exit 1
fi
set -a
# shellcheck disable=SC1091
source "${REPO_ROOT}/.env"
set +a
presentation_init
presentation_live_status "${TF_VAR_project_name:-poc-devsecops}"
presentation_post_apply_summary "${TF_VAR_project_name:-poc-devsecops}" "${TF_VAR_backend_replica_count:-2}" "${TF_VAR_host_frontend_port:-3000}" "${TF_VAR_network_name:-app-vpc}"
presentation_footer "${TF_VAR_project_name:-poc-devsecops}" "${TF_VAR_host_frontend_port:-3000}" "${TF_VAR_network_name:-app-vpc}"
