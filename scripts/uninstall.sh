#!/usr/bin/env bash
#
# Execute this command locally
#
# ./uninstall.sh
#
# Example:
# VM_IP=65.108.148.216 REMOTE_HOME_DIR=$HOME CLUSTER_NAME=toto TCE_VERSION=v0.12.0 ./scripts/uninstall.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
# - CLUSTER_NAME: TCE Kind cluster name
# - VM_IP: IP address of the VM where the cluster is running
# - TCE_VERSION: Version of the Tanzu client (e.g. v0.12.0)

set -e

CLUSTER_NAME=${CLUSTER_NAME:-toto}
REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}

DIR=`dirname $0` # to get the location where the script is located

. $DIR/util.sh

log "YELLOW" "Deleting the TCE cluster $CLUSTER_NAME"
tanzu uc delete $CLUSTER_NAME

log "YELLOW" "Uninstall the Tanzu CLI"
$REMOTE_HOME_DIR/.local/share/tce/uninstall.sh

log "YELLOW" "Remove tce temp directory"
rm -rf $REMOTE_HOME_DIR/tce

log "YELLOW" "Remove .kube-tkg"
rm -rf $REMOTE_HOME_DIR/.kube-tkg