#!/usr/bin/env bash

VM_IP=${VM_IP:=127.0.0.1}
REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
CLUSTER_NAME=${CLUSTER_NAME-control-plane}
TCE_DIR=$REMOTE_HOME_DIR/tce
TCE_PACKAGES_NAMESPACE=tanzu-package-repo-global

PKG_FQNAME="harbor.community.tanzu.vmware.com"
IP_AND_DOMAIN_NAME="$VM_IP.nip.io"

DIR=`dirname $0` # to get the location where the script is located

. $DIR/util.sh

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
CN = "harbor.$IP_AND_DOMAIN_NAME"
[x509_ext]
basicConstraints        = critical, CA:TRUE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always, issuer:always
keyUsage                = critical, cRLSign, digitalSignature, keyCertSign
nsComment               = "OpenSSL Generated Certificate"
subjectAltName          = @alt_names
[alt_names]
DNS.1 = "harbor.$IP_AND_DOMAIN_NAME"
DNS.2 = "notary.$IP_AND_DOMAIN_NAME"
EOF
)
echo "$CFG"
}

log "CYAN" "Populate a self signed certificate ..."
mkdir -p $TCE_DIR/certs/harbor.$IP_AND_DOMAIN_NAME

log "CYAN" "Generate the openssl stuff"
create_openssl_cfg > $TCE_DIR/certs/req.cnf

log "CYAN" "Create the self signed certificate certificate and client key files"
openssl req -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:4096 \
  -keyout $TCE_DIR/certs/harbor.${IP_AND_DOMAIN_NAME}/tls.key \
  -out $TCE_DIR/certs/harbor.${IP_AND_DOMAIN_NAME}/tls.crt \
  -config $TCE_DIR/certs/req.cnf \
  -sha256

log_line "CYAN" "Copy the tls.crt and tls.key file to the control plane container"
docker exec $CLUSTER_NAME-control-plane mkdir -p /root/certs
docker cp $TCE_DIR/certs/harbor.${IP_AND_DOMAIN_NAME}/tls.crt $CLUSTER_NAME-control-plane:/root/certs
docker cp $TCE_DIR/certs/harbor.${IP_AND_DOMAIN_NAME}/tls.key $CLUSTER_NAME-control-plane:/root/certs

log_line "CYAN" "Update the control plane container containerd file to add the harbor mirror"
docker cp $CLUSTER_NAME-control-plane:/etc/containerd/config.toml $TCE_DIR/config.toml
cat << EOF >> $TCE_DIR/config.toml
[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors.harbor.$IP_AND_DOMAIN_NAME]
      endpoint = ["https://harbor.$IP_AND_DOMAIN_NAME"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs]
    [plugins."io.containerd.grpc.v1.cri".registry.configs.harbor.$IP_AND_DOMAIN_NAME.tls]
      cert_file = "/root/certs/tls.crt"
      key_file  = "/root/certs/tls.key"
EOF
cat $TCE_DIR/config.toml

log_line "CYAN" "Copy the new containerd config.toml file"
docker cp $TCE_DIR/config.toml $CLUSTER_NAME-control-plane:/etc/containerd/config.toml

log_line "CYAN" "Copy the tls.crt under /usr/local/share/ca-certificates/harbor.$VM_IP.nip.io.crt and update the the ca-certificates"
docker cp tce/certs/harbor.$VM_IP.nip.io/tls.crt $CLUSTER_NAME-control-plane:/usr/local/share/ca-certificates/harbor.$VM_IP.nip.io.crt
docker exec $CLUSTER_NAME-control-plane update-ca-certificates

log_line "CYAN" "Restart the containerd service"
sudo docker exec $CLUSTER_NAME-control-plane service containerd restart

PKG_FQNAME="harbor.community.tanzu.vmware.com"
jsonBody=`tanzu package available list -o json`
PKG_VERSION=`echo $jsonBody | jq -r '.[] | select(.name == "'"$PKG_FQNAME"'")."latest-version"'`
PKG_NAME=`echo $jsonBody | jq -r '.[] | select(.name == "'"$PKG_FQNAME"'")."display-name"'`

cat <<EOF > $TCE_DIR/values-harbor.yml
namespace: harbor
hostname: harbor.$VM_IP.nip.io
port:
  https: 443
logLevel: info
enableContourHttpProxy: true
tlsCertificateSecretName: harbor-tls
EOF

