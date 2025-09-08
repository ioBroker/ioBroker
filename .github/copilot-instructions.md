# ioBroker Platform Installer

ioBroker is a comprehensive home automation and IoT integration platform installer and management system. This repository contains cross-platform installation scripts, diagnostic tools, and the NPX package for setting up complete ioBroker instances.

**Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.**

## Working Effectively

### Bootstrap and Build
- Install dependencies: `npm install` -- takes 30 seconds
- Build distribution scripts: `node tasks --create` -- takes 1 second. Creates scripts in `dist/` directory
- Lint code (DEPRECATED): ESLint config uses old .eslintrc.json format incompatible with ESLint 9.x. Do NOT run `npx eslint` - it will fail. Code quality checks are handled in CI.
- Test basic functionality: `node test.js` -- tests if admin interface is reachable on localhost:8081

### Installation Testing (Linux/macOS)
- **NEVER CANCEL**: Installation takes 6-10 minutes. NEVER CANCEL. Set timeout to 15+ minutes.
- Install ioBroker: `curl -sL https://iobroker.net/install.sh | bash -` -- takes 6-10 minutes. Creates system user, installs Node.js, sets up systemd service.
- Test installation: `chmod +x installer.sh && ./installer.sh` -- takes 6-10 minutes. NEVER CANCEL.
- Manual verification after install: `curl -s http://127.0.0.1:8081 | grep '<title>Admin</title>'` -- should return Admin interface

### Windows NPX Installation
- **NEVER CANCEL**: NPX installation takes 3-8 minutes. Set timeout to 12+ minutes.
- Create test directory: `mkdir C:\iobroker && cd C:\iobroker`
- Install via NPX: `npx @iobroker/install` -- downloads and installs ioBroker platform
- Windows service setup: `node install.js` -- registers Windows service
- Test: Start ioBroker service and verify admin interface

### Diagnostic Tools
- System diagnosis: `./diag.sh` -- comprehensive system health check
- Language options: `./diag.sh --de` for German output, `./diag.sh --help` for options
- Fix common issues: `./fix_installation.sh` -- repairs permissions, updates Node.js, compresses databases
- Node.js update: `./node-update.sh` -- updates Node.js to recommended version

## Validation

### Critical Validation Steps
- **ALWAYS** run complete installation test before making changes to installer scripts
- **NEVER CANCEL** long-running installations - they take 6-10 minutes minimum
- Test both Linux and Windows installation paths when modifying core logic
- **MANDATORY**: After any changes to installer scripts, run: `./installer.sh` and wait for completion
- Verify admin interface: `curl -s http://127.0.0.1:8081 | grep '<title>Admin</title>'`
- Check service status: `sudo systemctl status iobroker` on Linux

### Known Installation Issues
- SSL certificate errors: Use `npm install --strict-ssl=false` if npm fails with certificate errors
- File lock errors: Normal during installation, installer handles retries automatically
- Service startup delays: ioBroker service may take 1-2 minutes to fully start after installation

## Common Tasks

### Build and Deploy Scripts
The following are critical build operations:

#### Build Process
```bash
# Create distribution scripts (always run this after modifying source scripts)
node tasks --create

# Deploy to production (requires SFTP credentials)
npm run deploy
```

#### Script Structure
- `installer.sh` + `installer_library.sh` → `dist/install.sh` (combined)
- `fix_installation.sh` + `installer_library.sh` → `dist/fix.sh` (combined)
- `diag.sh` → `dist/diag.sh` (copied)
- `node-update.sh` → `dist/node-update.sh` (copied)

### Repository Structure
```bash
ls /                   # Repository root
.
..
README.md              # Project overview and installation instructions
package.json           # NPM package configuration
installer.sh           # Main Linux/macOS installation script
installer_library.sh   # Shared library functions
fix_installation.sh    # System repair and maintenance script
diag.sh               # Diagnostic tool
node-update.sh        # Node.js update utility
lib-npx/              # Windows NPX installation logic
  install.js          # Main NPX entry point
  installCopyFiles.js # File copying logic
  installSetup.js     # Service setup
  checkVersions.js    # Version validation
  tools.js           # Utility functions
install/windows/      # Windows-specific files
tasks.js             # Build and deploy script
test.js              # Basic functionality test
versions.json        # Supported Node.js/npm versions
.github/workflows/   # CI/CD pipelines
```

