#!/usr/bin/env bash
# Logs para demo acadêmica (sourced por dev-up.sh). PT-BR.
# Relaciona: PoC AWS (VPC, SG, RDS, EKS, storage) ↔ containers locais ↔ conceitos da monografia.

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
	_c "$_C_CYAN$_C_BOLD" "  PoC DevSecOps local — IaC + Shift-left + análise estática (Checkov)"
	_c "$_C_CYAN$_C_BOLD" "══════════════════════════════════════════════════════════════════════"
	echo ""
}

presentation_research_bridge() {
	_c "$_C_BLUE$_C_BOLD" "  📚  Conceitos"
	_c "$_C_DIM" "     • Shift-left: controles de segurança antes do deploy (SAST em IaC e imagens)."
	_c "$_C_DIM" "     • IaC auditável: Terraform descreve rede, dados, compute e borda como código."
	_c "$_C_DIM" "     • Fail-fast: Checkov bloqueia o fluxo local se houver falhas (como pre-commit/CI)."
	_c "$_C_DIM" "     • Nesta PoC em containers não rodamos GitGuardian nem OPA/Rego — apenas Checkov;"
	_c "$_C_DIM" "       na PoC AWS completa essas camadas complementam a esteira."
	echo ""
	_c "$_C_BLUE$_C_BOLD" "  ☁️  Paralelo com a PoC AWS (Terraform em ambiente real)"
	_c "$_C_DIM" "     Referência de arquitetura: módulos vpc, security, iam, storage, database (RDS),"
	_c "$_C_DIM" "     cluster (EKS + workernodes). Abaixo, o que cada *container local* evoca nesse desenho."
	echo ""
	_c "$_C_DIM" "     ┌──────────────────────────┬────────────────────────────────────────────────┐"
	_c "$_C_DIM" "     │ Módulo / serviço AWS     │ Representação nesta PoC (Docker + Terraform) │"
	_c "$_C_DIM" "     ├──────────────────────────┼────────────────────────────────────────────────┤"
	_c "$_C_DIM" "     │ VPC + subnets + rotas    │ docker_network (bridge + IPAM) — rede isolada │"
	_c "$_C_DIM" "     │ Security Groups          │ Isolamento por rede Docker + privileged=false│"
	_c "$_C_DIM" "     │ RDS (PostgreSQL)         │ Container postgres + volume persistente      │"
	_c "$_C_DIM" "     │ EKS / pods / tasks       │ N réplicas FastAPI (balanceadas pelo nginx)  │"
	_c "$_C_DIM" "     │ ELB / Ingress / estático │ nginx: entrada HTTP, /api/ → pool de APIs    │"
	_c "$_C_DIM" "     │ S3 / endpoints / IAM     │ Não modelados aqui (só na PoC AWS)           │"
	_c "$_C_DIM" "     └──────────────────────────┴────────────────────────────────────────────────┘"
	echo ""
}

presentation_pipeline_stages() {
	_c "$_C_MAGENTA$_C_BOLD" "  ⚙️  Esteira local (trecho que o dev-up reproduz antes do provisionamento)"
	_c "$_C_DIM" "     Etapa A — Qualidade de IaC (no GitHub Actions também: terraform fmt/validate)"
	_c "$_C_DIM" "             Aqui: assumimos código válido; init/apply validam na prática."
	_c "$_C_DIM" "     Etapa B — SAST / conformidade (Checkov, políticas inspiradas em boas práticas CIS)"
	_c "$_C_DIM" "             Alvo 1: terraform/ (HCL, grafo de recursos, docker_container…)"
	_c "$_C_DIM" "             Alvo 2: app/**/Dockerfile (USER, HEALTHCHECK, superfície de ataque)"
	_c "$_C_DIM" "     Etapa C — Provisionamento (terraform apply → Docker cria rede, volumes, containers)"
	_c "$_C_DIM" "             Equivalente conceitual a aplicar um plano na conta AWS."
	echo ""
}

