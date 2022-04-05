#!/usr/bin/env bash

VM_IP=${VM_IP:=127.0.0.1}
REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
TCE_DIR=$REMOTE_HOME_DIR/tce
TCE_PACKAGES_NAMESPACE=tanzu-package-repo-global
PKG_NAME="harbor"
PKG_FQNAME="harbor.community.tanzu.vmware.com"

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

log "CYAN" "Populate a self signed certificate ..."
mkdir -p $TCE_DIR/certs/${REG_SERVER}
sudo mkdir -p /etc/docker/certs.d/${REG_SERVER}

log "CYAN" "Generate the openssl stuff"
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

cat <<EOF > $TCE_DIR/values-harbor.yml
namespace: harbor
hostname: harbor.$VM_IP.nip.io
port:
  https: 443
logLevel: info
enableContourHttpProxy: true
tlsCertificateSecretName: harbor-tls
EOF

jsonBody=`tanzu package available list -o json`
PKG_VERSION=`echo $jsonBody | jq -r '.[] | select(.name == "'"$PKG_FQNAME"'")."latest-version"'`
PKG_SHORT_NAME=`echo $jsonBody | jq -r '.[] | select(.name == "'"$PKG_FQNAME"'")."display-name"'`
echo "Installing $PKG_NAME - $PKG_FQNAME - $PKG_VERSION"

tanzu package install $PKG_NAME --package-name $PKG_FQNAME --version $PKG_VERSION -n $TCE_PACKAGES_NAMESPACE -f $TCE_DIR/values-${packages[$i,0]}.yml --wait=false

log_line "YELLOW" "Execute some additional stuffs for Harbor"
imgpkg pull -b projects.registry.vmware.com/tce/harbor -o $TCE_DIR/harbor
$TCE_DIR/harbor/config/scripts/generate-passwords.sh >> $TCE_DIR/values-harbor.yml
head -n -1 $TCE_DIR/values-harbor.yml> $TCE_DIR/new-values-harbor.yml; mv $TCE_DIR/new-values-harbor.yml $TCE_DIR/values-harbor.yml

log_line "YELLOW" "Execute some additional stuffs for Harbor"
kubectl create -n harbor secret generic harbor-tls \
  --type=kubernetes.io/tls \
  --from-file=$TCE_DIR/certs/harbor.$VM_IP.nip.io/tls.crt \
  --from-file=$TCE_DIR/certs/harbor.$VM_IP.nip.io/tls.key

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
