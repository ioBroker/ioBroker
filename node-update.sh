#!/bin/bash
# ioBroker Node.js Update Script
# Refactored for clarity, safety, and maintainability
# Author: Thomas Braun
# License: MIT
#
# Copyright (c) 2026 Thomas Braun
# Some parts are contributed by Mistral AI.

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is furnished
# to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -euo pipefail # Fail on errors, unset variables, or pipeline errors

# --- Constants ---
readonly VERSION="2026-10-15"
# Overridable for CI, see installer_library.sh. The default is applied before
# readonly, otherwise a value from the environment would be overwritten here.
readonly VERSIONS_URL="${VERSIONS_URL:-https://raw.githubusercontent.com/ioBroker/ioBroker/master/versions.json}"
readonly NODESOURCE_KEY_FINGERPRINT="6F71F525282841EEDAF851B42F59B5F99B1BE0B4"
readonly DEFAULT_NODE_MAJOR=24
# Fallback list, only used when versions.json cannot be downloaded
readonly DEFAULT_ACCEPTED_NODE_MAJORS="22 24 26"
readonly DOCKER_MARKER="/opt/scripts/.docker_config/.thisisdocker"
readonly IOB_DIR="/opt/iobroker"
readonly IOB_USER="iobroker"
readonly LOG_DIR="/opt/iobroker/log"

# --- Global Variables ---
DRY_RUN=false
FORCE=false
SUDOX=""
NODE_MAJOR=""
# Full semver string (e.g. "27.0.0-alpha.1") if the user passed one with --force,
# empty otherwise. Only the major part goes into the NodeSource repository.
NODE_VERSION_FULL=""
NODERECOM=""
VERNODE=""
HOST_PLATFORM=""
INSTALL_CMD=""
INSTALL_CMD_ARGS=() # Array for proper quoting
VERSIONS_JSON=""    # cache, versions.json is downloaded at most once per run
VERSIONS_JSON_FETCHED=false
LOG_FILE="" # set by init_logging()

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

# --- File Logging ---
# Mirrors ALL terminal output (stdout and stderr, including output of
# external commands like apt-get/npm) into a log file.
init_logging() {
    # Delete log files older than 10 days
    find "$LOG_DIR" -name 'iob-nodejs-update-*.log' -type f -mtime +10 -delete 2>/dev/null || true

    # Create the log file owned by $IOB_USER:$IOB_USER
    LOG_FILE="$LOG_DIR/iob-nodejs-update-$(date '+%Y-%m-%d_%H-%M-%S').log"
    $SUDOX touch "$LOG_FILE" 2>/dev/null || true
    $SUDOX chown "$IOB_USER:$IOB_USER" "$LOG_FILE" 2>/dev/null || true
    # Duplicate stdout and stderr: everything goes to the terminal AND the file
    exec &> >(tee -a "$LOG_FILE")

    log "info" "Logging to $LOG_FILE"
}

# --- Cleanup ---
# Only clean up temporary files, NOT the repository files
cleanup() {
    log "info" "Cleaning up temporary files..."
    if [[ -n "$SUDOX" ]]; then
        # Only remove temporary key files, NOT the repository
        $SUDOX rm -f /usr/share/keyrings/nodesource.gpg.new 2>/dev/null || true
    fi

    # Remove ANSI color codes and "Reading database" progress lines from the log
    $SUDOX sed -i -e 's/\x1b\[[0-9;]*m//g' \
        -e 's/\r/\n/g' \
        -e '/^\(Reading database \.\.\. .*\)$/d' "$LOG_FILE" 2>/dev/null || true
}

trap cleanup EXIT

