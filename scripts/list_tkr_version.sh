#!/usr/bin/env bash

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