presentation_section_static_analysis() {
	echo ""
	_c "$_C_MAGENTA$_C_BOLD" "┌─────────────────────────────────────────────────────────────────────┐"
	_c "$_C_MAGENTA$_C_BOLD" "│  🔒  Etapa B — Análise estática (Checkov) = gate antes do deploy    │"
	_c "$_C_MAGENTA$_C_BOLD" "└─────────────────────────────────────────────────────────────────────┘"
	_c "$_C_DIM" "     Objetivo: detectar configurações inseguras *antes* de materializar infraestrutura."
	_c "$_C_DIM" "     • Terraform: políticas sobre recursos declarativos (ex.: privilégio excessivo)."
	_c "$_C_DIM" "     • Dockerfiles: baseline de endurecimento de imagem (não-root, HEALTHCHECK)."
	echo ""
}

presentation_note_ci() {
	_c "$_C_BLUE" "  🔄  Pipeline completo no GitHub Actions (.github/workflows/pipeline.yml)"
	_c "$_C_DIM" "      checkout → setup Terraform → fmt -check → init → validate → Checkov (×2) → plan"
	_c "$_C_DIM" "      O que você vê *abaixo* é a mesma família de verificação Checkov do CI, em modo local."
	echo ""
}

presentation_section_provision() {
	local replicas="${1:-2}"
	echo ""
	_c "$_C_GREEN$_C_BOLD" "┌─────────────────────────────────────────────────────────────────────┐"
	_c "$_C_GREEN$_C_BOLD" "│  ☁️  Etapa C — Provisionamento declarativo (Terraform → Docker)      │"
	_c "$_C_GREEN$_C_BOLD" "└─────────────────────────────────────────────────────────────────────┘"
	_c "$_C_DIM" "     Ordem dos módulos (como na PoC AWS: rede → dados → compute → borda):"
	_c "$_C_DIM" "     1. network   → analogia VPC (rede isolada + serviços anexos)"
	_c "$_C_DIM" "     2. database  → analogia RDS PostgreSQL em subnets privadas"
	_c "$_C_DIM" "     3. backend   → analogia workloads no EKS (N réplicas = N tasks/pods)"
	_c "$_C_DIM" "     4. frontend  → analogia ALB/Ingress + conteúdo estático"
	echo ""
}

presentation_skip_checkov() {
	_c "$_C_YELLOW" "  ⏭️  Checkov ignorado (--skip-checkov / CHECKOV=0). Sem esta etapa não há simulação"
	_c "$_C_YELLOW" "     completa do gate SAST da monografia. Para ensaios rápidos apenas."
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
		# --skip-download + BC_SKIP_MAPPING: evita chamadas HTTPS a api0.prismacloud.io (falham em redes corporativas / WSL com inspeção TLS).
		docker run --rm \
			-e BC_SKIP_MAPPING=TRUE \
			-v "${repo_root}:/workspace:ro" \
			bridgecrew/checkov:latest \
			--skip-download \
			-d /workspace/terraform --framework terraform --compact
		local ec1=$?
		docker run --rm \
			-e BC_SKIP_MAPPING=TRUE \
			-v "${repo_root}:/workspace:ro" \
			bridgecrew/checkov:latest \
			--skip-download \
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
		export BC_SKIP_MAPPING=TRUE
		checkov --skip-download -d terraform --framework terraform --compact &&
			checkov --skip-download -d app --framework dockerfile --compact
	)
}

presentation_checkov_ok() {
	echo ""
	_c "$_C_GREEN$_C_BOLD" "  ✅ Gate Checkov: passou nos alvos Terraform + Dockerfiles (fail-fast satisfeito)."
	_c "$_C_DIM" "     Prosseguindo para materializar os “serviços AWS simulados” como containers."
	echo ""
}

presentation_checkov_hint_install() {
	_c "$_C_DIM" "     Dica: pip install checkov   ou   Docker puxará bridgecrew/checkov automaticamente."
	echo ""
}

presentation_live_status() {
	echo ""
	_c "$_C_BOLD" "  📦  Containers em execução (estado atual do “landing zone” local)"
	docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E 'NAMES|EKS-FASTAPI|ELB-NGINX|RDS-POSTGRES' || _c "$_C_DIM" "    (nenhum container relevante encontrado)"
	echo ""
}

