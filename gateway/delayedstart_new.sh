#!/usr/bin/env bash
# Restart Docker the right way: detect docker path, detect service manager,
# stop cleanly, start cleanly, and verify.

set -Eeuo pipefail

### ---- Config (override via env) -------------------------------------------
WAIT_BEFORE_STOP="${WAIT_BEFORE_STOP:-0}"       # seconds to wait before stopping
STOP_TIMEOUT="${STOP_TIMEOUT:-60}"              # seconds to wait for stop
START_TIMEOUT="${START_TIMEOUT:-90}"            # seconds to wait for start
DOCKER_SERVICE_NAME="${DOCKER_SERVICE_NAME:-docker}"  # unit or service name
### -------------------------------------------------------------------------

log() {
  printf '[%(%Y-%m-%d %H:%M:%S)T] %s\n' -1 "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# 1) Find docker binary
DOCKER_BIN="$(command -v docker || true)"
if [[ -z "${DOCKER_BIN}" ]]; then
  # Common fallbacks
  for p in /usr/bin/docker /usr/local/bin/docker /bin/docker; do
    [[ -x "$p" ]] && DOCKER_BIN="$p" && break
  done
fi
[[ -n "${DOCKER_BIN}" ]] || fail "Docker binary not found in PATH or common locations."

log "Using docker binary: ${DOCKER_BIN} ($("${DOCKER_BIN}" --version 2>/dev/null || echo unknown))"

# 2) Detect service manager
USE_SYSTEMD=false
USE_SYSV=false
if have_cmd systemctl && systemctl >/dev/null 2>&1; then
  USE_SYSTEMD=true
elif have_cmd service; then
  USE_SYSV=true
else
  # Fallback to init.d script if present
  [[ -x "/etc/init.d/${DOCKER_SERVICE_NAME}" ]] || fail "No systemd, no 'service', and no /etc/init.d/${DOCKER_SERVICE_NAME}"
  USE_SYSV=true
fi

# Helper: wait for systemd state
wait_systemd_state() {
  local unit="$1" want_state="$2" timeout="$3"
  local start_ts now
  start_ts=$(date +%s)
  while true; do
    if systemctl is-"${want_state}" --quiet "$unit"; then
      return 0
    fi
    now=$(date +%s)
    if (( now - start_ts > timeout )); then
      return 1
    fi
    sleep 1
  done
}

# Helper: verify docker responds
verify_docker_up() {
  # Socket might take a moment even after service is "active"
  local start_ts=$(date +%s)
  while true; do
    if "${DOCKER_BIN}" info >/dev/null 2>&1; then
      return 0
    fi
    if (( $(date +%s) - start_ts > START_TIMEOUT )); then
      return 1
    fi
    sleep 1
  done
}

# Optional delay before stopping (e.g., to let workloads quiesce)
if (( WAIT_BEFORE_STOP > 0 )); then
  log "Waiting ${WAIT_BEFORE_STOP}s before stopping Docker (WAIT_BEFORE_STOP=${WAIT_BEFORE_STOP})..."
  sleep "${WAIT_BEFORE_STOP}"
fi

# 3) Stop Docker
log "Stopping Docker service (${DOCKER_SERVICE_NAME})..."
if $USE_SYSTEMD; then
  # Prefer systemd unit names docker.service / docker
  UNIT="${DOCKER_SERVICE_NAME}.service"
  # If the exact unit isn't known, try to find it
  if ! systemctl list-unit-files | grep -q "^${DOCKER_SERVICE_NAME}\.service"; then
    # try dockerd.service as a rare fallback
    if systemctl list-unit-files | grep -q "^dockerd\.service"; then
      UNIT="dockerd.service"
      log "Detected dockerd.service instead."
    fi
  fi

  # Stop and wait inactive
  systemctl stop "$UNIT" || fail "systemctl stop $UNIT failed"
  if ! wait_systemd_state "$UNIT" inactive "$STOP_TIMEOUT"; then
    fail "Timed out waiting for $UNIT to stop (>${STOP_TIMEOUT}s)."
  fi
else
  # Legacy SysV/service
  if have_cmd service; then
    service "${DOCKER_SERVICE_NAME}" stop || fail "service ${DOCKER_SERVICE_NAME} stop failed"
  else
    "/etc/init.d/${DOCKER_SERVICE_NAME}" stop || fail "/etc/init.d/${DOCKER_SERVICE_NAME} stop failed"
  fi

  # Best-effort wait until the socket disappears
  start_ts=$(date +%s)
  while [[ -S /var/run/docker.sock ]]; do
    (( $(date +%s) - start_ts > STOP_TIMEOUT )) && fail "Timed out waiting for docker socket to close."
    sleep 1
  done
fi
log "Docker service stopped."

# 4) Start Docker
log "Starting Docker service (${DOCKER_SERVICE_NAME})..."
if $USE_SYSTEMD; then
  UNIT="${DOCKER_SERVICE_NAME}.service"
  systemctl start "$UNIT" || fail "systemctl start $UNIT failed"
  if ! wait_systemd_state "$UNIT" active "$START_TIMEOUT"; then
    fail "Timed out waiting for $UNIT to become active (>${START_TIMEOUT}s)."
  fi
else
  if have_cmd service; then
    service "${DOCKER_SERVICE_NAME}" start || fail "service ${DOCKER_SERVICE_NAME} start failed"
  else
    "/etc/init.d/${DOCKER_SERVICE_NAME}" start || fail "/etc/init.d/${DOCKER_SERVICE_NAME} start failed"
  fi
fi

# 5) Verify Docker is responsive
log "Verifying Docker API is responsive..."
if ! verify_docker_up; then
  fail "Docker did not become responsive within ${START_TIMEOUT}s."
fi

# 6) Success
log "Docker service is up and healthy."

