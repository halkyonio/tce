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
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM (e.g /home/snowdrop)
# - VM_IP: IP address of the VM where the cluster is running (e.g 10.1.1.2)
# - CLUSTER_NAME: TCE Kind cluster name (e.g toto)
# - TCE_VERSION: Version of the Tanzu client to be installed. (e.g. v0.12.0)
# - TKR_VERSION: kubernetes version which corresponds to the Tanzu Kind Node TCE image. (e.g v1.22.5)
# - REMOTE_K8S_PORT: Remote port to access the Kubernetes API Server (e.g. 31452)
#
set -e

VM_IP=${VM_IP:=127.0.0.1}
CLUSTER_NAME=${CLUSTER_NAME:=toto}
REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
REMOTE_K8S_PORT=${REMOTE_K8S_PORT:-31452}

TCE_VERSION=${TCE_VERSION:-v0.12.0}
TKR_VERSION=${TKR_VERSION:-v1.22.7}
TCE_DIR=$REMOTE_HOME_DIR/tce

DIR=`dirname $0` # to get the location where the script is located

. $DIR/util.sh

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
      apiServerPort: $REMOTE_K8S_PORT
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
PortsToForward: []
SkipPreflight: false
ControlPlaneNodeCount: "1"
WorkerNodeCount: "0"
EOF

log "CYAN" "Create the $CLUSTER_NAME TCE cluster"
tanzu uc create $CLUSTER_NAME -f $TCE_DIR/config.yml

sleep 10s

log_line "GREEN" ""
log_line "GREEN" "The TCE kind cluster '$CLUSTER_NAME' has been created on a K8s cluster: $TKR_VERSION !"
log_line "GREEN" "The following packages are available: "

# Print a table containing the packages
header="\033[0;32m %-30s | %-55s | %10s\n"
format="\033[0;32m %-30s | %-55s | %10s\n"

printf "$header" "Name" "Package Name" "Version"
repeat 101 '-'; echo

while read -r package; do
  name=$(echo $package | jq -r '."display-name"')
  package_name=$(echo $package | jq -r '."name"')
  package_version=$(echo $package | jq -r '."latest-version"')
  printf "$format" "$name" "$package_name" "$package_version"
done <<< "$(tanzu package available list -A -o json | jq -c '.[]')"

log_line "GREEN" ""
log_line "GREEN" "You can access it remotely using the url: https://$VM_IP:$REMOTE_K8S_PORT"
log_line "GREEN" "Update then your .kube/conf file with this cfg: $REMOTE_HOME_DIR/.config/tanzu/tkg/unmanaged/$CLUSTER_NAME/kube.conf"
log_line "GREEN" ""
cat $REMOTE_HOME_DIR/.config/tanzu/tkg/unmanaged/$CLUSTER_NAME/kube.conf
log_line "GREEN" ""