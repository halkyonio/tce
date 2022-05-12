#!/usr/bin/env bash
#
# This script requires: curl, grep, sed, tr, and jq in order to work
#
# Execute this command locally
#
# ./list_tkr_version.sh
#
# Example:
# TCE_VERSION=dev ./scripts/list_tkr_version.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
# - TCE_VERSION: Version of TCE used to check the TKG version compatibles

REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
TCE_VERSION=${TCE_VERSION:-v0.12.0}
DIR=`dirname $0`

. $DIR/util.sh

if ! command -v jq &> /dev/null
then
    log "RED" "jq not be found. Please install it - https://stedolan.github.io/jq/"
    exit
fi

if ! command -v yq &> /dev/null
then
    log "RED" "yq not be found. Please install it - https://github.com/kislyuk/yq"
    exit
fi

cat $REMOTE_HOME_DIR/.config/tanzu/tkg/unmanaged/compatibility/projects.registry.vmware.com_tce_compatibility_v8 | yq | jq -r '.unmanagedClusterPluginVersions[] | select(.version == "'"$TCE_VERSION"'")."supportedTkrVersions"'