#!/bin/bash
#
# duranc_gw_rasp_pi.sh -- Duranc VMS Gateway installer for Raspberry Pi 4 and Pi 5
#
# ONE script for both boards. Pi 4 and Pi 5 are both aarch64 and run the same
# durancai/*-gateway-rasp-pi image (a single linux/arm64 image as of 02-09-2026), so the
# old _4 / _5 pair had nothing real to differ on: their delayedstart and
# doc_container_status helpers were byte-identical, and only the filenames, one PyYAML pin
# and a dead ":pi5" image tag separated them. The one genuine per-board difference is RAM,
# which is measured here and turned into the container's Node heap cap.
#
# THIS FILE IS A BUILD TEMPLATE. __DOCKER_HUB_USER__ and __DOCKER_HUB_TOKEN__ are filled in
# from repository secrets by .github/workflows/build-rasp-pi-installers.yml, which then
# compiles it with shc into duranc_gw_rasp_pi{,_prod,_nas}.sh.x. Never commit real
# credentials here -- this repository is public.
#
# Usage (compiled form):
#   duranc_gw_rasp_pi.sh.x                 # mode baked in at build time
#   duranc_gw_rasp_pi.sh.x prod            # or overridden per run
#   DURANC_GW_MODE=nas duranc_gw_rasp_pi.sh.x
#
#   staging  durancai/staging-gateway-rasp-pi:latest     + docker volumes
#   prod     durancai/production-gateway-rasp-pi:latest  + docker volumes
#   nas      durancai/production-gateway-rasp-pi:latest  + /local-storage bind mounts
#
# Requires the 64-bit Raspberry Pi OS or Ubuntu Server arm64. Safe to re-run: every step
# is guarded, and the cron entries are rewritten rather than appended.

BOOTSTRAP_RAW="https://raw.githubusercontent.com/duranctechind/duranc_bootstrap/master/gateway"
SCRIPTS_DIR="/.scripts"
CRON_MARK="# <DURANC-GW>"
DOCKER_HUB_USER="__DOCKER_HUB_USER__"
DOCKER_HUB_TOKEN="__DOCKER_HUB_TOKEN__"

MODE="${1:-${DURANC_GW_MODE:-staging}}"

say()  { echo "[duranc-gw] $*"; }
fail() { echo "[duranc-gw] ERROR: $*" >&2; exit 1; }

pause_exit() {
    # Only wait for a key when a human is actually at a terminal.
    [ -t 0 ] && read -n 1 -s -r -p "Press any key to exit"
    echo
    exit 1
}

# run a slow, quiet command behind a spinner so the screen never looks frozen.
# The command is a fixed shell string (our own text, never user input); eval keeps
# pipes such as the docker-login one intact. On a non-terminal (piped install) it
# just prints start/done instead of animating. On failure the captured output is shown.
# ponytail: eval of literal strings only; the spinner is for steps with no native progress.
run_step() {
    local msg="$1" cmd="$2" log rc
    log="$(mktemp)"
    ( eval "$cmd" ) >"$log" 2>&1 &
    local pid=$! frames='|/-\' i=0
    if [ -t 1 ]; then
        printf '\033[?25l' 2>/dev/null   # hide cursor
        while kill -0 "$pid" 2>/dev/null; do
            printf '\r[duranc-gw] %s %s ' "$msg" "${frames:i++%4:1}"
            sleep 0.2
        done
        printf '\033[?25h\r' 2>/dev/null # show cursor, return to line start
    else
        printf '[duranc-gw] %s ...\n' "$msg"
    fi
    wait "$pid"; rc=$?
    if [ "$rc" -eq 0 ]; then
        say "$msg ... done"
    else
        say "$msg ... FAILED"
        sed 's/^/    /' "$log"
    fi
    rm -f "$log"
    return $rc
}

case "$MODE" in
    staging) COMPOSE_SRC="doc-comp-gw-rasp-pi.yml"      ;;
    prod)    COMPOSE_SRC="doc-comp-gw-rasp-pi-prod.yml" ;;
    nas)     COMPOSE_SRC="doc-comp-gw-rasp-pi-nas.yml"  ;;
    *)       fail "unknown mode '$MODE' (expected staging, prod or nas)" ;;
