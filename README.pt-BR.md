# PoC DevSecOps — “Nuvem” local com Docker + Terraform + Checkov

Este repositório é uma **prova de conceito local** que reproduz um fluxo de provisionamento no estilo AWS usando **Terraform**, **Docker**, **Checkov** e **GitHub Actions**. **Não há provedor de nuvem**: os containers representam computação, uma rede Docker definida pelo usuário representa uma VPC, e o PostgreSQL roda como camada de dados em estilo gerenciado.

> **Idioma:** [English](README.md) · **Português (Brasil)** (este arquivo)

## Início rápido (ver funcionando)

**Um único comando (recomendado):** na **raiz do repositório**:

```bash
./dev-up.sh
```

O script verifica o **Docker**, cria **`.env`** a partir de `.env.example` se necessário, prefere **Terraform no PATH** se estiver funcional; caso contrário executa **Terraform em Docker** (e se `terraform init` no host falhar, tenta de novo com Docker). **Antes do `apply`**, executa o **Checkov** em `terraform/` e `app/` (usa o binário `checkov` se existir, senão a imagem `bridgecrew/checkov`). A saída é formatada para apresentação: blocos explicando análise estática, nota sobre o pipeline no GitHub Actions, depois o provisionamento Terraform e, ao final, um `docker ps` ao vivo e comandos para inspecionar rede e containers. Use **`./dev-up.sh --skip-checkov`** para pular a varredura (mais rápido). Depois de tudo rodando, **`make inspect`** reimprime só o resumo e os comandos, sem Terraform.

Defina **`CHECKOV=0`** no ambiente para o mesmo efeito de `--skip-checkov`.

**Derrubar a stack:** `./dev-down.sh` ou `make dev-down` (equivale a `terraform destroy`). Em seguida `./dev-up.sh` recria tudo.

Se o Docker não estiver instalado (somente Ubuntu/Debian):

```bash
./dev-up.sh --install-deps
```

Para instalar também o pacote APT **`terraform`** da HashiCorp:

```bash
./dev-up.sh --install-deps --with-terraform-apt
```

Instalações não interativas (para scripts): `./dev-up.sh --yes --install-deps`

Outros pontos de entrada: `make dev-up` (equivalente a `./dev-up.sh`), `make demo`, `./scripts/dev-up.sh`.

---

**Passos manuais (equivalentes ao fluxo antigo):**

1. **Iniciar o Docker** (Docker Engine em execução na máquina).
2. **Terraform:** opcional — se não estiver instalado, o Makefile / `dev-up.sh` usará Terraform em Docker quando o binário não existir.
3. Executar `make demo` ou `make tf-init` e depois `make tf-apply`.

4. **Visualizar:**
   - **Navegador:** abrir `http://localhost:3000` (ou o `frontend_url` impresso por `make open`).
   - **Containers:** `make status` ou `docker ps --filter name=poc-devsecops`.
   - **API:** `curl -s http://localhost:3000/api/status` (JSON com informações do BD e da réplica).

5. **Parar / remover:** `make tf-destroy` (stack gerenciada pelo Terraform) ou `make compose-down` (stack Compose).

**Ainda mais simples (sem Terraform):** `cp .env.example .env`, ajuste senhas se quiser, depois `make compose-up` e abra `http://localhost:3000`.

**Credenciais:** coloque usuário e senha do banco no `.env` como `TF_VAR_postgres_user` e `TF_VAR_postgres_password` (e `POSTGRES_*` correspondentes para o Compose). O Makefile carrega o `.env` para você — **não** é necessário executar `source .env` manualmente para `make demo`, `make tf-plan` ou `make tf-apply`.

**Por que “repositório inteiro no disco”?** O Terraform constrói imagens usando caminhos como `../app/backend` em relação à pasta `terraform/`. Você só precisa desse detalhe se rodar o Terraform **dentro de um container**; aí monta-se o projeto inteiro (veja o final do README). Um `make demo` normal a partir de um clone comum é suficiente.

