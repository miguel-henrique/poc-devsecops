SHELL := /bin/bash
.DEFAULT_GOAL := help

TF_DIR := terraform
ENV_FILE ?= .env

# Run a command with $(ENV_FILE) sourced (so TF_VAR_* are set for Terraform).
with-env = bash -c 'set -euo pipefail; set -a; source "$(ENV_FILE)"; set +a; $(1)'

.PHONY: help demo demo-plan status open load-env envcheck tf-init tf-fmt tf-validate checkov tf-plan tf-apply tf-destroy compose-up compose-down

help:
	@echo "PoC DevSecOps — common targets"
	@echo ""
	@echo "  Quick path (present / try the PoC):"
	@echo "    make demo        — create .env if missing, then init + apply (needs Docker + terraform)"
	@echo "    make demo-plan   — same as demo but plan only (no changes)"
	@echo "    make status      — docker ps (project containers)"
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

demo:
	@if [[ ! -f "$(ENV_FILE)" ]]; then \
		echo "Creating $(ENV_FILE) from .env.example (edit passwords if needed)."; \
		cp .env.example "$(ENV_FILE)"; \
	fi
	@$(call with-env,cd $(TF_DIR) && terraform init -input=false)
	@$(call with-env,cd $(TF_DIR) && terraform apply -input=false -auto-approve)
	@echo ""
	@$(MAKE) --no-print-directory open
	@$(MAKE) --no-print-directory status

demo-plan:
	@if [[ ! -f "$(ENV_FILE)" ]]; then cp .env.example "$(ENV_FILE)"; fi
	@$(call with-env,cd $(TF_DIR) && terraform init -input=false)
	@$(call with-env,cd $(TF_DIR) && terraform plan -input=false -no-color)

status:
	@echo "Containers matching name poc-devsecops:"
	@if docker ps --filter "name=poc-devsecops" --format "{{.Names}}" 2>/dev/null | grep -q .; then \
		docker ps --filter "name=poc-devsecops" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"; \
	else \
		echo "(none — run make demo or make compose-up first)"; \
	fi

open:
	@cd $(TF_DIR) && terraform output -no-color 2>/dev/null || { echo "No Terraform state yet — run make demo first."; exit 0; }
	@echo ""
	@echo "Visual check: open frontend_url in a browser."
	@echo 'CLI example: curl -s $$(terraform -chdir=$(TF_DIR) output -raw api_proxy_path)status'

load-env:
	@if [[ ! -f "$(ENV_FILE)" ]]; then echo "Missing $(ENV_FILE). Copy from .env.example"; exit 1; fi
	@grep -v '^#' "$(ENV_FILE)" | grep -v '^$$' | sed 's/^/export /'

envcheck:
	@test -n "$$TF_VAR_postgres_user" || (echo "Set TF_VAR_postgres_user (source .env)" && exit 1)
	@test -n "$$TF_VAR_postgres_password" || (echo "Set TF_VAR_postgres_password" && exit 1)

tf-init:
	cd $(TF_DIR) && terraform init

tf-fmt:
	cd $(TF_DIR) && terraform fmt -recursive

tf-validate: tf-init
	cd $(TF_DIR) && terraform validate

checkov:
	checkov -d $(TF_DIR) --framework terraform --compact && \
	checkov -d app --framework dockerfile --compact

tf-plan:
	@if [[ ! -f "$(ENV_FILE)" ]]; then echo "Missing $(ENV_FILE). Run: cp .env.example .env"; exit 1; fi
	@$(call with-env,cd $(TF_DIR) && terraform plan -input=false)

tf-apply:
	@if [[ ! -f "$(ENV_FILE)" ]]; then echo "Missing $(ENV_FILE). Run: cp .env.example .env"; exit 1; fi
	@$(call with-env,cd $(TF_DIR) && terraform apply -input=false -auto-approve)

tf-destroy:
	@if [[ ! -f "$(ENV_FILE)" ]]; then echo "Missing $(ENV_FILE). Run: cp .env.example .env"; exit 1; fi
	@$(call with-env,cd $(TF_DIR) && terraform destroy -input=false -auto-approve)

compose-up:
	docker compose --env-file $(ENV_FILE) up --build -d

compose-down:
	docker compose down -v