esac
COMPOSE_FILE="$HOME/.dur-gw-rasp-pi.yml"

# ---------------------------------------------------------------------------
# 1. Board and OS checks
#
# The gateway image is linux/arm64 ONLY. On a 32-bit Raspberry Pi OS (armv7l) docker would
# fail the pull with an unhelpful "no matching manifest" from inside compose, so refuse up
# front and say what to do about it.
# ---------------------------------------------------------------------------
ARCH="$(uname -m)"
DPKG_ARCH="$(dpkg --print-architecture 2>/dev/null)"
MODEL="$(tr -d '\0' < /proc/device-tree/model 2>/dev/null)"
[ -n "$MODEL" ] || MODEL="unknown (not a Raspberry Pi?)"
say "board : $MODEL"
say "arch  : $ARCH${DPKG_ARCH:+ / $DPKG_ARCH}"
say "mode  : $MODE"

if [ "$ARCH" != "aarch64" ] || [ "${DPKG_ARCH:-arm64}" != "arm64" ]; then
    echo >&2
    echo "The Duranc gateway image is 64-bit (linux/arm64) only, but this system reports" >&2
    echo "kernel '$ARCH' and userland '${DPKG_ARCH:-unknown}'." >&2
    echo "Install the 64-bit Raspberry Pi OS (or Ubuntu Server arm64) and re-run. A 64-bit" >&2
    echo "kernel with a 32-bit userland is not enough: 'dpkg --print-architecture' must" >&2
    echo "read arm64." >&2
    pause_exit
fi

# RAM -> Node heap cap. The image ships 2048MB, right for a Pi 5 or a 4/8GB Pi 4; a 2GB
# Pi 4 has to be told to use less, or V8 will commit more than the board owns.
MEM_MB=$(awk '/^MemTotal:/ { printf "%d", $2 / 1024 }' /proc/meminfo 2>/dev/null)
[ -n "$MEM_MB" ] || MEM_MB=2048
if [ "$MEM_MB" -ge 3000 ]; then NODE_HEAP=2048; else NODE_HEAP=1024; fi
say "memory: ${MEM_MB}MB -> Node heap ${NODE_HEAP}MB"

# ---------------------------------------------------------------------------
# 2. NAS pre-flight (nas mode only)
# ---------------------------------------------------------------------------
if [ "$MODE" = "nas" ]; then
    NAS_LINK=/local-storage
    if [ -L "$NAS_LINK" ]; then
        if [ -e "$NAS_LINK" ]; then
            say "local storage folder is linked to the NAS/external HDD"
        else
            echo "$NAS_LINK is a BROKEN symbolic link. Fix the NAS mount and re-run." >&2
            pause_exit
        fi
    elif [ -e "$NAS_LINK" ]; then
        echo "$NAS_LINK exists but is not a symbolic link. Link it to the NAS and re-run." >&2
        pause_exit
    else
        echo "$NAS_LINK is missing. Create the symbolic link to the NAS and re-run." >&2
        pause_exit
    fi
fi

# ---------------------------------------------------------------------------
# 3. Passwordless sudo for the install user
# ---------------------------------------------------------------------------
sudo ls >/dev/null || fail "sudo access is required"
SUDOERS_LINE="$USER ALL=(ALL) NOPASSWD:ALL"
if sudo grep -qF "$SUDOERS_LINE" /etc/sudoers; then
    say "sudo permission entry already present"
else
    say "adding passwordless sudo for $USER"
    echo "$SUDOERS_LINE" | sudo tee -a /etc/sudoers >/dev/null
fi

# ---------------------------------------------------------------------------
# 4. Swap
# ---------------------------------------------------------------------------
if sudo grep -q '/mnt/4GB.swap' /etc/fstab; then
    say "swap entry already present"
elif sudo fallocate -l 4G /mnt/4GB.swap 2>/dev/null &&
     sudo mkswap /mnt/4GB.swap >/dev/null 2>&1 &&
     sudo chmod 600 /mnt/4GB.swap &&
     sudo swapon /mnt/4GB.swap 2>/dev/null; then
    echo "/mnt/4GB.swap  none  swap  sw 0  0" | sudo tee -a /etc/fstab >/dev/null
    say "added 4GB swap"
