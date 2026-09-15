#!/usr/bin/env bash
# =====================================================================
#  RETIRED 2026-09-15 - DO NOT USE THIS INSTALLER
# =====================================================================
#  It logged in to Docker Hub as the invoking user while running every
#  docker/compose call as root, so the first pull of a private image failed
#  with "pull access denied for durancai/staging-installer-web-gw, repository
#  does not exist or may require 'docker login'". It also fetched its compose
#  from the wrong GitHub org, polled for image updates on an unaligned timer,
#  and wrote unverified nameservers into the gateway bundle.
#
#  Replaced by duranc_multi_gw_installer_new-x64.sh, which takes --env.
# =====================================================================
cat <<'NOTICE'

  This installer has been RETIRED and will not run.
  Use the command below instead (one line):

  curl -fsSL -o $HOME/duranc_gw_installer.sh "https://raw.githubusercontent.com/duranctechind/duranc_bootstrap/master/gateway/duranc_multi_gw_installer_new-x64.sh?cb=$(date +%s)" && chmod +x $HOME/duranc_gw_installer.sh && sudo bash $HOME/duranc_gw_installer.sh --env stg

  Full procedure: Duranc_Docker_GW_Installation_Ubuntu_v3.2

NOTICE
exit 1
