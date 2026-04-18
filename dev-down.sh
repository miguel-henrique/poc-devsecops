#!/usr/bin/env bash
# Derruba toda a stack Terraform (rede, volumes, containers). Depois rode ./dev-up.sh de novo.
exec "$(cd "$(dirname "$0")" && pwd)/scripts/dev-up.sh" --destroy "$@"
