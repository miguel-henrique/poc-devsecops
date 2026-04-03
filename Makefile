SHELL := /bin/bash
.DEFAULT_GOAL := help

TF_DIR := terraform
ENV_FILE ?= .env

# Use host `terraform` if installed; otherwise run Terraform inside Docker (see scripts/terraform-docker.sh).
TF := $(shell command -v terraform 2>/dev/null)
ifeq ($(TF),)
  TF := $(CURDIR)/scripts/terraform-docker.sh
endif

# Run a command with $(ENV_FILE) sourced (so TF_VAR_* are set for Terraform).
with-env = bash -c 'set -euo pipefail; set -a; source "$(ENV_FILE)"; set +a; $(1)'

.PHONY: help dev-up demo demo-plan status inspect open load-env envcheck tf-init tf-fmt tf-validate checkov tf-plan tf-apply tf-destroy compose-up compose-down

help:
	@echo "PoC DevSecOps — common targets"
	@echo ""
	@echo "  One command (recommended):"
	@echo "    ./dev-up.sh              — checks Docker, .env, Terraform host or Docker, init + apply"
	@echo "    ./dev-up.sh --install-deps   — Ubuntu/Debian: install docker.io if missing (sudo)"
	@echo "    make dev-up ARGS='--install-deps'  — same script (optional ARGS)"
	@echo ""
	@echo "  Quick path (Make + Terraform wrapper):"
	@echo "    make demo        — create .env if missing, then init + apply (needs Docker; Terraform optional)"
	@echo "    make demo-plan   — same as demo but plan only (no changes)"
	@echo "    make status      — docker ps (project containers)"
	@echo "    make inspect     — reimprime resumo + comandos (scripts/inspect-stack.sh)"
	@echo "    make open        — print URLs to open in a browser"
	@echo ""
	@echo "  Terraform (reads $(ENV_FILE) automatically for plan/apply/destroy):"
	@echo "    make tf-init      — terraform init ($(TF_DIR))"
	@echo "    make tf-fmt       — terraform fmt -recursive"
	@echo "    make tf-validate  — init + validate"
	@echo "    make checkov      — security scan Terraform + Dockerfiles"
	@echo "    make tf-plan      — plan (requires Docker + credentials)"
	@echo "    make tf-apply     — apply stack"
	@echo "    make tf-destroy   — destroy stack"
	@echo ""
	@echo "  Without Terraform:"
	@echo "    make compose-up   — docker compose up (fallback)"
	@echo ""
	@echo "  Advanced: eval \$$(make load-env)  — print export lines to copy into your shell"

dev-up:
	@$(CURDIR)/scripts/dev-up.sh $(ARGS)

demo:
	@if [[ ! -f "$(ENV_FILE)" ]]; then \
		echo "Creating $(ENV_FILE) from .env.example (edit passwords if needed)."; \
		cp .env.example "$(ENV_FILE)"; \
	fi
	@$(call with-env,$(TF) -chdir=$(TF_DIR) init -input=false)
	@$(call with-env,$(TF) -chdir=$(TF_DIR) apply -input=false -auto-approve)
	@echo ""
	@$(MAKE) --no-print-directory open
	@$(MAKE) --no-print-directory status

demo-plan:
	@if [[ ! -f "$(ENV_FILE)" ]]; then cp .env.example "$(ENV_FILE)"; fi
	@$(call with-env,$(TF) -chdir=$(TF_DIR) init -input=false)
	@$(call with-env,$(TF) -chdir=$(TF_DIR) plan -input=false -no-color)

inspect:
	@$(CURDIR)/scripts/inspect-stack.sh

status:
	@echo "Containers matching name poc-devsecops:"
	@if docker ps --filter "name=poc-devsecops" --format "{{.Names}}" 2>/dev/null | grep -q .; then \
		docker ps --filter "name=poc-devsecops" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"; \
	else \
		echo "(none — run make demo or make compose-up first)"; \
	fi

open:
	@$(TF) -chdir=$(TF_DIR) output -no-color 2>/dev/null || { echo "No Terraform state yet — run make demo first."; exit 0; }
	@echo ""
	@echo "Visual check: open frontend_url in a browser."
	@echo "CLI quick test: curl -s http://localhost:3000/api/status   (change port if TF_VAR_host_frontend_port differs)"

load-env:
	@if [[ ! -f "$(ENV_FILE)" ]]; then echo "Missing $(ENV_FILE). Copy from .env.example"; exit 1; fi
	@grep -v '^#' "$(ENV_FILE)" | grep -v '^$$' | sed 's/^/export /'

envcheck:
	@test -n "$$TF_VAR_postgres_user" || (echo "Set TF_VAR_postgres_user (source .env)" && exit 1)
	@test -n "$$TF_VAR_postgres_password" || (echo "Set TF_VAR_postgres_password" && exit 1)

tf-init:
	$(TF) -chdir=$(TF_DIR) init

tf-fmt:
	$(TF) -chdir=$(TF_DIR) fmt -recursive

tf-validate: tf-init
	$(TF) -chdir=$(TF_DIR) validate

checkov:
	checkov -d $(TF_DIR) --framework terraform --compact && \
	checkov -d app --framework dockerfile --compact

tf-plan:
	@if [[ ! -f "$(ENV_FILE)" ]]; then echo "Missing $(ENV_FILE). Run: cp .env.example .env"; exit 1; fi
	@$(call with-env,$(TF) -chdir=$(TF_DIR) plan -input=false)

tf-apply:
	@if [[ ! -f "$(ENV_FILE)" ]]; then echo "Missing $(ENV_FILE). Run: cp .env.example .env"; exit 1; fi
	@$(call with-env,$(TF) -chdir=$(TF_DIR) apply -input=false -auto-approve)

tf-destroy:
	@if [[ ! -f "$(ENV_FILE)" ]]; then echo "Missing $(ENV_FILE). Run: cp .env.example .env"; exit 1; fi
	@$(call with-env,$(TF) -chdir=$(TF_DIR) destroy -input=false -auto-approve)

compose-up:
	docker compose --env-file $(ENV_FILE) up --build -d

compose-down:
	docker compose down -v