log_line "CYAN" "Populate the password and append additional secret keys to the values file"
imgpkg pull -b projects.registry.vmware.com/tce/harbor -o $TCE_DIR/harbor
$TCE_DIR/harbor/config/scripts/generate-passwords.sh >> $TCE_DIR/values-harbor.yml
head -n -1 $TCE_DIR/values-harbor.yml > $TCE_DIR/new-values-harbor.yml; mv $TCE_DIR/new-values-harbor.yml $TCE_DIR/values-harbor.yml

jsonBody=`tanzu package available list -o json`
PKG_SHORT_NAME=`echo $jsonBody | jq -r '.[] | select(.name == "'"cert-manager.community.tanzu.vmware.com"'")."display-name"'`
status=$(tanzu package installed -n $TCE_PACKAGES_NAMESPACE get $PKG_SHORT_NAME -o json | jq -r '.[].status')
if [ "$status" != "Reconcile succeeded" ]; then
  echo "The package cert-manager.community.tanzu.vmware.com is mandatory"
  exit
fi

PKG_SHORT_NAME=`echo $jsonBody | jq -r '.[] | select(.name == "'"contour.community.tanzu.vmware.com"'")."display-name"'`
status=$(tanzu package installed -n $TCE_PACKAGES_NAMESPACE get $PKG_SHORT_NAME -o json | jq -r '.[].status')
if [ "$status" != "Reconcile succeeded" ]; then
  echo "The package contour.community.tanzu.vmware.com is mandatory"
    exit
fi

log_line "CYAN" "Create the harbor-tls kubernetes secret containing the crt and key files"
kubectl create ns harbor
kubectl create -n harbor secret generic harbor-tls \
  --type=kubernetes.io/tls \
  --from-file=$TCE_DIR/certs/harbor.$VM_IP.nip.io/tls.crt \
  --from-file=$TCE_DIR/certs/harbor.$VM_IP.nip.io/tls.key

tanzu package install $PKG_NAME --package-name $PKG_FQNAME --version $PKG_VERSION -n $TCE_PACKAGES_NAMESPACE -f $TCE_DIR/values-$PKG_NAME.yml

HARBOR_PWD_STR=$(cat $TCE_DIR/values-$PKG_NAME.yml | grep harborAdminPassword)
IFS=': ' && read -a strarr <<< $HARBOR_PWD_STR
HARBOR_PWD=${strarr[1]}

log_line "YELLOW" ""
log_line "YELLOW" "Harbor URL: https://harbor.$VM_IP.nip.io and admin password: $HARBOR_PWD"
log_line "YELLOW" ""
log_line "YELLOW" "To allow locally to pull/push an image to the private registry, then copy the tls.crt file to the docker certificates folder: /etc/docker/certs.d/harbor.$VM_IP.nip.io/"
log_line "YELLOW" "sudo cp $TCE_DIR/certs/harbor.$VM_IP.nip.io/tls.crt /etc/docker/certs.d/harbor.$VM_IP.nip.io/"
log_line "YELLOW" ""
log_line "YELLOW" "Log on: docker login harbor.$VM_IP.nip.io -u admin -p $HARBOR_PWD"
log_line "YELLOW" "Tag and push an image:"
log_line "YELLOW" "docker pull gcr.io/google-samples/hello-app:1.0"
log_line "YELLOW" "docker tag gcr.io/google-samples/hello-app:1.0 harbor.$VM_IP.nip.io/library/hello-app:1.0"
log_line "YELLOW" "docker push harbor.$VM_IP.nip.io/library/hello-app:1.0"
log_line "YELLOW" ""
log_line "YELLOW" "Create a kubernetes pod to verify if the cluster can pull the image: "
log_line "YELLOW" "kubectl create deployment hello --image=harbor.$VM_IP.nip.io/library/hello-app:1.0"
log_line "YELLOW" "kubectl rollout status deployment/hello"
log_line "YELLOW" "deployment "hello" successfully rolled out"
log_line "YELLOW" ""
log_line "YELLOW" "To push/pull images from the Harbor registry using a pod, create a secret and configure the imagePullSecrets of the service account"
log_line "YELLOW" "kubectl -n <NAMESPACE> create secret harbor-creds regcred \""
log_line "YELLOW" "    --docker-server=harbor.$VM_IP.nip.io \""
log_line "YELLOW" "    --docker-username=admin \""
log_line "YELLOW" "    --docker-password=$HARBOR_PWD"
log_line "YELLOW" "kubectl patch serviceaccount <ACCOUNT_NAME> -n <NAMESPACE> -p '{"imagePullSecrets": [{"name": "harbor-creds"}]}'"
