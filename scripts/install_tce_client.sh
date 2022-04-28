#!/usr/bin/env bash
#
# This script requires: curl, grep, sed, tr, and jq in order to work
#
# Execute this command locally
#
# ./scripts/install_tce_client.sh
#
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
# - TCE_VERSION: Version of the Tanzu client to be installed. E.g. v0.11.0
#
set -e

KUBE_CFG=${KUBE_CFG:=config}
REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}

TCE_VERSION=${TCE_VERSION:-v0.11.0}
TCE_DIR=$REMOTE_HOME_DIR/tce

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

log "CYAN" "Set the KUBECONFIG=$HOME/.kube/${KUBE_CFG}"
export KUBECONFIG=$HOME/.kube/${KUBE_CFG}

SECONDS=0

log "CYAN" "Installing the tanzu client version: $TCE_VERSION"
curl -H "Accept: application/vnd.github.v3.raw" \
    -L https://api.github.com/repos/vmware-tanzu/community-edition/contents/hack/get-tce-release.sh | \
    bash -s $TCE_VERSION linux
mkdir -p $TCE_DIR
mv tce-linux-amd64-$TCE_VERSION.tar.gz $TCE_DIR
tar xzvf $TCE_DIR/tce-linux-amd64-$TCE_VERSION.tar.gz -C $TCE_DIR/
$TCE_DIR/tce-linux-amd64-$TCE_VERSION/install.sh

mkdir -p $REMOTE_HOME_DIR/.tanzu
tanzu completion bash >  $REMOTE_HOME_DIR/.tanzu/completion.bash.inc