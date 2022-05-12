#!/usr/bin/env bash
#
# Execute this command locally to remobe the Tanzu TCE client
#
# uninstall_tce_client.sh
#
# Example:
# TCE_VERSION=v0.12.0 ./scripts/uninstall_tce_client.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
# - TCE_VERSION: Version of the Tanzu client (e.g. v0.12.0)

set -e

REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
TCE_VERSION=${TCE_VERSION:-v0.12.0}
DIR=`dirname $0` # to get the location where the script is located

. $DIR/util.sh

log "YELLOW" "Uninstalling the Tanzu CLI"
$REMOTE_HOME_DIR/.local/share/tce/uninstall.sh

log "YELLOW" "Remove downloaded file"
rm -rf $REMOTE_HOME_DIR/tce/tce-linux-amd64-$TCE_VERSION.tar.gz
log "YELLOW" "Remove local project created"
rm -rf $REMOTE_HOME_DIR/tce/tce-linux-amd64-$TCE_VERSION/