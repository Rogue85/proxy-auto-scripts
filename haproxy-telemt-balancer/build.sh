#!/usr/bin/env bash
set -euo pipefail

PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${PKG_DIR}/.." && pwd)"
SRC_DIR="${PKG_DIR}/src"
DIST_DIR="${REPO_ROOT}/dist"
OUT="${DIST_DIR}/telemt-haproxy-balancer.sh"
COMMON_UI="${REPO_ROOT}/common/lib_ui.sh"
COMMON_PRIV="${REPO_ROOT}/common/telemt_privilege.sh"

mkdir -p "${DIST_DIR}"

if [[ ! -f "${COMMON_UI}" ]]; then
  echo "Missing ${COMMON_UI}" >&2
  exit 1
fi
if [[ ! -f "${COMMON_PRIV}" ]]; then
  echo "Missing ${COMMON_PRIV}" >&2
  exit 1
fi
if [[ ! -f "${PKG_DIR}/haproxy.cfg.tpl" ]]; then
  echo "Missing ${PKG_DIR}/haproxy.cfg.tpl" >&2
  exit 1
fi
for f in install.sh utils.sh start.sh; do
  if [[ ! -f "${SRC_DIR}/${f}" ]]; then
    echo "Missing ${SRC_DIR}/${f}" >&2
    exit 1
  fi
done

{
  printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'export TELEMT_BALANCER_MONOLITH=1' ''
  printf '%s\n' '# --- lib_ui.sh (from common) ---'
  tail -n +2 "${COMMON_UI}"
  printf '\n%s\n' '# --- telemt_privilege.sh (from common) ---'
  tail -n +2 "${COMMON_PRIV}"
  printf '\n%s\n' '# --- haproxy.cfg.tpl (embedded) ---'
  printf '%s\n' 'telemt_embedded_haproxy_cfg_tpl() {'
  printf '%s\n' "cat <<'__TELEMT_HAPROXY_TPL__'"
  cat "${PKG_DIR}/haproxy.cfg.tpl"
  printf '%s\n' '__TELEMT_HAPROXY_TPL__'
  printf '%s\n' '}'
  printf '\n%s\n' '# --- install.sh ---'
  tail -n +3 "${SRC_DIR}/install.sh"
  printf '\n%s\n' '# --- utils.sh ---'
  tail -n +3 "${SRC_DIR}/utils.sh"
  printf '\n%s\n' '# --- start.sh ---'
  tail -n +3 "${SRC_DIR}/start.sh"
} > "${OUT}"

chmod +x "${OUT}"
echo "Wrote ${OUT}"
