#!/usr/bin/env bash
# shellcheck enable=quote-safe-variables

set -euo pipefail

# Set variables
DEPLOY_USER="deploy"
SSH_PORT="7777"
CI_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO161WqDKh4KNLeFH5Aq00O67MR4GtVO8EgEEt77J7M/ github-actions-deploy"
MY_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFBvNBP6AbtDOaMyMpOQUEF93e8osMYPdDHimU7jdEyP"

# Define log helper
log() {
    echo "[LOG] $*"
}

# Define error helper
error() {
    echo "[ERR] $*" >&2
    exit 1
}

create_user() {
    echo "123"
}

log "user ID is $EUID"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run the script with root user."
    fi
}


main() {
    check_root
    create_user
    echo "All passed"
    exit 0
}
main "$@"