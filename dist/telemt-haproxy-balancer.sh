#!/usr/bin/env bash
set -euo pipefail
export TELEMT_BALANCER_MONOLITH=1

# --- lib_ui.sh (from common) ---

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

# --- telemt_privilege.sh (from common) ---

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

# --- haproxy.cfg.tpl (embedded) ---
telemt_embedded_haproxy_cfg_tpl() {
cat <<'__TELEMT_HAPROXY_TPL__'
global
    log stdout format raw local0
    maxconn 10000

defaults
    log global
    mode tcp
    option tcplog
    option clitcpka
    option srvtcpka
    timeout connect 5s
    timeout client 2h
    timeout server 2h
    timeout check 5s

frontend tcp_in
    bind *:${LISTEN_PORT}
    maxconn 8000
    default_backend telemt_nodes

backend telemt_nodes
    balance roundrobin
    stick-table type ip size 200k expire 30m
    stick on src
    default-server inter 5s rise 2 fall 3${SEND_PROXY_V2_SUFFIX}
${TELEMT_BACKEND_SERVERS}
__TELEMT_HAPROXY_TPL__
}

# --- install.sh ---

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE=""
if [[ -z "${TELEMT_BALANCER_MONOLITH:-}" ]]; then
  source "${SCRIPT_DIR}/include_paths.sh"
  TEMPLATE_FILE="${TELEMT_PKG_ROOT}/haproxy.cfg.tpl"
fi

if [[ -z "${BASH_VERSION:-}" ]]; then
  ui_err "Run this script with bash: bash install.sh"
  exit 1
fi

RUN_DIR="${PWD}"
ENV_FILE="${RUN_DIR}/telemt-haproxy-balancer.env"

telemt_haproxy_template_stream() {
  if declare -F telemt_embedded_haproxy_cfg_tpl >/dev/null 2>&1; then
    telemt_embedded_haproxy_cfg_tpl
  else
    cat "${TELEMT_PKG_ROOT}/haproxy.cfg.tpl"
  fi
}
OUTPUT_CFG="${RUN_DIR}/haproxy.cfg"
CONTAINER_NAME="telemt-haproxy-balancer"
ENV_ERROR=""

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    ui_err "Not found: ${cmd}"
    exit 1
  fi
}

ui_show_container_logs() {
  local title="$1"
  ui_log_block_begin "${title}"
  docker logs "${CONTAINER_NAME}" 2>&1 | ui_log_stream || true
  ui_log_block_end
}