else
    sudo rm -f /mnt/4GB.swap
    say "WARNING: could not add swap, continuing without it"
fi

# ---------------------------------------------------------------------------
# 5. Docker engine and compose v2
#
# Compose v2 is required, not merely preferred: the compose files use current-spec volume
# syntax ("name:" with "external: true"), which pip's docker-compose 1.28 cannot parse.
# The convenience script installs docker-ce together with the compose plugin, which
# retires the old pip3 + libhdf5 + libffi + PyYAML==5.3.1 + PATH sequence entirely.
# ---------------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
    say "docker not found -- installing from get.docker.com"
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh || fail "could not download the docker installer"
    sudo sh /tmp/get-docker.sh || fail "docker installation failed"
    rm -f /tmp/get-docker.sh
    sudo usermod -aG docker "$USER"
    say "NOTE: $USER was added to the docker group; that takes effect on next login."
fi

if ! sudo docker compose version >/dev/null 2>&1; then
    run_step "installing the docker compose plugin" \
        "sudo apt-get update -qq && sudo apt-get install -y docker-compose-plugin" || true
fi
sudo docker compose version >/dev/null 2>&1 || fail \
    "docker compose v2 is unavailable. Install it with 'sudo apt-get install docker-compose-plugin' (it needs Docker's own apt repo, which get.docker.com adds) and re-run."

say "docker  : $(sudo docker --version)"
say "compose : $(sudo docker compose version --short 2>/dev/null)"
sudo systemctl enable docker >/dev/null 2>&1

# ---------------------------------------------------------------------------
# 6. Helper scripts and cron
#
# 0755 root-owned, not 0777: the delayed-start entry runs out of the ROOT crontab, so a
# world-writable script there is a local root escalation. 0755 still lets the status check
# run under $USER.
# ---------------------------------------------------------------------------
say "installing helper scripts into $SCRIPTS_DIR"
sudo mkdir -p "$SCRIPTS_DIR"
for helper in delayedstart_rasp_pi.sh.x doc_container_status_rasp_pi.sh.x; do
    sudo curl -fsSL "$BOOTSTRAP_RAW/$helper" -o "$SCRIPTS_DIR/$helper" || \
        fail "could not download $helper from $BOOTSTRAP_RAW"
    [ -s "$SCRIPTS_DIR/$helper" ] || fail "$helper downloaded empty"
done
sudo chown root:root "$SCRIPTS_DIR" "$SCRIPTS_DIR"/*.sh.x
sudo chmod 0755 "$SCRIPTS_DIR" "$SCRIPTS_DIR"/*.sh.x

# Rewrite our own cron lines instead of appending. The old installers grepped for
# "delayedstart_rasp_pi", a substring that also matches the Pi-5 variant's entry, so
# upgrading a board left a stale line pointing at a helper nothing refreshes any more.
# Going through 'crontab -' also gets the file validated, unlike appending straight to
# /var/spool/cron/crontabs/root.
say "updating the root crontab"
REBOOT_BIN="$(command -v reboot || echo /sbin/reboot)"
{
    sudo crontab -l 2>/dev/null | grep -vE 'delayedstart_rasp_pi|doc_container_status_rasp_pi|<DURANC-GW>'
    echo "45 23 * * * $REBOOT_BIN $CRON_MARK nightly reboot"
    echo "@reboot $SCRIPTS_DIR/delayedstart_rasp_pi.sh.x $CRON_MARK"
    echo "*/5 * * * * sudo -u $USER $SCRIPTS_DIR/doc_container_status_rasp_pi.sh.x $CRON_MARK"
} | sudo crontab - || fail "could not write the root crontab"

# ---------------------------------------------------------------------------
# 7. Docker Hub login (read-only pull token, never written to a file)
#
# Run under sudo so the credentials land in /root/.docker/config.json, which is the exact
# path the compose file mounts into watchtower. The old installers symlinked
# ~/.docker/auth.json and mounted "~/.docker/auth.json", a path sudo does not expand the
# way it looks -- a dangling mount there is how a whole estate silently stopped
# auto-updating (18-08-2026).
# ---------------------------------------------------------------------------
run_step "logging in to Docker Hub as $DOCKER_HUB_USER" \
    "echo '$DOCKER_HUB_TOKEN' | sudo docker login --username '$DOCKER_HUB_USER' --password-stdin" || \
    fail "docker login failed -- check network access to registry-1.docker.io"
