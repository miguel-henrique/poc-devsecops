#!/usr/bin/env bash
# Pretty presentation logs for dev-up.sh (sourced, not executed directly).
# Portuguese (BR) labels for demos acadêmicas — adjust TERM=dumb or non-tty disables colors.

presentation_init() {
	PRESENTATION_USE_COLOR=0
	if [[ -n "${FORCE_COLOR:-}" ]] || { [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]; }; then
		PRESENTATION_USE_COLOR=1
	fi
	# shellcheck disable=SC2034
	_C_RESET=$'\033[0m'
	_C_DIM=$'\033[2m'
	_C_BOLD=$'\033[1m'
	_C_CYAN=$'\033[0;36m'
	_C_GREEN=$'\033[0;32m'
	_C_YELLOW=$'\033[0;33m'
	_C_MAGENTA=$'\033[0;35m'
	_C_BLUE=$'\033[0;34m'
}

_c() {
	local code="$1"
	shift
	if [[ "$PRESENTATION_USE_COLOR" -eq 1 ]]; then
		printf '%b%s%b\n' "$code" "$*" "$_C_RESET"
	else
		printf '%s\n' "$*"
	fi
}

presentation_banner() {
	_c "$_C_CYAN$_C_BOLD" "══════════════════════════════════════════════════════════════════════"
	_c "$_C_CYAN$_C_BOLD" "  PoC DevSecOps — ambiente local (IaC + análise estática + containers)"
	_c "$_C_CYAN$_C_BOLD" "══════════════════════════════════════════════════════════════════════"
	echo ""
}

presentation_section_static_analysis() {
	echo ""
	_c "$_C_MAGENTA$_C_BOLD" "┌─────────────────────────────────────────────────────────────────────┐"
	_c "$_C_MAGENTA$_C_BOLD" "│  🔒  Análise estática de infraestrutura e imagens (Checkov)        │"
	_c "$_C_MAGENTA$_C_BOLD" "└─────────────────────────────────────────────────────────────────────┘"
	_c "$_C_DIM" "     • Terraform (HCL): políticas em grafo, boas práticas declarativas"
	_c "$_C_DIM" "     • Dockerfiles: usuário não-root, HEALTHCHECK, higiene de build"
	echo ""
}

presentation_note_ci() {
	_c "$_C_BLUE" "  🔄  Pipeline de CI (GitHub Actions)"
	_c "$_C_DIM" "      No repositório, .github/workflows/pipeline.yml executa em cada push:"
	_c "$_C_DIM" "      terraform fmt, init, validate → Checkov (Terraform + Dockerfiles) → terraform plan"
	_c "$_C_DIM" "      Abaixo: mesma verificação Checkov que o CI roda no GitHub (reprodução local)."
	echo ""
}

presentation_section_provision() {
	local replicas="${1:-2}"
	echo ""
	_c "$_C_GREEN$_C_BOLD" "┌─────────────────────────────────────────────────────────────────────┐"
	_c "$_C_GREEN$_C_BOLD" "│  ☁️   Provisionamento declarativo (Terraform → Docker)               │"
	_c "$_C_GREEN$_C_BOLD" "└─────────────────────────────────────────────────────────────────────┘"
	_c "$_C_DIM" "     Analogia com nuvem: rede (VPC) → dados (RDS) → compute (réplicas) → borda (nginx)"
	_c "$_C_DIM" "     • Rede isolada          → docker_network (bridge + IPAM)"
	_c "$_C_DIM" "     • Banco gerenciado      → PostgreSQL + volume persistente"
	_c "$_C_DIM" "     • Camada de aplicação   → FastAPI × ${replicas} (balanceado pelo nginx)"
	_c "$_C_DIM" "     • Entrada HTTP          → nginx (proxy / + /api/)"
	echo ""
}

presentation_skip_checkov() {
	_c "$_C_YELLOW" "  ⏭️  Checkov ignorado (--skip-checkov). Para demonstrar análise estática, rode sem essa opção."
	echo ""
}