docker_daemon_ok() {
  command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

wait_for_docker_daemon() {
  local i
  for i in {1..30}; do
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

install_docker() {
  local get_docker_sh="${RUN_DIR}/get-docker.sh"
  ui_warn "Docker is not installed or the daemon is not reachable."
  ui_info "Installing Docker via get.docker.com ..."
  require_cmd curl
  curl -fsSL https://get.docker.com -o "${get_docker_sh}"
  sh "${get_docker_sh}"
  rm -f "${get_docker_sh}"
  if ! wait_for_docker_daemon; then
    ui_err "Docker was installed but the daemon is still not reachable. Start Docker and run this script again."
    exit 1
  fi
  ui_ok "Docker daemon is reachable"
}

ensure_docker() {
  if docker_daemon_ok; then
    return 0
  fi
  if command -v docker >/dev/null 2>&1; then
    if command -v systemctl >/dev/null 2>&1; then
      systemctl start docker 2>/dev/null || true
      if wait_for_docker_daemon; then
        return 0
      fi
    fi
    ui_err "Docker is installed but the daemon is not reachable (docker info failed). Start Docker and run this script again."
    exit 1
  fi
  install_docker
  if ! docker_daemon_ok; then
    ui_err "Docker is still not available after installation."
    exit 1
  fi
}

wait_for_haproxy_ready() {
  local i
  local log_out=""
  local running=""
  for i in {1..10}; do
    sleep 1
    if ! docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
      ui_err "HAProxy container is missing."
      exit 1
    fi
    running="$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || echo false)"
    log_out="$(docker logs --tail 200 "${CONTAINER_NAME}" 2>&1 || true)"
    if [[ "${running}" != "true" ]]; then
      ui_err "HAProxy container is not running."
      ui_show_container_logs "Container logs"
      exit 1
    fi
    if echo "${log_out}" | grep -qiE '\[ALERT\]|\[EMERG\]|cannot bind socket|Permission denied'; then
      ui_err "HAProxy reported errors in logs."
      ui_show_container_logs "Container logs"
      exit 1
    fi
    if echo "${log_out}" | grep -qiE 'New worker|Starting HAProxy|already running'; then
      return 0
    fi
  done
  log_out="$(docker logs --tail 200 "${CONTAINER_NAME}" 2>&1 || true)"
  if echo "${log_out}" | grep -qiE '\[ALERT\]|\[EMERG\]|cannot bind socket|Permission denied'; then
    ui_err "HAProxy reported errors in logs after wait."
    ui_show_container_logs "Container logs"
    exit 1
  fi
  running="$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || echo false)"
  if [[ "${running}" == "true" ]]; then
    return 0
  fi
  ui_err "HAProxy did not become ready within 10s."
  ui_show_container_logs "Container logs"
  exit 1
}

load_existing_env() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    return
  fi

  if ! parse_env_file; then
    reset_invalid_env_or_exit
    return
  fi

  if ! validate_loaded_env; then
    reset_invalid_env_or_exit
  fi
}

parse_env_file() {
  local line=""
  local line_no=0
  local key=""
  local value=""
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line_no=$((line_no + 1))
    line="${line%$'\r'}"
    if [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    if [[ ! "${line}" =~ ^([A-Z0-9_]+)=(.*)$ ]]; then
      ENV_ERROR="line ${line_no} has invalid format"
      return 1
    fi
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    case "${key}" in
      LISTEN_PORT|TELEMT_UPSTREAM_PORT|TELEMT_UPSTREAM_HOSTS|SEND_PROXY_V2)
        printf -v "${key}" '%s' "${value}"
        ;;
      *)
        ENV_ERROR="line ${line_no} contains unknown key ${key}"
        return 1
        ;;
    esac
  done < "${ENV_FILE}"
  return 0
}

validate_loaded_env() {
  if [[ -z "${TELEMT_UPSTREAM_HOSTS:-}" ]]; then
    ENV_ERROR="TELEMT_UPSTREAM_HOSTS is empty"
    return 1
  fi
  if [[ -n "${LISTEN_PORT:-}" ]] && { ! [[ "${LISTEN_PORT}" =~ ^[0-9]+$ ]] || (( LISTEN_PORT < 1 || LISTEN_PORT > 65535 )); }; then
    ENV_ERROR="invalid LISTEN_PORT: ${LISTEN_PORT}"
    return 1
  fi
  if [[ -n "${TELEMT_UPSTREAM_PORT:-}" ]] && { ! [[ "${TELEMT_UPSTREAM_PORT}" =~ ^[0-9]+$ ]] || (( TELEMT_UPSTREAM_PORT < 1 || TELEMT_UPSTREAM_PORT > 65535 )); }; then
    ENV_ERROR="invalid TELEMT_UPSTREAM_PORT: ${TELEMT_UPSTREAM_PORT}"
    return 1
  fi
  if [[ -n "${SEND_PROXY_V2:-}" ]] && [[ "${SEND_PROXY_V2}" != "true" && "${SEND_PROXY_V2}" != "false" ]]; then
    ENV_ERROR="SEND_PROXY_V2 must be true or false"
    return 1
  fi
  return 0
}

reset_invalid_env_or_exit() {
  local answer=""
  ui_blank
  ui_err "Invalid env file: ${ENV_FILE}"
  ui_warn "${ENV_ERROR}"
  printf '%s%s%s ' "${UI_BOLD}" "Overwrite from scratch? [y/N]:" "${UI_RESET}"
  read -r answer
  if [[ "${answer}" == "y" || "${answer}" == "Y" ]]; then
    rm -f "${ENV_FILE}"
    unset LISTEN_PORT TELEMT_UPSTREAM_PORT TELEMT_UPSTREAM_HOSTS SEND_PROXY_V2
    ui_info "The env file will be recreated after input."
  else
    ui_err "Fix ${ENV_FILE} and run the script again."
    exit 1
  fi
}

