#!/bin/bash
#
# delayedstart_rasp_pi.sh -- restart the Docker daemon shortly after boot (Pi 4 and Pi 5).
#
# Runs from the root crontab as "@reboot". The Pi brings up its network and its USB/NVMe
# storage after cron fires, and a docker daemon that started before them leaves containers
# wedged on missing binds or a dead default route, so the daemon gets one clean cycle once
# the board has settled.
#
# Identical for Pi 4 and Pi 5 -- the old _4 and _5 copies of this file were byte-identical.

sleep 30

log() { echo "[delayedstart] $*"; }

if command -v systemctl >/dev/null 2>&1; then
    stop_docker()  { systemctl stop docker;  }
    start_docker() { systemctl start docker; }
elif [ -x /usr/sbin/service ]; then
    stop_docker()  { /usr/sbin/service docker stop;  }
    start_docker() { /usr/sbin/service docker start; }
else
    stop_docker()  { service docker stop;  }
    start_docker() { service docker start; }
fi

log "stopping the Docker service"
stop_docker
log "Docker service stopped"

sleep 10

log "starting the Docker service"
start_docker
log "Docker service started"

# Confirm the daemon actually answers, rather than assuming the unit going active is
# enough -- the socket can lag the service by a few seconds.
for _ in $(seq 1 30); do
    if docker info >/dev/null 2>&1; then
        log "Docker is responsive"
        exit 0
    fi
    sleep 2
done

log "WARNING: Docker did not become responsive within 60s"
exit 1
