# PoC DevSecOps — Local “Cloud” on Docker + Terraform + Checkov

This repository is a **local proof of concept** that mirrors an AWS-style provisioning flow using **Terraform**, **Docker**, **Checkov**, and **GitHub Actions**. There is **no cloud provider**: containers stand in for compute, a user-defined Docker network stands in for a VPC, and PostgreSQL runs as a managed-style data tier.

## Architecture

| Concern | Real cloud analogue | This PoC |
|--------|---------------------|----------|
| Network isolation | VPC + subnets | `docker_network` with a dedicated bridge and `/16` IPAM |
| Data tier | RDS | `postgres:16-alpine` with a named volume |
| App tier | Auto Scaling / ECS tasks | Multiple `docker_container` API replicas (`backend_replica_count`) |
| Edge / UI | ALB + static site | `nginx` (unprivileged) reverse proxy + static assets |
| Secrets | Parameter Store / Secrets Manager | Environment variables (`TF_VAR_*` / `.env`), never committed |

**Traffic flow:** Browser → `localhost:3000` (configurable) → nginx → upstream pool of FastAPI replicas → PostgreSQL on the private network.

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────────────────┐
│   Browser   │────▶│  nginx (frontend) │────▶│  FastAPI × N (backend pool)  │
└─────────────┘     └──────────────────┘     └──────────────┬──────────────┘
                                                            │
                                                            ▼
                                               ┌────────────────────────┐
                                               │ PostgreSQL (database)  │
                                               └────────────────────────┘
         All containers attach to one Docker network (simulated VPC).
```

## Repository layout

- `terraform/` — Root module and reusable modules (`network`, `database`, `backend`, `frontend`).
- `app/backend/` — FastAPI service (`/health`, `/api/status`).
- `app/frontend/` — Static UI + nginx configs (Terraform renders upstream list for load spreading).
- `.github/workflows/pipeline.yml` — CI: `fmt`, `init`, `validate`, Checkov, `plan`.
- `docker-compose.yml` — Optional stack without Terraform (single API replica).
- `Makefile` — Convenience targets for local workflows.

## Prerequisites

- Docker Engine (daemon reachable at `/var/run/docker.sock` by default).
- Terraform `>= 1.5` (or run it via a container — see below).
- Python 3 + `pip` **or** the `bridgecrew/checkov` container for scans.

## Configuration

1. Copy `.env.example` to `.env` and set strong values for database credentials.
2. Export variables for Terraform (the Makefile documents the pattern):

   ```bash
   set -a && source .env && set +a
   ```

   Required for apply/plan: `TF_VAR_postgres_user`, `TF_VAR_postgres_password`.

3. Optional: copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` for non-env configuration (keep `terraform.tfvars` out of Git).

## Run locally (Terraform)

From the repository root, with Docker running and env vars loaded:

```bash
make tf-init
make tf-plan    # or: terraform -chdir=terraform plan
make tf-apply   # creates network, DB volume, images, containers
```

Open the UI from Terraform outputs, e.g. `http://localhost:3000` (default `host_frontend_port`).

**Scaling:** `TF_VAR_backend_replica_count` (1–5) controls how many API containers are created; nginx load-balances across their names on the Docker network.

### Terraform via container (optional)

If Terraform is not installed on the host, you can run commands with the official image. Mount the **whole repository** so paths like `${path.root}/../app/backend` resolve:

```bash
docker run --rm -u "$(id -u):$(id -g)" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$(pwd)":/project -w /project/terraform \
  hashicorp/terraform:1.9.0 plan -input=false
```

## Run locally (Docker Compose fallback)

For a quick path without Terraform:

```bash
cp .env.example .env
docker compose --env-file .env up --build -d
```

Compose uses `app/frontend/nginx.compose.conf` (single upstream) and publishes `HOST_FRONTEND_PORT` → container `8080`.

## CI/CD (GitHub Actions)

Workflow: `.github/workflows/pipeline.yml`

1. Checkout repository.
2. Install Checkov (`pip`).
3. Install Terraform (`hashicorp/setup-terraform`).
4. `terraform fmt -check -recursive` inside `terraform/`.
5. `terraform init` / `terraform validate`.
6. **Checkov** — two passes:
   - `terraform/` with `--framework terraform` (static HCL / graph checks).
   - `app/` with `--framework dockerfile` (image hygiene: non-root, `HEALTHCHECK`, etc.).
7. `terraform plan` (requires Docker on the runner; the default `ubuntu-latest` image can talk to the local Docker daemon).

The job is configured to **fail** if Checkov reports failed checks (no soft-fail).

## Security scanning with Checkov

- **Terraform:** `checkov -d terraform --framework terraform` scans `.tf` files (provider-agnostic checks). Many policies target AWS/Azure/GCP; this PoC still benefits from general graph and metadata checks. For Docker-specific runtime settings, rely on explicit `privileged = false` in the stacks and on Dockerfile policies.
- **Dockerfiles:** `checkov -d app --framework dockerfile` enforces baseline image hygiene (examples: `CKV_DOCKER_2` HEALTHCHECK, `CKV_DOCKER_3` non-root `USER`).

### Intentional misconfiguration (lesson) and fix

During development, two common findings surfaced and were **fixed** in tree:

1. **Dockerfile (`CKV_DOCKER_2`, `CKV_DOCKER_3`):** Missing `HEALTHCHECK` and missing explicit non-root `USER` caused failures. Fixed by adding `HEALTHCHECK`, `USER appuser` (backend), and `nginxinc/nginx-unprivileged` + `USER nginx` (frontend) so nginx can bind port `8080` without root.
2. **Terraform (`docker_container.privileged`):** Setting `privileged = true` would grant excessive host capabilities and is flagged by security reviews. This stack sets `privileged = false` everywhere.

To see Checkov fail locally, temporarily remove `USER` or `HEALTHCHECK` from a Dockerfile and run `make checkov`.

## How Terraform maps to “AWS-like” concepts

- **Regions / accounts** are not modeled; instead, `project_name` prefixes resource names.
- **VPC** → `docker_network` with labels (`simulates = aws-vpc`).
- **RDS** → `docker_container` + `docker_volume` for PostgreSQL data.
- **ECS / ASG** → `count` on `docker_container` for API replicas.
- **ALB** → nginx upstream over multiple backend hostnames.

No AWS APIs or credentials are used.

## Outputs

After `terraform apply`, inspect:

```bash
terraform -chdir=terraform output
```

You should see `frontend_url`, `api_proxy_path`, `backend_container_names`, and `database_host`.

## Makefile targets

| Target | Purpose |
|--------|---------|
| `make load-env` | Prints `export ...` lines from `.env` (run with `eval "$(make load-env)"`). |
| `make tf-init` | `terraform init` |
| `make tf-validate` | init + `validate` |
| `make checkov` | Terraform + Dockerfile scans |
| `make tf-plan` / `make tf-apply` / `make tf-destroy` | Full lifecycle (needs env + Docker) |
| `make compose-up` / `make compose-down` | Docker Compose fallback |

## Git

Initialize a local repository when you are ready:

```bash
git init
git add .
git commit -m "Add local DevSecOps PoC with Terraform, Docker, and Checkov"
```

Track `terraform/.terraform.lock.hcl` for reproducible provider versions; do **not** commit `.terraform/`, `.env`, or `terraform.tfvars` with secrets.
