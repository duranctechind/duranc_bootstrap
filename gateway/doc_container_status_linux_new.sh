#!/usr/bin/env bash
#
# doc_container_status_linux_new.sh
#
# Reusable watchdog.
# - Runs from cron every 2 minutes as root in production.
# - Can ALSO be run manually by a normal user (for debugging).
#
# Behavior:
#   - Look at ALL Docker containers on this host.
#   - If any container is NOT running:
#       * If it's part of a docker compose project:
#           - Try to bring that whole compose project up.
#           - If compose metadata is incomplete (no working_dir),
#             but the project is "duranc_gateway_stack", fall back to the
#             known bundle path so we can still heal gateways.
#           - If still not healable, fall back to `docker start <container>`.
#       * If it's NOT from compose, just `docker start <container>`.
#
set -Eeuo pipefail

########################################
# Detect privilege level
########################################
IS_ROOT=0
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
  IS_ROOT=1
fi

########################################
# Paths / Files
########################################
TZ_STR="${TZ_STR:-Asia/Kolkata}"

if [ "$IS_ROOT" -eq 1 ]; then
  LOG_FILE="/var/log/duranc-status.log"
  LOCK_FILE="/var/lock/duranc_status.lock"
else
  LOG_FILE="${HOME}/duranc-status.log"
  LOCK_FILE="${TMPDIR:-/tmp}/duranc_status.lock.$USER"
fi

DOCKER_SERVICE_NAME="${DOCKER_SERVICE_NAME:-docker}"

# Hardcoded fallback for gateway stack
GATEWAY_PROJECT="duranc_gateway_stack"
GATEWAY_BUNDLE_DIR="/opt/duranc/duranc-gateway/gateway-bundle"
GATEWAY_COMPOSE_FILE="${GATEWAY_BUNDLE_DIR}/docker-compose.yml"

########################################
# Helpers
########################################
log() {
  TZ="$TZ_STR" printf '[%(%Y-%m-%d %H:%M:%S %Z)T] %s\n' -1 "$*" | tee -a "$LOG_FILE"
}

fatal() {
  log "FATAL: $*"
  exit 1
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

########################################
# Prepare dirs
########################################
if [ "$IS_ROOT" -eq 1 ]; then
  mkdir -p /var/lock /var/log || true
else
  mkdir -p "$(dirname "$LOG_FILE")" || true
  mkdir -p "$(dirname "$LOCK_FILE")" || true
fi

########################################
# Concurrency guard
########################################
exec 9>"$LOCK_FILE" || { echo "Cannot open lock $LOCK_FILE"; exit 1; }
if ! flock -n 9; then
  echo "Another watchdog run is still active, exiting."
  exit 0
fi
trap 'rm -f "$LOCK_FILE" 2>/dev/null || true' EXIT

########################################
# Docker availability
########################################
DOCKER_BIN="$(command -v docker || true)"
if [ -z "$DOCKER_BIN" ]; then
  for p in /usr/bin/docker /usr/local/bin/docker /bin/docker; do
    [ -x "$p" ] && DOCKER_BIN="$p" && break
  done
fi
[ -n "$DOCKER_BIN" ] || fatal "docker binary not found"

if ! "$DOCKER_BIN" info >/dev/null 2>&1; then
  if [ "$IS_ROOT" -eq 1 ] && have_cmd systemctl && systemctl is-enabled --quiet "${DOCKER_SERVICE_NAME}.service" 2>/dev/null; then
    log "Docker not responding -> starting ${DOCKER_SERVICE_NAME}.service ..."
    systemctl start "${DOCKER_SERVICE_NAME}.service" || true
    "$DOCKER_BIN" info >/dev/null 2>&1 || fatal "Docker still not responding after start attempt"
  else
    fatal "Docker daemon not responding (are you root or in docker group?)"
  fi
fi

########################################
# Extract compose meta from a container
# stdout: "<project> <service> <workdir>"
# return 0 if compose-managed, else 1
########################################
get_compose_meta() {
  local cname="$1"
  local project service workdir
  project="$("$DOCKER_BIN" inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$cname" 2>/dev/null || true)"
  service="$("$DOCKER_BIN" inspect -f '{{ index .Config.Labels "com.docker.compose.service" }}' "$cname" 2>/dev/null || true)"
  workdir="$("$DOCKER_BIN" inspect -f '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' "$cname" 2>/dev/null || true)"

  # Not compose-managed?
  if [ -z "$project" ] || [ "$project" = "<no value>" ]; then
    return 1
  fi

  # Some engines don't fill working_dir. Try guess from first bind mount:
  if [ -z "$workdir" ] || [ "$workdir" = "<no value>" ]; then
    workdir="$("$DOCKER_BIN" inspect -f '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}} {{end}}{{end}}' "$cname" | awk 'NR==1{print $1}')"
  fi

  echo "$project $service $workdir"
  return 0
}

