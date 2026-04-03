#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${TELEMT_BALANCER_MONOLITH:-}" ]]; then
  source "${SCRIPT_DIR}/include_paths.sh"
fi

if [[ -z "${BASH_VERSION:-}" ]]; then
  ui_err "Run this script with bash: bash start.sh"
  exit 1
fi

telemt_require_root

run_install() {
  if [[ -n "${TELEMT_BALANCER_MONOLITH:-}" ]]; then
    telemt_install_main
  else
    bash "${SCRIPT_DIR}/install.sh"
  fi
}

run_remove() {
  if [[ -n "${TELEMT_BALANCER_MONOLITH:-}" ]]; then
    telemt_utils_main remove
  else
    bash "${SCRIPT_DIR}/utils.sh" remove
  fi
}

run_logs() {
  if [[ -n "${TELEMT_BALANCER_MONOLITH:-}" ]]; then
    telemt_utils_main logs
  else
    bash "${SCRIPT_DIR}/utils.sh" logs
  fi
}

run_status() {
  if [[ -n "${TELEMT_BALANCER_MONOLITH:-}" ]]; then
    telemt_utils_main status
  else
    bash "${SCRIPT_DIR}/utils.sh" status
  fi
}

show_menu() {
  ui_blank
  ui_section "telemt-haproxy-balancer"
  ui_menu_item "1" "Install / Update"
  ui_menu_item "2" "Remove"
  ui_menu_item "3" "Logs"
  ui_menu_item "4" "Status"
  ui_menu_item "5" "Exit"
  ui_rule
}

while true; do
  show_menu
  printf '%s%s%s ' "${UI_BOLD}" "Select:" "${UI_RESET}"
  read -r choice
  case "${choice}" in
    1)
      run_install
      ;;
    2)
      run_remove
      ;;
    3)
      run_logs
      ;;
    4)
      run_status
      ;;
    5)
      ui_ok "Bye"
      exit 0
      ;;
    *)
      ui_warn "Invalid choice. Enter 1, 2, 3, 4, or 5."
      ;;
  esac
done
