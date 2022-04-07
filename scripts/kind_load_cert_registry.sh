#!/usr/bin/env bash

REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
CLUSTER_NAME=${CLUSTER_NAME-control-plane}
LOCAL_CERT_PATH=${LOCAL_CERT_PATH}

VM_IP=${VM_IP:=127.0.0.1}
REGISTRY_HOST_NAME=${REGISTRY_HOST_NAME}
IP_NIP_IO=${VM_IP}.nip.io
REGISTRY_FQNAME=${REGISTRY_HOST_NAME}.${IP_NIP_IO}

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

log_line "CYAN" "The registry fully qualified name is: ${REGISTRY_FQNAME}"

log_line "CYAN" "Copy the tls.crt and tls.key file to the control plane container"
docker exec $CLUSTER_NAME-control-plane mkdir -p /etc/certs
docker cp $LOCAL_CERT_PATH/tls.crt $CLUSTER_NAME-control-plane:/etc/certs
docker cp $LOCAL_CERT_PATH/tls.key $CLUSTER_NAME-control-plane:/etc/certs

log_line "CYAN" "Update the control plane container containerd file to add the harbor mirror"
docker cp $CLUSTER_NAME-control-plane:/etc/containerd/config.toml $TCE_DIR/config.toml
cat << EOF >> $TCE_DIR/config.toml
[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors.${REGISTRY_FQNAME}]
      endpoint = ["https://${REGISTRY_FQNAME}"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs]
    [plugins."io.containerd.grpc.v1.cri".registry.configs.${REGISTRY_FQNAME}.tls]
      cert_file = "/etc/certs/tls.crt"
      key_file  = "/etc/certs/tls.key"
EOF
cat $TCE_DIR/config.toml

log_line "CYAN" "Copy the new containerd config.toml file"
docker cp $TCE_DIR/config.toml $CLUSTER_NAME-control-plane:/etc/containerd/config.toml

log_line "CYAN" "Copy the tls.crt under /usr/local/share/ca-certificates/ and update the the ca-certificates"
docker cp /etc/certs/tls.crt $CLUSTER_NAME-control-plane:/usr/local/share/ca-certificates/${REGISTRY_FQNAME}
docker exec $CLUSTER_NAME-control-plane update-ca-certificates

log_line "CYAN" "Restart the containerd service"
sudo docker exec $CLUSTER_NAME-control-plane service containerd restart