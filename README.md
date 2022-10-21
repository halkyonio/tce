# Tanzu Community Edition

* [Warning](#warning)
* [Introduction](#introduction)
* [TCE installation](#tce-installation)
  * [All in one](#all-in-one)
  * [Manual steps](#manual-steps)
    * [Install TCE](#install-tce)
    * [Create a K8s cluster](#create-a-k8s-cluster)
    * [Configure/install the needed packages](#configureinstall-the-needed-packages)
* [Demo](#demo)

## Warning

This project has been archived as Tanzu Community Edition OSS project is EOL (December 2022) and been replaced by TKG !

## Introduction

This page describes how to install Tanzu community Edition (aka: TCE) and play a nice Spring Boot Petclinic demo. 

**TL;DR**

TCE is a standalone client designed around a pluggable architecture, able to create clusters (unmanaged - local or managed - AWS, Azure, vSphere)
like the packages and/or repository about the components to be installed.

References: 

- Github repo: https://github.com/vmware-tanzu/community-edition

- Doc: https://tanzucommunityedition.io/

## TCE installation 

### All in one

Use the following bash [script](scripts/install.sh) to perform the following operations:

- Install the Tanzu binary client 
- Create an [unmanaged](https://tanzucommunityedition.io/docs/v0.12/getting-started-unmanaged/#getting-started-with-unmanaged-clusters) kubernetes cluster 
- Deploy some cool packages such as the [App-Toolkit package](https://tanzucommunityedition.io/docs/v0.12/package-readme-app-toolkit-0.2.0/) able to demo a GitOps scenario

Execute the `./scripts/install.sh` where you will set the following variables:

- **REMOTE_HOME_DIR**: home directory where files will be installed locally or within the remote VM
- **VM_IP**: IP address of the VM where the cluster is running (e.g.: 127.0.0.1)
- **CLUSTER_NAME**: TCE Kind cluster name
- **TCE_VERSION**: Version of the Tanzu client to be installed. (e.g.: v0.12.0)
- **TKR_VERSION**: kubernetes version which corresponds to the Tanzu Kind Node TCE image. (e.g.: v1.22.7-2)
- **REGISTRY_SERVER**: Container image registry (e.g: docker.io, ghcr.io, ...)
- **REGISTRY_OWNER**: Username of the account, github org used to access the Registry server
- **REGISTRY_USERNAME**: Registry account username
- **REGISTRY_PASSWORD**: Registry account password

```bash
REMOTE_HOME_DIR="$HOME" \
VM_IP="127.0.0.1" \
CLUSTER_NAME="toto" \
TCE_VERSION="v0.12.0" \
TKR_VERSION="v1.22.7-2" \
REGISTRY_SERVER="ghcr.io" \
REGISTRY_OWNER="<org>" \
REGISTRY_USERNAME="<github_user>" \
REGISTRY_PASSWORD="<github_token>" \
./scripts/install.sh

or for remote deployment

tar -czf - ./scripts/*.sh |  ssh -i ${SSH_KEY} ${USER}@${IP} -p ${PORT} "tar -xzf -"
ssh -i ${SSH_KEY} ${USER}@${IP} -p ${PORT} \
    REMOTE_HOME_DIR="/home/centos" \
    VM_IP=${IP} \
    CLUSTER_NAME="toto" \
    TCE_VERSION="v0.12.0" \
    TKR_VERSION="v1.22.7-2" \
    REGISTRY_SERVER="ghcr.io" \
    REGISTRY_OWNER="<org>" \
    REGISTRY_USERNAME="<github_user>" \
    REGISTRY_PASSWORD="<github_token>" \
    "bash ./scripts/install.sh"
```

To uninstall it, use the command 

```bash
REMOTE_HOME_DIR="/home/snowdrop" \
CLUSTER_NAME="toto" \
./scripts/uninstall.sh

or

ssh -i ${SSH_KEY} ${USER}@${IP} -p ${PORT} \
    REMOTE_HOME_DIR="/home/snowdrop" \
    CLUSTER_NAME="toto" \
    "bash ./scripts/uninstall.sh"
````

If you need to use a private image registry (= harbor), then execute the following bash command top of a running TCE.
It will install the harbor package, will populate a selfsigned CA certificate/key and update the containerd running within the control-plane.
Follow the instructions within the terminal to figure out how to update the docker certificate folder, to log on and push images to the private registry:
```bash
REMOTE_HOME_DIR=<LOCAL_OR_REMOTE_HOME_DIR> VM_IP=<VM_IP> CLUSTER_NAME="toto" ./scripts/install_harbor.sh
```

### Manual steps

#### Install TCE

Install the Tanzu client using either [released version](https://tanzucommunityedition.io/docs/v0.12/cli-installation/) or a [snapshot](https://github.com/vmware-tanzu/community-edition#latest-daily-build)
as described hereafter

```bash
mkdir tce && cd tce/
TCE_OS_VERSION="tce-linux-amd64-v0.12.0-dev.1"
wget https://storage.googleapis.com/tce-cli-plugins-staging/build-daily/2022-03-08/$TCE_OS_VERSION.tar.gz
./install.sh

# Add completion
mkdir $HOME/.tanzu
tanzu completion bash >  $HOME/.tanzu/completion.bash.inc
printf "\n# Tanzu shell completion\nsource '$HOME/.tanzu/completion.bash.inc'\n" >> $HOME/.bash_profile
```

#### Create a K8s cluster

Create the TCE unmanaged cluster (= Kind cluster)
```bash
tanzu uc delete toto
tanzu uc create toto -p 80:80 -p 443:443
```

#### Configure/install the needed packages

Install the needed packages
```bash
TCE_DIR=tce

tanzu package install secretgen-controller --package-name secretgen-controller.community.tanzu.vmware.com --version 0.7.1 -n tkg-system

IP="<IP_OF_THE_VM>"
REGISTRY_SERVER="<ghcr.io or docker.io or>"
REGISTRY_OWNER="<docker username or github org>"
REGISTRY_USERNAME="<docker account or github username>"
REGISTRY_PASSWORD="<docker password or github token>"
tanzu secret registry add registry-credentials --server ghcr.io --username $REGISTRY_USERNAME --password $REGISTRY_PASSWORD --export-to-all-namespaces`

cat <<EOF > $TCE_DIR/app-toolkit-values.yml
contour:
  envoy:
    service:
      type: ClusterIP
    hostPorts:
      enable: true
knative_serving:
  domain:
    type: real
    name: ${IP}.nip.io
kpack:
  kp_default_repository: "$REGISTRY_SERVER/$REGISTRY_OWNER/build-service"
  kp_default_repository_username: "$REGISTRY_USERNAME"
  kp_default_repository_password: "$REGISTRY_PASSWORD"
cartographer-catalog:
  registry:
      server: $REGISTRY_SERVER
      repository: $REGISTRY_OWNER
EOF
tanzu package install app-toolkit --package-name app-toolkit.community.tanzu.vmware.com --version 0.2.0 -f $TCE_DIR/app-toolkit-values.yml -n tanzu-package-repo-global
```

## Demo

We will now install a Spring Petclinic demo and check if the application os build/deployed and service exposed
```bash
APP=spring-tap-petclinic \
tanzu apps workload create $APP \
  --git-repo https://github.com/halkyonio/$APP.git#
  --git-branch main \
  --type web \
  --label app.kubernetes.io/part-of=$APP \
  -n demo
```
Tail the log of the workload to follow the status about the build, ...
```bash
tanzu apps workload -n demo tail spring-tap-petclinic
+ spring-tap-petclinic-build-1-build-pod › prepare
- spring-tap-petclinic-build-1-build-pod › prepare
+ spring-tap-petclinic-build-1-build-pod › prepare
+ spring-tap-petclinic-build-1-build-pod › analyze
- spring-tap-petclinic-build-1-build-pod › prepare
+ spring-tap-petclinic-build-1-build-pod › prepare
...
spring-tap-petclinic-build-1-build-pod[build] Paketo BellSoft Liberica Buildpack 9.3.1
spring-tap-petclinic-build-1-build-pod[build]   https://github.com/paketo-buildpacks/bellsoft-liberica
spring-tap-petclinic-build-1-build-pod[build]   Build Configuration:
spring-tap-petclinic-build-1-build-pod[build]     $BP_JVM_TYPE                 JRE             the JVM type - JDK or JRE
spring-tap-petclinic-build-1-build-pod[build]     $BP_JVM_VERSION              11              the Java version
...
```
Finally, get the URL of the service to access it using this command and open the address
within your favorite browser
```bash
# spring-tap-petclinic: Ready
---
lastTransitionTime: "2022-05-12T10:09:29Z"
message: ""
reason: Ready
status: "True"
type: Ready

Source
type:     git
url:      https://github.com/halkyonio/spring-tap-petclinic.git
branch:   main

Pods
NAME                                     STATUS      RESTARTS   AGE
spring-tap-petclinic-build-1-build-pod   Succeeded   0          10m

Knative Services
NAME                   READY   URL
spring-tap-petclinic   Ready   http://spring-tap-petclinic.demo.65.108.212.158.nip.io
```

Enjoy !!
