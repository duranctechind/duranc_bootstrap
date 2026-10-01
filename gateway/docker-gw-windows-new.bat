@echo off
::Create a link for docker config
::mklink /H C:/Users/%USERNAME%/.docker/auth.json C:/Users/%USERNAME%/.docker/config.json

echo | set /p="2e8afdc0-884c-4446-a8ec-53642e310c09" | docker login --username durancinc --password-stdin

::Create docker volumes for persistent storage
docker volume create --name=stg-gw-files
docker volume create --name=stg-motion-files

::Download docker compose file
curl -o C:/Users/%USERNAME%/docker-compose-gateway-windows.yml https://raw.githubusercontent.com/duranctechind/duranc_bootstrap/master/gateway/docker-compose-gateway-windows.yml

::Build docker containers
docker-compose -f C:/Users/%USERNAME%/docker-compose-gateway-windows.yml up -d

::Delete compose file
del C:/Users/%USERNAME%/docker-compose-gateway-windows.yml

::Show running container
docker ps -a

@echo on