### Key Configuration Files

#### versions.json
```json
{
    "nodeJsAccepted": [18, 20, 22, 24],
    "nodeJsRecommended": 22,
    "npmRecommended": 10
}
```

#### package.json Dependencies
- Core: fs-extra, semver, yargs
- Dev: eslint (deprecated config), mocha, chai, ssh2
- Optional: dotenv, windows-shortcuts (Windows only)

### CI/CD Workflows
- `test.yml`: Runs installation tests on Ubuntu/macOS with Node.js 18/20/22/24
- `npx_install.yml`: Tests Windows NPX installation
- `deploy.yml`: Deploys scripts to production servers on release

### Development Guidelines
- **TIMING CRITICAL**: All installer operations are time-sensitive. NEVER use default timeouts.
- **PLATFORM AWARENESS**: Code must handle Linux, macOS, and Windows differences
- **USER SAFETY**: Installers create system users and services - test thoroughly
- **SSL ISSUES**: Common in CI environments - document workarounds
- **SERVICE DELAYS**: ioBroker service startup is slow - build in appropriate waits

### Troubleshooting
- Installation hangs: Normal - installations take 6-10 minutes, NEVER CANCEL
- npm SSL errors: Use `--strict-ssl=false` flag
- Service won't start: Check `/opt/iobroker` permissions and file ownership
- Admin not accessible: Wait 2-3 minutes after installation, service is slow to start
- File lock errors: Retry installation, installer handles this automatically

### Maintenance Commands
- Always run after making installer changes: `node tasks --create && ./installer.sh`
- Test Windows changes: Test NPX flow in Windows environment
- Verify CI compatibility: Check that changes work with GitHub Actions workflows
- Update documentation: Update README.md if installation process changes

## Changelog and Version Management

### Script-to-Changelog Mapping
When making changes to shell scripts, **ALWAYS** update the corresponding changelog file:

- `diag.sh` → `CHANGELOG_DIAG_LINUX.md`
- `fix_installation.sh` → `CHANGELOG_FIXER_LINUX.md`
- `installer.sh` → `CHANGELOG_INSTALLER_LINUX.md`
- `node-update.sh` → `CHANGELOG_NODE_UPDATER.md`

### Version Variables in Scripts
When modifying shell scripts, **ALWAYS** update the version variable to current date (YYYY-MM-DD format):

- `diag.sh`: Update `SKRIPTV="YYYY-MM-DD"`
- `fix_installation.sh`: Update `FIXER_VERSION="YYYY-MM-DD"`
- `installer.sh`: Update `INSTALLER_VERSION="YYYY-MM-DD"`
- `node-update.sh`: Update `VERSION="YYYY-MM-DD"`

### Changelog Update Process
1. **Before making script changes**: Note the current date in YYYY-MM-DD format
2. **When editing scripts**: Update the version variable to current date
3. **Document changes**: Add new entry at the top of corresponding changelog file:
   ```markdown
   ## YYYY-MM-DD
   * Single concise description of the change made in this PR
   ```
4. **One line per PR**: Each PR must have exactly ONE bullet point entry in the changelog - combine related changes into a single descriptive line
5. **Follow existing format**: Use same markdown style and bullet points as existing entries
6. **Be specific**: Describe what was changed, not just "updated script"

### Example Changelog Entry
```markdown
## 2025-09-08
* Updated GitHub Copilot integration instructions with one-line-per-PR requirement
```

## Critical Warnings
- **NEVER CANCEL BUILDS OR INSTALLATIONS** - They take 6-10 minutes minimum
- **ALWAYS SET LONG TIMEOUTS** - Use 15+ minutes for installation commands
- **SSL CERTIFICATE ISSUES ARE COMMON** - Use `--strict-ssl=false` for npm in CI
- **MANUAL VALIDATION IS MANDATORY** - Always test complete installation flow after changes