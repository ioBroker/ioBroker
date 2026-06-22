#!/bin/bash
# ioBroker Node.js Update Script
# Refactored for clarity, safety, and maintainability
# Author: Thomas Braun
# License: MIT
#
# Copyright (c) 2026 Thomas Braun

# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

set -euo pipefail  # Fail on errors, unset variables, or pipeline errors

# --- Constants ---
readonly VERSION="2026-06-21"
readonly VERSIONS_URL="https://raw.githubusercontent.com/ioBroker/ioBroker/master/versions.json"
readonly NODESOURCE_KEY_FINGERPRINT="6F71F525282841EEDAF851B42F59B5F99B1BE0B4"
readonly DEFAULT_NODE_MAJOR=22
readonly DOCKER_MARKER="/opt/scripts/.docker_config/.thisisdocker"
readonly IOB_DIR="/opt/iobroker"
readonly IOB_USER="iobroker"

# --- Global Variables ---
DRY_RUN=false
SUDOX=""
NODE_MAJOR=""
NODERECOM=""
VERNODE=""
HOST_PLATFORM=""
INSTALL_CMD=""
INSTALL_CMD_ARGS=()  # Array for proper quoting

# --- Logging ---
log() {
    local level="$1"
    local message="$2"
    case "$level" in
        "error") echo -e "\033[31m[ERROR] $message\033[0m" >&2 ;;
        "warn")  echo -e "\033[33m[WARN] $message\033[0m" >&2 ;;
        "info")  echo -e "\033[32m[INFO] $message\033[0m" ;;
        *)       echo -e "$message" ;;
    esac
}

# --- Cleanup ---
# Only clean up temporary files, NOT the repository files
cleanup() {
    log "info" "Cleaning up temporary files..."
    if [[ -n "$SUDOX" ]]; then
        # Only remove temporary key files, NOT the repository
        $SUDOX rm -f /usr/share/keyrings/nodesource.gpg.new 2>/dev/null || true
    fi
}

trap cleanup EXIT

# --- Validation Functions ---
validate_node_major() {
    local major="$1"
    if [[ ! "$major" =~ ^[0-9]+$ ]]; then
        log "error" "Invalid Node.js major version: $major. Must be a number (e.g., 20, 22)."
        exit 1
    fi
    if [[ "$major" -lt 18 ]]; then
        log "error" "Node.js major version must be >= 18."
        exit 1
    fi
}

check_dependencies() {
    local deps=("curl" "gpg" "iobroker" "iob" "systemd-detect-virt" "apt-get" "apt-mark")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log "error" "Required command '$dep' is not installed."
            exit 1
        fi
    done
}

check_internet() {
    if ! curl -sL --connect-timeout 5 https://github.com &>/dev/null; then
        log "error" "No internet connection. Cannot fetch Node.js version."
        exit 1
    fi
}

# --- Version Detection ---
get_recommended_node_major() {
    local versions_json
    versions_json=$(curl -sL --connect-timeout 10 "$VERSIONS_URL" 2>/dev/null || return 1)
    echo "$versions_json" | grep -oP '"nodeJsRecommended"\s*:\s*\K[0-9]+' || echo "$DEFAULT_NODE_MAJOR"
}

get_current_node_version() {
    if command -v node &>/dev/null; then
        node -v 2>/dev/null || echo "not installed"
    else
        echo "not installed"
    fi
}

# --- System Checks ---
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log "error" "This script must not be run as root. Please use your standard user."
        exit 1
    fi
    if ! sudo -v 2>/dev/null; then
        log "error" "sudo privileges are required but not available."
        exit 1
    fi
    SUDOX="sudo"
}

check_docker() {
    if [[ -f "$DOCKER_MARKER" ]]; then
        log "error" "Updating Node.js in Docker is not supported. Please update your Docker container."
        exit 1
    fi
}

check_wsl() {
    local sys_virt
    sys_virt=$(systemd-detect-virt 2>/dev/null || echo "none")
    if [[ "$sys_virt" == "wsl" ]]; then
        log "error" "WSL is not supported."
        exit 1
    fi
}

check_debian() {
    if [[ ! -f "/etc/debian_version" ]]; then
        log "error" "Only Debian-based Linux systems are supported."
        exit 1
    fi
    local debian_version
    debian_version=$(cat /etc/debian_version 2>/dev/null || echo "")
    if [[ "$debian_version" == *"buster"* || "$debian_version" == 10.* ]]; then
        log "error" "Debian 10 'Buster' has reached End of Life and is not supported. Please install the current Debian Stable release."
        exit 1
    fi
}

