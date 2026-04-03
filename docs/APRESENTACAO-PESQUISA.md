# Apresentação do projeto: PoC DevSecOps com Infraestrutura como Código

**Contexto:** pesquisa acadêmica em **DevSecOps** e **Infraestrutura como Código (IaC)**.

Este documento resume o repositório **poc-devsecops** e explicita como ele se articula com esses eixos temáticos, para uso em seminários, bancas ou relatórios de pesquisa.

---

## 1. Enquadramento na pesquisa

### DevSecOps

**DevSecOps** integra práticas de segurança ao longo do ciclo de vida de desenvolvimento e operação de software — “shift left” — em vez de tratar segurança apenas como etapa final ou responsabilidade isolada.

Neste projeto, isso aparece de forma **concreta e reproduzível**:

- **Análise estática de infraestrutura e imagens** com **Checkov** (Terraform e Dockerfiles).
- **Pipeline de CI** (GitHub Actions) que executa formatação, validação do Terraform e varredura de segurança **antes** de considerar o código “pronto”.
- **Boas práticas explícitas** no código: containers não privilegiados, health checks, usuários não root nas imagens, segredos fora do repositório (`.env` / variáveis, não commitadas).

Assim, o repositório funciona como **estudo de caso** de como automatizar verificações de segurança em um fluxo que mistura aplicação, containers e IaC.

### Infraestrutura como Código (IaC)

**IaC** trata a infraestrutura (rede, computação, dados, configuração) como **código versionado**: declarativo ou imperativo, revisável, testável e aplicável de forma repetível.

Aqui, o **Terraform** descreve de forma declarativa:

- rede lógica (análogo conceitual a uma VPC),
- banco de dados com volume persistente,
- réplicas da API,
- frontend com proxy reverso e balanceamento entre upstreams.

Ou seja, o ambiente não é montado “à mão” no Docker; ele é **derivado de definições em HCL**, alinhado ao núcleo temático da pesquisa sobre IaC.

---

## 2. Objetivo do projeto (o que este PoC demonstra)

Demonstrar, **sem depender de nuvem pública**, um fluxo que combina:

| Dimensão | O que o PoC evidencia |
|----------|------------------------|
| **IaC** | Provisionamento declarativo com módulos Terraform (`network`, `database`, `backend`, `frontend`). |
| **DevOps** | Build de imagens, orquestração local via Docker, um comando para subir o ambiente (`./dev-up.sh` / `make demo`). |
| **Segurança no pipeline** | Checkov em Terraform e Dockerfiles; falha de build se políticas críticas forem violadas. |
| **Rastreabilidade** | Código e configuração no Git; lock file de providers para reprodutibilidade. |

A analogia intencional com ambientes em nuvem (VPC, RDS, balanceador, réplicas) **facilita a narrativa** da pesquisa: o mesmo raciocínio de IaC e segurança aplica-se a AWS/Azure/GCP, aqui **didaticamente simplificado** em Docker local.

---

## 3. Relação direta com os temas da pesquisa

1. **IaC como objeto de estudo** — O Terraform é o artefato central de “infraestrutura”; mudanças na topologia passam por revisão de código e por ferramentas de análise.
2. **DevSecOps como processo** — Segurança não é um anexo: está embutida em Dockerfile (usuário, HEALTHCHECK), em recursos Terraform (`privileged = false`) e em gates no CI.
3. **Pesquisa aplicada** — O repositório pode ser apresentado como **prova de conceito** ou **artefato experimental** que materializa conceitos da revisão bibliográfica (IaC, supply chain, políticas como código).

---

## 4. Componentes principais (para slides ou defesa oral)

- **Terraform + provider Docker:** infraestrutura local expressa como código.
- **Aplicação:** API FastAPI + frontend estático servido por nginx (não privilegiado).
- **Dados:** PostgreSQL em container com volume nomeado.
- **CI/CD:** workflow que valida Terraform e roda Checkov.
- **Alternativa sem Terraform:** Docker Compose para quem quiser apenas o runtime, mantendo o paralelo “declarativo vs. compose” como ponto de discussão metodológico.

---

## 5. Como apresentar em poucos minutos (roteiro sugerido)

1. **Problema da pesquisa:** integrar segurança e governança em pipelines com IaC.
2. **Hipótese ou pergunta:** políticas automatizadas (Checkov) + IaC reduzem classes de erros e aumentam rastreabilidade.
3. **Método / artefato:** este repositório como PoC reproduzível.
4. **Demo:** `./dev-up.sh` → navegador em `http://localhost:3000` → `curl` na API → mostrar trecho do workflow do GitHub Actions e um relatório Checkov.
5. **Conclusão:** o projeto **instancia** DevSecOps e IaC de forma local; limitações (não é produção, não há nuvem real) devem ser declaradas como **delimitação** da pesquisa.

---

## 6. Limitações úteis para mencionar academicamente

- Ambiente **local**; não substitui testes em nuvem nem threat modeling completo.
- Checkov e políticas são **configuráveis**; o conjunto usado é uma **amostra** de boas práticas, não um catálogo exaustivo.
- Segredos são variáveis de ambiente — adequado ao PoC; em produção discute-se cofres de segredos e rotação.

---

## 7. Referência ao repositório

- Documentação técnica detalhada: `README.md` (inglês) e `README.pt-BR.md` (português).
- Este arquivo: `docs/APRESENTACAO-PESQUISA.md`.

## 8. Demonstração no terminal (gravar ou compartilhar tela)

O script **`./dev-up.sh`** foi pensado para apresentações:

1. **Checkov** — mostra na prática a *análise estática* de infraestrutura (Terraform) e de Dockerfiles, alinhada ao que o **GitHub Actions** faz no CI.
2. **Terraform apply** — texto introdutório ligando rede, banco, réplicas e nginx à analogia com nuvem.
3. **Resumo final** — `docker ps` ao vivo e uma lista de comandos (`docker network inspect`, `terraform output`, etc.) para você copiar durante a defesa.

Para **repetir só o bloco final** sem subir tudo de novo: `make inspect` ou `./scripts/inspect-stack.sh`.

Para iterar rápido sem Checkov: `./dev-up.sh --skip-checkov` ou `CHECKOV=0 ./dev-up.sh`.

---

*Boa apresentação — adapte trechos conforme normas da sua instituição (ABNT, formatação de trabalhos de conclusão, etc.).*
