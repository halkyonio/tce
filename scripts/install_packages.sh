#!/usr/bin/env bash
#
#
# Execute this command locally to install the pckages on TCE
#
# ./install_packages.sh
#
# Example:
# VM_IP=65.108.148.216 CLUSTER_NAME=toto ./scripts/install_packages.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
# - VM_IP: IP address of the VM where the cluster is running
# - REGISTRY_SERVER: Container image registry (e.g: docker.io, ghcr.io, ...)
# - REGISTRY_OWNER: Username of the account, github org used to access the Registry server
# - REGISTRY_USERNAME: Registry account username
# - REGISTRY_PASSWORD: Registry account password
#
set -e

VM_IP=${VM_IP:=127.0.0.1}
CLUSTER_NAME=${CLUSTER_NAME:=toto}
REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}

REGISTRY_SERVER=${REGISTRY_SERVER}
REGISTRY_OWNER=${REGISTRY_OWNER}
REGISTRY_USERNAME=${REGISTRY_USERNAME}
REGISTRY_PASSWORD=${REGISTRY_PASSWORD}

TCE_DIR=$REMOTE_HOME_DIR/tce
TCE_PACKAGES_NAMESPACE=tanzu-package-repo-global
TCE_CORE_PACKAGES_NAMESPACE=tkg-system

DIR=`dirname $0` # to get the location where the script is located

. $DIR/util.sh

SECONDS=0

log "CYAN" "Install the repository containing the kubernetes dashboard package"
tanzu package repository add demo-repo --url ghcr.io/halkyonio/packages/demo-repo:0.1.0 -n $TCE_PACKAGES_NAMESPACE

log "CYAN" "Install first the mandatory packages: secregen-controller"
# for pkg in secretgen-controller:secretgen-controller.community.tanzu.vmware.com:0.7.1:$TCE_CORE_PACKAGES_NAMESPACE
# do
#   IFS=':' read -ra param <<< "$pkg"
#   log "CYAN" "Deploy package: ${param[0]} - ${param[1]} - ${param[2]} from repo namespace: ${param[3]}"
#   tanzu package install ${param[0]} --package-name ${param[1]} --version ${param[2]} -n ${param[3]}
# done
tanzu package install secretgen-controller -p secretgen-controller.community.tanzu.vmware.com -v 0.7.1 -n $TCE_CORE_PACKAGES_NAMESPACE

log "CYAN" "Create and export to all the namespaces the registry credentials secret"
tanzu secret registry add registry-credentials --server ghcr.io --username $REGISTRY_USERNAME --password $REGISTRY_PASSWORD --export-to-all-namespaces -y

log "CYAN" "Got the latest version of the packages to be installed ..."
declare -A packages
packages[1,0]="app-toolkit"
packages[1,1]="app-toolkit.community.tanzu.vmware.com"
packages[1,2]="YES"
cat <<EOF > $TCE_DIR/values-app-toolkit.yml
contour:
  envoy:
    service:
      type: ClusterIP
    hostPorts:
      enable: true

knative_serving:
  domain:
    type: real
    name: ${VM_IP}.nip.io

kpack:
  kp_default_repository: "$REGISTRY_SERVER/$REGISTRY_OWNER/build-service"
  kp_default_repository_username: "$REGISTRY_USERNAME"
  kp_default_repository_password: "$REGISTRY_PASSWORD"

cartographer_catalog:
  registry:
    server: $REGISTRY_SERVER
    repository: $REGISTRY_OWNER

developer_namespace: demo
EOF

packages[2,0]="k8s-ui"
packages[2,1]="kubernetes-dashboard.halkyonio.io"
packages[2,2]="YES"
cat <<EOF > $TCE_DIR/values-k8s-ui.yml
vm_ip: $VM_IP
EOF

for ((i=1;i<=2;i++)) do
        PKG_NAME=${packages[$i,1]}
        jsonBody=`tanzu package available list -A -o json`
        PKG_VERSION=`echo $jsonBody | jq -r '.[] | select(.name == "'"$PKG_NAME"'")."latest-version"'`
        PKG_SHORT_NAME=`echo $jsonBody | jq -r '.[] | select(.name == "'"$PKG_NAME"'")."display-name"'`
        packages[$i,3]=$PKG_VERSION
        echo "Installing ${packages[$i,0]} - ${packages[$i,1]} - ${packages[$i,3]}"
        if [ "${packages[$i,2]}" = "YES" ]; then
          tanzu package install ${packages[$i,0]} --package-name ${packages[$i,1]} --version ${packages[$i,3]} -n $TCE_PACKAGES_NAMESPACE -f $TCE_DIR/values-${packages[$i,0]}.yml
        else
          tanzu package install ${packages[$i,0]} --package-name ${packages[$i,1]} --version ${packages[$i,3]} -n $TCE_PACKAGES_NAMESPACE
        fi
done

log "YELLOW" "Kubernetes URL: https://k8s-ui.$VM_IP.nip.io"
kubectl rollout status deployment/kubernetes-dashboard -n kubernetes-dashboard --timeout=240s
K8S_UI_TOKEN=$(kubectl get secret $(kubectl get serviceaccount kubernetes-dashboard -n kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" -n kubernetes-dashboard | base64 --decode)
log_line "YELLOW" "Kubernetes dashboard TOKEN: $K8S_UI_TOKEN"

ELAPSED="Elapsed: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec" && echo $ELAPSED
log "YELLOW" "Elapsed time to create TCE and install the packages: $ELAPSED"