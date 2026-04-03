#!/usr/bin/env bash

telemt_require_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    return 0
  fi
  if declare -F ui_err >/dev/null 2>&1; then
    ui_err "Run as root (e.g. sudo bash this script). Docker install and HAProxy need elevated privileges."
  else
    printf '%s\n' "Run as root (e.g. sudo bash this script). Docker install and HAProxy need elevated privileges." >&2
  fi
  exit 1
}
