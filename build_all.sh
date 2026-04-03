#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS=(
  haproxy-telemt-balancer
)

for name in "${PROJECTS[@]}"; do
  script="${ROOT}/${name}/build.sh"
  if [[ ! -f "${script}" ]]; then
    echo "build_all: skip, missing ${script}" >&2
    continue
  fi
  bash "${script}"
done