# --- Validation Functions ---
# Accepts, depending on the mode:
#   normal: a plain major version ("22") that ioBroker accepts (versions.json)
#   --force: any semver string or major ("27", "27.0.0", "27.0.0-alpha.1")
validate_node_major() {
    local version="$1"
    version="${version#v}" # tolerate a leading "v"

    if [[ "$FORCE" == true ]]; then
        # Relaxed semver check: major[.minor[.patch]][-prerelease]
        if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){0,2}(-[A-Za-z0-9.]+)?$ ]]; then
            log "error" "Invalid Node.js version: $version. Expected a semver string like '22', '27.0.0' or '27.0.0-alpha.1'."
            exit 1
        fi
        log "warn" "Force mode: skipping the ioBroker acceptance check for Node.js $version. This version is UNSUPPORTED, use it at your own risk!"
        return
    fi

    if [[ ! "$version" =~ ^[0-9]+$ ]]; then
        log "error" "Invalid Node.js major version: $version. Must be a number (e.g., 20, 22). Use --force for unsupported or prerelease versions."
        exit 1
    fi
    local accepted
    accepted=$(get_accepted_node_majors)
    if [[ " $accepted " != *" $version "* ]]; then
        log "error" "ioBroker does not support Node.js $version. Accepted major versions: $accepted. Use --force to install it anyway."
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
# versions.json is the single source of truth shared with ioBroker.admin,
# the repobuilder and the Windows installer. Download it once and reuse it.
fetch_versions_json() {
    if [[ "$VERSIONS_JSON_FETCHED" == false ]]; then
        VERSIONS_JSON_FETCHED=true
        VERSIONS_JSON=$(curl -sL --connect-timeout 10 "$VERSIONS_URL" 2>/dev/null) || VERSIONS_JSON=""
    fi
    printf '%s' "$VERSIONS_JSON"
}

get_recommended_node_major() {
    local recommended
    recommended=$(fetch_versions_json | grep -oP '"nodeJsRecommended"\s*:\s*\K[0-9]+' || true)
    if [[ "$recommended" =~ ^[0-9]+$ ]]; then
        echo "$recommended"
    else
        log "warn" "Could not read the recommended Node.js version from $VERSIONS_URL. Falling back to v$DEFAULT_NODE_MAJOR."
        echo "$DEFAULT_NODE_MAJOR"
    fi
}

