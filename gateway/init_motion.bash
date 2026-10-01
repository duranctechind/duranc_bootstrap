#!/bin/bash
date=`date`
HOSTED_ROOT=https://portal.duranc.com/bootstrap/
# Packages
echo "Updating OS Packages..."
sudo apt-get update 2> $HOME/update_error.txt

# Check if apt-get command is successfull or not
if [ -s $HOME/update_error.txt ]; then
	# The file is not-empty.
	echo -e "\e[31mapt-get update command is NOT successfull...Please check\e[0m"
	# check if apt-get update has error
	FILE_UPDATE_TO_CHECK="$HOME/update_error.txt"
	STRING_UPDATE_TO_CHECK="E:"
	if grep -q "$STRING_UPDATE_TO_CHECK" "$FILE_UPDATE_TO_CHECK"
	then
		echo " "
		echo "***Warning: There are errors while running apt-update... Please resolve them***"
		echo "***Warning: There are errors while running apt-update at $date... Please resolve them***" > $HOME/gw_update_error.txt
		echo " "
	fi
	exit
else
	# The file is empty.
	echo "apt-get update is successfull...Continue to next step"
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y dpkg ffmpeg python3-pip ipython3 libatlas-base-dev arp-scan libxml++2.6-dev libxslt1-dev autossh python3-numpy emacs git silversearcher-ag libgeos-dev python3-skimage python3-opencv python3-matplotlib unzip portaudio19-dev python3-pyaudio python3-websocket
	# Install VLC player
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y vlc
fi

# In order to scan more efficiently cameras, let's allow normal user to do arp scanning:    
sudo chmod u+s /usr/sbin/arp-scan
    
# For systemd daemonization to work for non-root users, do:
sudo adduser $USER systemd-journal
sudo loginctl enable-linger $USER

# for /dev/videoX access to work, must do this:
sudo addgroup $USER video

# Upgrade PIP
pip3 install --upgrade pip
pip3 install numpy==1.22.0 onnxruntime==1.15.1

# check for sudo permission duplicate entry in sudoers file
FILE_TO_CHECK_1="/etc/sudoers"
STRING_TO_CHECK_1="$USER ALL=(ALL) NOPASSWD:ALL"
if  sudo grep -q "$STRING_TO_CHECK_1" "$FILE_TO_CHECK_1" ; then
	echo 'sudo permission entry exists in sudoers file' ;
else
	## Add Sudo permision to gwuser
	echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers >/dev/null
fi

# installation new mp4 recovery software [untrunc]
FILEDIRECTORY_UNTRUNC=$HOME/.recovery/untrunc-new
UNTRUNC_FILE=untrunc

if [ ! -e $FILEDIRECTORY_UNTRUNC/$UNTRUNC_FILE ]
then
	DIRECTORY="$HOME/.recovery"
	if [ -d "$DIRECTORY" ]; then
		# Remove recovery directory
		rm -fR $DIRECTORY/untrunc-new
	fi
	
	# Recovery of broken mp4 clips
	mkdir -p $HOME/.recovery/untrunc-new
	echo 'Recovery directory created:' $DIRECTORY

	# install packaged dependencies
	sudo apt-get update
	sudo apt-get install -y libavformat-dev libavcodec-dev libavutil-dev
	
	# get the source code
	cd $HOME/.recovery/untrunc-new
	git clone https://github.com/anthwlock/untrunc.git .
	
	# compile untrunc
	cd $HOME/.recovery/untrunc-new/
	make
	sudo cp $HOME/.recovery/untrunc-new/untrunc /usr/local/bin 
else
    echo 'New Untrunc Already Compiled....'
fi

# Install Motion software
mkdir -p $HOME/.motion
mkdir -p $HOME/.motion/feeds
mkdir -p $HOME/.motion/event

