#!/bin/bash

###---Bash file for docker local deployment automation in Linux---###

# check for sudo permission duplicate entry in sudoers file
FILE_TO_CHECK_1="/etc/sudoers"
STRING_TO_CHECK_1="$USER ALL=(ALL) NOPASSWD:ALL"
if  sudo grep -q "$STRING_TO_CHECK_1" "$FILE_TO_CHECK_1"
then
	echo 'sudo permission entry exists in sudoers file'
else
	## Add Sudo permision for logged in user
	echo 'NO sudo permission entry exists in sudoers file... so adding it'
	echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers >/dev/null
fi

#Download Nginx file for docker
mkdir $HOME/nginx
wget -O $HOME/nginx/nginx.tmpl https://raw.githubusercontent.com/duranctechind/duranc_bootstrap/master/gateway/dockerfiles/nginx/nginx.tmpl

#Create docker network and volumes for persistent storage
docker network create duranc-network --subnet "18.19.0.0/16"
docker volume create --name=stg-virtual-hosts
docker volume create --name=stg-virtual-conf
docker volume create --name=stg-virtual-certs
docker volume create --name=stg-virtual-acme
docker volume create --name=stg-html-files
docker volume create --name=stg-duranc-db
docker volume create --name=stg-duranc-data
docker volume create --name=stg-duranc-portal
docker volume create --name=stg-duranc-messenger
docker volume create --name=stg-duranc-streamer
docker volume create --name=stg-rec-files
docker volume create --name=stg-rec-motion-files

# Create symlink to mount in auto updater
ln -s $HOME/.docker/config.json $HOME/.docker/auth.json