run_checkov_scan() {
	local repo_root="$1"
	local use_docker="${2:-0}"

	if [[ "$use_docker" -eq 1 ]]; then
		_c "$_C_CYAN" "  → Executando Checkov via imagem Docker (bridgecrew/checkov)…"
		docker image inspect bridgecrew/checkov:latest >/dev/null 2>&1 || {
			_c "$_C_DIM" "     (puxando imagem na primeira execução — pode levar um minuto)"
			docker pull bridgecrew/checkov:latest
		}
		# Entrypoint do container já é checkov
		docker run --rm \
			-v "${repo_root}:/workspace:ro" \
			bridgecrew/checkov:latest \
			-d /workspace/terraform --framework terraform --compact
		local ec1=$?
		docker run --rm \
			-v "${repo_root}:/workspace:ro" \
			bridgecrew/checkov:latest \
			-d /workspace/app --framework dockerfile --compact
		local ec2=$?
		if [[ $ec1 -ne 0 || $ec2 -ne 0 ]]; then
			return 1
		fi
		return 0
	fi

	_c "$_C_CYAN" "  → Executando Checkov no host…"
	(
		cd "$repo_root" || exit 1
		checkov -d terraform --framework terraform --compact &&
			checkov -d app --framework dockerfile --compact
	)
}

presentation_checkov_ok() {
	echo ""
	_c "$_C_GREEN$_C_BOLD" "  ✅ Checkov: nenhuma falha bloqueante nos alvos configurados (Terraform + Dockerfiles)."
	echo ""
}

presentation_checkov_hint_install() {
	_c "$_C_DIM" "     Dica: pip install checkov   ou   use Docker (este script tenta Docker se não houver checkov)."
	echo ""
}

presentation_live_status() {
	local project="${1:-poc-devsecops}"
	echo ""
	_c "$_C_BOLD" "  📦  Containers em execução"
	docker ps --filter "name=${project}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || _c "$_C_DIM" "    (nenhum container encontrado com esse filtro)"
	echo ""
}

presentation_footer() {
	local project="${1:-poc-devsecops}"
	local port="${2:-3000}"
	local net_suffix="${3:-app-vpc}"
	local full_net="${project}-${net_suffix}"
	echo ""
	_c "$_C_CYAN$_C_BOLD" "══════════════════════════════════════════════════════════════════════"
	_c "$_C_CYAN$_C_BOLD" "  📋  Comandos úteis para inspeção do ambiente"
	_c "$_C_CYAN$_C_BOLD" "══════════════════════════════════════════════════════════════════════"
	echo ""
	_c "$_C_BOLD" "  Serviços em execução (containers do projeto)"
	_c "$_C_DIM" "    docker ps --filter \"name=${project}\" --format \"table {{.Names}}\\t{{.Status}}\\t{{.Ports}}\""
	echo ""
	_c "$_C_BOLD" "  Rede análoga à VPC"
	_c "$_C_DIM" "    docker network inspect ${full_net} --format '{{json .Name}} {{json .IPAM.Config}}'"
	_c "$_C_DIM" "    docker network ls | grep -E \"${project}|NAME\""
	echo ""
	_c "$_C_BOLD" "  Detalhes de um serviço (substitua o nome)"
	_c "$_C_DIM" "    docker inspect ${project}-web --format '{{.Name}} → {{.State.Status}} → {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'"
	_c "$_C_DIM" "    docker inspect ${project}-db --format '{{.Name}} health: {{.State.Health.Status}}'"
	echo ""
	_c "$_C_BOLD" "  Saídas do Terraform (URLs, hosts)"
	_c "$_C_DIM" "    terraform -chdir=terraform output"
	_c "$_C_DIM" "    curl -s http://localhost:${port}/api/status | jq .   # se tiver jq"
	echo ""
	_c "$_C_BOLD" "  Pipeline CI (não executa localmente no dev-up — apenas no GitHub)"
	_c "$_C_DIM" "    cat .github/workflows/pipeline.yml"
	_c "$_C_DIM" "    # jobs: checkout → setup terraform → fmt/validate → checkov → plan"
	echo ""
	_c "$_C_GREEN" "  🌐 Frontend:  http://localhost:${port}"
	_c "$_C_GREEN" "  🔌 API teste:  curl -s http://localhost:${port}/api/status"
	echo ""
}
