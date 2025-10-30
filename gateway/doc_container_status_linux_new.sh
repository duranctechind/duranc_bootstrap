#!/usr/bin/env bash
#
# doc_container_status_linux_new.sh
#
# Reusable watchdog.
# - Runs from cron every 2 minutes as root in production.
# - Can ALSO be run manually by a normal user (for debugging).
#
# Behavior:
#   1. Look at ALL Docker containers on this host (not just duranc_gateway_*).
#   2. If any container is NOT running:
#        - If it's part of a docker compose project, run `docker compose up -d`
#          for that whole project (once per project per run).
#        - Otherwise, try `docker start <container>`.
#
# This ensures gateways (and any other services) auto-heal.
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
  # Fallbacks for manual (non-root) runs
  LOG_FILE="${HOME}/duranc-status.log"
  LOCK_FILE="${TMPDIR:-/tmp}/duranc_status.lock.$USER"
fi

DOCKER_SERVICE_NAME="${DOCKER_SERVICE_NAME:-docker}"

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
# Prepare dirs (handle both root / non-root)
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
# Locate docker binary and ensure daemon is live
########################################
DOCKER_BIN="$(command -v docker || true)"
if [ -z "$DOCKER_BIN" ]; then
  for p in /usr/bin/docker /usr/local/bin/docker /bin/docker; do
    [ -x "$p" ] && DOCKER_BIN="$p" && break
  done
fi
[ -n "$DOCKER_BIN" ] || fatal "docker binary not found"

# Ensure daemon is live.
# Root path: we can try to start/recover Docker via systemctl.
# Non-root path: we just check; if it's dead we bail gracefully.
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
# Extract docker compose metadata from container
# Output: "<project> <service> <workdir>" or "" if not compose
########################################
get_compose_meta() {
  local cname="$1"
  local project service workdir
  project="$("$DOCKER_BIN" inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$cname" 2>/dev/null || true)"
  service="$("$DOCKER_BIN" inspect -f '{{ index .Config.Labels "com.docker.compose.service" }}' "$cname" 2>/dev/null || true)"
  workdir="$("$DOCKER_BIN" inspect -f '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' "$cname" 2>/dev/null || true)"

  # If no project label -> not compose
  if [ -z "$project" ] || [ "$project" = "<no value>" ]; then
    return 1
  fi

  # Some engines don't fill working_dir. Try to guess from first bind mount.
  if [ -z "$workdir" ] || [ "$workdir" = "<no value>" ]; then
    workdir="$("$DOCKER_BIN" inspect -f '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}} {{end}}{{end}}' "$cname" | awk 'NR==1{print $1}')"
  fi

  echo "$project $service $workdir"
  return 0
}

########################################
# Heal a full compose project
########################################
heal_compose_stack() {
  local project="$1"
  local workdir="$2"

  # find a compose file to run
  local compose_file=""
  for cand in docker-compose.yml compose.yml docker-compose.yaml compose.yaml; do
    if [ -f "$workdir/$cand" ]; then
      compose_file="$workdir/$cand"
      break
    fi
  done

  if [ -z "$compose_file" ]; then
    log "WARN: compose stack '$project' has no compose file in $workdir"
    return 1
  fi

  if [ "$IS_ROOT" -ne 1 ]; then
    log "NOTICE: Would heal compose stack '$project', but not root. Try sudo."
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
# Heal a single plain container
########################################
heal_single_container() {
  local cname="$1"
  if [ "$IS_ROOT" -ne 1 ]; then
    log "NOTICE: Container '$cname' is down; would 'docker start' but not root. Try sudo."
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
echo "Host: $(hostname)"           | tee -a "$LOG_FILE"
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

  # already up? skip.
  if [ "$state_running" = "true" ]; then
    continue
  fi

  # down or exited => heal attempt
  meta="$(get_compose_meta "$cname" || true)"
  if [ -n "$meta" ]; then
    project="$(echo "$meta" | awk '{print $1}')"
    workdir="$(echo "$meta" | awk '{print $3}')"

    # avoid repeating project heal
    if [ -n "$project" ] && [ -z "${healed_project[$project]+x}" ]; then
      heal_compose_stack "$project" "$workdir"
      healed_project[$project]="yes"
    else
      log "Compose project '$project' already healed in this run. Skipping duplicate."
    fi
  else
    heal_single_container "$cname"
  fi
done

log "Watchdog run complete."
log "================================"
exit 0