## Arquitetura

| Aspecto | Analogia na nuvem real | Esta PoC |
|--------|-------------------------|----------|
| Isolamento de rede | VPC + sub-redes | `docker_network` com bridge dedicado e IPAM `/16` |
| Camada de dados | RDS | `postgres:16-alpine` com volume nomeado |
| Camada de aplicação | Auto Scaling / tarefas ECS | Vários `docker_container` da API (`backend_replica_count`) |
| Borda / UI | ALB + site estático | nginx (não privilegiado) como proxy reverso + arquivos estáticos |
| Segredos | Parameter Store / Secrets Manager | Variáveis de ambiente (`TF_VAR_*` / `.env`), nunca commitadas |

**Fluxo de tráfego:** Navegador → `localhost:3000` (configurável) → ELB-NGINX → pool upstream EKS-FASTAPI-XX (réplicas FastAPI) → RDS-POSTGRES na rede VPC-DOCKERNETWORK.

```
┌─────────────┐     ┌────────────────────┐     ┌────────────────────────────────┐
│  Navegador  │────▶│  ELB-NGINX         │────▶│  EKS-FASTAPI-XX × N (FastAPI)  │
└─────────────┘     └────────────────────┘     └──────────────┬─────────────────┘
                                                           │
                                                           ▼
                                              ┌────────────────────────────┐
                                              │ RDS-POSTGRES               │
                                              └────────────────────────────┘
         Todos os containers na mesma rede Docker (VPC-DOCKERNETWORK, simulando uma VPC).
```

## Organização do repositório

- `terraform/` — Módulo raiz e módulos reutilizáveis (`network`, `database`, `backend`, `frontend`).
- `app/backend/` — Serviço FastAPI (`/health`, `/api/status`).
- `app/frontend/` — UI estática + configs nginx (o Terraform gera a lista de upstreams para balanceamento).
- `.github/workflows/pipeline.yml` — CI: `fmt`, `init`, `validate`, Checkov, `plan`.
   - `docker-compose.yml` — Stack opcional sem Terraform (nomes: RDS-POSTGRES, EKS-FASTAPI-01, ELB-NGINX, VPC-DOCKERNETWORK).
- `Makefile` — Alvos de conveniência para fluxos locais.
- `dev-up.sh` / `scripts/dev-up.sh` — Bootstrap em um passo: checa dependências, Terraform no host ou Docker, init + apply.
- `scripts/terraform-docker.sh` — Executa Terraform em Docker quando `terraform` não está instalado; repassa `TF_VAR_*` e adiciona `--group-add` com o GID do socket Docker para o container usar `/var/run/docker.sock`.

- **Docker Engine** — daemon acessível em `/var/run/docker.sock` (padrão no Linux).

---

**Convenção de nomes dos containers (mapeamento AWS):**

- `RDS-POSTGRES`: Banco PostgreSQL (simula AWS RDS)
- `EKS-FASTAPI-XX`: Réplicas FastAPI backend (simula nós EKS, XX = 01, 02, ...)
- `ELB-NGINX`: nginx frontend (simula Elastic Load Balancer)
- `VPC-DOCKERNETWORK`: Rede Docker (simula uma VPC)
- **Terraform `>= 1.5`** — opcional neste repositório: se `terraform` **não** estiver no `PATH`, o `make` usa [`scripts/terraform-docker.sh`](scripts/terraform-docker.sh) (imagem oficial `hashicorp/terraform` com o repositório montado). Ainda assim é necessário Docker.
- Python 3 + `pip` **ou** o container `bridgecrew/checkov` para varreduras (somente se rodar Checkov localmente).

### Iniciar o Docker (Linux)

Verificar:

```bash
docker version
```

Se falhar por permissão, o usuário pode precisar do grupo `docker` (sair e entrar de novo na sessão após):

```bash
sudo usermod -aG docker "$USER"
```

Se o daemon estiver parado:

```bash
sudo systemctl start docker
sudo systemctl enable docker   # opcional: iniciar no boot
```

### “Permission denied” em `/var/run/docker.sock` durante `apply` (Terraform em Docker)

O container do Terraform roda com seu user id. O socket costuma ser `root:docker` com modo `660`, então o wrapper passa **`--group-add` com o gid do socket** do host. Depois de atualizar `scripts/terraform-docker.sh`, execute `./dev-up.sh` de novo.

Se ainda falhar: garanta que o usuário no host consiga rodar `docker ps` (grupo `docker`, depois **sair e entrar na sessão**), e que nada force `DOCKER_HOST` para um socket não padrão sem ajustar o wrapper.

### Instalar Terraform no PATH (opcional)

Os repositórios padrão do Ubuntu **não** incluem Terraform. Se você rodar `sudo apt install terraform` **sem** adicionar antes o repositório da HashiCorp, receberá **`E: Unable to locate package terraform`**. É preciso adicionar o repositório e instalar.

**Opção A — APT HashiCorp (Debian / Ubuntu), execute o bloco inteiro em ordem:**

```bash
sudo apt install -y wget gnupg software-properties-common

wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt install -y terraform
terraform version
```

**Opção B — Snap (sem repositório APT):**

```bash
sudo snap install terraform
```

**Opção C — Não instalar Terraform** e usar apenas o wrapper Docker deste repositório: execute **`make demo`** / **`make tf-init`** na raiz do projeto. O Makefile usa `scripts/terraform-docker.sh` quando `terraform` não está no **PATH** (Docker precisa estar rodando; `TF_VAR_*` do `.env` são passados ao container).

## Configuração

1. Copie `.env.example` para `.env` (ou confie no `make demo` para criar) e defina **`TF_VAR_postgres_user`** e **`TF_VAR_postgres_password`** (e chaves **`POSTGRES_*`** correspondentes para Docker Compose).
2. **Não é necessário `source .env` manualmente** para `make demo`, `make tf-plan`, `make tf-apply` ou `make tf-destroy` — o Makefile carrega o `.env` nesses alvos.
3. Opcional: copie `terraform/terraform.tfvars.example` para `terraform/terraform.tfvars` para variáveis extras (mantenha segredos fora do Git).

## Execução local (Terraform)

Na raiz do repositório, com Docker em execução:

```bash
make demo
```

Ou passo a passo:

```bash
make tf-init
make tf-plan
make tf-apply
```

Depois `make open` para URLs/outputs, ou abra `http://localhost:3000` por padrão.

**Escalonamento:** `TF_VAR_backend_replica_count` (1–5) define quantos containers de API são criados; o nginx faz balanceamento entre os nomes na rede Docker.

### Terraform via container (opcional)

Se não estiver usando `make`, o mesmo wrapper que o Makefile usa é:

```bash
./scripts/terraform-docker.sh -chdir=terraform plan -input=false
```

Execute isso na **raiz do repositório** para o projeto montar corretamente.

## Execução local (alternativa Docker Compose)

Para um caminho rápido sem Terraform:

```bash
cp .env.example .env
docker compose --env-file .env up --build -d
```

O Compose usa `app/frontend/nginx.compose.conf` (um único upstream) e publica `HOST_FRONTEND_PORT` → `8080` no container.

## CI/CD (GitHub Actions)

Workflow: `.github/workflows/pipeline.yml`

1. Checkout do repositório.
2. Instalar Checkov (`pip`).
3. Instalar Terraform (`hashicorp/setup-terraform`).
4. `terraform fmt -check -recursive` dentro de `terraform/`.
5. `terraform init` / `terraform validate`.
6. **Checkov** — duas passagens:
   - `terraform/` com `--framework terraform` (HCL estático / checagens em grafo).
   - `app/` com `--framework dockerfile` (higiene de imagem: não-root, `HEALTHCHECK`, etc.).
7. `terraform plan` (exige Docker no runner; a imagem padrão `ubuntu-latest` fala com o daemon Docker local).

