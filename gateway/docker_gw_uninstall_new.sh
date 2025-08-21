#!/bin/bash

scriptsDir="/.scripts"
dt=$(TZ=IST-5:30 date)
dockerCMD=`which docker`

# Checking if duranc_gateway container exists or not
#(If the container exists and is running, the container ID is returned. If it doesn't exist, or exists but is stopped, an empty string comes back.)
containerCheck=$($dockerCMD ps -q -f name="duranc_gateway")
if [[ "$containerCheck" == "" ]]
then
	echo "Date: $dt" > $scriptsDir/containerCheckerr.log
	echo "duranc_gateway container does not exists or stopped" >> $scriptsDir/containerCheckerr.log
else
	# Check if uninstall file exists
	string=$($dockerCMD exec -t duranc_gateway cat /root/.duranc/gateway/uninstall.txt)
	if [[ $string == *"No such file or directory"* ]]
	then
		echo "Date: $dt" > $scriptsDir/containerCheckerr.log
		echo "Uninstall file does NOT exists in duranc gateway container" >> $scriptsDir/containerCheckerr.log
	elif [[ "$string" == "" ]]
	then
		#Found uninstall file so performing uninstallation process
		echo "Date: $dt" > $scriptsDir/gwuninstall.log
		echo "Uninstall file EXISTS in duranc gateway container" >> $scriptsDir/gwuninstall.log
		containerID=$($dockerCMD ps | awk '/duranc_gateway/ { print $1 }')
		imagename=$($dockerCMD ps | awk '/duranc_gateway/ { print $2 }')
		volumes=$($dockerCMD container inspect -f '{{ range .Mounts }}{{ .Name }} {{ end }}' duranc_gateway)
		
		#Stopping and Removing Gateway Container
		echo "container ID to be removed: $containerID" >> $scriptsDir/gwuninstall.log
		containerStop="$dockerCMD stop $containerID"
		eval $containerStop
		
		containerRemove="$dockerCMD container rm $containerID"
		eval $containerRemove

		#Removing Gateway Image
		echo "image to be removed: $imagename" >> $scriptsDir/gwuninstall.log
		imageRemove="$dockerCMD image rm $imagename"
		eval $imageRemove
		
		#Removing Volumes
		for volume in $volumes
		do
		  #echo $volume
		  echo "volume to remove: $volume" >> $scriptsDir/gwuninstall.log
		  volumeRemove="$dockerCMD volume rm $volume"
		  eval $volumeRemove
		done
		
		#Comment the line in crontab (Future Use)
		#sudo sed -e '/docker_gw_uninstall.sh.x/ s/^#*/#/' -i /var/spool/cron/crontabs/root
	else
		echo "Date: $dt" > $scriptsDir/containerCheckerr.log
		echo "Docker command output does not match case" >> $scriptsDir/containerCheckerr.log
	fi
fi
