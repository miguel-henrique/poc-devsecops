# Mapeamento: PoC AWS ↔ PoC em containers ↔ conceitos da monografia

Este documento amarra três eixos: a **PoC Terraform na AWS** (repositório de referência com VPC, segurança, RDS, EKS, storage), a **PoC local com Docker** deste repositório, e os **conceitos da monografia** (DevSecOps, IaC, shift-left, SAST, fail-fast, conformidade).

## 1. PoC AWS (estrutura de referência)

No projeto de referência (`main.tf`), a composição modular é:

| Módulo Terraform | Papel na AWS |
|------------------|--------------|
| `vpc` | VPC, subnets, route tables, anexo a Transit Gateway |
| `security` | Security Groups (ex.: RDS, EKS cluster, worker nodes) |
| `iam` | Papéis e identidades para nós e serviços |
| `storage` | Armazenamento objeto (ex.: S3) e políticas / endpoint |
| `database` | RDS PostgreSQL em subnets dedicadas |
| `cluster` | EKS, node groups, add-ons |

Essa é a **“landing zone” real**: múltiplas AZs, SGs explícitos, IAM e storage além do runtime da aplicação.

## 2. PoC local (este repositório) — o que espelha e o que não espelha

| Peça AWS (PoC real) | Representação na PoC Docker | Observação |
|---------------------|-----------------------------|------------|
| VPC + subnets | `docker_network` com IPAM | Uma rede bridge substitui **várias** subnets; não há TGW |
| Security Groups | Isolamento por rede + `privileged = false` | Não há regras ingress/egress granulares como na AWS |
| RDS | Container `postgres` + `docker_volume` | Mesmo motor (PostgreSQL), sem Multi-AZ nem backups gerenciados |
| EKS + worker nodes | N containers `api-*` (FastAPI) | Sem control plane Kubernetes; réplicas = tasks/pods conceituais |
| ALB / Ingress | Container `web` (nginx) + `upstream` | Um único host publica porta (ex.: 3000) |
| S3 / endpoints / IAM | *Não modelado* | Permanece só na PoC AWS; a monografia fala de S3 criptografado etc. |

**Conclusão didática:** a PoC em containers é um **modelo reduzido** para demonstrar **IaC + pipeline de segurança + topologia lógica**, não paridade 1:1 com a AWS.

## 3. Conceitos da monografia e onde aparecem aqui

| Conceito | Onde se materializa nesta PoC |
|----------|-------------------------------|
| **IaC** | Todo o ambiente em `terraform/` (módulos `network`, `database`, `backend`, `frontend`) |
| **Shift-left** | Checkov **antes** do `terraform apply` no `./dev-up.sh`; CI no GitHub Actions |
| **SAST em infraestrutura** | Checkov em `terraform/` (framework Terraform) |
| **SAST em imagens** | Checkov em `app/**/Dockerfile` |
| **Fail-fast** | Falha do Checkov interrompe o script; no CI, job vermelho |
| **Segredos fora do Git** | `.env` / `TF_VAR_*` (GitGuardian na monografia complementa em repositório real) |
| **Governança em código (OPA/Rego)** | **Não implementado** na PoC Docker — citado na monografia para a esteira AWS/organizacional |
| **Pre-commit hooks** | **Opcional** no laptop; o papel análogo é “rodar Checkov antes de commitar” (ver guia de experimentos) |

## 4. Roteiro sugerido para banca

1. Mostrar `main.tf` da PoC AWS (módulos) e o `terraform/main.tf` local (ordem network → database → backend → frontend).  
2. Executar `./dev-up.sh` e apontar no output: etapa Checkov (SAST), etapa apply (provisionamento), mapa container → serviço AWS.  
3. Mencionar explicitamente o que **não** está na PoC local (S3, IAM fino, OPA, GitGuardian) para delimitar o trabalho.

Arquivo relacionado: [GUIA-EXPERIMENTOS-CHECKOV.md](GUIA-EXPERIMENTOS-CHECKOV.md).
