#!/usr/bin/env bash

REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
TCE_VERSION=${TCE_VERSION:-v0.12.0}

. $DIR/util.sh

cat $REMOTE_HOME_DIR/.config/tanzu/tkg/unmanaged/compatibility/projects.registry.vmware.com_tce_compatibility_v8 | yq | jq -r '.unmanagedClusterPluginVersions[] | select(.version == "'"$TCE_VERSION"'")."supportedTkrVersions"'