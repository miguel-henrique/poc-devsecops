# PoC DevSecOps — Local “Cloud” on Docker + Terraform + Checkov

**Language:** English (this file) · [Português (Brasil)](README.pt-BR.md)

This repository is a **local proof of concept** that mirrors an AWS-style provisioning flow using **Terraform**, **Docker**, **Checkov**, and **GitHub Actions**. There is **no cloud provider**: containers stand in for compute, a user-defined Docker network stands in for a VPC, and PostgreSQL runs as a managed-style data tier.

## Quick start (see it working)

**Single command (recommended):** from the **repository root**:

```bash
./dev-up.sh
```

This script checks **Docker**, creates **`.env`** from `.env.example` if needed, prefers **Terraform on your PATH** if it works, otherwise runs **Terraform in Docker** (and if host `terraform init` fails, it retries with Docker). **Before `apply`**, it runs **Checkov** on `terraform/` and `app/` (uses the `checkov` binary if installed, otherwise the `bridgecrew/checkov` image). The output is formatted for demos: sections for static analysis, a short note mirroring the GitHub Actions pipeline, then Terraform provisioning, then a live `docker ps` plus copy-paste inspection commands. Use **`./dev-up.sh --skip-checkov`** to skip the scan (faster iteration). After a successful run, **`make inspect`** reprints the inspection block without Terraform.

Set **`CHECKOV=0`** in the environment for the same effect as `--skip-checkov`.

**Tear down:** `./dev-down.sh` or `make dev-down` (runs `terraform destroy`). Then `./dev-up.sh` to reprovision.

**Academic mapping & Checkov experiments:** [docs/MAPEAMENTO-AWS-E-MONOGRAFIA.md](docs/MAPEAMENTO-AWS-E-MONOGRAFIA.md), [docs/GUIA-EXPERIMENTOS-CHECKOV.md](docs/GUIA-EXPERIMENTOS-CHECKOV.md).

If Docker is not installed (Ubuntu/Debian only):

```bash
./dev-up.sh --install-deps
```

To also install the **`terraform`** APT package from HashiCorp:

```bash
./dev-up.sh --install-deps --with-terraform-apt
```

Non-interactive installs (for scripts): `./dev-up.sh --yes --install-deps`

Other entry points: `make dev-up` (same as `./dev-up.sh`), `make demo`, `./scripts/dev-up.sh`.

---

**Manual steps (equivalent to the old flow):**

1. **Start Docker** (Docker Engine running on your machine).
2. **Terraform:** optional — leave it out and the Makefile / `dev-up.sh` will use Docker for Terraform when the binary is missing.
3. Run `make demo` or `make tf-init` then `make tf-apply`.

4. **Visualize:**
   - **Browser:** open `http://localhost:3000` (or the `frontend_url` printed by `make open`).
   - **Containers:** `make status` or `docker ps --filter name=poc-devsecops`.
   - **API:** `curl -s http://localhost:3000/api/status` (JSON with DB + replica info).

5. **Stop / remove:** `make tf-destroy` (Terraform-managed stack) or `make compose-down` (Compose stack).

**Even simpler (no Terraform):** `cp .env.example .env`, edit passwords if you like, then `make compose-up` and open `http://localhost:3000`.

**Credentials:** put database user/password in `.env` as `TF_VAR_postgres_user` and `TF_VAR_postgres_password` (and matching `POSTGRES_*` for Compose). The Makefile loads `.env` for you — you do **not** need to run `source .env` by hand for `make demo`, `make tf-plan`, or `make tf-apply`.

**Why “full repo on disk”?** Terraform builds images using paths like `../app/backend` relative to the `terraform/` folder. You only need that detail if you run Terraform **inside a container**; then you mount the whole project (see end of README). A normal `make demo` from a normal clone is enough.

## Architecture

| Concern | Real cloud analogue | This PoC |
|--------|---------------------|----------|
| Network isolation | VPC + subnets | `docker_network` with a dedicated bridge and `/16` IPAM |
| Data tier | RDS | `postgres:16-alpine` with a named volume |
| App tier | Auto Scaling / ECS tasks | Multiple `docker_container` API replicas (`backend_replica_count`) |
| Edge / UI | ALB + static site | `nginx` (unprivileged) reverse proxy + static assets |
| Secrets | Parameter Store / Secrets Manager | Environment variables (`TF_VAR_*` / `.env`), never committed |

**Traffic flow:** Browser → `localhost:3000` (configurable) → ELB-NGINX → upstream pool of EKS-FASTAPI-XX (FastAPI replicas) → RDS-POSTGRES on the VPC-DOCKERNETWORK network.

```
┌─────────────┐     ┌────────────────────┐     ┌────────────────────────────────┐
│   Browser   │────▶│  ELB-NGINX         │────▶│  EKS-FASTAPI-XX × N (FastAPI)  │
└─────────────┘     └────────────────────┘     └──────────────┬────────────────┘
                                                            │
                                                            ▼
                                               ┌────────────────────────────┐
                                               │ RDS-POSTGRES               │
                                               └────────────────────────────┘
         All containers attach to one Docker network (VPC-DOCKERNETWORK, simulating a VPC).
```

## Repository layout

- `terraform/` — Root module and reusable modules (`network`, `database`, `backend`, `frontend`).
- `app/backend/` — FastAPI service (`/health`, `/api/status`).
- `app/frontend/` — Static UI + nginx configs (Terraform renders upstream list for load spreading).
- `.github/workflows/pipeline.yml` — CI: `fmt`, `init`, `validate`, Checkov, `plan`.
   - `docker-compose.yml` — Optional stack without Terraform (nomes: RDS-POSTGRES, EKS-FASTAPI-01, ELB-NGINX, VPC-DOCKERNETWORK).
