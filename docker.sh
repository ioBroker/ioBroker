#!/bin/bash
# ioBroker Docker helper
# Shows whether Docker is installed and running, and installs it on request.
# Called as "iob docker", see PARAMETERS.md.
# License: MIT

set -euo pipefail # Fail on errors, unset variables, or pipeline errors

# --- Constants ---
readonly VERSION="2026-10-26"
# Docker's own convenience script, supports Debian, Ubuntu, Raspberry Pi OS, Fedora, CentOS and RHEL
readonly GET_DOCKER_URL="https://get.docker.com"
readonly IOB_USER="iobroker"
# Must match HARDENED_SUDOERS_MARKER in installer_library.sh: a hardened installation
# must not get the iobroker user into the docker group, which is equivalent to root.
readonly SUDOERS_FILE="/etc/sudoers.d/iobroker"
readonly HARDENED_SUDOERS_MARKER="# ioBroker hardened mode: no root rights for the iobroker user"

# --- Global Variables ---
ASSUME_YES=false
SUDOX=""
GET_DOCKER_SCRIPT="" # temporary copy of get.docker.com, removed on exit

# --- Logging ---
log() {
    local level="$1"
    local message="$2"
    case "$level" in
    "error") echo -e "\033[31m[ERROR] $message\033[0m" >&2 ;;
    "warn") echo -e "\033[33m[WARN] $message\033[0m" >&2 ;;
    "info") echo -e "\033[32m[INFO] $message\033[0m" ;;
    *) echo -e "$message" ;;
    esac
}

cleanup() {
    if [[ -n "$GET_DOCKER_SCRIPT" ]]; then
        rm -f "$GET_DOCKER_SCRIPT"
    fi
}

trap cleanup EXIT

usage() {
    echo "Usage: iob docker [OPTIONS]"
    echo ""
    echo "Shows whether Docker is installed and running. If it is not installed,"
    echo "asks whether it should be installed now."
    echo ""
    echo "Options:"
    echo "  -y, --yes    Answer all questions with yes (install without asking)"
    echo "  -h, --help   Show this help message"
    echo ""
    echo "Exit code: 0 if Docker is installed at the end, 1 otherwise."
}

# Asks a yes/no question. -y answers it, and a missing answer (no terminal, EOF) counts as "no".
# Accepts y/yes and the German j/ja, in any case.
confirm() {
    local question="$1"
    local answer
    if [[ "$ASSUME_YES" == true ]]; then
        return 0
    fi
    read -rp "$question [y/N] " answer || answer=""
    [[ "$answer" =~ ^([Yy]([Ee][Ss])?|[Jj][Aa]?)$ ]]
}

# Same probe as node-update.sh: -n first for NOPASSWD setups, then the form that may ask
# for a password. Only called when root rights are really needed, not for the status.
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        SUDOX=""
        return
    fi
    if ! sudo -n true 2>/dev/null && ! sudo -v; then
        log "error" "sudo privileges are required but not available."
        exit 1
    fi
    SUDOX="sudo"
}

# --- Detection ---
running_in_container() {
    [[ -f /.dockerenv || -f /run/.containerenv || -f /opt/scripts/.docker_config/.thisisdocker ]]
}

running_in_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

docker_installed() {
    command -v docker &>/dev/null
}

# systemctl and pgrep work for every user. Docker Desktop (macOS, WSL integration) runs its engine
# in a VM that neither of them sees, so "docker info" comes last: it needs access to the socket.
docker_daemon_running() {
    systemctl is-active --quiet docker 2>/dev/null || pgrep -x dockerd &>/dev/null || docker info &>/dev/null
}

systemd_running() {
    [[ "$(ps -p 1 -o comm= 2>/dev/null)" == "systemd" ]]
}

# The service of Docker Engine. Docker Desktop has none, its engine runs while the app does.
docker_service_exists() {
    systemd_running && systemctl cat docker.service &>/dev/null
}

# The docker group belongs to a Docker Engine on this Linux host, which includes Docker Desktop's
# WSL integration. Docker Desktop on macOS does not use it, and inside a container the group is not
# the one that owns the socket of the host.
docker_group_applies() {
    [[ "$(uname)" == "Linux" ]] && ! running_in_container
}

iob_user_exists() {
    id "$IOB_USER" &>/dev/null
}

iob_user_in_docker_group() {
    id -nG "$IOB_USER" 2>/dev/null | tr ' ' '\n' | grep -qx docker
}

is_hardened_setup() {
    $SUDOX grep -qsxF "$HARDENED_SUDOERS_MARKER" "$SUDOERS_FILE" &>/dev/null
}

print_status() {
    local compose_version
    echo ""
    echo "Docker status"
    if docker_installed; then
        echo "  Docker:          installed ($(docker --version 2>/dev/null || echo "unknown version"))"
        if docker_daemon_running; then
            echo "  Docker daemon:   running"
        else
            echo "  Docker daemon:   not running"
        fi
        if compose_version=$(docker compose version --short 2>/dev/null); then
            echo "  Docker Compose:  $compose_version"
        else
            echo "  Docker Compose:  not installed"
        fi
    else
        echo "  Docker:          not installed"
    fi
    if iob_user_exists; then
        if iob_user_in_docker_group; then
            echo "  User $IOB_USER:   member of the docker group"
        else
            echo "  User $IOB_USER:   not a member of the docker group"
        fi
    fi
    echo ""
}

