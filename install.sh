#!/usr/bin/env bash
#
# RITA is brought to you by Offensive CounterMeasures.
# offensivecountermeasures.com

set -o errexit
set -o pipefail

_NAME=$(basename "${0}")
_INSDIR="/usr/local"
_SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

__help() {
	cat <<HEREDOC

Welcome to the RITA installer.

Usage:
	${_NAME} [<arguments>]
	${_NAME} -h | --help

Options:
	-h --help			Show this help message.
	-i --install-dir		Directory to install to.
	-u --uninstall			Remove RITA.

HEREDOC
}

__prep() {
	cat <<HEREDOC
So here's what this script will need to do to prepare for RITA:

1) Download and install Bro, Golang, and the latest version of MongoDB.

2) Set up a Golang development enviornment in order to 'go get' and 'build' RITA.

This requires us to create directory "go" in your home folder and add a new PATH and GOPATH entry to your .bashrc

3) Create a configuration directory for RITA under your home folder called .rita

HEREDOC
}

__title() {
	cat <<HEREDOC
 _ \ _ _| __ __|  \ 
   /   |     |   _ \ 
_|_\ ___|   _| _/  _\ 

Brought to you by the Offensive CounterMeasures

HEREDOC
}

__uninstall() {
	printf "Removing $_RITADIR \n"
	rm -rf $_RITADIR
	printf "Removing $GOPATH/bin/rita \n"
	rm -rf $GOPATH/bin/rita
	printf "Removing $GOPATH/src/github.com/ocmdev \n"
	rm -rf $GOPATH/src/github.com/ocmdev
	printf "Removing $HOME/.rita \n"
	rm -rf $HOME/.rita

	if [[ "${1}" == "resinstall" ]]; then
		__install
	fi
}

__install() {

	# Check if RITA is already installed, if so ask if this is a re-install
	if [ -e $_RITADIR ]
	then
		printf "[+] $_RITADIR already exists.\n"
		read -p "[-] Would you like to erase it and re-install? [y/n] " -n 1 -r
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
			__uninstall reinstall
		else
			exit -1
		fi
	fi

	# Setup requirements
	sudo curl -sSL https://github.com/icy/pacapt/raw/ng/pacapt > /usr/local/bin/pacapt
	sudo chmod 755 /usr/local/bin/pacapt

	if [[ "${OSTYPE}" != linux* ]]; then
		echo "Unsupported Operating System Detected (${OSTYPE}), exiting..."
		exit 1
	fi
	
	echo -e "[+] Updating packages...\n"

	pacapt -Sy

	echo -e "\n[+] Ensuring bro is installed...\n"

	pacapt -S bro broctl --no-confirm

	echo "\n[+] Ensuring go is installed...\n"

	# Check if go is not available in the path
	if [ ! $(command -v go) ]
	then
		# Check if go is available in the standard location
		if [ ! -e "/usr/local/go" ]
		then
			# golang download
			curl -sSL https://storage.googleapis.com/golang/go1.7.1.linux-amd64.tar.gz > go1.7.1.linux-amd64.tar.gz
			tar -zxf go1.7.1.linux-amd64.tar.gz -C /usr/local/
			echo 'export PATH=$PATH:/usr/local/go/bin' >> $HOME/.bashrc
			rm go1.7.1.linux-amd64.tar.gz
		fi
		# Add go to the path
		export PATH="$PATH:/usr/local/go/bin"
	else
		echo -e "\e[31m[-] WARNING: Go has been detected on this system,\e[37m RITA has only been tested with golang 1.7.  Make sure your golang is up to date
with 'go version', otherwise you can remove golang and let this script install the correct version for you!\n"
		
		sleep 10s
	fi

	echo -e "[+] Configuring Go dev environment...\n\e[0m"

	# Check if the GOPATH isn't set
	if [ -z "${GOPATH}" ]
	then
		mkdir -p $HOME/go/{src,pkg,bin}
		echo 'export GOPATH=$HOME/go' >> $HOME/.bashrc
		export GOPATH=$HOME/go
		echo 'export PATH=$PATH:$GOPATH/bin' >> $HOME/.bashrc
		export PATH=$PATH:$GOPATH/bin
	else
		echo -e "[-] GOPATH seems to be set, we'll skip this part then for now\n"
	fi

	echo -e "[+] Installing MongoDB...\n"

	if [ $(command -v lsb_release) ]; then
                echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.4.list
        elif [[ -f /etc/centos-release ]]; then
                echo -e "[mongodb-org-3.4]\nname=MongoDB Repository\nbaseurl=https://repo.mongodb.org/yum/redhat/3.4/mongodb-org/3.4/x86_64/\ngpgcheck=1\nenabled=1\ngpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc" > /etc/yum.repos.d/mongodb-org-3.4.repo
        fi

	pacapt -Sy
	pacapt -S mongodb-org --no-confirm

	printf "\n[+] Running 'go get github.com/ocmdev/rita...'\n\n"

	# Build RITA

	pacapt -S build-essential golang --no-confirm
	go get github.com/ocmdev/rita
	printf "[+] Installing RITA...\n\n"
	cd $GOPATH/src/github.com/ocmdev/rita
	make install

	printf "[+] Transferring files...\n\n"
	mkdir $_RITADIR

	cp -r $_SCRIPTDIR/etc $_RITADIR/etc
	cp $_SCRIPTDIR/LICENSE $_RITADIR/LICENSE

	# Install the base configuration file
	printf "[+] Installing config to $HOME/.rita/config.yaml\n\n"
	mkdir $HOME/.rita
	cp $_SCRIPTDIR/etc/rita.yaml $HOME/.rita/config.yaml
	

	# Give ownership of ~/go to the user
	sudo chown -R $SUDO_USER:$SUDO_USER $HOME/go
	sudo chown -R $SUDO_USER:$SUDO_USER $HOME/.rita

	echo -e "[+] Make sure you also configure Bro and run with 'sudo broctl deploy' and make sure MongoDB is running with the command 'mongo' or 'sudo mongo'."

	echo -e "[+] If you need to stop Mongo at any time, run 'sudo service mongod stop'"
	echo -e "[+] In order to finish the installation, reload bash config with 'source ~/.bashrc'."
	echo -e "[+] Also make sure to start the mongoDB service with 'sudo service mongod start before running RITA."
	echo -e "[+] You can access the mongo shell with 'sudo mongo'\n"


	echo -e "[+] You may need to source your .bashrc before you call RITA!\n"

	echo -e "Thank you for installing RITA!\n"
	echo -e "OCMDev Group projects IRC #ocmdev on OFTC\n"
	echo -e "Happy hunting\n"

}

# start point for installer
__entry() {

	# Check for help or other install dir
	if [[ "${1:-}" =~ ^-h|--help$ ]]
	then
		__help
		exit 0
	fi

	if [[ "${1:-}" =~ ^-i|--install-dir ]]
	then
		_INSDIR=$( echo "${@}" | cut -d' ' -f2 )
	fi
	
	# Set the rita directory	
	_RITADIR="$_INSDIR/rita"
	

	# Check to see if the user has permission to install to this directory
	if [ -w $_INSDIR ]
	then
		# Check if we are uninstalling
		if [[ "${1:-}" =~ ^-u|--uninstall ]]
		then
			__uninstall
		else
			__install
		fi
	else
		printf "You do NOT have permission to write to $_INSDIR\n\n"
		__help
	fi
}

__entry "${@:-}"