# Check hardware version for Raspberry Pi
hdver=`uname -m`
if [ $hdver != "armv7l" ] 
then
	echo "This is regular machine..."
	# Perform below steps only if internet is working
	ping -q -c3 "www.google.com" > /dev/null
	if [ $? -eq 0 ]
	then
		echo "Internet UP"
		motion_version=$(/usr/bin/dpkg -s motion | grep Version | grep -oP "Version: \K[0-9.]+")
		if [[ $motion_version != 4.5.1* ]]; then
			ubuntu_codename=$(lsb_release -cs)
			motion_git_release_url="https://github.com/Motion-Project/motion/releases/download/release-4.5.1"
			architecture=$(dpkg --print-architecture)
			package_name="${ubuntu_codename}_motion_4.5.1-1_${architecture}.deb"
			if wget --spider "$motion_git_release_url/$package_name" 2>/dev/null; then
				wget -O $package_name "$motion_git_release_url/$package_name"
				sudo apt-get purge motion
				sudo dpkg -i $package_name
				sudo apt-get install -f
			else
				echo "Couldnt download motion for Ubuntu $ubuntu_codename, $architecture"
			fi
		fi
		mv $HOME/.motion/motion.conf $HOME/.motion/motion-orig.conf
		motion_version=$(/usr/bin/dpkg -s motion | grep Version | grep -oP "Version: \K[0-9.]+")
		echo "motion-version: " $motion_version
		# Check version
		if [[ $motion_version == 4.0.* ]]; then
			wget -O $HOME/.motion/motion.conf $HOSTED_ROOT/gateway/motion-4.0.conf
		elif [[ $motion_version == 4.2.* ]]; then
			wget -O $HOME/.motion/motion.conf $HOSTED_ROOT/gateway/motion-4.2.conf
		elif [[ $motion_version == 4.5.1* ]]; then
			wget -O $HOME/.motion/motion.conf $HOSTED_ROOT/gateway/motion-4.5.1.conf
		else
			echo "Version is outside the specified range or not recognized."
		fi
		# CHECK IF MOTION.CONF FILE IS EMPTY OR NOT
		if [ -s $HOME/.motion/motion.conf ]; then
			# The file is not-empty.
			echo -e "\e[31mMotion configuration downloaded successfully\e[0m"
			rm -f $HOME/.motion/motion-orig.conf
		else
			# The file is empty.
			mv $HOME/.motion/motion-orig.conf $HOME/.motion/motion.conf
		fi

		##SCRIPT FOR DOWNLOADING LATEST WEIGHT FILES --START ->
		# Input file
		WEIGHTS_DIR=$HOME/.motion/weights
		FILE1=latestweight.txt
		FILE2=currentweight.txt

		if [ -e $WEIGHTS_DIR/$FILE1 ]
		then
			echo "File Exists"
			rm -f $WEIGHTS_DIR/$FILE1
			wget -O $HOME/.motion/weights/latestweight.txt $HOSTED_ROOT/gateway/weights/latestweight.txt
			diff --brief <(sort $WEIGHTS_DIR/$FILE1) <(sort $WEIGHTS_DIR/$FILE2) >/dev/null
			comp_value=$?
			#Comparing two files
			if [ $comp_value -eq 1 ]
			then
				# List of files to download
				FILESLIST=("libdarknet.so" "duranc_tiny_v3.weights" "duranc_tiny_v3.names" "duranc_tiny_v3.cfg")
				# Base URL for the downloads
				WEIGHTS_URL="$HOSTED_ROOT/gateway/weights"
				# Flag to check if all files downloaded successfully
				ALL_DOWNLOADED=true
				# Download each file with a .new extension
				for file in "${FILESLIST[@]}"; do
					wget -O "${WEIGHTS_DIR}/${file}.new" "${WEIGHTS_URL}/${file}"
					
					# Check if the file is non-zero size
					if [ ! -s "${WEIGHTS_DIR}/${file}.new" ]; then
						echo "Failed to download or file is empty: ${file}"
						ALL_DOWNLOADED=false
						break
					fi
				done
				# If all files were downloaded successfully, overwrite the originals
				if $ALL_DOWNLOADED; then
					for file in "${FILESFILESLIST[@]}"; do
						mv "${WEIGHTS_DIR}/${file}.new" "${WEIGHTS_DIR}/${file}"
					done
					cp "${WEIGHTS_DIR}/${FILE1}" "${WEIGHTS_DIR}/${FILE2}"

					echo "All files were updated successfully!"
				else
					echo "Files were not updated due to an error."
					# Remove any .new files to clean up
					for file in "${FILESLIST[@]}"; do
						rm -f "${WEIGHTS_DIR}/${file}.new"
					done
				fi

			else
				echo "No change in Files"
			fi
		else
			# Fresh Installation, create weights file directory
			mkdir -p $HOME/.motion/weights
			echo "You need to download $FILE1"
			wget -O $HOME/.motion/weights/latestweight.txt $HOSTED_ROOT/gateway/weights/latestweight.txt
			wget -O $HOME/.motion/weights/libdarknet.so $HOSTED_ROOT/gateway/weights/libdarknet.so
			wget -O $HOME/.motion/weights/duranc_tiny_v3.weights $HOSTED_ROOT/gateway/weights/duranc_tiny_v3.weights
			wget -O $HOME/.motion/weights/duranc_tiny_v3.names $HOSTED_ROOT/gateway/weights/duranc_tiny_v3.names
			wget -O $HOME/.motion/weights/duranc_tiny_v3.cfg $HOSTED_ROOT/gateway/weights/duranc_tiny_v3.cfg
			# Copy latestweight.txt TO currentweight.txt
			cp $WEIGHTS_DIR/$FILE1 $WEIGHTS_DIR/$FILE2
		fi
		##SCRIPT FOR DOWNLOADING LATEST WEIGHT FILES --END <-
	else
		echo "Internet Down"
	fi