ask_value() {
  local var_name="$1"
  local prompt="$2"
  local default_value="$3"
  local input_value=""
  printf '%s%s%s [%s%s%s]: ' "${UI_BOLD}" "${prompt}" "${UI_RESET}" "${UI_DIM}" "${default_value}" "${UI_RESET}"
  read -r input_value
  if [[ -z "${input_value}" ]]; then
    printf -v "${var_name}" '%s' "${default_value}"
  else
    printf -v "${var_name}" '%s' "${input_value}"
  fi
}

ask_hosts() {
  local default_hosts="${1:-}"
  local entered=""
  printf '%s%s%s [%s%s%s]: ' "${UI_BOLD}" "Telemt IP/FQDN list (comma-separated)" "${UI_RESET}" "${UI_DIM}" "${default_hosts}" "${UI_RESET}"
  read -r entered
  if [[ -z "${entered}" ]]; then
    TELEMT_UPSTREAM_HOSTS="${default_hosts}"
  else
    TELEMT_UPSTREAM_HOSTS="${entered}"
  fi
  TELEMT_UPSTREAM_HOSTS="$(echo "${TELEMT_UPSTREAM_HOSTS}" | tr -d '[:space:]')"
  if [[ -z "${TELEMT_UPSTREAM_HOSTS}" ]]; then
    ui_err "At least one upstream host is required."
    exit 1
  fi
  ui_warn "You may need proxy_protocol = true in the telemt configuration."
}

validate_env() {
  if ! [[ "${LISTEN_PORT}" =~ ^[0-9]+$ ]] || (( LISTEN_PORT < 1 || LISTEN_PORT > 65535 )); then
    ui_err "Invalid LISTEN_PORT: ${LISTEN_PORT}"
    exit 1
  fi
  if ! [[ "${TELEMT_UPSTREAM_PORT}" =~ ^[0-9]+$ ]] || (( TELEMT_UPSTREAM_PORT < 1 || TELEMT_UPSTREAM_PORT > 65535 )); then
    ui_err "Invalid TELEMT_UPSTREAM_PORT: ${TELEMT_UPSTREAM_PORT}"
    exit 1
  fi
  if [[ "${SEND_PROXY_V2}" != "true" && "${SEND_PROXY_V2}" != "false" ]]; then
    ui_err "SEND_PROXY_V2 must be true or false."
    exit 1
  fi
}

generate_backend_servers() {
  local hosts_csv="$1"
  local upstream_port="$2"
  local idx=1
  local result=""
  IFS=',' read -r -a hosts_array <<< "${hosts_csv}"
  for host in "${hosts_array[@]}"; do
    if [[ -z "${host}" ]]; then
      continue
    fi
    result+="    server telemt_${idx} ${host}:${upstream_port} check"$'\n'
    idx=$((idx + 1))
  done
  if [[ -z "${result}" ]]; then
    ui_err "At least one valid upstream host is required."
    exit 1
  fi
  TELEMT_BACKEND_SERVERS="${result%$'\n'}"
}

render_haproxy_cfg() {
  local proxy_suffix=""
  local line=""
  local rendered_line=""
  if [[ "${SEND_PROXY_V2}" == "true" ]]; then
    proxy_suffix=" send-proxy-v2"
  fi

  : > "${OUTPUT_CFG}"
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" == *'${TELEMT_BACKEND_SERVERS}'* ]]; then
      printf '%s\n' "${TELEMT_BACKEND_SERVERS}" >> "${OUTPUT_CFG}"
      continue
    fi
    rendered_line="${line//'${LISTEN_PORT}'/${LISTEN_PORT}}"
    rendered_line="${rendered_line//'${SEND_PROXY_V2_SUFFIX}'/${proxy_suffix}}"
    printf '%s\n' "${rendered_line}" >> "${OUTPUT_CFG}"
  done < <(telemt_haproxy_template_stream)
}