########################################
# Heal compose stack (generic)
########################################
heal_compose_stack_generic() {
  local project="$1"
  local workdir="$2"

  # Try common compose file names under detected workdir
  local compose_file=""
  for cand in docker-compose.yml compose.yml docker-compose.yaml compose.yaml; do
    if [ -n "$workdir" ] && [ -f "$workdir/$cand" ]; then
      compose_file="$workdir/$cand"
      break
    fi
  done

  if [ -z "$compose_file" ]; then
    log "WARN: no compose file found in '$workdir' for project '$project'"
    return 1
  fi

  if [ "$IS_ROOT" -ne 1 ]; then
    log "NOTICE: would heal compose stack '$project' using $compose_file, but not root. Skipping."
    return 0
  fi

  log "Healing compose stack '$project' (dir=$workdir file=$(basename "$compose_file")) ..."
  (
    cd "$workdir"
    COMPOSE_PROJECT_NAME="$project" "$DOCKER_BIN" compose -f "$compose_file" up -d || {
      log "ERROR: compose up -d failed for project '$project'"
      return 1
    }
  )
  log "Heal complete for compose stack '$project'."
  return 0
}

########################################
# Heal compose stack (gateway fallback)
########################################
heal_compose_stack_gateway_fallback() {
  # This uses the known duranc gateway bundle path
  if [ "$IS_ROOT" -ne 1 ]; then
    log "NOTICE: would heal gateway stack '$GATEWAY_PROJECT' via ${GATEWAY_COMPOSE_FILE}, but not root. Skipping."
    return 0
  fi

  if [ ! -f "$GATEWAY_COMPOSE_FILE" ]; then
    log "ERROR: gateway compose file missing at $GATEWAY_COMPOSE_FILE"
    return 1
  fi

  log "Healing gateway stack '$GATEWAY_PROJECT' via fallback ($GATEWAY_COMPOSE_FILE) ..."
  (
    cd "$GATEWAY_BUNDLE_DIR"
    COMPOSE_PROJECT_NAME="$GATEWAY_PROJECT" "$DOCKER_BIN" compose -f "$GATEWAY_COMPOSE_FILE" up -d || {
      log "ERROR: compose up -d failed for gateway fallback '$GATEWAY_PROJECT'"
      return 1
    }
  )
  log "Heal complete for gateway stack '$GATEWAY_PROJECT'."
  return 0
}

########################################
# Heal single container (last resort)
########################################
heal_single_container() {
  local cname="$1"

  if [ "$IS_ROOT" -ne 1 ]; then
    log "NOTICE: '$cname' is down; would 'docker start' but not root. Skipping."
    return 0
  fi

  log "Attempting to start standalone container '$cname' ..."
  "$DOCKER_BIN" start "$cname" >/dev/null 2>&1 && \
    log "Started container '$cname'." || \
    log "ERROR: failed to start container '$cname'."
}

########################################
# Main
########################################
log "================================"
TZ="$TZ_STR" date +"Watchdog Run: %Y-%m-%d %H:%M:%S %Z" | tee -a "$LOG_FILE"
echo "Host: $(hostname)" | tee -a "$LOG_FILE"
echo "Docker: $("$DOCKER_BIN" --version 2>/dev/null)" | tee -a "$LOG_FILE"
[ "$IS_ROOT" -eq 1 ] && echo "Mode: root/cron"   | tee -a "$LOG_FILE" || echo "Mode: user/test" | tee -a "$LOG_FILE"

declare -A healed_project

ALL_CONTAINERS="$("$DOCKER_BIN" ps -a --format '{{.Names}}')"

for cname in $ALL_CONTAINERS; do
  [ -z "$cname" ] && continue

  state_status="$("$DOCKER_BIN" inspect -f '{{.State.Status}}' "$cname" 2>/dev/null || echo "unknown")"
  state_running="$("$DOCKER_BIN" inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo "false")"
  state_exit="$("$DOCKER_BIN" inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo "255")"

  log "Check $cname: status=$state_status running=$state_running exit=$state_exit"

  # If it's running, skip.
  if [ "$state_running" = "true" ]; then
    continue
  fi

  # Not running -> heal
  meta="$(get_compose_meta "$cname" || true)"
  if [ -n "$meta" ]; then
    project="$(echo "$meta" | awk '{print $1}')"
    workdir="$(echo "$meta" | awk '{print $3}')"

    # skip duplicate heal of same project in the same pass
    if [ -n "$project" ] && [ -z "${healed_project[$project]+x}" ]; then
      log "Container '$cname' belongs to compose project '$project' (workdir='$workdir'). Needs heal."

      # 1. Try generic heal with discovered workdir
      if [ -n "$workdir" ] && heal_compose_stack_generic "$project" "$workdir"; then
        healed_project[$project]="yes"
        continue
      fi

      # 2. If generic failed and this is the known gateway project, do gateway fallback
      if [ "$project" = "$GATEWAY_PROJECT" ]; then
        if heal_compose_stack_gateway_fallback; then
          healed_project[$project]="yes"
          continue
        fi
      fi

      # 3. Last resort: try to start the single container
      heal_single_container "$cname"
      healed_project[$project]="yes"
    else
      log "Compose project '$project' already healed in this run. Skipping duplicate."
    fi
  else
    # No compose meta, standalone container
    heal_single_container "$cname"
  fi
done

log "Watchdog run complete."
log "================================"
exit 0