else
	echo "This is Raspberry Pi..."
	# Perform below steps only if internet is working
	ping -q -c3 "www.google.com" > /dev/null
	if [ $? -eq 0 ]
	then
		echo "Internet UP"
		mv $HOME/.motion/motion.conf $HOME/.motion/motion-orig.conf
		wget -O $HOME/.motion/motion.conf $HOSTED_ROOT/gateway/motion_pi.conf
		# CHECK IF MOTION.CONF FILE IS EMPTY OR NOT
		if [ -s $HOME/.motion/motion.conf ]; then
			# The file is not-empty.
			echo -e "\e[31mMotion configuration downloaded successfully\e[0m"
			rm -f $HOME/.motion/motion-orig.conf
		else
			# The file is empty.
			mv $HOME/.motion/motion-orig.conf $HOME/.motion/motion.conf
		fi
	else
		echo "Internet Down"
	fi
fi

# check for motion.conf duplicate entry in root cron tab
FILE_TO_CHECK="/var/spool/cron/crontabs/root"
STRING_TO_CHECK="motion.conf"
if  sudo grep -q "$STRING_TO_CHECK" "$FILE_TO_CHECK" ; then
	echo 'motion conf entry exists in cron tab' ;
else
	echo "@reboot /usr/bin/motion -c $HOME/.motion/motion.conf" | sudo tee -a /var/spool/cron/crontabs/root >/dev/null 	## Add cronjob of motion

fi

# Installing PM2 for NodeJS Streamer
FILEDIRECTORY_LOCALSTR=$HOME/.localstr
LOCALSTR_FILE=index.js
NOD_MOD=$HOME/.localstr/node_modules

