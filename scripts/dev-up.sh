#!/usr/bin/env bash
# One-shot: ensure .env, check Docker, pick Terraform (host binary or Docker image), init + apply, print URLs.
# Usage:
#   ./scripts/dev-up.sh
#   ./scripts/dev-up.sh --install-deps          # Ubuntu/Debian: sudo apt install docker.io etc. if missing
#   ./scripts/dev-up.sh --install-deps --with-terraform-apt
#   ./scripts/dev-up.sh --yes --install-deps  # non-interactive apt -y
#   ./scripts/dev-up.sh --destroy   # ou ./dev-down.sh / make dev-down
#   ./scripts/dev-up.sh --skip-checkov   # pula Checkov (mais rápido; sem demo de análise estática)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
# shellcheck source=dev-up-logs.sh
source "${REPO_ROOT}/scripts/dev-up-logs.sh"

DOCKER_TF_IMAGE="${TERRAFORM_IMAGE:-hashicorp/terraform:1.9.0}"
DOCKER_TF="${REPO_ROOT}/scripts/terraform-docker.sh"
ENV_EXAMPLE="${REPO_ROOT}/.env.example"
ENV_FILE="${REPO_ROOT}/.env"
TF_DIR="${REPO_ROOT}/terraform"

INSTALL_DEPS=0
INSTALL_TF_APT=0
ASSUME_YES=0
DO_DESTROY=0
SKIP_CHECKOV="${SKIP_CHECKOV:-0}"

info() { printf '\033[0;32m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[WARN]\033[0m %s\n' "$*" >&2; }
err() { printf '\033[0;31m[ERR]\033[0m %s\n' "$*" >&2; }

usage() {
	cat <<'EOF'
Usage: scripts/dev-up.sh [options]

  (no flags)        Create .env if needed, use host Terraform or Docker, init + apply.
  --install-deps    Ubuntu/Debian: sudo apt install docker.io and tools if Docker is missing.
  --with-terraform-apt   With --install-deps: also add HashiCorp APT and install terraform.
  -y, --yes         Non-interactive apt (DEBIAN_FRONTEND=noninteractive).
  --destroy         terraform destroy (equivalente a ./dev-down.sh / make dev-down).
  --skip-checkov    Não executa Checkov antes do apply (mais rápido).
  -h, --help        This help.

  CHECKOV=0|1       Se CHECKOV=0 no ambiente, equivale a --skip-checkov.
  TF_VAR_pip_trusted_host_build=true   Se pip falhar com erro SSL no build (proxy corporativo), defina no .env.
EOF
	exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--install-deps) INSTALL_DEPS=1 ;;
		--with-terraform-apt)
			INSTALL_TF_APT=1
			INSTALL_DEPS=1
			;;
		--yes | -y) ASSUME_YES=1 ;;
		--destroy) DO_DESTROY=1 ;;
		--skip-checkov) SKIP_CHECKOV=1 ;;
		-h | --help) usage 0 ;;
		*) err "Unknown option: $1"; usage 1 ;;
	esac
	shift
done

# CHECKOV=0 no ambiente pula análise estática (mesmo efeito que --skip-checkov)
if [[ "${CHECKOV:-1}" == "0" ]]; then
	SKIP_CHECKOV=1
fi

maybe_noninteractive_apt() {
	if [[ "$ASSUME_YES" -eq 1 ]]; then
		export DEBIAN_FRONTEND=noninteractive
	fi
}

is_ubuntu_debian() {
	[[ -f /etc/os-release ]] || return 1
	source /etc/os-release 2>/dev/null || true
	[[ "${ID:-}" == "ubuntu" || "${ID:-}" == "debian" || "${ID_LIKE:-}" == *debian* ]]
}