save_env() {
  cat > "${ENV_FILE}" <<EOF
LISTEN_PORT=${LISTEN_PORT}
TELEMT_UPSTREAM_PORT=${TELEMT_UPSTREAM_PORT}
TELEMT_UPSTREAM_HOSTS=${TELEMT_UPSTREAM_HOSTS}
SEND_PROXY_V2=${SEND_PROXY_V2}
EOF
}

validate_haproxy_cfg() {
  docker run --rm \
    -v "${OUTPUT_CFG}:/usr/local/etc/haproxy/haproxy.cfg:ro" \
    "${HAPROXY_IMAGE}" \
    haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
}

deploy() {
  ui_info "Pulling image ${HAPROXY_IMAGE} ..."
  docker pull "${HAPROXY_IMAGE}"
  if docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
    docker rm -f "${CONTAINER_NAME}" >/dev/null
  fi
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    --network host \
    --user 0:0 \
    --ulimit nofile=200000:200000 \
    -v "${OUTPUT_CFG}:/usr/local/etc/haproxy/haproxy.cfg:ro" \
    --log-driver json-file \
    --log-opt max-size=10m \
    --log-opt max-file=3 \
    "${HAPROXY_IMAGE}" >/dev/null
  ui_ok "Container started: ${CONTAINER_NAME}"
}

telemt_install_main() {
  telemt_require_root
  ui_section "telemt-haproxy-balancer — install / update"

  if ! declare -F telemt_embedded_haproxy_cfg_tpl >/dev/null 2>&1; then
    if [[ ! -f "${TEMPLATE_FILE}" ]]; then
      ui_err "Template not found: ${TEMPLATE_FILE}"
      exit 1
    fi
  fi

  ui_section "Docker"
  ensure_docker

  ui_section "Configuration"
  load_existing_env

  LISTEN_PORT="${LISTEN_PORT:-443}"
  TELEMT_UPSTREAM_PORT="${TELEMT_UPSTREAM_PORT:-443}"
  TELEMT_UPSTREAM_HOSTS="${TELEMT_UPSTREAM_HOSTS:-}"
  SEND_PROXY_V2="${SEND_PROXY_V2:-true}"
  HAPROXY_IMAGE="haproxy:latest"

  ask_hosts "${TELEMT_UPSTREAM_HOSTS}"
  ask_value LISTEN_PORT "HAProxy listen port" "${LISTEN_PORT}"
  ask_value TELEMT_UPSTREAM_PORT "Telemt upstream port" "${TELEMT_UPSTREAM_PORT}"
  ask_value SEND_PROXY_V2 "Enable send-proxy-v2 (true/false)" "${SEND_PROXY_V2}"

  validate_env
  generate_backend_servers "${TELEMT_UPSTREAM_HOSTS}" "${TELEMT_UPSTREAM_PORT}"
  render_haproxy_cfg
  save_env

  ui_section "Validate configuration"
  validate_haproxy_cfg
  ui_ok "haproxy -c passed"

  ui_section "Deploy"
  deploy

  ui_section "Wait for HAProxy (up to 10s)"
  wait_for_haproxy_ready
  ui_ok "HAProxy looks healthy"

  ui_section "Summary"
  ui_ok "Done"
  ui_info "Telemt servers: ${TELEMT_UPSTREAM_HOSTS}"
  ui_info "HAProxy port: ${LISTEN_PORT}"
  ui_info "Env file: ${ENV_FILE}"
}

main() {
  telemt_install_main
}

if [[ -z "${TELEMT_BALANCER_MONOLITH:-}" ]]; then
  main "$@"
fi

# --- utils.sh ---

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
  if ! command -v docker >/dev/null 2>&1; then
    ui_err "Not found: docker"
    exit 1
  fi
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

# --- start.sh ---

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
