#!/usr/bin/env bash
#
# Execute this command locally
#
# ./uninstall.sh
#
# Example:
# VM_IP=65.108.148.216 REMOTE_HOME_DIR=$HOME CLUSTER_NAME=toto TCE_VERSION=v0.11.0 ./scripts/uninstall.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
# - CLUSTER_NAME: TCE Kind cluster name
# - VM_IP: IP address of the VM where the cluster is running
# - TCE_VERSION: Version of the Tanzu client (e.g. v0.11.0)

set -e

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

log() {
  MSG="${@:2}"
  echo; repeat_char ${1} '#'; log_msg ${1} ${MSG}; repeat_char ${1} '#'; echo
}

KUBE_CFG_FILE=${KUBE_CFG_FILE:-config}
CLUSTER_NAME=${CLUSTER_NAME:-toto}

export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

#log "YELLOW" "Removing the k8s-ui release from helm"
#helm uninstall k8s-ui -n kubernetes-dashboard

log "YELLOW" "Deleting the TCE cluster $CLUSTER_NAME"
tanzu uc delete $CLUSTER_NAME

log "YELLOW" "Uninstall the Tanzu CLI"
~/.local/share/tce/uninstall.sh

log "YELLOW" "Remove downloaded files"
rm -rf $REMOTE_HOME_DIR/tce/tce-linux-amd64-$TCE_VERSION/
rm $REMOTE_HOME_DIR/tce/tce-linux-amd64-$TCE_VERSION.tar.gz || true