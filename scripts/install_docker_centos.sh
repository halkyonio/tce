#!/usr/bin/env bash
#
# This script requires: curl, grep, sed, tr, and jq in order to work
#
# Execute this command locally
#
# ./install_docker_centos.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM

set -e

VM_IP=${VM_IP:=127.0.0.1}
REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}

# Defining some colors for output
RED='\033[0;31m'
NC='\033[0m' # No Color
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

repeat_char(){
  COLOR=${1}
	for i in {1..50}; do echo -ne "${!COLOR}$2${NC}"; done
}

log_msg() {
    COLOR=${1}
    MSG="${@:2}"
    echo -e "\n${!COLOR}## ${MSG}${NC}"
}

log_line() {
    COLOR=${1}
    MSG="${@:2}"
    echo -e "${!COLOR}## ${MSG}${NC}"
}

log() {
  MSG="${@:2}"
  echo; repeat_char ${1} '#'; log_msg ${1} ${MSG}; repeat_char ${1} '#'; echo
}

log "CYAN" "Check the linux distro, calculate the new path to get the docker dnf repo"
LINUX_DISTRO_NAME=$(awk -F= '$1=="NAME" { print $2 ;}' /etc/os-release)
if [ "$LINUX_DISTRO_NAME" = "Rocky Linux" ]; then
    REPO_SUBPATH="centos"
elif [ "$LINUX_DISTRO_NAME" = "Fedora Linux" ]; then
    REPO_SUBPATH="fedora"
    sudo dnf -y install dnf-plugins-core
else
   REPO_SUBPATH="centos"
fi

log "CYAN" "Add the docker dnf repo"
sudo dnf config-manager --add-repo https://download.docker.com/linux/$REPO_SUBPATH/docker-ce.repo
#sudo dnf install docker-ce docker-ce-cli containerd.io docker-compose-plugin
log "CYAN" "Install docker-ce docker-ce-cli containerd.io"
sudo dnf -y install docker-ce docker-ce-cli containerd.io

log "CYAN" "Launch the docker daemon"
sudo systemctl start docker
sudo systemctl status docker

log "CYAN" "Add groupadd docker and usermod -aG docker $USER"
sudo groupadd -f docker
sudo usermod -aG docker $USER