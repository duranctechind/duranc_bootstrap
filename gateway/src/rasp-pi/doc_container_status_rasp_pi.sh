#!/bin/bash
#
# doc_container_status_rasp_pi.sh -- restart any container that is not running (Pi 4 and Pi 5).
#
# Runs from the root crontab every 5 minutes as the install user. Identical for Pi 4 and
# Pi 5 -- the old _4 and _5 copies of this file were byte-identical.

DOCKER_BIN="$(command -v docker)"
if [ -z "$DOCKER_BIN" ]; then
    echo "UNKNOWN - docker binary not found"
    exit 3
fi

# A run that overlaps the previous one can fight it over the same restart, and on a Pi a
# restart is slow enough for that to happen. Skip rather than queue.
LOCK="/tmp/.duranc_gw_status.lock"
exec 9>"$LOCK" 2>/dev/null || true
if command -v flock >/dev/null 2>&1; then
    flock -n 9 || { echo "another status check is still running, skipping"; exit 0; }
fi

if ! "$DOCKER_BIN" info >/dev/null 2>&1; then
    echo "CRITICAL - the docker daemon is not responding"
    exit 2
fi

rc=0

# Read straight from docker rather than through a temp file in $HOME, and ask for the
# running state in the same call so a container that changes state mid-run cannot be
# reported against a name that no longer exists.
while read -r name state; do
    [ -n "$name" ] || continue
    echo "container $name state is $state"
    if [ "$state" != "running" ]; then
        echo "CRITICAL - $name is not running, restarting it"
        if "$DOCKER_BIN" restart "$name" >/dev/null 2>&1; then
            echo "$name restarted"
        else
            echo "ERROR - could not restart $name"
            rc=2
        fi
    fi
done < <("$DOCKER_BIN" ps -a --format '{{.Names}} {{.State}}')

exit $rc
