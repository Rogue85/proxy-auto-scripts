#!/usr/bin/env bash

if [[ -n "${TELEMT_BALANCER_MONOLITH:-}" ]]; then
  return 0
fi

_TELEMT_CALLER="${BASH_SOURCE[1]:-}"
if [[ -z "${_TELEMT_CALLER}" ]]; then
  echo "telemt: include_paths must be sourced from a project script" >&2
  exit 1
fi

TELEMT_SRC_DIR="$(cd -- "$(dirname -- "${_TELEMT_CALLER}")" && pwd)"
TELEMT_PKG_ROOT="$(cd -- "${TELEMT_SRC_DIR}/.." && pwd)"
TELEMT_REPO_ROOT="$(cd -- "${TELEMT_PKG_ROOT}/.." && pwd)"
TELEMT_COMMON_LIB_UI="${TELEMT_REPO_ROOT}/common/lib_ui.sh"
TELEMT_LOCAL_LIB_UI="${TELEMT_SRC_DIR}/lib_ui.sh"

if [[ -f "${TELEMT_COMMON_LIB_UI}" ]]; then
  source "${TELEMT_COMMON_LIB_UI}"
elif [[ -f "${TELEMT_LOCAL_LIB_UI}" ]]; then
  source "${TELEMT_LOCAL_LIB_UI}"
else
  echo "telemt: lib_ui not found (tried ${TELEMT_COMMON_LIB_UI} and ${TELEMT_LOCAL_LIB_UI})" >&2
  exit 1
fi