#if [ ! -e $FILEDIRECTORY_LOCALSTR/$LOCALSTR_FILE ]
if [ ! -d "$NOD_MOD" ]
then
	NODE_VERSION=12.10.0
	sudo apt purge nodejs -y
	sudo rm -r /usr/lib/node_modules

	sudo apt-get install -y curl git wget

	# Set up the NVM_DIR variable and clone the NVM repository from a given branch.
	export NVM_DIR="$HOME/.nvm" && (
	git clone -b v0.32.1 https://portal.duranc.com/git/nvm.git "$NVM_DIR"
	) && \. "$NVM_DIR/nvm.sh"

	# Define the lines we want to ensure are in ~/.bashrc for NVM initialization.
	NVM_LINES=(
		'export NVM_DIR="$HOME/.nvm"'
		'[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm'
	)

	# Loop through each line and append it to ~/.bashrc if it's not already present.
	for LINE in "${NVM_LINES[@]}"; do
		grep -qF -- "$LINE" ~/.bashrc || echo "$LINE" >> ~/.bashrc
	done

	source $HOME/.bashrc

	nvm install $NODE_VERSION
	nvm use v$NODE_VERSION
	nvm alias default v$NODE_VERSION

	nodejs --version
	npm --version

	npm install -g node-gyp
	npm install -g pm2
	pm2 update
	pm2 install pm2-logrotate
	pm2 set pm2-logrotate:retain 7
	pm2 set pm2-logrotate:compress true
	sudo ln -s "$(which npm)" /usr/bin/npm
else
    echo 'Node and NPM Already Installed....'
fi
#local rtsp server install/update
#wget -O - https://github.com/duranctechind/duranc_bootstrap/raw/master/gateway/mediamtx/mediamtx_update.bash|bash
# This has given problems many times: should be in the default path, but many times, is not
# Enable it right now
export PATH=$PATH:$HOME/.local/bin

# If you're running this manually, just see that the above line is in your .bashrc 
# ..and that your run it *now*

# The following is automagic fixing of the problem (don't do this manually):

### complement the path to have $HOME/.local/bin
fname=$HOME"/.bashrc"
tmp="/tmp/bashrc"
add="export PATH=\$PATH:\$HOME/.local/bin # <DURANC>"
# remove duranc specific stuff => tmpfile
grep -v "<DURANC>" $fname > $tmp
# add duranc specific stuff to tmpfile
# comm="sed -i '2s/^/"$add"/' "$tmp
# echo $comm
# $comm
echo $add | cat - $tmp > $fname

# create a directory for systemd logs that does not disappear between boots
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal

### add line "Storage=persistent" to "/etc/systemd/journald.conf"
fname="/etc/systemd/journald.conf"
tmp="/tmp/journald.conf.tmp"
# lines to be added
add1="Storage=persistent # <DURANC>"
add2="RateLimitInterval=0 # <DURANC>"
add3="RateLimitBurst=0 # <DURANC>"
add4="SystemMaxUse=100M # <DURANC>"
# remove duranc specific stuff => tmpfile
sudo grep -v "<DURANC>" $fname > $tmp
# add duranc specific stuff to tmpfile
sudo echo $add1 >> $tmp
sudo echo $add2 >> $tmp
sudo echo $add3 >> $tmp
sudo echo $add4 >> $tmp
# tmpfile to final file
sudo cp -f $tmp $fname

# *** restart to make the changes effective ***
sudo systemctl restart systemd-journald

### complement the path to have $HOME/.local/bin
fname="/etc/sysctl.conf"
tmp="/tmp/sysctl.conf"
add1="net.core.wmem_max=2097152 # <DURANC>"
add2="net.core.rmem_max=2097152 # <DURANC>"
add3="fs.file-max = 2097152 # <DURANC>"
# remove duranc specific stuff => tmpfile
grep -v "<DURANC>" $fname > $tmp
# add duranc specific stuff to tmpfile
# comm="sed -i '2s/^/"$add"/' "$tmp
# echo $comm
# $comm
echo $add1 >> $tmp
echo $add2 >> $tmp
echo $add3 >> $tmp
sudo cp -f $tmp $fname
sudo sysctl -p


### Increase ulimt openfiles
fname="/etc/security/limits.conf"
tmp="/tmp/limits.conf"
add1="$USER       soft    nofile          50000 # <DURANC>"
add2="$USER       hard    nofile          50000 # <DURANC>"
# remove duranc specific stuff => tmpfile
grep -v "<DURANC>" $fname > $tmp
# add duranc specific stuff to tmpfile
# comm="sed -i '2s/^/"$add"/' "$tmp
# echo $comm
# $comm
echo $add1 >> $tmp
echo $add2 >> $tmp
sudo cp -f $tmp $fname

