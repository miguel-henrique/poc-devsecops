# Guia: experimentar o Checkov (e contrastar com detecção de credenciais)

Este guia ajuda a **ver o Checkov falhar de propósito** (fail-fast / shift-left) e esclarece **o que o Checkov não faz**, para alinhar com a monografia (GitGuardian, OPA, etc.).

## O que o Checkov faz neste projeto

- **Terraform** (`terraform/`): analisa HCL e o grafo de recursos; muitas regras são pensadas para AWS/Azure/GCP, mas várias checagens genéricas e de providers (incl. Docker) ainda se aplicam.
- **Dockerfiles** (`app/`): regras de endurecimento (ex.: `USER`, `HEALTHCHECK`).

## O que o Checkov *não* substitui

- **Segredos em repositório** (tokens, chaves AWS coladas em `.tf` ou `.env` commitado): a monografia cita **GitGuardian** e hooks — o fluxo ideal é *nunca commitar* segredo + scanner de segredos dedicado. O Checkov pode acusar **alguns** padrões de segredo em IaC, mas **não** é equivalente a GitGuardian/gitleaks para todo tipo de vazamento.
- **OPA / Rego** (governança e FinOps customizados): não estão nesta PoC local; na monografia aparecem na esteira mais ampla.

---

## Experimento A — Endurecimento de imagem (Dockerfile)

1. Abra `app/backend/Dockerfile` (ou `app/frontend/Dockerfile`).
2. Comente temporariamente a linha `USER …` ou remova o `HEALTHCHECK`.
3. Rode:

   ```bash
   make checkov
   ```

   ou só Dockerfiles:

   ```bash
   checkov -d app --framework dockerfile
   ```

4. Observe falhas (ex.: políticas CKV_DOCKER_*). Isso ilustra **SAST em artefatos de build** antes de publicar a imagem.
5. **Reverta** o arquivo antes de commitar.

---

## Experimento B — Privilégio excessivo no runtime (Terraform → Docker)

1. Em `terraform/modules/frontend/main.tf` (ou outro `docker_container`), altere temporariamente:

   ```hcl
   privileged = true
   ```

   (hoje o projeto usa `false` de propósito.)

2. Rode:

   ```bash
   checkov -d terraform --framework terraform
   ```

3. Verifique se alguma regra do Checkov sinaliza `privileged` ou configurações equivalentes (o conjunto exato depende da versão do Checkov e do provider). Se **não** aparecer falha, use o argumento na **defesa**: nem toda má prática tem política pronta — por isso combina-se **várias ferramentas** e **revisão humana**.
4. **Reverta** para `privileged = false`.

---

## Experimento C — “Credencial” no código (expectativa realista)

1. Crie um arquivo **não commitado** ou use um branch de teste. Por exemplo, adicione **temporariamente** em um `.tf` (não use chaves reais):

   ```hcl
   # APENAS DEMO — NÃO COMMITAR
   variable "demo_leaked_secret" {
     default = "AKIAIOSFODNN7EXAMPLE"
     sensitive = false
   }
   ```

2. Rode `checkov -d terraform --framework terraform` e observe se alguma regra de **segredo genérico** acusa (varia por versão).

3. Para uma demo de **vazamento em commit**, o fluxo mais fiel à monografia é citar **GitGuardian / gitleaks** no repositório real; o Checkov complementa com **misconfiguration**, não com cobertura total de segredos.

4. **Apague** o trecho de demo.

**Importante:** nunca suba chaves reais. Use sempre exemplos fictícios do tipo `AKIA…EXAMPLE`.

---

## Experimento D — Falha no `./dev-up.sh`

Depois de introduzir uma violação que o Checkov detecta, rode:

```bash
./dev-up.sh
```

O script deve **parar antes** do `terraform apply`, reproduzindo o **fail-fast** descrito na monografia.

Para pular o gate (só desenvolvimento):

```bash
./dev-up.sh --skip-checkov
```

---

## Pre-commit (opcional)

Para aproximar a monografia de **hooks locais**:

```bash
pip install pre-commit checkov
# exemplo: hook que roda checkov nos diretórios terraform/ e app/
```

Você pode registrar um hook que chama `make checkov` antes do `git commit`. Detalhes dependem do ambiente; o importante conceitualmente é: **mesmas verificações do CI o mais cedo possível**.
