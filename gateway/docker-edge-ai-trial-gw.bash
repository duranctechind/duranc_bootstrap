#!/bin/bash
###---Bash file to setup Dockerized Duranc Gateway with Auto Updater in Linux---###
sudo ls

# Install docker compose software
sudo apt-get install -y docker-compose

#Create a link for docker config
ln -s $HOME/.docker/config.json $HOME/.docker/auth.json

#Create docker volumes for persistent storage
docker volume create edge-ai-gw-files
docker volume create edge-ai-motion-files

#Download docker compose file
wget -O $HOME/edgeAItrialGWlinux.yml https://raw.githubusercontent.com/duranctechind/duranc_bootstrap/master/gateway/docker-compose-edge-ai-trial-gw-linux.yml

# Build docker containers
docker-compose -f $HOME/edgeAItrialGWlinux.yml up -d

# Show running container
docker ps -a
