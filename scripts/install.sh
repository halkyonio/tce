#!/usr/bin/env bash
#
# This script requires: curl, grep, sed, tr, and jq in order to work
#
# Execute this command locally
#
# ./install.sh
#
# Example:
# VM_IP=65.108.148.216 CLUSTER_NAME=toto ./scripts/install.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
# - VM_IP: IP address of the VM where the cluster is running
# - CLUSTER_NAME: TCE Kind cluster name
# - TCE_VERSION: Version of the Tanzu client to be installed. E.g. v0.12.0
# - TKR_VERSION: kubernetes version which corresponds to the Tanzu Kind Node TCE image. E.G. v1.22.5
#
set -e

VM_IP=${VM_IP:=127.0.0.1}
CLUSTER_NAME=${CLUSTER_NAME:=toto}
REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}

TCE_VERSION=${TCE_VERSION:-v0.12.0}
TKR_VERSION=${TKR_VERSION:-v1.22.7}
TCE_DIR=$REMOTE_HOME_DIR/tce
REGISTRY_SERVER=${REGISTRY_SERVER}
REGISTRY_OWNER=${REGISTRY_OWNER}
REGISTRY_USERNAME=${REGISTRY_USERNAME}
REGISTRY_PASSWORD=${REGISTRY_PASSWORD}
TCE_PACKAGES_NAMESPACE=tanzu-package-repo-global

DIR=`dirname $0` # to get the location where the script is located

SECONDS=0

. $DIR/util.sh
. $DIR/install_tce_client.sh
. $DIR/create_tce_cluster.sh
. $DIR/install_packages.sh

ELAPSED="Elapsed: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec" && echo $ELAPSED
log "YELLOW" "Elapsed time to create TCE and install the packages: $ELAPSED"