O job está configurado para **falhar** se o Checkov reportar checagens falhas (sem soft-fail).

## Varredura de segurança com Checkov

- **Terraform:** `checkov -d terraform --framework terraform` analisa arquivos `.tf` (checagens agnósticas de provedor). Muitas políticas miram AWS/Azure/GCP; esta PoC ainda se beneficia de checagens gerais de grafo e metadados. Para configurações de runtime Docker, confie em `privileged = false` explícito e nas políticas de Dockerfile.
- **Dockerfiles:** `checkov -d app --framework dockerfile` impõe higiene básica de imagem (exemplos: `CKV_DOCKER_2` HEALTHCHECK, `CKV_DOCKER_3` usuário não root).

### Configuração intencionalmente incorreta (lição) e correção

Durante o desenvolvimento, dois achados comuns surgiram e foram **corrigidos** no próprio repositório:

1. **Dockerfile (`CKV_DOCKER_2`, `CKV_DOCKER_3`):** Ausência de `HEALTHCHECK` e de `USER` não root explícito geravam falhas. Corrigido com `HEALTHCHECK`, `USER appuser` (backend) e `nginxinc/nginx-unprivileged` + `USER nginx` (frontend) para o nginx bindar na porta `8080` sem root.
2. **Terraform (`docker_container.privileged`):** `privileged = true` concederia capacidades excessivas no host e é sinalizado em revisões de segurança. Esta stack define `privileged = false` em todos os lugares.

Para ver o Checkov falhar localmente, remova temporariamente `USER` ou `HEALTHCHECK` de um Dockerfile e execute `make checkov`.

## Como o Terraform mapeia conceitos “estilo AWS”

- **Regiões / contas** não são modeladas; em vez disso, `project_name` prefixa nomes de recursos.
- **VPC** → `docker_network` com labels (`simulates = aws-vpc`).
- **RDS** → `docker_container` + `docker_volume` para dados do PostgreSQL.
- **ECS / ASG** → `count` em `docker_container` para réplicas da API.
- **ALB** → upstream nginx sobre vários hostnames de backend.

Nenhuma API ou credencial da AWS é usada.

## Outputs

Após `terraform apply`, inspecione:

```bash
terraform -chdir=terraform output
```

Você deve ver `frontend_url`, `api_proxy_path`, `backend_container_names` e `database_host`.

## Alvos do Makefile

| Alvo | Função |
|------|--------|
| `make load-env` | Imprime linhas `export ...` a partir do `.env` (use com `eval "$(make load-env)"`). |
| `make tf-init` | `terraform init` |
| `make tf-validate` | init + `validate` |
| `make checkov` | Varreduras Terraform + Dockerfile |
| `make tf-plan` / `make tf-apply` / `make tf-destroy` | Ciclo completo (precisa de env + Docker) |
| `make compose-up` / `make compose-down` | Alternativa Docker Compose |

## Git

Inicialize um repositório local quando estiver pronto:

```bash
git init
git add .
git commit -m "Add local DevSecOps PoC with Terraform, Docker, and Checkov"
```

Versione `terraform/.terraform.lock.hcl` para provedores reproduzíveis; **não** faça commit de `.terraform/`, `.env` nem `terraform.tfvars` com segredos.

---

## Documentação acadêmica

- [`docs/APRESENTACAO-PESQUISA.md`](docs/APRESENTACAO-PESQUISA.md) — texto para apresentação e defesa  
- [`docs/MAPEAMENTO-AWS-E-MONOGRAFIA.md`](docs/MAPEAMENTO-AWS-E-MONOGRAFIA.md) — PoC AWS (VPC, RDS, EKS…) ↔ containers locais ↔ conceitos da monografia  
- [`docs/GUIA-EXPERIMENTOS-CHECKOV.md`](docs/GUIA-EXPERIMENTOS-CHECKOV.md) — como quebrar o Checkov de propósito e contraste com GitGuardian/OPA
