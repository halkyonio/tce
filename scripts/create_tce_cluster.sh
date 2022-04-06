#!/usr/bin/env bash
#
# This script requires: curl, grep, sed, tr, and jq in order to work
#
# Execute this command locally
#
# ./create_tce_cluster.sh
#
# Example:
# VM_IP=65.108.148.216 CLUSTER_NAME=toto ./scripts/install.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
# - VM_IP: IP address of the VM where the cluster is running
# - CLUSTER_NAME: TCE Kind cluster name
# - REMOTE_HOME_DIR: Remote home dir where the script is executed
# - TCE_VERSION: Version of the Tanzu client to be installed. E.g. v0.11.0
# - TKR_VERSION: kubernetes version which corresponds to the Tanzu Kind Node TCE image. E.G. v1.22.5
#
set -e

KUBE_CFG=${KUBE_CFG:=config}
VM_IP=${VM_IP:=127.0.0.1}
CLUSTER_NAME=${CLUSTER_NAME:=toto}
REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}

TCE_VERSION=${TCE_VERSION:-v0.11.0}
TKR_VERSION=${TKR_VERSION:-v1.22.5}
TCE_DIR=$REMOTE_HOME_DIR/tce
TCE_PACKAGES_NAMESPACE=tanzu-package-repo-global

REG_SERVER=harbor.$VM_IP.nip.io

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

log "CYAN" "Install the tanzu client version: $TCE_VERSION"
curl -H "Accept: application/vnd.github.v3.raw" \
    -L https://api.github.com/repos/vmware-tanzu/community-edition/contents/hack/get-tce-release.sh | \
    bash -s $TCE_VERSION linux
mv tce-linux-amd64-$TCE_VERSION.tar.gz $TCE_DIR
tar xzvf $TCE_DIR/tce-linux-amd64-$TCE_VERSION.tar.gz -C $TCE_DIR/
$TCE_DIR/tce-linux-amd64-$TCE_VERSION/install.sh

mkdir -p $REMOTE_HOME_DIR/.tanzu
tanzu completion bash >  $REMOTE_HOME_DIR/.tanzu/completion.bash.inc

log "CYAN" "Configure the TCE cluster config file: $TCE_DIR/config.yml"
cat <<EOF > $TCE_DIR/config.yml
ClusterName: $CLUSTER_NAME
KubeconfigPath: ""
ExistingClusterKubeconfig: ""
NodeImage: ""
Provider: kind
ProviderConfiguration:
  rawKindConfig: |
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    networking:
      apiServerAddress: $VM_IP
      apiServerPort: 31452
    nodes:
    - role: control-plane
      extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
Cni: calico
CniConfiguration: {}
PodCidr: 10.244.0.0/16
ServiceCidr: 10.96.0.0/16
TkrLocation: projects.registry.vmware.com/tce/tkr:$TKR_VERSION
PortsToForward: []
SkipPreflight: false
ControlPlaneNodeCount: "1"
WorkerNodeCount: "0"
EOF

log "CYAN" "Create the $CLUSTER_NAME TCE cluster"
tanzu uc create $CLUSTER_NAME -f $TCE_DIR/config.yml

log "CYAN" "Install our demo repository containing the kubernetes dashboard package"
tanzu package repository add demo-repo --url ghcr.io/halkyonio/packages/demo-repo:0.1.0 -n $TCE_PACKAGES_NAMESPACE