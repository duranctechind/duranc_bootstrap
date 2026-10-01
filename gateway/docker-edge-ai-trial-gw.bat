@echo OFF
REM Create a link for docker config
REM mklink /H C:/Users/%USERNAME%/.docker/auth.json C:/Users/%USERNAME%/.docker/config.json

REM Create docker volumes for persistent storage
docker volume create edge-ai-gw-files
docker volume create edge-ai-motion-files

REM Download docker compose file
curl -o C:/Users/%USERNAME%/docker-compose-edge-ai-trial-gw-win.yml https://raw.githubusercontent.com/duranctechind/duranc_bootstrap/master/gateway/docker-compose-edge-ai-trial-gw-win.yml

REM Build docker containers
docker-compose -f C:/Users/%USERNAME%/docker-compose-edge-ai-trial-gw-win.yml up -d

REM Show running container
docker ps -a

@echo ON