sudo test -f /root/.docker/config.json || \
    fail "docker login reported success but /root/.docker/config.json is missing"

# ---------------------------------------------------------------------------
# 8. Storage
# ---------------------------------------------------------------------------
if [ "$MODE" = "nas" ]; then
    say "creating NAS-backed storage folders"
    sudo mkdir -p /local-storage/gw-files /local-storage/motion-files
else
    say "creating docker volumes"
    sudo docker volume create --name=stg-gw-files     >/dev/null
    sudo docker volume create --name=stg-motion-files >/dev/null
fi

# ---------------------------------------------------------------------------
# 9. Compose file
# ---------------------------------------------------------------------------
say "fetching $COMPOSE_SRC"
curl -fsSL "$BOOTSTRAP_RAW/$COMPOSE_SRC" -o "$COMPOSE_FILE" || \
    fail "could not download $COMPOSE_SRC from $BOOTSTRAP_RAW"
grep -q 'duranc_gateway' "$COMPOSE_FILE" || \
    fail "$COMPOSE_FILE does not look like a gateway compose file"

# Board-specific Node heap, measured in step 1.
sed -i "s|__NODE_HEAP__|${NODE_HEAP}|g" "$COMPOSE_FILE"
sudo docker compose -f "$COMPOSE_FILE" config >/dev/null || \
    fail "$COMPOSE_FILE is not valid for this docker compose version"

# Pull the image with docker's OWN progress bars visible, rather than letting the pull
# happen silently inside "up -d". The gateway image is a few hundred MB and the first
# download on a Pi can take several minutes -- a blank cursor there looks hung, which is
# exactly what it looked like before. "up -d" afterward is quick because the image is local.
say "downloading the gateway image (first run: this can take several minutes)"
sudo docker compose -f "$COMPOSE_FILE" pull || fail "could not download the gateway image"

run_step "starting the gateway container" \
    "sudo docker compose -f '$COMPOSE_FILE' up -d" || fail "docker compose up failed"

# ---------------------------------------------------------------------------
# 10. Show the result
# ---------------------------------------------------------------------------
sleep 10
clear
sudo docker ps -a
echo
say "installed on $MODEL in '$MODE' mode. Compose file: $COMPOSE_FILE"
say "gateway logs:  docker exec duranc_gateway ls /persistent/logs"
say "service state: docker exec duranc_gateway supervisorctl status"

# ---------------------------------------------------------------------------
# 11. Activate the docker group in THIS terminal
#
# usermod added $USER to the docker group, but this shell was started before that, so it
# has not picked the group up yet -- a plain "docker ps" here fails with
# "permission denied ... /var/run/docker.sock" until the user logs out and back in.
# Make sure the membership exists, then exec 'newgrp docker', which REPLACES this process
# with a shell that carries the group, so docker works in the same terminal with no
# re-login. exec must be the last thing the script does (nothing after it runs). On a
# non-interactive/piped run there is no shell to hand over to, so we just tell the user.
# ---------------------------------------------------------------------------
if ! getent group docker >/dev/null 2>&1; then
    :   # no docker group at all (shouldn't happen after a docker install) -- nothing to do
elif getent group docker | tr ',' ' ' | grep -qw "$USER" && docker ps >/dev/null 2>&1; then
    :   # already a member AND active in this shell -- docker already works, leave as is
else
    getent group docker | tr ',' ' ' | grep -qw "$USER" || sudo usermod -aG docker "$USER"
    if [ -t 0 ] && [ -t 1 ] && command -v newgrp >/dev/null 2>&1; then
        echo
        say "Activating the docker group in this terminal so 'docker' works without sudo."
        say "You are now in a docker-enabled shell -- type 'exit' when finished."
        exec newgrp docker
    else
        echo
        say "NOTE: log out and back in (or run 'newgrp docker') to use docker without sudo."
    fi
fi
