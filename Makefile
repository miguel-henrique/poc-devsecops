SHELL := /bin/bash
.DEFAULT_GOAL := help

TF_DIR := terraform
ENV_FILE ?= .env

.PHONY: help envcheck tf-init tf-fmt tf-validate checkov tf-plan tf-apply tf-destroy compose-up compose-down

help:
	@echo "PoC DevSecOps — common targets"
	@echo "  make load-env     — export TF_VAR_* from $(ENV_FILE) (run: eval \$$(make load-env))"
	@echo "  make tf-init      — terraform init ($(TF_DIR))"
	@echo "  make tf-fmt       — terraform fmt -recursive"
	@echo "  make tf-validate  — init + validate"
	@echo "  make checkov      — security scan Terraform"
	@echo "  make tf-plan      — plan (requires Docker + credentials)"
	@echo "  make tf-apply     — apply stack"
	@echo "  make tf-destroy   — destroy stack"
	@echo "  make compose-up   — docker compose up (fallback without Terraform)"

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

tf-plan: envcheck tf-init
	cd $(TF_DIR) && terraform plan -input=false

tf-apply: envcheck tf-init
	cd $(TF_DIR) && terraform apply -input=false -auto-approve

tf-destroy: envcheck tf-init
	cd $(TF_DIR) && terraform destroy -input=false -auto-approve

compose-up:
	docker compose --env-file $(ENV_FILE) up --build -d

compose-down:
	docker compose down -v
