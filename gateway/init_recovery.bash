#!/bin/bash
DIRECTORY="$HOME/.recovery"
if [ ! -d "$DIRECTORY" ]; then
	# Recovery of broken mp4 clips
	mkdir $HOME/.recovery
	cd $HOME/.recovery
	echo 'Recovery directory created:' $DIRECTORY

	# install packaged dependencies
	sudo apt-get update
	sudo apt-get -y install libavformat-dev libavcodec-dev libavutil-dev unzip g++ wget make nasm zlib1g-dev

	# download and extract
	wget -O $HOME/.recovery/master.zip https://raw.githubusercontent.com/duranctechind/duranc_bootstrap/master/gateway/untrunc/master.zip
	unzip master.zip
	cd $HOME/.recovery/untrunc-master
	wget -O $HOME/.recovery/untrunc-master/v12.3.zip https://raw.githubusercontent.com/duranctechind/duranc_bootstrap/master/gateway/untrunc/libav/v12.3.zip
	unzip $HOME/.recovery/untrunc-master/v12.3.zip

	# build libav
	cd $HOME/.recovery/untrunc-master/libav-12.3/
	./configure && make

	# build untrunc
	cd $HOME/.recovery/untrunc-master
	/usr/bin/g++ -o untrunc -I./libav-12.3 file.cpp main.cpp track.cpp atom.cpp mp4.cpp -L./libav-12.3/libavformat -lavformat -L./libav-12.3/libavcodec -lavcodec -L./libav-12.3/libavresample -lavresample -L./libav-12.3/libavutil -lavutil -lpthread -lz

	# adding to path
	echo 'export PATH=$PATH:$HOME/.recovery/untrunc-master # <RECOVERY>' >> ~/.bashrc 
else
    echo 'Recovery directory exists:' $DIRECTORY
fi
