#!/usr/bin/env bash
#
# This script requires: curl, grep, sed, tr, and jq in order to work
#
# Execute this command locally
#
# ./scripts/install_tce_client.sh
#
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
# - TCE_VERSION: Version of the Tanzu client to be installed. E.g. v0.12.0
#
set -e

REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}

TCE_VERSION=${TCE_VERSION:-v0.12.0}
TCE_DIR=$REMOTE_HOME_DIR/tce

DIR=`dirname $0` # to get the location where the script is located

. $DIR/util.sh

SECONDS=0

log "CYAN" "Installing the tanzu client version: $TCE_VERSION"
curl -H "Accept: application/vnd.github.v3.raw" \
    -L https://api.github.com/repos/vmware-tanzu/community-edition/contents/hack/get-tce-release.sh | \
    bash -s $TCE_VERSION linux
mkdir -p $TCE_DIR
mv tce-linux-amd64-$TCE_VERSION.tar.gz $TCE_DIR
tar xzvf $TCE_DIR/tce-linux-amd64-$TCE_VERSION.tar.gz -C $TCE_DIR/
$TCE_DIR/tce-linux-amd64-$TCE_VERSION/install.sh

mkdir -p $REMOTE_HOME_DIR/.tanzu
tanzu completion bash >  $REMOTE_HOME_DIR/.tanzu/completion.bash.inc