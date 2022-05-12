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

DIR=`dirname $0` # to get the location where the script is located

. $DIR/util.sh

log "CYAN" "Check the linux distro, calculate the new path to get the docker dnf repo"
LINUX_DISTRO_NAME=$(awk -F= '$1=="NAME" { print $2 ;}' /etc/os-release)
if [ "${LINUX_DISTRO_NAME}" = "\"Rocky Linux\"" ]; then
    log "CYAN" "Add docker dnf repo"
    sudo dnf config-manager --add-repo https://download.docker.com/linux/$REPO_SUBPATH/docker-ce.repo
    log "CYAN" "Install docker-ce docker-ce-cli containerd.io"
    sudo dnf install docker-ce docker-ce-cli containerd.io
elif [ "${LINUX_DISTRO_NAME}" = "\"Fedora Linux\"" ]; then
    REPO_SUBPATH="fedora"
    sudo dnf -y install dnf-plugins-core
    log "CYAN" "Add docker dnf repo"
    sudo dnf config-manager --add-repo https://download.docker.com/linux/$REPO_SUBPATH/docker-ce.repo
    log "CYAN" "Install docker-ce docker-ce-cli containerd.io"
    sudo dnf install docker-ce docker-ce-cli containerd.io
elif [ "${LINUX_DISTRO_NAME}" = "\"CentOS Linux\"" ]; then
    REPO_SUBPATH="centos"
    log "CYAN" "Add docker yum repo"
    sudo yum-config-manager --add-repo https://download.docker.com/linux/$REPO_SUBPATH/docker-ce.repo
    log "CYAN" "Install docker-ce docker-ce-cli containerd.io"
    sudo yum -y install docker-ce docker-ce-cli containerd.io
fi

log "CYAN" "Launch the docker daemon"
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl status docker

log "CYAN" "Add groupadd docker and usermod -aG docker $USER"
sudo groupadd -f docker
sudo usermod -aG docker $USER