- `Makefile` — Convenience targets for local workflows.
- `dev-up.sh` / `scripts/dev-up.sh` — One-shot bootstrap: checks deps, host Terraform or Docker, init + apply.
- `scripts/terraform-docker.sh` — Runs Terraform in Docker when `terraform` is not installed; forwards `TF_VAR_*` and adds `--group-add` for the Docker socket GID so the container can use `/var/run/docker.sock`.

- **Docker Engine** — daemon reachable at `/var/run/docker.sock` (default on Linux).

---

**Container naming convention (AWS mapping):**

- `RDS-POSTGRES`: PostgreSQL database (simulates AWS RDS)
- `EKS-FASTAPI-XX`: Backend FastAPI replicas (simulates EKS nodes, XX = 01, 02, ...)
- `ELB-NGINX`: Frontend nginx (simulates Elastic Load Balancer)
- `VPC-DOCKERNETWORK`: Docker network (simulates a VPC)
- **Terraform `>= 1.5`** — optional for this repo: if `terraform` is **not** on your `PATH`, `make` runs [`scripts/terraform-docker.sh`](scripts/terraform-docker.sh) (official `hashicorp/terraform` image with your repo mounted). You still need Docker for that.
- Python 3 + `pip` **or** the `bridgecrew/checkov` container for scans (only if you run Checkov locally).

### Start Docker (Linux)

Check:

```bash
docker version
```

If that fails with permission errors, your user may need the `docker` group (log out/in after):

```bash
sudo usermod -aG docker "$USER"
```

If the daemon is stopped:

```bash
sudo systemctl start docker
sudo systemctl enable docker   # optional: start on boot
```

### “Permission denied” on `/var/run/docker.sock` during `apply` (Terraform in Docker)

The Terraform container runs as your user id. The socket is usually `root:docker` with mode `660`, so the wrapper passes **`--group-add` with the socket’s group id** from the host. After updating `scripts/terraform-docker.sh`, run `./dev-up.sh` again.

If it still fails: ensure the host user can run `docker ps` (add to the `docker` group, then **log out and back in**), and that nothing overrides `DOCKER_HOST` to a non-default socket without updating the wrapper.

### Install Terraform on your PATH (optional)

Ubuntu’s default archives **do not** include Terraform. If you run `sudo apt install terraform` **without** adding HashiCorp’s repository first, you get **`E: Unable to locate package terraform`**. You must add the repo, then install.

**Option A — HashiCorp APT (Debian / Ubuntu), run the whole block in order:**

```bash
sudo apt install -y wget gnupg software-properties-common

wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt install -y terraform
terraform version
```

**Option B — Snap (no APT repo):**

```bash
sudo snap install terraform
```

**Option C — Skip installing Terraform** and use this repo’s Docker wrapper only: run **`make demo`** / **`make tf-init`** from the project root. The Makefile uses `scripts/terraform-docker.sh` when `terraform` is not on your `PATH` (Docker must be running; `TF_VAR_*` from `.env` are passed into the container).

## Configuration

1. Copy `.env.example` to `.env` (or rely on `make demo` to create it) and set **`TF_VAR_postgres_user`** and **`TF_VAR_postgres_password`** (and matching **`POSTGRES_*`** keys for Docker Compose).
2. **You do not need to `source .env` manually** for `make demo`, `make tf-plan`, `make tf-apply`, or `make tf-destroy` — the Makefile loads `.env` for those targets.
3. Optional: copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` for extra variables (keep secrets out of Git).

## Run locally (Terraform)

From the repository root, with Docker running:

```bash
make demo
```

Or step by step:

```bash
make tf-init
make tf-plan
make tf-apply
```

Then `make open` for URLs/outputs, or open `http://localhost:3000` by default.

**Scaling:** `TF_VAR_backend_replica_count` (1–5) controls how many API containers are created; nginx load-balances across their names on the Docker network.

### Terraform via container (optional)

If you are not using `make`, the same wrapper the Makefile uses is:

```bash
./scripts/terraform-docker.sh -chdir=terraform plan -input=false
```

Run that from the **repository root** so the project mounts correctly.

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
| `make dev-down` | Same as `./dev-down.sh` (`terraform destroy`) |
| `make tf-plan` / `make tf-apply` / `make tf-destroy` | Full lifecycle (needs env + Docker) |
| `make compose-up` / `make compose-down` | Docker Compose fallback |

## Academic docs (Portuguese)

- [`docs/APRESENTACAO-PESQUISA.md`](docs/APRESENTACAO-PESQUISA.md) — presentation narrative  
- [`docs/MAPEAMENTO-AWS-E-MONOGRAFIA.md`](docs/MAPEAMENTO-AWS-E-MONOGRAFIA.md) — AWS PoC vs local containers vs thesis concepts  
- [`docs/GUIA-EXPERIMENTOS-CHECKOV.md`](docs/GUIA-EXPERIMENTOS-CHECKOV.md) — deliberate Checkov failures; GitGuardian vs Checkov  

## Git

Initialize a local repository when you are ready:

```bash
git init
git add .
git commit -m "Add local DevSecOps PoC with Terraform, Docker, and Checkov"
```

Track `terraform/.terraform.lock.hcl` for reproducible provider versions; do **not** commit `.terraform/`, `.env`, or `terraform.tfvars` with secrets.
