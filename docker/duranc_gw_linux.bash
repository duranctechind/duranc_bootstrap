#!/bin/bash

###---Bash file to setup Dockerized Duranc Gateway with Auto Updater in Linux---###
sudo ls

# Install docker compose software
sudo apt-get install -y docker-compose

#Create a link for docker config
ln -s $HOME/.docker/config.json $HOME/.docker/auth.json

#Create docker volumes for persistent storage
docker volume create gw-files
docker volume create motion-files

#Download docker compose file
wget -O $HOME/docker-compose-gateway-linux.yml https://github.com/duranctechind/duranc_bootstrap/blob/master/docker/docker-compose-gateway-linux.yml

# Build docker containers
docker-compose -f $HOME/docker-compose-gateway-linux.yml up -d

# Show running container
clear
docker ps -a
