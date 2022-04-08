#!/usr/bin/env bash
#
# This script generates a Selfsigned CA using the Hostname of the registry
# upload it to kind control plan, update the containerd config.toml
# and restart containerd
#
# Execute this command locally
#
# ./inkind_gen_load_cert.sh
#
# Example:
# VM_IP=65.108.148.216 CLUSTER_NAME=toto ./scripts/install.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: (remote)home directory where files will be created within the remote VM
# - VM_IP: IP address of the VM where the cluster is running
# - CLUSTER_NAME: TCE Kind cluster name
# - REGISTRY_HOST_NAME: hostname fo the private registry (E.g harbor, kind-registry, ....)
#
REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
CLUSTER_NAME=${CLUSTER_NAME:-kind}

VM_IP=${VM_IP:=127.0.0.1}
REGISTRY_HOST_NAME=${REGISTRY_HOST_NAME}
IP_NIP_IO=${VM_IP}.nip.io
REGISTRY_FQNAME=${REGISTRY_HOST_NAME}.${IP_NIP_IO}

TEMP_DIR="${REMOTE_HOME_DIR}/temp"

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

log_line "CYAN" "The fully qualified name of the registry is: ${REGISTRY_FQNAME}"

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
CN = "$REGISTRY_HOST_NAME.$IP_AND_DOMAIN_NAME"
[x509_ext]
basicConstraints        = critical, CA:TRUE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always, issuer:always
keyUsage                = critical, cRLSign, digitalSignature, keyCertSign
nsComment               = "OpenSSL Generated Certificate"
subjectAltName          = @alt_names
[alt_names]
DNS.1 = "$REGISTRY_HOST_NAME.$IP_NIP_IO"
DNS.2 = "notary.$IP_NIP_IO"
EOF
)
echo "$CFG"
}

log "CYAN" "Populate a self signed certificate ..."
LOCAL_CERT_PATH="${TEMP_DIR}/certs"
log "CYAN" "Local cert registry path is: ${LOCAL_CERT_PATH}"

LOCAL_CERT_REGISTRY_PATH="${LOCAL_CERT_PATH}/${REGISTRY_FQNAME}"
log "CYAN" "Local cert path is: ${LOCAL_CERT_REGISTRY_PATH}"

mkdir -p ${LOCAL_CERT_REGISTRY_PATH}

log "CYAN" "Generate the openssl stuff"
create_openssl_cfg > ${LOCAL_CERT_PATH}/req.cnf

log "CYAN" "Create the self signed certificate certificate and client key files"
openssl req -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:4096 \
  -keyout ${LOCAL_CERT_REGISTRY_PATH}/tls.key \
  -out ${LOCAL_CERT_REGISTRY_PATH}/tls.crt \
  -config ${LOCAL_CERT_PATH}/req.cnf \
  -sha256


log_line "CYAN" "Copy the tls.crt and tls.key file to the control plane container"
docker exec ${CLUSTER_NAME}-control-plane mkdir -p /etc/certs
docker cp ${LOCAL_CERT_REGISTRY_PATH}/tls.crt ${CLUSTER_NAME}-control-plane:/etc/certs
docker cp ${LOCAL_CERT_REGISTRY_PATH}/tls.key ${CLUSTER_NAME}-control-plane:/etc/certs

log_line "CYAN" "Update the control plane container containerd file to add the harbor mirror"
docker cp ${CLUSTER_NAME}-control-plane:/etc/containerd/config.toml ${LOCAL_CERT_PATH}/config.toml
cat << EOF >> ${LOCAL_CERT_PATH}/config.toml
[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors.${REGISTRY_FQNAME}]
      endpoint = ["https://${REGISTRY_FQNAME}"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs]
    [plugins."io.containerd.grpc.v1.cri".registry.configs.${REGISTRY_FQNAME}.tls]
      cert_file = "/etc/certs/tls.crt"
      key_file  = "/etc/certs/tls.key"
EOF
cat ${LOCAL_CERT_PATH}/config.toml

log_line "CYAN" "Copy the new containerd config.toml file"
docker cp ${LOCAL_CERT_PATH}/config.toml ${CLUSTER_NAME}-control-plane:/etc/containerd/config.toml

log_line "CYAN" "Copy the tls.crt to /usr/local/share/ca-certificates/"
docker exec ${CLUSTER_NAME}-control-plane cp /etc/certs/tls.crt /usr/local/share/ca-certificates/${REGISTRY_FQNAME}.crt

log_line "CYAN" "Update the ca-certificates"
docker exec ${CLUSTER_NAME}-control-plane update-ca-certificates

log_line "CYAN" "Restart the containerd service"
sudo docker exec ${CLUSTER_NAME}-control-plane service containerd restart