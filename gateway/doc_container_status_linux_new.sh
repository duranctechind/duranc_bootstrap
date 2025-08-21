#!/usr/bin/env bash
# Auto-restart Docker containers that exited due to error (non-zero exit code).
# Safe, portable, and cron-friendly.

set -Eeuo pipefail

### ---- Config (override via env) -------------------------------------------
DOCKER_SERVICE_NAME="${DOCKER_SERVICE_NAME:-docker}"
LOG_FILE="${LOG_FILE:-$HOME/container_check.txt}"
LIST_FILE="${LIST_FILE:-$HOME/.cont_names.txt}"
LOCK_FILE="${LOCK_FILE:-/tmp/container_check.lock}"
TZ_STR="${TZ_STR:-Asia/Kolkata}"        # for timestamps
DRY_RUN="${DRY_RUN:-false}"             # set to "true" to simulate
OPT_OUT_LABEL="${OPT_OUT_LABEL:-com.duranc.autorestart}"  # set to "off" to skip
### -------------------------------------------------------------------------

log() {
  # Prints ISO timestamp in the configured timezone
  TZ="$TZ_STR" printf '[%(%Y-%m-%d %H:%M:%S %Z)T] %s\n' -1 "$*" | tee -a "$LOG_FILE"
}

fail() {
  log "ERROR: $*"
  exit 1
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# 0) Lock to avoid concurrent runs (cron-safe)
exec 9>"$LOCK_FILE" || { echo "Cannot open lock file $LOCK_FILE"; exit 1; }
if ! flock -n 9; then
  echo "Another instance is running, exiting."
  exit 0
fi
trap 'rm -f "$LOCK_FILE" 2>/dev/null || true' EXIT

# 1) Find docker binary
DOCKER_BIN="$(command -v docker || true)"
if [[ -z "${DOCKER_BIN}" ]]; then
  for p in /usr/bin/docker /usr/local/bin/docker /bin/docker; do
    [[ -x "$p" ]] && DOCKER_BIN="$p" && break
  done
fi
[[ -n "${DOCKER_BIN}" ]] || fail "Docker binary not found in PATH or common locations."

# 2) Basic checks: Docker daemon reachable
if ! "$DOCKER_BIN" info >/dev/null 2>&1; then
  # Try starting service if possible (optional)
  if have_cmd systemctl && systemctl is-enabled --quiet "${DOCKER_SERVICE_NAME}.service" 2>/dev/null; then
    log "Docker daemon not responding. Attempting to start ${DOCKER_SERVICE_NAME}.service ..."
    systemctl start "${DOCKER_SERVICE_NAME}.service" || true
    # Re-check
    "$DOCKER_BIN" info >/dev/null 2>&1 || fail "Docker daemon still not responding after start attempt."
  else
    fail "Docker daemon not responding. Start it and re-run."
  fi
fi

# 3) Build container list (ID + Name) for reference (like your original)
: >"$LIST_FILE"
"$DOCKER_BIN" ps -a --format '{{.ID}} {{.Names}}' > "$LIST_FILE"

# 4) Header in log
{
  echo "================================"
  echo "Docker Path: $DOCKER_BIN"
  TZ="$TZ_STR" date +"Container Check Run Time: %Y-%m-%d %H:%M:%S %Z"
} > "$LOG_FILE"

# 5) Iterate containers and evaluate status
while read -r contID contNAME; do
  [[ -z "${contID:-}" || -z "${contNAME:-}" ]] && continue

  # Fast skip if container opted out via label
  opt_out="$("$DOCKER_BIN" inspect -f '{{ index .Config.Labels "'"$OPT_OUT_LABEL"'" }}' "$contNAME" 2>/dev/null || true)"
  if [[ "${opt_out,,}" == "off" || "${opt_out,,}" == "false" || "${opt_out,,}" == "no" ]]; then
    log "Skipping $contNAME (opt-out label ${OPT_OUT_LABEL}=${opt_out})"
    continue
  fi

  # Gather state
  state_status="$("$DOCKER_BIN" inspect -f '{{.State.Status}}' "$contNAME" 2>/dev/null || echo "unknown")"
  state_running="$("$DOCKER_BIN" inspect -f '{{.State.Running}}' "$contNAME" 2>/dev/null || echo "false")"
  state_exit="$("$DOCKER_BIN" inspect -f '{{.State.ExitCode}}' "$contNAME" 2>/dev/null || echo "255")"
  state_oom="$("$DOCKER_BIN" inspect -f '{{.State.OOMKilled}}' "$contNAME" 2>/dev/null || echo "false")"

  log "Checking: $contNAME (status=$state_status running=$state_running exit=$state_exit oom=$state_oom)"

  # Decision matrix:
  # - running=true      => OK (no action)
  # - status=paused     => leave it alone
  # - status=exited
  #     - exit=0        => user likely stopped it cleanly -> don't restart
  #     - exit!=0       => crash/failed -> restart
  # - status=dead       => restart
  # - unknown/created   => best-effort: if not running and exit!=0 -> restart

  action="none"
  if [[ "$state_running" == "true" ]]; then
    action="skip-running"
  elif [[ "$state_status" == "paused" ]]; then
    action="skip-paused"
  elif [[ "$state_status" == "exited" && "$state_exit" != "0" ]]; then
    action="restart"
  elif [[ "$state_status" == "dead" ]]; then
    action="restart"
  elif [[ "$state_status" == "created" || "$state_status" == "unknown" ]]; then
    if [[ "$state_exit" != "0" ]]; then
      action="restart"
    fi
  fi

  case "$action" in
    restart)
      log 'CRITICAL - '"$contNAME"' - not running (exit code '"$state_exit"'). Restarting...'
      if [[ "${DRY_RUN}" == "true" ]]; then
        log "[DRY_RUN] docker restart $contNAME"
      else
        if "$DOCKER_BIN" restart "$contNAME" >/dev/null; then
          log "*** $contNAME - container restarted successfully."
        else
          log "ERROR: Failed to restart $contNAME"
        fi
      fi
      ;;
    skip-running)
      log "OK - $contNAME is running."
      ;;
    skip-paused)
      log "INFO - $contNAME is paused; leaving it as-is."
      ;;
    *)
      # No action taken; include brief note
      log "INFO - $contNAME requires no action (status=$state_status exit=$state_exit)."
      ;;
  esac

done < "$LIST_FILE"

echo "================================" >> "$LOG_FILE"
