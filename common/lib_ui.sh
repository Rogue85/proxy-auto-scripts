#!/usr/bin/env bash

UI_USE_COLOR=0
if [[ -t 1 ]]; then
  UI_USE_COLOR=1
fi

if [[ "${UI_USE_COLOR}" -eq 1 ]]; then
  UI_RESET=$'\033[0m'
  UI_BOLD=$'\033[1m'
  UI_DIM=$'\033[2m'
  UI_RED=$'\033[0;31m'
  UI_GREEN=$'\033[0;32m'
  UI_YELLOW=$'\033[1;33m'
  UI_BLUE=$'\033[0;34m'
  UI_CYAN=$'\033[0;36m'
else
  UI_RESET=
  UI_BOLD=
  UI_DIM=
  UI_RED=
  UI_GREEN=
  UI_YELLOW=
  UI_BLUE=
  UI_CYAN=
fi

ui_blank() {
  printf '\n'
}

ui_rule() {
  printf '%s' "${UI_DIM}"
  local i
  for i in {1..72}; do
    printf '─'
  done
  printf '%s\n' "${UI_RESET}"
}

ui_section() {
  ui_blank
  ui_rule
  printf '%s▶ %s%s\n' "${UI_BOLD}${UI_CYAN}" "$1" "${UI_RESET}"
  ui_rule
}

ui_info() {
  printf '%s[INFO]%s %s\n' "${UI_BLUE}" "${UI_RESET}" "$1"
}

ui_menu_item() {
  local num="$1"
  local text="$2"
  printf '  %s%s)%s %s\n' "${UI_DIM}" "${num}" "${UI_RESET}" "${text}"
}

ui_ok() {
  printf '%s[ OK ]%s %s\n' "${UI_GREEN}" "${UI_RESET}" "$1"
}

ui_warn() {
  printf '%s[WARN]%s %s\n' "${UI_YELLOW}" "${UI_RESET}" "$1"
}

ui_err() {
  printf '%s[ERR ]%s %s\n' "${UI_RED}" "${UI_RESET}" "$1" >&2
}

ui_log_block_begin() {
  local title="$1"
  ui_blank
  printf '%s┌── %s ──%s\n' "${UI_DIM}" "${title}" "${UI_RESET}"
}

ui_log_stream() {
  while IFS= read -r line || [[ -n "${line}" ]]; do
    printf '%s│%s %s\n' "${UI_DIM}" "${UI_RESET}" "${line}"
  done
}

ui_log_block_end() {
  printf '%s└' "${UI_DIM}"
  local i
  for i in {1..70}; do
    printf '─'
  done
  printf '%s\n' "${UI_RESET}"
}