# Returns a space-separated list of the major Node.js versions accepted by ioBroker, e.g., "22 24 26"
get_accepted_node_majors() {
    local accepted
    # Extract accepted versions from versions.json, fallback to default if empty

    accepted=$(fetch_versions_json | grep -oP '"nodeJsAccepted"\s*:\s*\[[^\]]*' | grep -oP '[0-9]+' | tr '\n' ' ' || true)

    # Remove duplicate and leading/trailing spaces
    accepted=${accepted// / }
    accepted=${accepted# }
    accepted=${accepted% }

    if [[ -n "$accepted" ]]; then
        echo "$accepted"
    else
        log "warn" "Could not read the accepted Node.js versions from $VERSIONS_URL. Falling back to: $DEFAULT_ACCEPTED_NODE_MAJORS."
        echo "$DEFAULT_ACCEPTED_NODE_MAJORS"
    fi
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
    # Two kinds of setup have to work here.
    #
    # Cloud images (EC2, GCP, Hetzner) grant NOPASSWD but never set a password, so there is
    # nothing to type. "sudo -v" still asks there, because it validates without a command and
    # only stays silent when every command is NOPASSWD - and the sudoers file this installer
    # writes to /etc/sudoers.d/iobroker is read after 90-cloud-init-users and covers single
    # commands only. So after an ioBroker installation, -v starts prompting on those images.
    #
    # Ordinary password sudo has no cached ticket on the first call, so the non-interactive
    # probe fails there although the user is perfectly entitled. Hence: try -n first, and only
    # fall back to the interactive form, which may legitimately ask for a password.
    if ! sudo -n true 2>/dev/null && ! sudo -v; then
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

# --- Package Database Consistency Check ---
check_package_database_consistency() {
    log "info" "Checking package database consistency with '$INSTALL_CMD update'..."
    if [[ "$DRY_RUN" == true ]]; then
        log "info" "[DRY RUN] Would execute: $SUDOX $INSTALL_CMD update"
    else
        # Keep the output so it can be shown if the update fails.
        # Note: 'local' must be declared separately, otherwise it masks the exit code.
        local update_output
        if ! update_output=$($SUDOX "$INSTALL_CMD" update 2>&1); then
            log "error" "Package database is inconsistent. '$INSTALL_CMD update' failed. Fix the issue and try again."
            log "error" "Output of '$INSTALL_CMD update':"
            printf '%s\n' "$update_output" >&2
            exit 1
        fi
        log "info" "Package database is consistent."
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
        INSTALL_CMD_ARGS=("install" "-qq" "--allow-downgrades") # Array for proper quoting
        ;;
    "Darwin")
        HOST_PLATFORM="osx"
        INSTALL_CMD="brew"
        INSTALL_CMD_ARGS=("install") # Array for proper quoting
        ;;
    "FreeBSD")
        HOST_PLATFORM="freebsd"
        INSTALL_CMD="pkg"
        INSTALL_CMD_ARGS=("install") # Array for proper quoting
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

check_architecture() {
    local arch
    arch=$(dpkg --print-architecture)
    case "$arch" in
    amd64 | arm64)
        log "info" "Supported architecture detected: $arch"
        ;;
    *)
        log "error" "Unsupported architecture: $arch. NodeSource does not provide a 32bit nodejs anymore, only amd64 and arm64 are supported. You will have to reinstall a 64bit Operating System."
        exit 1
        ;;
    esac
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
        log "error" "Unsupported architecture: $arch. NodeSource does not provide a 32bit nodejs anymore, only amd64 and arm64 are supported. You will have to reinstall a 64bit Operating System."
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
        if ! curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key |
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
    # Read the key once and handle the status explicitly: under "set -e" a failing
    # assignment would end the script right here, so the diagnostics below would never
    # run and an unreadable key would abort without saying why - after Node.js has
    # already been removed. "if ! var=$(...)" keeps that status in the condition.
    if ! gpg_output=$($SUDOX gpg --show-keys --with-colons /usr/share/keyrings/nodesource.gpg 2>&1); then
        log "error" "Could not read the NodeSource GPG key. Output of gpg:"
        printf '%s\n' "$gpg_output" >&2
        exit 1
    fi

    # --with-colons gives a stable field format, with the fingerprint in field 10 of the
    # fpr record. The previous version read the line after "pub" out of the human readable
    # output, so the "gpg: ... trustdb created" message that stderr carries on a first run
    # as root ended up in the fingerprint and failed the comparison. Anchoring on ^fpr:
    # ignores whatever else gpg writes.
    fingerprint=$(printf '%s\n' "$gpg_output" | awk -F: '/^fpr:/ {print $10; exit}')

    if [[ -z "$fingerprint" ]]; then
        log "error" "Could not extract fingerprint from GPG key. GPG output was:\n$gpg_output"
        exit 1
    fi

    if [[ "$fingerprint" != "$NODESOURCE_KEY_FINGERPRINT" ]]; then
        log "error" "NodeSource GPG key fingerprint mismatch! Expected: $NODESOURCE_KEY_FINGERPRINT, Got: $fingerprint"
        log "warn" "This error may be temporary. The GPG trust database might have been recreated. Please run the script again."
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

    # If the user passed a full semver string with --force, try to install exactly
    # that version from the repository of its major release first.
    if [[ -n "$NODE_VERSION_FULL" ]]; then
        log "info" "Trying to install Node.js $NODE_VERSION_FULL exactly..."
        if [[ "$DRY_RUN" == true ]]; then
            log "info" "[DRY RUN] Would execute: $SUDOX $INSTALL_CMD ${INSTALL_CMD_ARGS[*]} nodejs=$NODE_VERSION_FULL*"
        elif $SUDOX "$INSTALL_CMD" "${INSTALL_CMD_ARGS[@]}" "nodejs=$NODE_VERSION_FULL*"; then
            log "info" "Node.js $NODE_VERSION_FULL installed successfully."
            verify_installed_nodejs
            return
        else
            log "warn" "Node.js $NODE_VERSION_FULL is not available in the NodeSource repository. Falling back to the latest release of the v$NODE_MAJOR tree."
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

    verify_installed_nodejs
}