presentation_post_apply_summary() {
       local replicas="${2:-2}"
       local port="${3:-3000}"
       echo ""
       _c "$_C_GREEN$_C_BOLD" "══════════════════════════════════════════════════════════════════════"
       _c "$_C_GREEN$_C_BOLD" "  🗺️  O que foi provisionado e o que cada peça representa (AWS + monografia)"
       _c "$_C_GREEN$_C_BOLD" "══════════════════════════════════════════════════════════════════════"
       echo ""
       _c "$_C_BOLD" "  Rede"
       _c "$_C_DIM" "    Recurso Terraform: docker_network → nome VPC-DOCKERNETWORK"
       _c "$_C_DIM" "    Conceito AWS: VPC + anexo dos workloads (sub-redes reais colapsadas em um bridge)."
       _c "$_C_DIM" "    Conceito acadêmico: segmentação / superfície de ataque reduzida."
       echo ""
       _c "$_C_BOLD" "  Dados"
       _c "$_C_DIM" "    Container: RDS-POSTGRES  →  analogia Amazon RDS (PostgreSQL), dados em volume."
       _c "$_C_DIM" "    Conceito acadêmico: persistência gerenciada; credenciais via variáveis (não em Git)."
       echo ""
       _c "$_C_BOLD" "  Compute (réplicas da API)"
       local i
       for ((i = 1; i <= replicas; i++)); do
	       local idx=$(printf "%02d" "$i")
	       _c "$_C_DIM" "    Container: EKS-FASTAPI-${idx}  →  analogia pods/tasks no EKS ou serviços ECS."
       done
       _c "$_C_DIM" "    Conceito acadêmico: disponibilidade horizontal; cada réplica atende /health e /api/."
       echo ""
       _c "$_C_BOLD" "  Borda / apresentação"
       _c "$_C_DIM" "    Container: ELB-NGINX  →  analogia ALB + Ingress + origem estática (S3/CloudFront simpl.)."
       _c "$_C_DIM" "    Porta publicada: localhost:${port} → único ponto de entrada HTTP para a demo."
       _c "$_C_DIM" "    Tráfego: navegador → nginx → upstream pool → uma das réplicas FastAPI → RDS (db)."
       echo ""
}

presentation_footer() {
	local port="${2:-3000}"
	echo ""
	_c "$_C_CYAN$_C_BOLD" "══════════════════════════════════════════════════════════════════════"
	_c "$_C_CYAN$_C_BOLD" "  📋  Operação (Comandos para inspeção manual"
	_c "$_C_CYAN$_C_BOLD" "══════════════════════════════════════════════════════════════════════"
	echo ""
	_c "$_C_BOLD" "  Encerrar tudo e reprovisionar depois"
	_c "$_C_DIM" "    ./dev-down.sh          ou   ./dev-up.sh --destroy   ou   make dev-down"
	_c "$_C_DIM" "    Depois: ./dev-up.sh    (recria rede, volumes, containers do zero)"
	echo ""
	_c "$_C_BOLD" "  Serviços em execução"
	_c "$_C_DIM" "    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
	echo ""
	_c "$_C_BOLD" "  Rede (VPC local)"
	_c "$_C_DIM" "    docker network inspect VPC-DOCKERNETWORK --format '{{json .Name}} {{json .IPAM.Config}}'"
	_c "$_C_DIM" "    docker network ls | grep -E 'VPC-DOCKERNETWORK|NAME'"
	echo ""
	_c "$_C_BOLD" "  Um container em detalhe"
	_c "$_C_DIM" "    docker inspect ELB-NGINX --format '{{.Name}} → {{.State.Status}} → {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'"
	_c "$_C_DIM" "    docker inspect RDS-POSTGRES --format '{{.Name}} health: {{.State.Health.Status}}'"
	_c "$_C_DIM" "    docker inspect EKS-FASTAPI-01 --format '{{.Name}} → {{.State.Status}} → {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'"
	echo ""
	_c "$_C_BOLD" "  Terraform"
	_c "$_C_DIM" "    terraform -chdir=terraform output"
	_c "$_C_DIM" "    curl -s http://localhost:${port}/api/status | jq .   # se tiver jq"
	echo ""
	_c "$_C_BOLD" "  CI no GitHub (não roda no dev-up)"
	_c "$_C_DIM" "    cat .github/workflows/pipeline.yml"
	echo ""
	_c "$_C_BOLD" "  Experimentos com Checkov (quebrar de propósito)"
	_c "$_C_DIM" "    Ver: docs/GUIA-EXPERIMENTOS-CHECKOV.md"
	echo ""
	_c "$_C_GREEN" "  🌐 Frontend:  http://localhost:${port}"
	_c "$_C_GREEN" "  🔌 API teste:  curl -s http://localhost:${port}/api/status"
	echo ""
}
