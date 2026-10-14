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
    if id "$DEPLOY_USER" >/dev/null 2>&1; then
        log "User $DEPLOY_USER already exists."
    else
        log "User $DEPLOY_USER doesn't exist, creating user..."
        # Create user with home and set shell to bash
        useradd -m -s /bin/bash "$DEPLOY_USER"
        log "User created successfully."
    fi
}

setup_ssh_keys() {
    local auth_keys="/home/$DEPLOY_USER/.ssh/authorized_keys"
    local key

    log "Setting up SSH keys for $DEPLOY_USER..."

    # sshd ignores these files if the owner or modes are wrong
    install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
    touch "$auth_keys"
    chmod 600 "$auth_keys"
    chown "$DEPLOY_USER:$DEPLOY_USER" "$auth_keys"

    # Add each key only if it isn't there yet, so re-runs don't duplicate it
    for key in "$CI_PUBLIC_KEY" "$MY_PUBLIC_KEY"; do
        if grep -qxF "$key" "$auth_keys"; then
            log "Key already present, skipping."
        else
            echo "$key" >> "$auth_keys"
            log "Key added."
        fi
    done
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
    setup_ssh_keys
    echo "All passed"
    exit 0
}
main "$@"