# --- Check and remove hold from nodejs package ---
check_nodejs_hold() {
    log "info" "Checking if nodejs package is on hold..."
    if apt-mark showhold 2>/dev/null | grep -qx nodejs; then
        log "info" "nodejs package is on hold. Removing hold to allow update..."
        if [[ "$DRY_RUN" == true ]]; then
            log "info" "[DRY RUN] Would execute: $SUDOX apt-mark unhold nodejs"
        else
            if ! $SUDOX apt-mark unhold nodejs; then
                log "error" "Failed to remove hold from nodejs package."
                exit 1
            fi
            log "info" "Hold removed from nodejs package."
        fi
    else
        log "info" "nodejs package is not on hold."
    fi
}

# --- Platform Detection ---
detect_platform() {
    local unamestr
    unamestr=$(uname)
    case "$unamestr" in
        "Linux")
            HOST_PLATFORM="linux"
            INSTALL_CMD="apt-get"
            INSTALL_CMD_ARGS=("install" "-qq" "--allow-downgrades")  # Array for proper quoting
            ;;
        "Darwin")
            HOST_PLATFORM="osx"
            INSTALL_CMD="brew"
            INSTALL_CMD_ARGS=("install")  # Array for proper quoting
            ;;
        "FreeBSD")
            HOST_PLATFORM="freebsd"
            INSTALL_CMD="pkg"
            INSTALL_CMD_ARGS=("install")  # Array for proper quoting
            ;;
        *)
            log "error" "Unsupported platform: $unamestr"
            exit 1
            ;;
    esac
    if [[ "$INSTALL_CMD" != "apt-get" ]]; then
        log "error" "Only Debian-based systems are supported."
        exit 1
    fi
}

# --- ioBroker Controller Management ---
# Stop ioBroker using 'iob stop' command
stop_iobroker() {
    log "info" "Stopping ioBroker with 'iob stop'..."
    if [[ "$DRY_RUN" == true ]]; then
        log "info" "[DRY RUN] Would execute: iob stop"
    else
        if ! iob stop; then
            log "error" "Failed to stop ioBroker with 'iob stop'."
            exit 1
        fi
        log "info" "ioBroker stopped successfully."
    fi
}

# Start ioBroker using 'iob start' command
start_iobroker() {
    log "info" "Starting ioBroker with 'iob start'..."
    if [[ "$DRY_RUN" == true ]]; then
        log "info" "[DRY RUN] Would execute: iob start"
    else
        if ! iob start; then
            log "error" "Failed to start ioBroker with 'iob start'."
            exit 1
        fi
        log "info" "ioBroker started successfully."
    fi
}

# --- Node.js Installation ---
setup_nodesource_repo() {
    local arch
    arch=$(dpkg --print-architecture)
    if [[ "$arch" != "amd64" && "$arch" != "arm64" ]]; then
        log "error" "Unsupported architecture: $arch. Nodesoure does not provide a 32bit nodejs anymore, only amd64 and arm64 are supported. You will have to reinstall a 64bit Operating System."
        exit 1
    fi

    log "info" "Setting up NodeSource repository for Node.js $NODE_MAJOR..."

    # Ensure /usr/share/keyrings exists
    if [[ "$DRY_RUN" == false ]]; then
        $SUDOX mkdir -p /usr/share/keyrings
    fi

    # Remove old NodeSource repo files and keys (only if not dry run)
    if [[ "$DRY_RUN" == false ]]; then
        $SUDOX rm -f /usr/share/keyrings/nodesource.gpg /etc/apt/keyrings/nodesource.gpg 2>/dev/null || true
        $SUDOX rm -f /etc/apt/sources.list.d/nodesource.* 2>/dev/null || true
    fi

    # Download and verify GPG key
    log "info" "Downloading NodeSource GPG key..."
    if [[ "$DRY_RUN" == true ]]; then
        log "info" "[DRY RUN] Would download GPG key from https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key"
    else
        if ! curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
            $SUDOX gpg --dearmor -o /usr/share/keyrings/nodesource.gpg; then
            log "error" "Failed to download and import the NodeSource GPG key."
            exit 1
        fi
        $SUDOX chmod 644 /usr/share/keyrings/nodesource.gpg
    fi

    # Verify GPG key fingerprint
    log "info" "Verifying GPG key fingerprint..."
    local fingerprint
    local gpg_output
    gpg_output=$($SUDOX gpg --show-keys --with-fingerprint /usr/share/keyrings/nodesource.gpg 2>&1)

    # Extract fingerprint: Get the line after 'pub' and remove all spaces
    fingerprint=$(echo "$gpg_output" | awk '/pub/{getline; gsub(/ /, ""); print}')

    if [[ -z "$fingerprint" ]]; then
        log "error" "Could not extract fingerprint from GPG key. GPG output was:\n$gpg_output"
        exit 1
    fi

    if [[ "$fingerprint" != "$NODESOURCE_KEY_FINGERPRINT" ]]; then
        log "error" "NodeSource GPG key fingerprint mismatch! Expected: $NODESOURCE_KEY_FINGERPRINT, Got: $fingerprint"
        $SUDOX rm -f /usr/share/keyrings/nodesource.gpg
        exit 1
    fi
    log "info" "GPG key fingerprint verified successfully: $fingerprint"

    # Create new NodeSource repo file
    log "info" "Creating NodeSource repository file..."
    if [[ "$DRY_RUN" == true ]]; then
        log "info" "[DRY RUN] Would create /etc/apt/sources.list.d/nodesource.sources"
    else
        cat <<EOF | $SUDOX tee /etc/apt/sources.list.d/nodesource.sources >/dev/null
Types: deb
URIs: https://deb.nodesource.com/node_$NODE_MAJOR.x
Suites: nodistro
Components: main
Architectures: $arch
Signed-By: /usr/share/keyrings/nodesource.gpg
EOF
        if [[ ! -f /etc/apt/sources.list.d/nodesource.sources ]]; then
            log "error" "Failed to create NodeSource repository file."
            exit 1
        fi
    fi

    # Pin NodeSource repo to highest priority
    log "info" "Setting repository pin priority..."
    if [[ "$DRY_RUN" == true ]]; then
        log "info" "[DRY RUN] Would create /etc/apt/preferences.d/nodejs"
    else
        echo "Package: nodejs" | $SUDOX tee /etc/apt/preferences.d/nodejs >/dev/null
        echo "Pin: origin deb.nodesource.com" | $SUDOX tee -a /etc/apt/preferences.d/nodejs >/dev/null
        echo "Pin-Priority: 1001" | $SUDOX tee -a /etc/apt/preferences.d/nodejs >/dev/null
    fi

    log "info" "NodeSource repository configured successfully and will remain in the system."

    # Verify repository file exists
    if [[ "$DRY_RUN" == false && ! -f /etc/apt/sources.list.d/nodesource.sources ]]; then
        log "error" "NodeSource repository file not found after creation."
        exit 1
    fi
}