install_system_deps() {
	if ! is_ubuntu_debian; then
		err "Automatic install is only implemented for Ubuntu/Debian. Install Docker manually, then re-run without --install-deps."
		return 1
	fi
	maybe_noninteractive_apt
	info "Installing system packages (needs sudo)…"
	sudo apt-get update
	sudo apt-get install -y wget gnupg software-properties-common ca-certificates lsb-release

	if ! command -v docker >/dev/null 2>&1; then
		info "Installing docker.io…"
		sudo apt-get install -y docker.io
	fi
	sudo systemctl enable --now docker 2>/dev/null || sudo service docker start 2>/dev/null || true

	if [[ "$INSTALL_TF_APT" -eq 1 ]]; then
		info "Adding HashiCorp APT repository and installing terraform…"
		wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
		echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" |
			sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
		sudo apt-get update
		sudo apt-get install -y terraform
	fi

	if ! groups "$USER" 2>/dev/null | grep -q '\bdocker\b'; then
		warn "Adding user '$USER' to group 'docker' (you may need to log out and back in)."
		sudo usermod -aG docker "$USER" 2>/dev/null || true
	fi
}

ensure_env_file() {
	if [[ ! -f "$ENV_EXAMPLE" ]]; then
		err "Missing .env.example"
		exit 1
	fi
	if [[ ! -f "$ENV_FILE" ]]; then
		cp "$ENV_EXAMPLE" "$ENV_FILE"
		info "Created .env from .env.example — adjust secrets if needed."
	fi
	# shellcheck disable=SC1090
	set -a
	source "$ENV_FILE"
	set +a
	if [[ -z "${TF_VAR_postgres_user:-}" || -z "${TF_VAR_postgres_password:-}" ]]; then
		err ".env must set TF_VAR_postgres_user and TF_VAR_postgres_password"
		exit 1
	fi
}

check_docker() {
	if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
		return 0
	fi
	if [[ "$INSTALL_DEPS" -eq 1 ]]; then
		install_system_deps || true
	fi
	if ! command -v docker >/dev/null 2>&1; then
		err "Docker is not installed. Re-run with: $0 --install-deps"
		exit 1
	fi
	if ! docker info >/dev/null 2>&1; then
		err "Docker is installed but not usable. Try: newgrp docker   or   sudo systemctl start docker"
		exit 1
	fi
}

chmod +x "$DOCKER_TF" 2>/dev/null || true

# Returns 0 if host terraform should be used.
use_host_terraform() {
	command -v terraform >/dev/null 2>&1 || return 1
	# Quick sanity check
	if ! terraform version >/dev/null 2>&1; then
		return 1
	fi
	return 0
}

run_tf() {
	if [[ "${USE_TF:-}" != "host" && "${USE_TF:-}" != "docker" ]]; then
		err "Internal error: USE_TF not set"
		exit 1
	fi
	if [[ "$USE_TF" == "host" ]]; then
		terraform -chdir="$TF_DIR" "$@"
	else
		"$DOCKER_TF" -chdir=terraform "$@"
	fi
}

pick_terraform_backend() {
	if use_host_terraform; then
		USE_TF=host
		info "Using host Terraform: $(command -v terraform)"
	else
		USE_TF=docker
		info "Using Terraform in Docker (no working terraform on PATH)."
		docker image inspect "$DOCKER_TF_IMAGE" >/dev/null 2>&1 || docker pull "$DOCKER_TF_IMAGE"
	fi
}

# Try host Terraform first; if init fails, clear plugins dir and retry with Docker.
terraform_init_with_fallback() {
	pick_terraform_backend
	info "terraform init…"
	if run_tf init -input=false; then
		return 0
	fi
	if [[ "$USE_TF" == "host" ]]; then
		warn "Host terraform init failed — retrying with Docker image $DOCKER_TF_IMAGE …"
		rm -rf "${TF_DIR}/.terraform"
		USE_TF=docker
		docker image inspect "$DOCKER_TF_IMAGE" >/dev/null 2>&1 || docker pull "$DOCKER_TF_IMAGE"
		info "terraform init (Docker)…"
		run_tf init -input=false
	fi
}

