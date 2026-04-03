#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${TELEMT_BALANCER_MONOLITH:-}" ]]; then
  source "${SCRIPT_DIR}/include_paths.sh"
fi

if [[ -z "${BASH_VERSION:-}" ]]; then
  ui_err "Run this script with bash: bash utils.sh <command>"
  exit 1
fi

RUN_DIR="${PWD}"
CONTAINER_NAME="telemt-haproxy-balancer"
ENV_FILE="${RUN_DIR}/telemt-haproxy-balancer.env"
CFG_FILE="${RUN_DIR}/haproxy.cfg"

if ! command -v docker >/dev/null 2>&1; then
  ui_err "Not found: docker"
  exit 1
fi

show_help() {
  ui_section "utils — help"
  ui_info "Usage: bash utils.sh <command>"
  ui_blank
  ui_info "  logs    Stream container logs"
  ui_info "  status  Show container status"
  ui_info "  remove  Remove container and optionally local files"
}

cmd_logs() {
  if ! docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
    ui_err "Container not found: ${CONTAINER_NAME}"
    exit 1
  fi
  ui_info "Streaming logs for ${CONTAINER_NAME} (Ctrl+C to stop)"
  docker logs -f "${CONTAINER_NAME}"
}

cmd_status() {
  ui_section "Container status"
  docker ps -a --filter "name=^/${CONTAINER_NAME}$"
}

cmd_remove() {
  if docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
    docker rm -f "${CONTAINER_NAME}" >/dev/null
    ui_ok "Container removed: ${CONTAINER_NAME}"
  else
    ui_warn "Container not found: ${CONTAINER_NAME}"
  fi

  ui_blank
  printf '%s%s%s ' "${UI_BOLD}" "Remove local files ${ENV_FILE} and ${CFG_FILE}? [y/N]:" "${UI_RESET}"
  read -r answer
  if [[ "${answer}" == "y" || "${answer}" == "Y" ]]; then
    rm -f "${ENV_FILE}" "${CFG_FILE}"
    ui_ok "Local files removed"
  else
    ui_info "Local files kept"
  fi
}

telemt_utils_main() {
  local action="${1:-}"
  case "${action}" in
    logs)
      cmd_logs
      ;;
    status)
      cmd_status
      ;;
    remove)
      cmd_remove
      ;;
    *)
      show_help
      exit 1
      ;;
  esac
}

if [[ -z "${TELEMT_BALANCER_MONOLITH:-}" ]]; then
  telemt_utils_main "$@"
fi