install_nodejs() {
    log "info" "Updating package lists..."
    if [[ "$DRY_RUN" == true ]]; then
        log "info" "[DRY RUN] Would execute: $SUDOX $INSTALL_CMD update"
    else
        if ! $SUDOX "$INSTALL_CMD" update; then
            log "error" "Failed to update package lists."
            exit 1
        fi
    fi

    log "info" "Installing Node.js $NODE_MAJOR..."
    if [[ "$DRY_RUN" == true ]]; then
        log "info" "[DRY RUN] Would execute: $SUDOX $INSTALL_CMD ${INSTALL_CMD_ARGS[*]}"
    else
        # Fixed SC2086: Use array expansion with proper quoting
        if ! $SUDOX "$INSTALL_CMD" "${INSTALL_CMD_ARGS[@]}" nodejs; then
            log "error" "Failed to install Node.js $NODE_MAJOR."
            exit 1
        fi
    fi

    # Verify installation
    local new_version
    new_version=$(get_current_node_version)
    if [[ "$new_version" == "not installed" ]]; then
        log "error" "Node.js installation failed."
        exit 1
    fi
    log "info" "Node.js $new_version installed successfully."
}

remove_old_nodejs() {
    log "info" "Removing old Node.js versions..."
    local packages=("libnode*" "node-*" "nodejs-doc" "npm" "nodejs")
    if [[ "$DRY_RUN" == true ]]; then
        log "info" "[DRY RUN] Would remove packages: ${packages[*]}"
    else
        $SUDOX "$INSTALL_CMD" remove -qqy "${packages[@]}" 2>/dev/null || true
    fi
}

# --- Compatibility Check ---
compatibility_check() {
    log "info" "Checking npm dependencies for compatibility with Node.js $NODE_MAJOR..."
    if [[ ! -d "$IOB_DIR" ]]; then
        log "warn" "ioBroker directory not found at $IOB_DIR. Skipping compatibility check."
        return
    fi
    cd "$IOB_DIR" || return
    if [[ "$DRY_RUN" == true ]]; then
        log "info" "[DRY RUN] Would execute: npm i --dry-run"
    else
        if ! npm i --dry-run &>/tmp/npm_dryrun.log; then
            log "warn" "Potential compatibility issues detected. See /tmp/npm_dryrun.log for details."
        else
            log "info" "No compatibility issues found."
        fi
    fi
}

