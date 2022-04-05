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
# - REMOTE_HOME_DIR: Remote home dir where the script is executed
# - TCE_VERSION: Version of the Tanzu client to be installed. E.g. v0.11.0
#
set -e

KUBE_CFG=${KUBE_CFG:=config}
VM_IP=${VM_IP:=127.0.0.1}
CLUSTER_NAME=${CLUSTER_NAME:=toto}
REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}

TCE_VERSION=${TCE_VERSION:-v0.11.0}
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

create_openssl_cfg() {
CFG=$(cat <<EOF
[req]
distinguished_name = subject
x509_extensions    = x509_ext
prompt             = no
[subject]
C  = BE
ST = Namur
L  = Florennes
O  = Red Hat
OU = Snowdrop
CN = $REG_SERVER
[x509_ext]
basicConstraints        = critical, CA:TRUE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always, issuer:always
keyUsage                = critical, cRLSign, digitalSignature, keyCertSign
nsComment               = "OpenSSL Generated Certificate"
subjectAltName          = @alt_names
[alt_names]
DNS.1 = $REG_SERVER
DNS.2 = notary.$REG_SERVER
EOF
)
echo "$CFG"
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

log "CYAN" "Populate a self signed certificate ..."
mkdir -p $TCE_DIR/certs/${REG_SERVER}
sudo mkdir -p /etc/docker/certs.d/${REG_SERVER}

log "CYAN" "Generate the openssl stuff"

# Generate a CA certificate private key.
#openssl genrsa -out $TCE_DIR/certs/ca.key 4096

# Generate the CA certificate.
#openssl req -x509 -new -nodes -sha512 -days 3650 \
# -subj "/C=CN/ST=Namur/L=Florennes/O=Red Hat/OU=Snowdrop/CN=harbor.65.108.148.216.nip.io" \
# -key $TCE_DIR/certs/ca.key \
# -out $TCE_DIR/certs/ca.crt

# Generate a Server Certificate
#openssl genrsa -out tls.key 4096
#openssl req -sha512 -new \
#    -subj "/C=CN/ST=Namur/L=Florennes/O=Red Hat/OU=Snowdrop/CN=harbor.65.108.148.216.nip.io" \
#    -key $TCE_DIR/certs/tls.key \
#    -out $TCE_DIR/certs/tls.csr

# Generate an x509 v3 extension file.
# cat > $TCE_DIR/certs/v3.ext <<-EOF
# basicConstraints        = critical, CA:TRUE
# subjectKeyIdentifier    = hash
# authorityKeyIdentifier  = keyid:always, issuer:always
# keyUsage                = critical, cRLSign, digitalSignature, keyCertSign
# nsComment               = "OpenSSL Generated Certificate"
# subjectAltName          = @alt_names
#
#[alt_names]
#DNS.1=harbor.65.108.148.216.nip.io
#DNS.2=notary.harbor.65.108.148.216.nip.io
#EOF

# Use the v3.ext file to generate a certificate for your Harbor host.
#openssl x509 -req -sha512 -days 3650 \
#    -extfile $TCE_DIR/certs/v3.ext \
#    -CA $TCE_DIR/certs/ca.crt -CAkey $TCE_DIR/certs/ca.key -CAcreateserial \
#    -in $TCE_DIR/certs/tls.csr \
#    -out $TCE_DIR/certs/tls.crt

# mkdir -p $TCE_DIR/certs/${REG_SERVER}
# cp $TCE_DIR/certs/ca.crt $TCE_DIR/certs/${REG_SERVER}
# cp $TCE_DIR/certs/tls.crt $TCE_DIR/certs/${REG_SERVER}
# cp $TCE_DIR/certs/tls.key $TCE_DIR/certs/${REG_SERVER}

create_openssl_cfg > $TCE_DIR/certs/req.cnf

log "CYAN" "Create the self signed certificate certificate and client key files"
openssl req -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:4096 \
  -keyout $TCE_DIR/certs/${REG_SERVER}/tls.key \
  -out $TCE_DIR/certs/${REG_SERVER}/tls.crt \
  -config $TCE_DIR/certs/req.cnf \
  -sha256

sudo cp $TCE_DIR/certs/${REG_SERVER}/tls.crt /etc/docker/certs.d/${REG_SERVER}/tls.crt

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
    containerdConfigPatches:
    - |-
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${REG_SERVER}"]
        endpoint = ["https://${REG_SERVER}"]
      [plugins."io.containerd.grpc.v1.cri".registry.configs."${REG_SERVER}".tls]
        cert_file = "/etc/docker/certs.d/${REG_SERVER}/tls.crt"
        key_file  = "/etc/docker/certs.d/${REG_SERVER}/tls.key"
    nodes:
    - role: control-plane
      extraMounts:
        - containerPath: /etc/docker/certs.d/${REG_SERVER}
          hostPath: $TCE_DIR/certs/${REG_SERVER}
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
TkrLocation: projects.registry.vmware.com/tce/tkr:v1.21.5
PortsToForward: []
SkipPreflight: false
ControlPlaneNodeCount: "1"
WorkerNodeCount: "0"
EOF

log "CYAN" "Create the $CLUSTER_NAME TCE cluster"
tanzu uc create $CLUSTER_NAME -f $TCE_DIR/config.yml

#log "CYAN" "Check the latest image available of the repo for $TCE_VERSION "
#REPO_VERSION=$(crane ls projects.registry.vmware.com/tce/main | grep $TCE_VERSION | tail -1)
#log "CYAN" "Update the repository to get the latest packages"
#tanzu package repository update community-repository --url projects.registry.vmware.com/tce/main:$REPO_VERSION -n $TCE_PACKAGES_NAMESPACE

log "CYAN" "Install our demo repository containing the kubernetes dashboard package"
tanzu package repository add demo-repo --url ghcr.io/halkyonio/packages/demo-repo:0.1.0 -n $TCE_PACKAGES_NAMESPACE

log "CYAN" "Create the different needed namespaces: tce, harbor, kubernetes-dashboard"
kubectl create ns harbor
kubectl create ns kubernetes-dashboard

log "CYAN" "Got the latest version of the packages to be installed ..."
declare -A packages
packages[0,0]="cert-manager"
packages[0,1]="cert-manager.community.tanzu.vmware.com"
packages[0,2]=""

packages[1,0]="fluxcd"
packages[1,1]="fluxcd-source-controller.community.tanzu.vmware.com"
packages[1,2]=""

packages[2,0]="contour"
packages[2,1]="contour.community.tanzu.vmware.com"
packages[2,2]="YES"
cat <<EOF > $TCE_DIR/values-contour.yaml
envoy:
  service:
    type: ClusterIP
  hostPorts:
    enable: true
EOF

packages[3,0]="knative"
packages[3,1]="knative-serving.community.tanzu.vmware.com"
packages[3,2]="YES"
cat <<EOF > $TCE_DIR/values-knative.yml
domain:
  type: real
  name: $VM_IP.nip.io
EOF

packages[4,0]="kpack"
packages[4,1]="kpack.community.tanzu.vmware.com"
packages[4,2]=""

packages[5,0]="cartographer"
packages[5,1]="cartographer.community.tanzu.vmware.com"
packages[5,2]=""

packages[5,0]="harbor"
packages[5,1]="harbor.community.tanzu.vmware.com"
packages[5,2]="YES"
log "CYAN" "Harbor installation ..."
cat <<EOF > $TCE_DIR/values-harbor.yml
namespace: harbor
hostname: harbor.$VM_IP.nip.io
port:
  https: 443
logLevel: info
enableContourHttpProxy: true
tlsCertificateSecretName: harbor-tls
EOF

packages[6,0]="my-dashboard"
packages[6,1]="kubernetes-dashboard.halkyonio.io"
packages[6,2]="YES"
cat <<EOF > $TCE_DIR/k8s-ui-values.yml
vm_ip: $VM_IP
EOF

for ((i=0;i<=4;i++)) do
        PKG_NAME=${packages[$i,1]}
        jsonBody=`tanzu package available list -o json`
        PKG_VERSION=`echo $jsonBody | jq -r '.[] | select(.name == "'"$PKG_NAME"'")."latest-version"'`
        PKG_SHORT_NAME=`echo $jsonBody | jq -r '.[] | select(.name == "'"$PKG_NAME"'")."display-name"'`
        packages[$i,2]=$PKG_VERSION
        echo "Installing ${packages[$i,0]} - ${packages[$i,1]} - ${packages[$i,2]}"
        if [ "${packages[$i,3]}" = "" ]; then
          echo "tanzu package install contour --package-name ${packages[$i,1]} --version ${packages[$i,2]} -n $TCE_PACKAGES_NAMESPACE --wait=false"
        else
          echo "tanzu package install contour --package-name ${packages[$i,1]} --version ${packages[$i,2]} -n $TCE_PACKAGES_NAMESPACE -f $TCE_DIR/values-${packages[$i,0]}.yaml"
        fi
done

log_line "YELLOW" "Additional stuff for Harbor"
$TCE_DIR/harbor/config/scripts/generate-passwords.sh >> $TCE_DIR/values-harbor.yml
head -n -1 $TCE_DIR/values-harbor.yml> $TCE_DIR/new-values-harbor.yml; mv $TCE_DIR/new-values-harbor.yml $TCE_DIR/values-harbor.yml
kubectl create -n harbor secret generic harbor-tls --type=kubernetes.io/tls --from-file=$TCE_DIR/certs/harbor.$VM_IP.nip.io/tls.crt --from-file=$TCE_DIR/certs/harbor.$VM_IP.nip.io/tls.key

HARBOR_PWD_STR=$(cat $TCE_DIR/values-harbor.yml | grep harborAdminPassword)
IFS=': ' && read -a strarr <<< $HARBOR_PWD_STR
HARBOR_PWD=${strarr[1]}
log "YELLOW" "Harbor URL: https://harbor.$VM_IP.nip.io and admin password: $HARBOR_PWD"

log_line "YELLOW" "To push/pull images from the Harbor registry, create a secret and configure the imgPullSecret of the service account"
log_line "YELLOW" "kubectl -n <NAMESPACE> create secret docker-registry regcred \""
log_line "YELLOW" "    --docker-server=harbor.<IP>.nip.io \""
log_line "YELLOW" "    --docker-username=admin \""
log_line "YELLOW" "    --docker-password=<HARBOR_PWD>"
log_line "YELLOW" "kubectl patch serviceaccount default -n <NAMESPACE> -p '{"imagePullSecrets": [{"name": "regcred"}]}'"

log "YELLOW" "Kubernetes URL: https://k8s-ui.$VM_IP.nip.io"

ELAPSED="Elapsed: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec" && echo $ELAPSED
log "YELLOW" "Elapsed time to create TCE and install the packages: $ELAPSED"