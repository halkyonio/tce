#!/usr/bin/env bash
#
# Execute this command locally to remobe the Tanzu TCE client
#
# uninstall_tce_client.sh
#
# Example:
# TCE_VERSION=v0.11.0 ./scripts/uninstall_tce_client.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
# - TCE_VERSION: Version of the Tanzu client (e.g. v0.11.0)

set -e

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

log() {
  MSG="${@:2}"
  echo; repeat_char ${1} '#'; log_msg ${1} ${MSG}; repeat_char ${1} '#'; echo
}

log "YELLOW" "Uninstall the Tanzu CLI"
$REMOTE_HOME_DIR/.local/share/tce/uninstall.sh

log "YELLOW" "Remove downloaded files"
rm -rf $REMOTE_HOME_DIR/tce/tce-linux-amd64-$TCE_VERSION.tar.gz
rm -rf $REMOTE_HOME_DIR/tce/tce-linux-amd64-$TCE_VERSION/