# If a previous run left a Docker network but Terraform state was lost/reset, "create" fails with
# "network ... already exists". Import the existing network so apply can proceed.
reconcile_orphan_docker_network() {
	local project="${TF_VAR_project_name:-poc-devsecops}"
	local net="${TF_VAR_network_name:-app-vpc}"
	local full="${project}-${net}"
	if ! docker network inspect "$full" >/dev/null 2>&1; then
		return 0
	fi
	if run_tf state show 'module.network.docker_network.this' >/dev/null 2>&1; then
		return 0
	fi
	warn "Rede Docker '$full' já existe fora do state Terraform — importando para o state…"
	local nid
	nid="$(docker network inspect -f '{{.Id}}' "$full")"
	run_tf import -input=false "module.network.docker_network.this" "$nid"
}

# Runs apply once; on duplicate Docker network error, import and retry once. Surfaces pip/SSL hints.
terraform_apply_with_recovery() {
	reconcile_orphan_docker_network
	local log rc rc2
	log="$(mktemp)"
	set +e
	run_tf apply -input=false -auto-approve 2>&1 | tee "$log"
	rc=${PIPESTATUS[0]}
	set -e
	if [[ "$rc" -eq 0 ]]; then
		rm -f "$log"
		return 0
	fi
	if grep -qE 'Unable to create network:.*already exists|network with name .* already exists' "$log"; then
		warn "Conflito de rede Docker — importando rede existente e repetindo apply uma vez…"
		reconcile_orphan_docker_network
		set +e
		run_tf apply -input=false -auto-approve
		rc2=$?
		set -e
		rm -f "$log"
		return "$rc2"
	fi
	if grep -qE 'pip install|requirements\.txt|CERTIFICATE_VERIFY_FAILED|SSLError|certificate verify failed' "$log"; then
		warn "Build da imagem backend falhou (pip/HTTPS). Tente no .env: TF_VAR_pip_trusted_host_build=true (ambientes com proxy/SSL corporativo)."
	fi
	rm -f "$log"
	return "$rc"
}

destroy_stack() {
	pick_terraform_backend
	info "terraform destroy…"
	run_tf destroy -input=false -auto-approve
	info "Destroyed."
	exit 0
}

main() {
	ensure_env_file

	if [[ "$DO_DESTROY" -eq 1 ]]; then
		check_docker
		destroy_stack
	fi

	if [[ "$INSTALL_DEPS" -eq 1 ]] && ! docker info >/dev/null 2>&1; then
		install_system_deps || true
	fi

	check_docker

	presentation_init
	presentation_banner
	presentation_research_bridge

	if [[ "$SKIP_CHECKOV" -eq 1 ]]; then
		presentation_skip_checkov
	else
		presentation_pipeline_stages
		presentation_section_static_analysis
		presentation_note_ci
		if command -v checkov >/dev/null 2>&1; then
			if ! run_checkov_scan "$REPO_ROOT" 0; then
				err "Checkov falhou. Corrija os achados ou use --skip-checkov apenas para desenvolvimento."
				exit 1
			fi
		else
			presentation_checkov_hint_install
			if ! run_checkov_scan "$REPO_ROOT" 1; then
				err "Checkov (imagem Docker) falhou. Verifique o Docker ou use --skip-checkov."
				exit 1
			fi
		fi
		presentation_checkov_ok
	fi

	terraform_init_with_fallback

	local replicas="${TF_VAR_backend_replica_count:-2}"
	presentation_section_provision "$replicas"

	_c "$_C_YELLOW" "  ▶ terraform apply — criando/atualizando rede, banco, API e frontend…"
	info "terraform apply…"
	terraform_apply_with_recovery

	echo ""
	_c "$_C_BOLD" "  Saídas do Terraform (outputs):"
	run_tf output -no-color || true

	local project="${TF_VAR_project_name:-poc-devsecops}"
	local port="${TF_VAR_host_frontend_port:-3000}"
	local net="${TF_VAR_network_name:-app-vpc}"
	presentation_live_status "$project"
	presentation_post_apply_summary "$project" "$replicas" "$port" "$net"
	presentation_footer "$project" "$port" "$net"
}

main "$@"