verify_installed_nodejs() {
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

# --- Capabilities ---
# Installing the nodejs package replaces the node binary, and file capabilities do not survive
# that. Grant again what install_necessary_packages in installer_library.sh grants, otherwise
# adapters that need privileged ports or raw sockets (ping, BLE, ports below 1024) stop working.
set_node_capabilities() {
    local node_bin
    node_bin=$(readlink -f "$(command -v node)" 2>/dev/null || echo "")
    if [[ -z "$node_bin" ]]; then
        log "warn" "Node.js binary not found. Capabilities were not set, please run 'iob fix'."
        return
    fi

    # A capability missing from the bounding set (a container started without
    # --cap-add=NET_ADMIN, for example) must not be granted: the kernel would then refuse to
    # start node at all. Bits: 10 = cap_net_bind_service, 12 = cap_net_admin, 13 = cap_net_raw.
    local capbnd caps=() name bit
    capbnd=$(awk '/^CapBnd:/ {print $2}' /proc/self/status 2>/dev/null || echo "")
    for name in cap_net_admin:12 cap_net_bind_service:10 cap_net_raw:13; do
        bit=${name#*:}
        if [[ -z "$capbnd" ]] || (((16#$capbnd >> bit) & 1)); then
            caps+=("${name%%:*}")
        else
            log "warn" "${name%%:*} is not available on this system and was not granted to Node.js."
        fi
    done
    if [[ ${#caps[@]} -eq 0 ]]; then
        return
    fi

    local caps_arg
    caps_arg="$(
        IFS=,
        echo "${caps[*]}"
    )+eip"
    log "info" "Granting $caps_arg to $node_bin..."
    if [[ "$DRY_RUN" == true ]]; then
        log "info" "[DRY RUN] Would execute: $SUDOX setcap $caps_arg $node_bin"
    elif ! $SUDOX setcap "$caps_arg" "$node_bin"; then
        log "warn" "Failed to set the capabilities. Adapters that need privileged ports or raw sockets will not work until you run 'iob fix'."
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

# --- iob fix prompt ---
prompt_and_run_iob_fix() {
    if [[ "$DRY_RUN" == true ]]; then
        log "info" "[DRY RUN] Would prompt for running 'iob fix'"
        return
    fi

    # ioBroker is stopped at this point and only started after this function, and set -e would
    # end the script right here: neither a missing answer nor a failing fixer may abort it.
    local answer

    log "info" "It is strongly recommended to run 'iob fix' after updating Node.js to resolve potential dependency issues."
    # read fails without a terminal or on EOF, which counts as "no"
    read -rp "Do you want to run 'iob fix' now? [y/N] " answer || answer=""
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        log "info" "Running 'iob fix'..."
        if ! iob fix; then
            log "warn" "Failed to run 'iob fix'. Please check the output above and run it again later. ioBroker is started anyway."
            return
        fi
        log "info" "'iob fix' completed successfully."
    else
        log "info" "Skipping 'iob fix'. You can run it manually later if needed."
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
        --force)
            FORCE=true
            shift
            ;;
        --help | -h)
            echo "Usage: $0 [OPTIONS] [NODE_VERSION]"
            echo ""
            echo "Options:"
            echo "  --dry-run    Show what would be done without making changes"
            echo "  --force      Install Node.js even if ioBroker does not accept the version."
            echo "               Also allows full semver strings like '27.0.0-alpha.1'."
            echo "               The installed version is UNSUPPORTED, use it at your own risk!"
            echo "  --help, -h   Show this help message"
            echo ""
            echo "Arguments:"
            echo "  NODE_VERSION   Major version of Node.js to install (e.g., 20, 22)"
            echo "                If omitted, the recommended version from ioBroker or versions.json will be used."
            echo "                With --force, a full semver string (e.g., 27.0.0-alpha.1) is accepted as well."
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
    check_architecture

    # Check package database consistency (BEFORE init_logging to catch errors early)
    check_package_database_consistency

    # Set up file logging (needs sudo, hence after check_root)
    init_logging

    # Determine Node.js version
    if [[ -n "$custom_version" ]]; then
        validate_node_major "$custom_version"
        custom_version="${custom_version#v}" # tolerate a leading "v"
        # Only the major goes into the NodeSource repository URL, a full semver
        # string is remembered separately and pinned during installation.
        NODE_MAJOR="${custom_version%%-*}"
        NODE_MAJOR="${NODE_MAJOR%%.*}"
        if [[ "$FORCE" == true && "$custom_version" != "$NODE_MAJOR" ]]; then
            NODE_VERSION_FULL="$custom_version"
            log "info" "Custom installation of Node.js v$NODE_VERSION_FULL requested (major: v$NODE_MAJOR)."
        else
            log "info" "Custom installation of Node.js v$NODE_MAJOR requested."
        fi
    else
        local recommended_major
        recommended_major=$(get_recommended_node_major)
        NODE_MAJOR="$recommended_major"
        log "info" "No specific version given. Installing recommended version from Node.js v.$NODE_MAJOR tree."
    fi

    # Get current version
    VERNODE=$(get_current_node_version)
    log "info" "Current Node.js version: $VERNODE"

    # Compare major versions only: VERNODE is a full version ("v22.11.0"),
    # while NODE_MAJOR holds just the major ("22").
    local current_major
    NODERECOM="$NODE_MAJOR"
    current_major="${VERNODE#v}"
    current_major="${current_major%%.*}"

    # Check if update is needed - Fixed SC2144: Use explicit file check instead of glob pattern
    if [[ "$current_major" == "$NODERECOM" && -f /etc/apt/sources.list.d/nodesource.sources && "$FORCE" == false ]]; then
        # Check if any Node.js binaries exist in directories other than /usr/bin/ or /bin/
        # This is important for identifying 'wild' installations done via tools like nvm or n.
        # We only want nodesource installations done via packagemanager and they live in above directories.
        local required_binaries=("nodejs" "node" "npm" "npx")
        local wrong_location_binaries=()
        local all_binaries_found=()

        for binary in "${required_binaries[@]}"; do
            # Find all locations of this binary
            local binary_locations
            binary_locations=$(which -a "$binary" 2>/dev/null || true)

            if [[ -n "$binary_locations" ]]; then
                while IFS= read -r location; do
                    if [[ -n "$location" && "$location" != "/usr/bin/$binary" && "$location" != "/bin/$binary" ]]; then
                        wrong_location_binaries+=("$location")
                        all_binaries_found+=("$location")
                    fi
                done <<<"$binary_locations"
            fi
        done

        if [[ ${#wrong_location_binaries[@]} -gt 0 ]]; then
            log "warn" "Node.js binaries found in incorrect locations (should only be in /usr/bin/ or /bin/): ${wrong_location_binaries[*]}"
            log "info" "Removing binaries from incorrect locations..."
            for location in "${all_binaries_found[@]}"; do
                if [[ "$DRY_RUN" == true ]]; then
                    log "info" "[DRY RUN] Would remove $location"
                else
                    $SUDOX rm -f "$location"
                fi
            done
            log "info" "Restarting script to ensure proper installation..."
            if [[ -x "$0" ]]; then
                exec "$0" "$@"
            else
                exec bash "$0" "$@"
            fi
        fi

        log "info" "Nothing to do. Node.js $VERNODE is already installed and the NodeSource repository is set up."
        # An "apt upgrade" of nodejs since the last run drops the capabilities as well. Setting
        # them again is harmless, and it makes this command the way to restore them.
        set_node_capabilities
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

    # The new binary has lost the capabilities, set them before ioBroker starts again
    set_node_capabilities

    # Prompt for iob fix
    prompt_and_run_iob_fix
    # Start ioBroker with 'iob start' after successful Node.js installation
    start_iobroker

    # Final message
    if [[ "$DRY_RUN" == true ]]; then
        log "info" "Dry run completed. No changes were made."
    else
        log "info" "Node.js update completed successfully!"
        log "info" "The NodeSource repository has been permanently added to your system."
        log "info" "You can now update Node.js in the future using: sudo apt update && sudo apt upgrade nodejs"
        log "info" "Every such upgrade replaces the Node.js binary and drops its capabilities. Run 'iob fix' afterwards to set them again."
        log "warn" "DO NOT use 'nodejs-update' as part of your regular update process!"
        log "warn" "DO NOT use node version managers like 'nvm', 'n' and others in parallel. They will break your installation!"
        if [[ -f "/var/run/reboot-required" ]]; then
            log "warn" "This system needs to be REBOOTED NOW!"
        fi
    fi
}

# --- Entry Point ---
main "$@"