# --- Path Validation ---
validate_node_paths() {
    local correct=true
    local paths=("nodejs:/usr/bin/nodejs" "node:/usr/bin/node" "npm:/usr/bin/npm" "npx:/usr/bin/npx")

    for path_spec in "${paths[@]}"; do
        local cmd=${path_spec%%:*}
        local expected_path=${path_spec#*:}
        local actual_path
        actual_path=$(type -p "$cmd" 2>/dev/null || echo "")

        if [[ -n "$actual_path" && "$actual_path" != "$expected_path" ]]; then
            log "warn" "Incorrect path for $cmd: $actual_path (expected: $expected_path)"
            correct=false
        fi
    done

    if [[ "$correct" == false ]]; then
        log "info" "Your Node.js installation seems to be faulty. Fixing paths..."
        for path_spec in "${paths[@]}"; do
            local cmd=${path_spec%%:*}
            local expected_path=${path_spec#*:}
            local actual_path
            actual_path=$(type -p "$cmd" 2>/dev/null || echo "")

            if [[ -n "$actual_path" && "$actual_path" != "$expected_path" ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    log "info" "[DRY RUN] Would remove $actual_path and symlink to $expected_path"
                else
                    $SUDOX rm -f "$actual_path"
                    $SUDOX ln -sf "$expected_path" "$actual_path"
                fi
            fi
        done
        log "info" "Paths have been corrected. Please verify with 'iob diag'."
    else
        log "info" "Node.js paths are correct."
    fi
}

# --- Main Function ---
main() {
    # Parse arguments
    local custom_version=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS] [NODE_MAJOR_VERSION]"
                echo ""
                echo "Options:"
                echo "  --dry-run    Show what would be done without making changes"
                echo "  --help, -h   Show this help message"
                echo ""
                echo "Arguments:"
                echo "  NODE_MAJOR_VERSION   Major version of Node.js to install (e.g., 20, 22)"
                echo "                      If omitted, the recommended version from ioBroker or versions.json will be used."
                exit 0
                ;;
            *)
                if [[ -n "$custom_version" ]]; then
                    log "error" "Only one version argument is allowed."
                    exit 1
                fi
                custom_version="$1"
                shift
                ;;
        esac
    done

    # Check dependencies
    check_dependencies
    check_internet

    # Check system
    check_root
    check_docker
    check_wsl
    check_debian
    detect_platform

    # Determine Node.js version
    if [[ -n "$custom_version" ]]; then
        validate_node_major "$custom_version"
        NODE_MAJOR="$custom_version"
        log "info" "Custom installation of Node.js v$NODE_MAJOR requested."
    else
        local recommended_major
        recommended_major=$(get_recommended_node_major)
        NODE_MAJOR="$recommended_major"
        log "info" "No specific version given. Installing recommended version from Node.js v.$NODE_MAJOR tree."
    fi

    # Get current version
    VERNODE=$(get_current_node_version)
    log "info" "Current Node.js version: $VERNODE"

    # Check if update is needed - Fixed SC2144: Use explicit file check instead of glob pattern
    if [[ "$VERNODE" == "v$NODERECOM" && -f /etc/apt/sources.list.d/nodesource.sources ]]; then
        log "info" "Nothing to do. Your version ($VERNODE) is already the recommended one."
        log "info" "You can keep your system up-to-date using: sudo apt update && sudo apt full-upgrade"
        log "warn" "DO NOT use 'nodejs-update' as part of your regular update process!"
        log "warn" "DO NOT use node version managers like 'nvm', 'n' and others in parallel. They will break your installation!"
        if [[ -f "/var/run/reboot-required" ]]; then
            log "warn" "This system needs to be REBOOTED NOW!"
        fi
        exit 0
    fi

    # Stop ioBroker with 'iob stop' before starting work
    stop_iobroker

    # Validate paths
    validate_node_paths

    # Remove old Node.js
    remove_old_nodejs

    # Setup NodeSource repo
    setup_nodesource_repo

    # Check and remove hold from nodejs package before installation
    check_nodejs_hold

    # Install Node.js
    install_nodejs

    # Compatibility check
    compatibility_check

    # Start ioBroker with 'iob start' after successful Node.js installation
    start_iobroker

    # Final message
    if [[ "$DRY_RUN" == true ]]; then
        log "info" "Dry run completed. No changes were made."
    else
        log "info" "Node.js update completed successfully!"
        log "info" "The NodeSource repository has been permanently added to your system."
        log "info" "You can now update Node.js in the future using: sudo apt update && sudo apt upgrade nodejs"
        log "warn" "DO NOT use 'nodejs-update' as part of your regular update process!"
        log "warn" "DO NOT use node version managers like 'nvm', 'n' and others in parallel. They will break your installation!"
        if [[ -f "/var/run/reboot-required" ]]; then
            log "warn" "This system needs to be REBOOTED NOW!"
        fi
    fi
}

# --- Entry Point ---
main "$@"