# Exits with an explanation where the convenience script cannot work
check_install_supported() {
    case "$(uname)" in
    "Linux") ;;
    "Darwin")
        log "error" "Docker cannot be installed automatically on macOS. Install Docker Desktop: https://docs.docker.com/desktop/setup/install/mac-install/"
        exit 1
        ;;
    *)
        log "error" "Docker is not available for $(uname)."
        exit 1
        ;;
    esac
    if running_in_container; then
        log "error" "ioBroker runs inside a container. Install Docker on the host system instead."
        exit 1
    fi
    if running_in_wsl; then
        log "error" "WSL detected. Install Docker Desktop on Windows and enable its WSL integration: https://docs.docker.com/desktop/features/wsl/"
        exit 1
    fi
}

install_docker() {
    log "info" "Downloading the Docker installation script from $GET_DOCKER_URL..."
    GET_DOCKER_SCRIPT=$(mktemp)
    if ! curl -fsSL --connect-timeout 10 --max-time 60 "$GET_DOCKER_URL" -o "$GET_DOCKER_SCRIPT"; then
        log "error" "Cannot download $GET_DOCKER_URL. Please check the internet connection."
        exit 1
    fi

    log "info" "Installing Docker, this can take a few minutes..."
    if ! $SUDOX sh "$GET_DOCKER_SCRIPT"; then
        log "error" "The Docker installation failed. Please check the output above."
        exit 1
    fi

    # Debian and Ubuntu start the service from the package, Fedora/CentOS/RHEL do not
    if systemd_running; then
        start_docker_service
    fi
    log "info" "Docker is installed."
}

start_docker_service() {
    if ! $SUDOX systemctl enable --now docker; then
        log "warn" "Could not start the Docker service. Try '$SUDOX systemctl start docker'."
    fi
}

# Offers to start the service if Docker is installed but its daemon is not running
offer_docker_start() {
    if docker_daemon_running; then
        return
    fi
    if ! docker_service_exists; then
        log "warn" "The Docker daemon is not running. Start Docker Desktop or the Docker service of your system."
        return
    fi
    if confirm "The Docker daemon is not running. Start it now and at every boot?"; then
        check_sudo
        start_docker_service
    else
        log "warn" "The Docker daemon is not running. Start it with 'sudo systemctl enable --now docker'."
    fi
}

log_hardened() {
    log "info" "Hardened installation: the user $IOB_USER is not added to the docker group, because membership there is equivalent to root rights."
}

# Offers to add the iobroker user to the docker group if Docker is installed but it is not a member
offer_docker_group() {
    if ! iob_user_exists || iob_user_in_docker_group; then
        return
    fi
    if ! docker_group_applies; then
        if running_in_container; then
            log "info" "ioBroker runs inside a container, so the docker group is not changed here. Access to the Docker socket of the host has to be configured for the container."
        fi
        return
    fi
    # The sudoers file is readable for root only. With root or passwordless sudo a hardened
    # installation is recognized before the question, otherwise add_iob_user_to_docker_group
    # recognizes it once sudo has the password.
    if [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null; then
        check_sudo
        if is_hardened_setup; then
            log_hardened
            return
        fi
    fi
    if confirm "Add the user $IOB_USER to the docker group?"; then
        check_sudo
        add_iob_user_to_docker_group
    fi
}

# ioBroker needs the group to talk to the Docker socket, e.g. for adapters that manage containers
add_iob_user_to_docker_group() {
    if ! iob_user_exists || iob_user_in_docker_group; then
        return
    fi
    if is_hardened_setup; then
        log_hardened
        return
    fi
    if ! $SUDOX usermod -a -G docker "$IOB_USER"; then
        log "warn" "Could not add the user $IOB_USER to the docker group. Try '$SUDOX usermod -a -G docker $IOB_USER'."
        return
    fi
    log "info" "Added the user $IOB_USER to the docker group."
    log "info" "Restart ioBroker with 'iob restart', so that it gets the new group membership."
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -y | --yes)
            ASSUME_YES=true
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        --allow-root)
            # Handled by the iob wrapper, nothing to do here
            ;;
        *)
            log "error" "Unknown option: $1"
            usage
            exit 1
            ;;
        esac
        shift
    done

    log "info" "ioBroker Docker helper $VERSION"
    print_status

    # The platform checks of check_install_supported are about the convenience script only.
    # An existing Docker, e.g. Docker Desktop with its WSL integration, is handled everywhere.
    if docker_installed; then
        offer_docker_start
        offer_docker_group
        exit 0
    fi

    check_install_supported
    if ! confirm "Docker is not installed. Do you want to install it now?"; then
        log "info" "Docker was not installed. Run 'iob docker -y' to install it without asking."
        exit 1
    fi

    check_sudo
    install_docker
    add_iob_user_to_docker_group
    print_status
}

main "$@"
