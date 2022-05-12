#!/usr/bin/env bash
#
# This script installs on a TCE K8s cluster the kubeapps UI
#
# ./install_kubeapps.sh
#
# Example:
# VM_IP=65.108.148.216 ./scripts/install_kubeapps.sh
#
# Define the following env vars:
# - VM_IP: IP address of the VM where the cluster is running
#
# To remove the kubeapps
# helm uninstall kubeapps -n kubeapps
# kubectl delete ns kubeapps
#

DIR=`dirname $0` # to get the location where the script is located

. $DIR/util.sh

cat <<EOF > kubeapps-values.yml
dashboard:
  image:
    registry: ghcr.io
    repository: halkyonio/dashboard
    tag: dev
kubeops:
  enabled: true
  image:
    registry: ghcr.io
    repository: halkyonio/kubeops
    tag: dev
kubeappsapis:
  image:
    registry: ghcr.io
    repository: halkyonio/kubeapps-apis
    tag: dev
  enabledPlugins:
    - resources
    - kapp-controller-packages
    - helm-packages
packaging:
  helm:
    enabled: true
  carvel:
    enabled: true
featureFlags:
  operators: false
EOF
kubectl create ns kubeapps
helm install kubeapps -n kubeapps bitnami/kubeapps -f kubeapps-values.yml
cat <<EOF | kubectl apply -f -
apiVersion: projectcontour.io/v1
kind: HTTPProxy
metadata:
  name: kubeapps-grpc
  namespace: kubeapps
spec:
  virtualhost:
    fqdn: kubeapps.$VM_IP.nip.io
  routes:
    - conditions:
      - prefix: /apis/
      pathRewritePolicy:
        replacePrefix:
        - replacement: /
      services:
      - name: kubeapps-internal-kubeappsapis
        port: 8080
        protocol: h2c
    - services:
      - name: kubeapps
        port: 80
EOF
kubectl create --namespace default serviceaccount kubeapps-operator
kubectl create clusterrolebinding kubeapps-operator --clusterrole=cluster-admin --serviceaccount=default:kubeapps-operator
kubectl create clusterrolebinding kubeapps-operator-cluster-admin --clusterrole=cluster-admin --serviceaccount kubeapps:kubeapps-operator
KUBEAPPS_TOKEN=$(kubectl get --namespace default secret $(kubectl get --namespace default serviceaccount kubeapps-operator -o jsonpath='{range .secrets[*]}{.name}{"\n"}{end}' | grep kubeapps-operator-token) -o jsonpath='{.data.token}' -o go-template='{{.data.token | base64decode}}')
log_line "YELLOW" "Kubeapps TOKEN: $KUBEAPPS_TOKEN"
log_line "YELLOW" "Kubeapps URL: https://kubeapps.$VM_IP.nip.io"
log_line "YELLOW" "Install OLM if not yet done !!"
log_line "YELLOW" "curl -L https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.20.0/install.sh -o install.sh"
log_line "YELLOW" "chmod +x install.sh"
log_line "YELLOW" "./install.sh v0.20.0"