### Increase ulimt in user conf openfiles
fname="/etc/systemd/user.conf"
tmp="/tmp/user.conf"
add1="DefaultLimitNOFILE=50000 # <DURANC>"
# remove duranc specific stuff => tmpfile
grep -v "<DURANC>" $fname > $tmp
# add duranc specific stuff to tmpfile
# comm="sed -i '2s/^/"$add"/' "$tmp
# echo $comm
# $comm
echo $add1 >> $tmp
sudo cp -f $tmp $fname

### Increase ulimt in user conf openfiles
fname="/etc/systemd/system.conf"
tmp="/tmp/system.conf"
add1="DefaultLimitNOFILE=50000 # <DURANC>"
# remove duranc specific stuff => tmpfile
grep -v "<DURANC>" $fname > $tmp
# add duranc specific stuff to tmpfile
# comm="sed -i '2s/^/"$add"/' "$tmp
# echo $comm
# $comm
echo $add1 >> $tmp
sudo cp -f $tmp $fname


sudo mkdir -p /.scripts
sudo chmod 777 -R /.scripts
SCRIPT=/.scripts/service_ensure_running.sh
CRON_STRING_TO_CHECK="service_ensure_running"
CRON_FILE="/var/spool/cron/crontabs/root"
wget -O $SCRIPT.new $HOSTED_ROOT/gateway/service_ensure_running.sh
if [ $? -eq 0 ]; then
    mv $SCRIPT.new $SCRIPT
else
    echo "Download failed. Not replacing the script."
    rm -f $SCRIPT.new
fi
sudo chmod 777 -R /.scripts
if  sudo grep -q "$CRON_STRING_TO_CHECK" "$CRON_FILE" ; then
	echo 'docker container status entry exists in cron tab' ;
else
	echo "*/15 * * * * sudo -u $USER $SCRIPT" | sudo tee -a $CRON_FILE >/dev/null
fi




# Base directory
WEIGHTS_DIR="$HOME/.motion/weights"
mkdir -p ${WEIGHTS_DIR}  # Using the correct mkdir command

ONNX_JSON="onnx.json"
WEIGHTS_URL="$HOSTED_ROOT/gateway/weights"

wget -O "${WEIGHTS_DIR}/${ONNX_JSON}.new" "${WEIGHTS_URL}/${ONNX_JSON}"
# Compare .new file with the existing one
if [ $? -eq 0 ] && ! cmp -s "${WEIGHTS_DIR}/${ONNX_JSON}" "${WEIGHTS_DIR}/${ONNX_JSON}.new"; then
    # List of files to download
    FILESLIST=("duranc_all_tiny_v7.names" "duranc_all_tiny_v7.onnx")
    ALL_DOWNLOADED=true
    # Download each file with a .new extension
    for file in "${FILESLIST[@]}"; do
        wget -O "${WEIGHTS_DIR}/${file}.new" "${WEIGHTS_URL}/${file}"
        # Check if the file is non-zero size
        if [ ! -s "${WEIGHTS_DIR}/${file}.new" ]; then
            echo "Failed to download or file is empty: ${file}"
            ALL_DOWNLOADED=false
            break
        fi
    done
    # If all files were downloaded successfully, overwrite the originals
    if $ALL_DOWNLOADED; then
        for file in "${FILESLIST[@]}"; do
            mv "${WEIGHTS_DIR}/${file}.new" "${WEIGHTS_DIR}/${file}"
        done
        mv "${WEIGHTS_DIR}/${ONNX_JSON}.new" "${WEIGHTS_DIR}/${ONNX_JSON}"  # Using mv instead of cp
        echo "All files were updated successfully!"
    else
        echo "Files were not updated, deleting new files."
        # Remove any .new files to clean up
        for file in "${FILESLIST[@]}"; do
            rm -f "${WEIGHTS_DIR}/${file}.new"
        done
        rm -f "${WEIGHTS_DIR}/${ONNX_JSON}.new"  # Clean up the json .new file as well
    fi
fi