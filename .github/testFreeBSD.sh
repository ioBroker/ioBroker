#!/usr/bin/env bash
# End-to-end test of the FreeBSD installation path.
# Runs inside the FreeBSD VM started by .github/workflows/freebsd.yml.
#
# This is a port of the former .cirrus.yml test_script. It runs dist/install.sh and
# dist/fix.sh rather than installer.sh and fix_installation.sh, because those download
# installer_library.sh from master at runtime and would test that instead of this branch.
set -eu

WORKSPACE=$(pwd)

wait_for_admin() {
    local i
    for i in $(seq 1 36); do
        if curl -s --insecure http://127.0.0.1:8081 | grep -q '<title>Admin</title>'; then
            echo "admin is reachable after $((i * 5))s"
            return 0
        fi
        sleep 5
    done
    echo "admin did not become reachable within 180s"
    return 1
}

# Built here rather than on the host so the artifacts cannot be lost in the workspace
# sync, and so that "node tasks --create" is covered on FreeBSD too.
echo "::group::Build the self-contained scripts"
node tasks --create
echo "::endgroup::"

echo "::group::Install ioBroker"
bash "$WORKSPACE/dist/install.sh" --silent
echo "::endgroup::"

echo "::group::File permissions"
bash "$WORKSPACE/.github/testFiles.sh"
echo "::endgroup::"

echo "::group::Admin reachable"
wait_for_admin
echo "::endgroup::"

# Installing this adapter needs python, so it also covers the python dependency
echo "::group::Install an adapter that requires python"
iobroker url iobroker.lovelace
echo "::endgroup::"

echo "::group::Stop ioBroker before running the fixer"
# Resolved here, not at the top: before the installation neither directory exists yet
IOB_DIR=$([ -d /opt/iobroker ] && echo "/opt/iobroker" || echo "/usr/local/iobroker")
cd "$IOB_DIR"
node node_modules/iobroker.js-controller/iobroker.js stop
sleep 60
cd "$WORKSPACE"
echo "::endgroup::"

echo "::group::Run the fixer"
bash "$WORKSPACE/dist/fix.sh"
echo "::endgroup::"

echo "::group::File permissions after the fixer"
bash "$WORKSPACE/.github/testFiles.sh"
echo "::endgroup::"

echo "FreeBSD installation test finished successfully"
